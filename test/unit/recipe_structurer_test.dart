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
  });
}
