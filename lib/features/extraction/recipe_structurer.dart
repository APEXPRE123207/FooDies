import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/networking/ollama_client.dart';
import '../../core/utils/logger.dart';
import '../recipes/domain/models/ingredient.dart';
import '../recipes/domain/models/nutrition_info.dart';
import '../recipes/domain/models/recipe.dart';
import '../recipes/domain/models/recipe_step.dart';
import '../recipes/domain/models/recipe_tag.dart';
import 'nutrition_calculator.dart';

class RecipeValidationException implements Exception {
  final String message;
  RecipeValidationException(this.message);
  @override
  String toString() => message;
}

class RecipeStructurer {
  final OllamaClient _ollamaClient;
  final Uuid _uuid;

  RecipeStructurer({
    required OllamaClient ollamaClient,
    Uuid? uuid,
  })  : _ollamaClient = ollamaClient,
        _uuid = uuid ?? const Uuid();

  /// JSON Schema definition for Ollama Cloud structured outputs
  static const Map<String, dynamic> recipeJsonSchema = {
    'type': 'object',
    'properties': {
      'is_valid_recipe': {'type': 'boolean'},
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'difficulty': {'type': 'string'},
      'servings': {
        'type': 'object',
        'properties': {
          'amount': {'type': 'integer'},
          'is_estimated': {'type': 'boolean'}
        },
        'required': ['amount']
      },
      'times': {
        'type': 'object',
        'properties': {
          'prep_time_minutes': {'type': 'integer'},
          'cook_time_minutes': {'type': 'integer'},
          'total_time_minutes': {'type': 'integer'},
          'is_estimated': {'type': 'boolean'}
        }
      },
      'best_for': {
        'type': 'object',
        'properties': {
          'primary_badge': {'type': 'string'},
          'fitness_and_gym': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'diet_suitability': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'lifestyle_and_occasion': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'suitability_reason': {'type': 'string'}
        }
      },
      'nutrition_per_serving': {
        'type': 'object',
        'properties': {
          'calories': {'type': 'number'},
          'protein_g': {'type': 'number'},
          'carbs_g': {'type': 'number'},
          'fat_g': {'type': 'number'},
          'fiber_g': {'type': 'number'},
          'macro_profile': {'type': 'string'},
          'is_estimated': {'type': 'boolean'}
        }
      },
      'ingredients': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'quantity': {'type': 'number'},
            'unit': {'type': 'string'},
            'prep_note': {'type': 'string'},
            'notes': {'type': 'string'},
            'is_optional': {'type': 'boolean'},
            'isOptional': {'type': 'boolean'},
            'is_estimated': {'type': 'boolean'}
          },
          'required': ['name']
        }
      },
      'instructions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'step_number': {'type': 'integer'},
            'stepNumber': {'type': 'integer'},
            'instruction': {'type': 'string'},
            'timer_minutes': {'type': 'integer'},
            'durationMinutes': {'type': 'integer'}
          },
          'required': ['instruction']
        }
      },
      'steps': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'stepNumber': {'type': 'integer'},
            'instruction': {'type': 'string'},
            'durationMinutes': {'type': 'integer'}
          },
          'required': ['stepNumber', 'instruction']
        }
      },
      'tags': {
        'type': 'object',
        'properties': {
          'cuisine': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'meal_type': {
            'type': 'array',
            'items': {'type': 'string'}
          },
          'cooking_method': {
            'type': 'array',
            'items': {'type': 'string'}
          }
        }
      },
      'search_keywords': {
        'type': 'array',
        'items': {'type': 'string'}
      }
    },
    'required': ['title', 'ingredients']
  };

  /// Main entry point: takes caption and optional transcript, queries Ollama Cloud, validates, and builds Recipe
  Future<Recipe> structureRecipe({
    required String? caption,
    required String? transcript,
    String? sourceUrl,
    String? sourcePlatform,
    String? imagePath,
  }) async {
    final combinedSource = StringBuffer();
    if (caption != null && caption.trim().isNotEmpty) {
      combinedSource.writeln('--- WRITTEN POST CAPTION & DESCRIPTION ---');
      combinedSource.writeln(caption.trim());
      combinedSource.writeln();
    }
    if (transcript != null && transcript.trim().isNotEmpty) {
      combinedSource.writeln('--- SPOKEN VIDEO AUDIO TRANSCRIPT (SPEECH EXTRACTED FROM VIDEO) ---');
      combinedSource.writeln(transcript.trim());
      combinedSource.writeln();
    }

    if (combinedSource.isEmpty) {
      throw RecipeValidationException('No caption or audio transcript available to structure.');
    }
    final systemPrompt = '''
You are an elite Culinary & Nutritional Data Extraction Engine for the "Foodies" platform. 
You will always receive two inputs from a social media food reel:
1. CAPTION: The written post description.
2. AUDIO TRANSCRIPT: The auto-generated speech-to-text transcript from the video's audio.

Your objective is to synthesize both sources into clean, reliable, kitchen-ready structured JSON recipe data with smart fitness, diet, and lifestyle categorization.

### CORE EXTRACTION & INFERENCE RULES

1. Source Synthesis & "Comment-for-DM" Recovery:
   - Treat the CAPTION and AUDIO TRANSCRIPT as two halves of a single dataset. Cross-reference both to capture every ingredient, quantity, and tip.
   - "COMMENT FOR DM" RECOVERY: Creators frequently gatekeep the written caption (e.g., "Comment PROTEIN and I'll DM you the recipe!") while speaking the actual recipe in the video audio. When the caption is promotional or lacks details, rely 100% on the AUDIO TRANSCRIPT to extract the recipe.
   - TRANSCRIPT TYPO CORRECTION: Audio transcripts are auto-generated and often contain phonetic speech-to-text errors (e.g., "paneer" -> "pioneer", "besan" -> "basin", "ghee" -> "gee", "soy chunks" -> "saw chunks", "1 tsp cumin" -> "1,000 human"). Use culinary context to automatically correct phonetic transcription errors into proper ingredient names and cooking terms.
   - TRUE INVALID FALLBACK & ZERO-HALLUCINATION POLICY:
     * If NEITHER the caption NOR the audio transcript provides recipe ingredients or preparation instructions (e.g., the caption is promotional like "Comment RECIPE" or "Watch till end" AND no audio transcript was captured), DO NOT INVENT OR HALLUCINATE A RECIPE!
     * Under NO circumstances should you fabricate cooking steps or ingredients that were neither written nor spoken.
     * In such cases, you MUST set `"is_valid_recipe": false`, `"ingredients": []`, and `"instructions": []`.

2. Dish Title & Description:
   - Extract the dish title faithfully in its original language, stripping away promotional clutter, emojis, and clickbait (e.g., convert "OMG Best Ever 10-Min Garlic Noodles!! 🔥🍜" to "Garlic Noodles").
   - If neither source has an explicit title, infer a concise, appetizing culinary title based on the primary ingredients and technique.
   - Generate a brief, 1-2 sentence appetizing summary of the dish.

3. Ingredients (Strict Grounding + Smart Quantity Inference):
   - Extract every ingredient mentioned in EITHER the caption OR the transcript.
   - Do NOT invent or hallucinate ingredients that are not mentioned or clearly implied.
   - Normalize quantities and units into standard culinary measurements (e.g., convert "a splash" to "1 tbsp", "a pinch" to "1/8 tsp", "1 scoop" to "30 g").
   - If an ingredient is mentioned without a quantity, provide a logical culinary estimate based on the dish's scale and set `"is_estimated": true`. If stated by the creator, set `"is_estimated": false`.
   - Flag garnishes, "to taste" items, or optional additions with `"is_optional": true`.
   - Separate preparation notes from the ingredient name (e.g., `"name": "chicken breast"`, `"prep_note": "diced into 1-inch cubes"`).

4. Cooking Instructions (Sequential & Actionable):
   - Synthesize the caption and transcript into clear, logical, chronological steps (1, 2, 3...).
   - Filter out social media banter, sponsor plugs, and calls to action ("Link in bio", "Comment RECIPE", "Follow for more").
   - Write in clear, imperative culinary language. Extract any time mentioned in a specific step into `"timer_minutes"`.

5. Time & Yield Estimation (Mandatory Fallback):
   - Extract `prep_time_minutes`, `cook_time_minutes`, and `servings` if explicitly stated in either source.
   - CRITICAL FALLBACK: If times or servings are NOT mentioned, calculate a realistic culinary approximation based on the ingredients, prep work, and cooking method. Never leave time fields as null.
   - Set `"is_estimated": true` whenever you approximate, and `false` when explicitly stated.

6. Nutritional Data (Extract or Estimate per Serving):
   - If the creator explicitly states `calories`, `protein_g`, `carbs_g`, or `fat_g` in the caption or transcript, extract them and set `"is_estimated": false`.
   - SMART FALLBACK: If macros are NOT stated by the creator, calculate a reasonable nutritional estimate per serving based on the extracted ingredient quantities and cooking method (accounting for cooking oils/butter/sauces), and set `"is_estimated": true`.

7. "Best For" Fitness, Diet & Lifestyle Suitability:
   - Analyze the ingredients, cooking method, and macros per serving to classify what the recipe is **Best For** across three distinct lenses:
     * `fitness_and_gym`: Evaluate objectively using nutritional logic (do not blindly trust creator hype):
       - "Muscle Gain / Bulking": High calorie (>500 kcal) AND high protein (>30g protein/serving).
       - "Fat Loss / Cutting": High volume, controlled calories (<450 kcal/serving), high protein-to-calorie ratio (at least 1g protein per 12-15 kcal).
       - "Pre-Workout Fuel": Moderate-to-high fast/complex carbs, low-to-moderate fat, easy to digest.
       - "Post-Workout Recovery": High protein (>25g) paired with moderate-to-high carbs to replenish glycogen.
       - "High-Protein Snack": Portable or quick snack with >15g protein.
       - "Cheat Meal / Treat": High calorie, high sugar, or deep-fried indulgent dishes.
     * `diet_suitability`: Strictly verify against all ingredients (including hidden sauces/oils):
       - Examples: "Clean Eating", "Keto-Friendly" (<10g net carbs), "Low-Carb", "Low-Calorie", "Low-Fat", "High-Fiber", "Gut-Healthy", "Diabetic-Friendly" (low glycemic index, no refined sugar), "Vegetarian", "Vegan", "Eggetarian", "Jain-Friendly", "Gluten-Free", "Dairy-Free", "Lactose-Free".
     * `lifestyle_and_occasion`: Practical real-life scenarios this dish is best suited for:
       - Examples: "Hostel / Dorm Friendly" (minimal equipment like kettle/induction, basic ingredients), "Bachelor / Beginner Friendly", "Meal Prep / Tiffin Box" (reheats well), "Late-Night Cravings", "10-Minute Busy Weeknight", "Budget-Friendly", "Kids Lunchbox", "Party / Game Night", "Date Night".
   - Generate a 1-sentence `"suitability_reason"` explaining *why* this dish fits those badges.

8. Multi-Dimensional Culinary Tags:
   - `cuisine`: e.g., "Indian", "Italian", "Mexican", "Korean", "Mediterranean", "Pan-Asian", "Continental".
   - `meal_type`: e.g., "Breakfast", "Lunch", "Dinner", "Snack", "Pre-Workout", "Post-Workout", "Dessert", "Beverage", "Side Dish".
   - `cooking_method`: e.g., "Air Fryer", "One-Pot", "No-Cook", "Pan-Seared", "Baked", "Stir-Fry", "Grilled", "Pressure Cooker", "Blender Only".

### OUTPUT FORMAT
Output ONLY raw, valid JSON matching the exact schema below. Do NOT wrap the output in Markdown code blocks (no ```json), and do NOT include any conversational text.

{
  "is_valid_recipe": boolean,
  "title": "string",
  "description": "string",
  "servings": {
    "amount": number,
    "is_estimated": boolean
  },
  "times": {
    "prep_time_minutes": number,
    "cook_time_minutes": number,
    "total_time_minutes": number,
    "is_estimated": boolean
  },
  "difficulty": "Easy" | "Medium" | "Hard",
  "best_for": {
    "primary_badge": "string",
    "fitness_and_gym": ["string"],
    "diet_suitability": ["string"],
    "lifestyle_and_occasion": ["string"],
    "suitability_reason": "string"
  },
  "nutrition_per_serving": {
    "calories": number,
    "protein_g": number,
    "carbs_g": number,
    "fat_g": number,
    "fiber_g": number | null,
    "macro_profile": "High-Protein" | "Balanced" | "High-Carb" | "Keto / High-Fat" | "Indulgent / Cheat",
    "is_estimated": boolean
  },
  "ingredients": [
    {
      "name": "string",
      "quantity": number | null,
      "unit": "string | null",
      "prep_note": "string | null",
      "is_optional": boolean,
      "is_estimated": boolean
    }
  ],
  "instructions": [
    {
      "step_number": number,
      "instruction": "string",
      "timer_minutes": number | null
    }
  ],
  "tags": {
    "cuisine": ["string"],
    "meal_type": ["string"],
    "cooking_method": ["string"]
  },
  "search_keywords": ["string"]
}
''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': combinedSource.toString()},
    ];

    AppLogger.info('Structuring recipe via Ollama Cloud...');
    final response = await _ollamaClient.chat(
      messages: messages,
      schemaFormat: recipeJsonSchema,
    );

    // Attempt parsing and validation
    try {
      return _parseAndValidate(
        rawContent: response.content,
        sourceUrl: sourceUrl,
        sourcePlatform: sourcePlatform,
        sourceCaption: caption,
        transcript: transcript,
        imagePath: imagePath,
      );
    } catch (firstError) {
      AppLogger.error('Initial recipe parsing failed, attempting corrective prompt: $firstError');

      // Stage E.1: Corrective retry
      final correctiveMessages = [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': combinedSource.toString()},
        {'role': 'assistant', 'content': response.content},
        {
          'role': 'user',
          'content': 'Your previous JSON response was invalid: $firstError. Please fix and return strictly valid JSON matching the schema.'
        }
      ];

      final retryResponse = await _ollamaClient.chat(
        messages: correctiveMessages,
        schemaFormat: recipeJsonSchema,
      );

      return _parseAndValidate(
        rawContent: retryResponse.content,
        sourceUrl: sourceUrl,
        sourcePlatform: sourcePlatform,
        sourceCaption: caption,
        transcript: transcript,
        imagePath: imagePath,
      );
    }
  }

  Recipe _parseAndValidate({
    required String rawContent,
    String? sourceUrl,
    String? sourcePlatform,
    String? sourceCaption,
    String? transcript,
    String? imagePath,
  }) {
    final cleanJson = _cleanJsonString(rawContent);
    Map<String, dynamic> json;
    try {
      dynamic decoded = jsonDecode(cleanJson);
      // In case the model double-encoded the JSON string
      if (decoded is String) {
        decoded = jsonDecode(_cleanJsonString(decoded));
      }
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      } else {
        throw RecipeValidationException('Expected a JSON map object from model, but got ${decoded.runtimeType}');
      }
    } catch (e) {
      throw RecipeValidationException('Failed to decode JSON from AI model: $e');
    }

    try {
      // Validate if AI flagged as not a recipe
      if (json['is_valid_recipe'] == false) {
        throw RecipeValidationException(
          'The post does not appear to contain a culinary recipe or cooking demonstration.',
        );
      }

      // Validate Title
      final title = json['title']?.toString().trim();
      if (title == null || title.isEmpty) {
        throw RecipeValidationException('Recipe title is missing or empty.');
      }

      // Ingredients list normalization
      final rawIngredients = json['ingredients'];
      final ingredientsRawList = <dynamic>[];
      if (rawIngredients is List) {
        ingredientsRawList.addAll(rawIngredients);
      } else if (rawIngredients is String && rawIngredients.trim().isNotEmpty) {
        ingredientsRawList.addAll(rawIngredients.split(RegExp(r'\r?\n|;')).where((s) => s.trim().isNotEmpty));
      }

      if (ingredientsRawList.isEmpty) {
        throw RecipeValidationException('At least one ingredient is required.');
      }

      final recipeId = _uuid.v4();
      final ingredients = <Ingredient>[];
      for (var i = 0; i < ingredientsRawList.length; i++) {
        final rawItem = ingredientsRawList[i];
        if (rawItem == null) continue;

        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          final name = item['name']?.toString().trim();
          if (name == null || name.isEmpty) continue;

          final note = (item['prep_note'] ?? item['notes'])?.toString().trim();
          final isOpt = item['is_optional'] == true ||
              item['isOptional'] == true ||
              item['is_optional']?.toString().toLowerCase() == 'true' ||
              item['isOptional']?.toString().toLowerCase() == 'true';

          ingredients.add(
            Ingredient(
              id: _uuid.v4(),
              recipeId: recipeId,
              name: name,
              quantity: _safeDouble(item['quantity']),
              unit: item['unit']?.toString().trim(),
              notes: note != null && note.isNotEmpty ? note : null,
              isOptional: isOpt,
              isEstimated: item['is_estimated'] == true,
              sortOrder: i,
            ),
          );
        } else if (rawItem is String && rawItem.trim().isNotEmpty) {
          ingredients.add(_parseIngredientString(rawItem.trim(), recipeId, i));
        }
      }

      if (ingredients.isEmpty) {
        throw RecipeValidationException('All extracted ingredients had empty names.');
      }

      // Steps / Instructions list normalization (supports 'instructions' or legacy 'steps')
      final rawSteps = json['instructions'] ?? json['steps'];
      final stepsRawList = <dynamic>[];
      if (rawSteps is List) {
        stepsRawList.addAll(rawSteps);
      } else if (rawSteps is String && rawSteps.trim().isNotEmpty) {
        stepsRawList.addAll(rawSteps.split(RegExp(r'\r?\n(?=\d+[\.\)]|\bstep\b)|\r?\n{2,}')).where((s) => s.trim().isNotEmpty));
      }

      if (stepsRawList.isEmpty) {
        throw RecipeValidationException('At least one cooking step is required.');
      }

      final steps = <RecipeStep>[];
      for (var i = 0; i < stepsRawList.length; i++) {
        final rawItem = stepsRawList[i];
        if (rawItem == null) continue;

        if (rawItem is Map) {
          final item = Map<String, dynamic>.from(rawItem);
          final instruction = item['instruction']?.toString().trim();
          if (instruction == null || instruction.isEmpty) continue;

          final stepNum = _safeInt(item['step_number'] ?? item['stepNumber'], defaultVal: i + 1)!;
          final duration = _safeInt(item['timer_minutes'] ?? item['durationMinutes']);

          steps.add(
            RecipeStep(
              id: _uuid.v4(),
              recipeId: recipeId,
              stepNumber: stepNum,
              instruction: instruction,
              durationMinutes: duration,
            ),
          );
        } else if (rawItem is String && rawItem.trim().isNotEmpty) {
          final clean = rawItem.replaceAll(RegExp(r'^(?:step\s*)?\d+[\.:\s]+', caseSensitive: false), '').trim();
          steps.add(
            RecipeStep(
              id: _uuid.v4(),
              recipeId: recipeId,
              stepNumber: i + 1,
              instruction: clean.isNotEmpty ? clean : rawItem.trim(),
            ),
          );
        }
      }

      if (steps.isEmpty) {
        throw RecipeValidationException('All extracted steps had empty instructions.');
      }

      // Servings (supports {amount: 2} or legacy servingCount: 2)
      int? parsedServing;
      if (json['servings'] is Map) {
        parsedServing = _safeInt(json['servings']['amount']);
      } else if (json['servings'] != null) {
        parsedServing = _safeInt(json['servings']);
      }
      parsedServing ??= _safeInt(json['servingCount'], defaultVal: 2);
      final servingCount = (parsedServing != null && parsedServing > 0) ? parsedServing : 2;

      // Times (supports times object or legacy prepTimeMinutes, etc.)
      int? prepTime;
      int? cookTime;
      int? totalTime;
      bool isTimeEstimated = false;

      if (json['times'] is Map) {
        final timesMap = json['times'] as Map;
        prepTime = _safeInt(timesMap['prep_time_minutes']);
        cookTime = _safeInt(timesMap['cook_time_minutes']);
        totalTime = _safeInt(timesMap['total_time_minutes']);
        isTimeEstimated = timesMap['is_estimated'] == true;
      }
      prepTime ??= _safeInt(json['prepTimeMinutes']);
      cookTime ??= _safeInt(json['cookTimeMinutes']);
      totalTime ??= _safeInt(json['totalTimeMinutes']);
      if (totalTime == null && (prepTime != null || cookTime != null)) {
        totalTime = (prepTime ?? 0) + (cookTime ?? 0);
      }

      // Nutrition: check creator stated or AI-extracted values
      NutritionInfo nutrition;
      Map<String, dynamic>? nutritionMap;
      if (json['nutrition_per_serving'] is Map) {
        nutritionMap = Map<String, dynamic>.from(json['nutrition_per_serving'] as Map);
      }

      final statedCalories = _safeDouble(nutritionMap?['calories'] ?? json['calories']);
      final statedProtein = _safeDouble(nutritionMap?['protein_g'] ?? nutritionMap?['protein'] ?? json['protein']);
      final statedCarbs = _safeDouble(nutritionMap?['carbs_g'] ?? nutritionMap?['carbs'] ?? json['carbs']);
      final statedFat = _safeDouble(nutritionMap?['fat_g'] ?? nutritionMap?['fat'] ?? json['fat']);

      if (statedCalories != null || statedProtein != null || statedCarbs != null || statedFat != null) {
        final isEstimated = nutritionMap?['is_estimated'] == true;
        nutrition = NutritionInfo(
          calories: statedCalories,
          proteinGrams: statedProtein,
          carbsGrams: statedCarbs,
          fatGrams: statedFat,
          method: isEstimated ? 'estimated' : 'creator',
          confidence: isEstimated ? 'medium' : 'high',
        );
      } else {
        // Estimate from ingredients using food composition database
        nutrition = NutritionCalculator.estimate(
          ingredients: ingredients,
          servingCount: servingCount,
        );
      }

      // Tags normalization & fitness / diet / lifestyle classification extraction
      final tags = <RecipeTag>[];
      final seenTagNames = <String>{};

      void addTag(String? rawName, String defaultCategory) {
        if (rawName == null) return;
        final name = rawName.trim();
        if (name.isEmpty) return;
        final lower = name.toLowerCase();
        if (seenTagNames.contains(lower)) return;
        seenTagNames.add(lower);
        tags.add(RecipeTag(id: _uuid.v4(), name: name, category: defaultCategory));
      }

      final rawTags = json['tags'];
      if (rawTags is Map) {
        for (final entry in rawTags.entries) {
          final cat = entry.key.toString().trim();
          final val = entry.value;
          if (val is List) {
            for (final item in val) {
              addTag(item?.toString(), cat);
            }
          } else if (val is String) {
            addTag(val, cat);
          }
        }
      } else if (rawTags is List) {
        for (final t in rawTags) {
          if (t != null) {
            final str = t.toString().trim();
            if (str.isNotEmpty) addTag(str, _categorizeTag(str));
          }
        }
      } else if (rawTags is String && rawTags.trim().isNotEmpty) {
        for (final t in rawTags.split(RegExp(r'[,\n#]'))) {
          final str = t.trim();
          if (str.isNotEmpty) addTag(str, _categorizeTag(str));
        }
      }

      // Best For badges
      final bestFor = json['best_for'];
      if (bestFor is Map) {
        addTag(bestFor['primary_badge']?.toString(), 'fitness');
        if (bestFor['fitness_and_gym'] is List) {
          for (final item in (bestFor['fitness_and_gym'] as List)) {
            addTag(item?.toString(), 'fitness');
          }
        }
        if (bestFor['diet_suitability'] is List) {
          for (final item in (bestFor['diet_suitability'] as List)) {
            addTag(item?.toString(), 'diet');
          }
        }
        if (bestFor['lifestyle_and_occasion'] is List) {
          for (final item in (bestFor['lifestyle_and_occasion'] as List)) {
            addTag(item?.toString(), 'lifestyle');
          }
        }
      }

      // Search keywords
      final keywords = json['search_keywords'];
      if (keywords is List) {
        for (final item in keywords) {
          addTag(item?.toString(), 'keyword');
        }
      }

      // Description & Suitability Reason
      String? description = json['description']?.toString().trim();
      final suitabilityReason = (bestFor is Map) ? bestFor['suitability_reason']?.toString().trim() : null;
      if (suitabilityReason != null && suitabilityReason.isNotEmpty) {
        if (description == null || description.isEmpty) {
          description = suitabilityReason;
        } else if (!description.contains(suitabilityReason)) {
          description = '$description\n\nBest for: $suitabilityReason';
        }
      }

      final primaryBadge = (bestFor is Map) ? bestFor['primary_badge']?.toString().trim() : null;
      final macroProfile = (nutritionMap != null) ? nutritionMap['macro_profile']?.toString().trim() : null;

      final now = DateTime.now();

      return Recipe(
        id: recipeId,
        title: title,
        description: description,
        sourceUrl: sourceUrl,
        sourcePlatform: sourcePlatform,
        sourceCaption: sourceCaption,
        transcript: transcript,
        originalLanguage: json['originalLanguage']?.toString().trim() ?? 'en',
        imagePath: imagePath,
        prepTimeMinutes: prepTime,
        cookTimeMinutes: cookTime,
        totalTimeMinutes: totalTime,
        isTimeEstimated: isTimeEstimated,
        servingCount: servingCount,
        nutrition: nutrition,
        primaryBadge: (primaryBadge != null && primaryBadge.isNotEmpty) ? primaryBadge : null,
        suitabilityReason: (suitabilityReason != null && suitabilityReason.isNotEmpty) ? suitabilityReason : null,
        macroProfile: (macroProfile != null && macroProfile.isNotEmpty) ? macroProfile : null,
        isFavorite: false,
        extractionConfidence: 0.95,
        createdAt: now,
        updatedAt: now,
        ingredients: ingredients,
        steps: steps,
        tags: tags,
      );
    } on RecipeValidationException {
      rethrow;
    } catch (e) {
      throw RecipeValidationException('Recipe parsing error: $e');
    }
  }

  int? _safeInt(dynamic val, {int? defaultVal}) {
    if (val == null) return defaultVal;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      final digits = RegExp(r'\d+').firstMatch(val)?.group(0);
      if (digits != null) return int.tryParse(digits) ?? defaultVal;
    }
    return defaultVal;
  }

  double? _safeDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is num) return val.toDouble();
    if (val is String) {
      final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(val)?.group(0);
      if (match != null) return double.tryParse(match);
    }
    return null;
  }

  String _cleanJsonString(String raw) {
    var s = raw.trim();
    // 1. If wrapped in markdown code fence (even with conversational text before/after)
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false).firstMatch(s);
    if (codeBlockMatch != null && codeBlockMatch.group(1) != null) {
      s = codeBlockMatch.group(1)!.trim();
    } else {
      // 2. Extract outermost { ... }
      final firstBrace = s.indexOf('{');
      final lastBrace = s.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        s = s.substring(firstBrace, lastBrace + 1).trim();
      }
    }
    return s;
  }

  String _categorizeTag(String tagName) {
    final lower = tagName.toLowerCase();
    if (lower.contains('italian') ||
        lower.contains('mexican') ||
        lower.contains('indian') ||
        lower.contains('chinese') ||
        lower.contains('thai') ||
        lower.contains('japanese') ||
        lower.contains('american') ||
        lower.contains('french') ||
        lower.contains('mediterranean')) {
      return 'cuisine';
    }
    if (lower.contains('breakfast') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('dessert') ||
        lower.contains('snack')) {
      return 'meal_type';
    }
    if (lower.contains('vegan') ||
        lower.contains('vegetarian') ||
        lower.contains('keto') ||
        lower.contains('gluten-free') ||
        lower.contains('low carb') ||
        lower.contains('healthy')) {
      return 'diet';
    }
    if (lower.contains('bake') ||
        lower.contains('fry') ||
        lower.contains('grill') ||
        lower.contains('air fryer') ||
        lower.contains('slow cook') ||
        lower.contains('one pot')) {
      return 'method';
    }
    return 'general';
  }

  Ingredient _parseIngredientString(String raw, String recipeId, int sortOrder) {
    final match = RegExp(r'^(\d+(?:\.\d+)?|\d+\/\d+)\s*([a-zA-Z]+)?\s+(.+)$').firstMatch(raw);
    if (match != null) {
      final qtyStr = match.group(1);
      final unitStr = match.group(2);
      final nameStr = match.group(3);

      double? qty;
      if (qtyStr != null) {
        if (qtyStr.contains('/')) {
          final parts = qtyStr.split('/');
          final n = double.tryParse(parts[0]);
          final d = double.tryParse(parts[1]);
          if (n != null && d != null && d != 0) {
            qty = n / d;
          }
        } else {
          qty = double.tryParse(qtyStr);
        }
      }

      return Ingredient(
        id: _uuid.v4(),
        recipeId: recipeId,
        name: nameStr?.trim() ?? raw,
        quantity: qty,
        unit: unitStr?.trim(),
        sortOrder: sortOrder,
      );
    }

    return Ingredient(
      id: _uuid.v4(),
      recipeId: recipeId,
      name: raw,
      sortOrder: sortOrder,
    );
  }
}
