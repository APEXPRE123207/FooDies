import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/networking/ollama_client.dart';
import 'package:foodies/core/networking/ollama_models.dart';
import 'package:foodies/core/storage/secure_storage_service.dart';
import 'package:foodies/features/extraction/recipe_structurer.dart';

class MockOllamaClient extends OllamaClient {
  final List<String> mockResponses;
  int callCount = 0;

  MockOllamaClient(this.mockResponses)
      : super(storage: SecureStorageService());

  @override
  Future<OllamaChatResponse> chat({
    required List<Map<String, String>> messages,
    String? model,
    Map<String, dynamic>? schemaFormat,
    bool forceJsonFormat = true,
  }) async {
    final responseContent = mockResponses[callCount % mockResponses.length];
    callCount++;
    return OllamaChatResponse(
      model: model ?? 'llama3.2',
      content: responseContent,
    );
  }
}

void main() {
  group('RecipeStructurer & Ollama Structured Output Validation Tests', () {
    test('successfully parses valid Ollama Cloud JSON schema response', () async {
      final sampleJson = jsonEncode({
        'title': 'Garlic Butter Shrimp Pasta',
        'description': 'Quick weeknight dinner with succulent shrimp.',
        'originalLanguage': 'en',
        'prepTimeMinutes': 10,
        'cookTimeMinutes': 12,
        'totalTimeMinutes': 22,
        'servingCount': 2,
        'calories': 580,
        'protein': 38,
        'carbs': 62,
        'fat': 18,
        'tags': ['Italian', 'Quick', 'Dinner'],
        'ingredients': [
          {'name': 'shrimp', 'quantity': 300, 'unit': 'g', 'notes': 'peeled and deveined'},
          {'name': 'pasta', 'quantity': 200, 'unit': 'g', 'notes': 'linguine'},
          {'name': 'butter', 'quantity': 2, 'unit': 'tbsp'},
          {'name': 'garlic', 'quantity': 3, 'unit': 'clove', 'notes': 'minced'},
        ],
        'steps': [
          {'stepNumber': 1, 'instruction': 'Boil linguine in salted water until al dente.', 'durationMinutes': 9},
          {'stepNumber': 2, 'instruction': 'Sauté garlic in butter until fragrant, then add shrimp until pink.', 'durationMinutes': 3},
          {'stepNumber': 3, 'instruction': 'Toss pasta directly into the garlic butter pan with a splash of pasta water.', 'durationMinutes': 2},
        ],
      });

      final mockClient = MockOllamaClient([sampleJson]);
      final structurer = RecipeStructurer(ollamaClient: mockClient);

      final recipe = await structurer.structureRecipe(
        caption: 'Garlic butter shrimp pasta ingredients...',
        transcript: null,
        sourceUrl: 'https://instagram.com/reel/SHRIMP_PASTA',
        sourcePlatform: 'instagram',
      );

      expect(recipe.title, 'Garlic Butter Shrimp Pasta');
      expect(recipe.ingredients.length, 4);
      expect(recipe.steps.length, 3);
      expect(recipe.prepTimeMinutes, 10);
      expect(recipe.cookTimeMinutes, 12);
      expect(recipe.nutrition.calories, 580);
      expect(recipe.nutrition.method, 'creator');
      expect(recipe.tags.length, 3);
      expect(recipe.tags.first.name, 'Italian');
    });

    test('retries with corrective prompt when initial output is malformed', () async {
      // 1st response: malformed JSON (missing closing brace and title)
      const badJson = '{"description": "Incomplete';
      // 2nd response: corrected valid JSON
      final goodJson = jsonEncode({
        'title': 'Crispy Fried Chicken',
        'ingredients': [
          {'name': 'chicken', 'quantity': 500, 'unit': 'g'},
          {'name': 'flour', 'quantity': 1, 'unit': 'cup'},
        ],
        'steps': [
          {'stepNumber': 1, 'instruction': 'Dredge in flour and deep fry for 12 mins.', 'durationMinutes': 12},
        ],
      });

      final mockClient = MockOllamaClient([badJson, goodJson]);
      final structurer = RecipeStructurer(ollamaClient: mockClient);

      final recipe = await structurer.structureRecipe(
        caption: 'Fried chicken recipe video caption...',
        transcript: null,
      );

      expect(mockClient.callCount, 2); // Confirms corrective retry occurred!
      expect(recipe.title, 'Crispy Fried Chicken');
      expect(recipe.ingredients.length, 2);
    });

    test('throws RecipeValidationException when required fields remain missing', () async {
      final invalidJson = jsonEncode({
        'title': '', // empty title
        'ingredients': [], // no ingredients
        'steps': [],
      });

      final mockClient = MockOllamaClient([invalidJson, invalidJson]);
      final structurer = RecipeStructurer(ollamaClient: mockClient);

      expect(
        () async => await structurer.structureRecipe(
          caption: 'Empty or broken caption',
          transcript: null,
        ),
        throwsA(isA<RecipeValidationException>()),
      );
    });

    test('successfully parses new rich schema with instructions, best_for badges, and times', () async {
      final newSchemaJson = jsonEncode({
        'is_valid_recipe': true,
        'title': 'High Protein Paneer Tikka',
        'description': 'Smoky oven baked paneer cubes packed with protein.',
        'servings': {'amount': 3, 'is_estimated': false},
        'times': {
          'prep_time_minutes': 15,
          'cook_time_minutes': 20,
          'total_time_minutes': 35,
          'is_estimated': false
        },
        'difficulty': 'Easy',
        'best_for': {
          'primary_badge': 'Muscle Gain / Bulking',
          'fitness_and_gym': ['Muscle Gain / Bulking', 'Post-Workout Recovery'],
          'diet_suitability': ['Vegetarian', 'High-Protein', 'Gluten-Free'],
          'lifestyle_and_occasion': ['Bachelor / Beginner Friendly', 'Meal Prep / Tiffin Box'],
          'suitability_reason': 'Delivers 35g of vegetarian protein with minimal prep.'
        },
        'nutrition_per_serving': {
          'calories': 380,
          'protein_g': 32.5,
          'carbs_g': 12.0,
          'fat_g': 22.0,
          'macro_profile': 'High-Protein',
          'is_estimated': false
        },
        'ingredients': [
          {
            'name': 'paneer',
            'quantity': 400,
            'unit': 'g',
            'prep_note': 'cut into 1-inch cubes',
            'is_optional': false,
            'is_estimated': false
          },
          {
            'name': 'Greek yogurt',
            'quantity': 0.5,
            'unit': 'cup',
            'prep_note': 'for marinade',
            'is_optional': false,
            'is_estimated': false
          },
          {
            'name': 'tikka masala spices',
            'quantity': 2,
            'unit': 'tbsp',
            'prep_note': null,
            'is_optional': false,
            'is_estimated': false
          }
        ],
        'instructions': [
          {
            'step_number': 1,
            'instruction': 'Mix Greek yogurt and spices in a large bowl.',
            'timer_minutes': 3
          },
          {
            'step_number': 2,
            'instruction': 'Coat paneer cubes evenly and marinate for 15 minutes.',
            'timer_minutes': 15
          },
          {
            'step_number': 3,
            'instruction': 'Bake or air fry at 200C until edges are charred.',
            'timer_minutes': 12
          }
        ],
        'tags': {
          'cuisine': ['Indian'],
          'meal_type': ['Lunch', 'Dinner'],
          'cooking_method': ['Air Fryer', 'Baked']
        },
        'search_keywords': ['paneer', 'tikka', 'high protein']
      });

      final mockClient = MockOllamaClient([newSchemaJson]);
      final structurer = RecipeStructurer(ollamaClient: mockClient);

      final recipe = await structurer.structureRecipe(
        caption: 'High protein paneer tikka recipe...',
        transcript: 'Today we are making high protein paneer tikka...',
      );

      expect(recipe.title, 'High Protein Paneer Tikka');
      expect(recipe.servingCount, 3);
      expect(recipe.prepTimeMinutes, 15);
      expect(recipe.cookTimeMinutes, 20);
      expect(recipe.totalTimeMinutes, 35);
      expect(recipe.ingredients.length, 3);
      expect(recipe.ingredients[0].notes, 'cut into 1-inch cubes');
      expect(recipe.steps.length, 3);
      expect(recipe.steps[0].instruction, 'Mix Greek yogurt and spices in a large bowl.');
      expect(recipe.steps[0].durationMinutes, 3);
      expect(recipe.nutrition.calories, 380);
      expect(recipe.nutrition.proteinGrams, 32.5);
      expect(recipe.tags.any((t) => t.name == 'Indian' && t.category == 'cuisine'), isTrue);
      expect(recipe.tags.any((t) => t.name == 'Muscle Gain / Bulking' && t.category == 'fitness'), isTrue);
      expect(recipe.tags.any((t) => t.name == 'Vegetarian' && t.category == 'diet'), isTrue);
    });

    test('throws RecipeValidationException when is_valid_recipe is false', () async {
      final invalidPostJson = jsonEncode({
        'is_valid_recipe': false,
        'title': 'Non-recipe Video',
        'ingredients': [],
        'instructions': [],
      });

      final mockClient = MockOllamaClient([invalidPostJson, invalidPostJson]);
      final structurer = RecipeStructurer(ollamaClient: mockClient);

      expect(
        () async => await structurer.structureRecipe(
          caption: 'Watch my travel vlog!',
          transcript: 'Hey guys we are traveling today',
        ),
        throwsA(isA<RecipeValidationException>()),
      );
    });
  });
}
