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
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'originalLanguage': {'type': 'string'},
      'prepTimeMinutes': {'type': 'integer'},
      'cookTimeMinutes': {'type': 'integer'},
      'totalTimeMinutes': {'type': 'integer'},
      'servingCount': {'type': 'integer'},
      'calories': {'type': 'number'},
      'protein': {'type': 'number'},
      'carbs': {'type': 'number'},
      'fat': {'type': 'number'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'ingredients': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'quantity': {'type': 'number'},
            'unit': {'type': 'string'},
            'notes': {'type': 'string'},
            'isOptional': {'type': 'boolean'}
          },
          'required': ['name']
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
      }
    },
    'required': ['title', 'ingredients', 'steps']
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
      combinedSource.writeln('--- SOURCE CAPTION & METADATA ---');
      combinedSource.writeln(caption.trim());
    }
    if (transcript != null && transcript.trim().isNotEmpty) {
      combinedSource.writeln('--- AUDIO TRANSCRIPT ---');
      combinedSource.writeln(transcript.trim());
    }

    if (combinedSource.isEmpty) {
      throw RecipeValidationException('No caption or audio transcript available to structure.');
    }

    final systemPrompt = '''
You are a master culinary data extraction engine for Foodies.
Your task is to extract a structured recipe from social media food reel captions and transcripts.

Strict Rules:
1. Extract the dish title faithfully in its original language.
2. List all ingredients mentioned with exact or estimated quantities, units, and optional status. Do NOT invent ingredients not mentioned.
3. List all cooking instructions in clear, logical, sequential steps (1, 2, 3...).
4. Extract prep and cooking times in minutes if mentioned; otherwise leave as null.
5. If the creator explicitly stated calories, protein, carbs, or fat, extract them. Otherwise leave as null.
6. Provide relevant category tags (e.g. "Italian", "Quick", "Dinner", "Vegetarian", "Dessert").
7. Output valid JSON matching the required schema. No Markdown wrapper, no conversational text.
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

          ingredients.add(
            Ingredient(
              id: _uuid.v4(),
              recipeId: recipeId,
              name: name,
              quantity: _safeDouble(item['quantity']),
              unit: item['unit']?.toString().trim(),
              notes: item['notes']?.toString().trim(),
              isOptional: item['isOptional'] == true || item['isOptional']?.toString().toLowerCase() == 'true',
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

      // Steps list normalization
      final rawSteps = json['steps'];
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

          steps.add(
            RecipeStep(
              id: _uuid.v4(),
              recipeId: recipeId,
              stepNumber: _safeInt(item['stepNumber'], defaultVal: i + 1)!,
              instruction: instruction,
              durationMinutes: _safeInt(item['durationMinutes']),
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

      // Tags normalization
      final rawTags = json['tags'];
      final rawTagsList = <String>[];
      if (rawTags is List) {
        for (final t in rawTags) {
          if (t != null) {
            final str = t.toString().trim();
            if (str.isNotEmpty) rawTagsList.add(str);
          }
        }
      } else if (rawTags is String && rawTags.trim().isNotEmpty) {
        rawTagsList.addAll(rawTags.split(RegExp(r'[,\n#]')).map((t) => t.trim()).where((t) => t.isNotEmpty));
      }

      final tags = rawTagsList
          .map((t) => RecipeTag(id: _uuid.v4(), name: t, category: _categorizeTag(t)))
          .toList();

      // Servings
      final parsedServing = _safeInt(json['servingCount'], defaultVal: 2)!;
      final servingCount = parsedServing > 0 ? parsedServing : 2;

      // Nutrition: check if explicitly stated by creator
      NutritionInfo nutrition;
      final statedCalories = _safeDouble(json['calories']);
      final statedProtein = _safeDouble(json['protein']);
      final statedCarbs = _safeDouble(json['carbs']);
      final statedFat = _safeDouble(json['fat']);

      if (statedCalories != null || statedProtein != null || statedCarbs != null || statedFat != null) {
        nutrition = NutritionInfo(
          calories: statedCalories,
          proteinGrams: statedProtein,
          carbsGrams: statedCarbs,
          fatGrams: statedFat,
          method: 'creator',
          confidence: 'high',
        );
      } else {
        // Estimate from ingredients using food composition database
        nutrition = NutritionCalculator.estimate(
          ingredients: ingredients,
          servingCount: servingCount,
        );
      }

      final now = DateTime.now();

      return Recipe(
        id: recipeId,
        title: title,
        description: json['description']?.toString().trim(),
        sourceUrl: sourceUrl,
        sourcePlatform: sourcePlatform,
        sourceCaption: sourceCaption,
        transcript: transcript,
        originalLanguage: json['originalLanguage']?.toString().trim() ?? 'en',
        imagePath: imagePath,
        prepTimeMinutes: _safeInt(json['prepTimeMinutes']),
        cookTimeMinutes: _safeInt(json['cookTimeMinutes']),
        totalTimeMinutes: _safeInt(json['totalTimeMinutes']),
        servingCount: servingCount,
        nutrition: nutrition,
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
