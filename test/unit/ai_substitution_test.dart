import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/networking/ollama_client.dart';
import 'package:foodies/core/networking/ollama_models.dart';
import 'package:foodies/core/storage/secure_storage_service.dart';
import 'package:foodies/features/recipes/data/ai_substitution_service.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/domain/models/recipe_step.dart';

class MockOllamaClient extends OllamaClient {
  final Future<OllamaChatResponse> Function(List<Map<String, String>> messages, bool forceJsonFormat) onChat;

  MockOllamaClient({required this.onChat}) : super(storage: SecureStorageService());

  @override
  Future<OllamaChatResponse> chat({
    required List<Map<String, String>> messages,
    String? model,
    Map<String, dynamic>? schemaFormat,
    bool forceJsonFormat = true,
  }) {
    return onChat(messages, forceJsonFormat);
  }
}

void main() {
  group('AiSubstitutionService & Interactive Chef Q&A Tests', () {
    final testRecipe = Recipe(
      id: 'rec_sub_1',
      title: 'Creamy Butter Chicken',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      ingredients: const [
        Ingredient(
          id: 'ing_1',
          recipeId: 'rec_sub_1',
          name: 'Chicken Breast',
          quantity: 500,
          unit: 'g',
        ),
        Ingredient(
          id: 'ing_2',
          recipeId: 'rec_sub_1',
          name: 'Heavy Cream',
          quantity: 100,
          unit: 'ml',
        ),
      ],
      steps: [
        RecipeStep(
          id: 'step_1',
          recipeId: 'rec_sub_1',
          stepNumber: 1,
          instruction: 'Sear the chicken in a hot skillet with spices for 6 minutes.',
        ),
        RecipeStep(
          id: 'step_2',
          recipeId: 'rec_sub_1',
          stepNumber: 2,
          instruction: 'Simmer the tomato gravy, then stir in heavy cream to finish.',
        ),
      ],
    );

    test('getSubstitutions successfully parses AI recommendations and includes recipe context', () async {
      final mockClient = MockOllamaClient(
        onChat: (messages, forceJsonFormat) async {
          expect(forceJsonFormat, isTrue);
          final prompt = messages.firstWhere((m) => m['role'] == 'user')['content']!;
          // Verifies recipe title, ingredients, and steps are in prompt
          expect(prompt, contains('Creamy Butter Chicken'));
          expect(prompt, contains('Chicken Breast'));
          expect(prompt, contains('Sear the chicken in a hot skillet'));

          return const OllamaChatResponse(
            model: 'qwen2.5:latest',
            content: '''{
              "substitutions": [
                {
                  "name": "Firm Tofu",
                  "ratio": "1:1 ratio",
                  "reason": "Press and sear until golden; holds up wonderfully in simmering tomato gravy.",
                  "dietary": "Vegan High-Protein"
                },
                {
                  "name": "Soy Chunks",
                  "ratio": "1:1 ratio (rehydrated)",
                  "reason": "Spongy texture deeply absorbs the aromatic spices and curry sauce.",
                  "dietary": "High-Fiber Vegan"
                }
              ]
            }''',
          );
        },
      );

      final service = AiSubstitutionService(ollamaClient: mockClient);
      final result = await service.getSubstitutions(
        recipe: testRecipe,
        ingredient: testRecipe.ingredients.first,
      );

      expect(result.isLiveAi, isTrue);
      expect(result.substitutions.length, equals(2));
      expect(result.substitutions[0].name, equals('Firm Tofu'));
      expect(result.substitutions[0].ratio, equals('1:1 ratio'));
      expect(result.substitutions[0].dietary, equals('Vegan High-Protein'));
    });

    test('askChefQuestion formats affirmative YES answer with direct verdict', () async {
      final mockClient = MockOllamaClient(
        onChat: (messages, forceJsonFormat) async {
          expect(forceJsonFormat, isFalse);
          return const OllamaChatResponse(
            model: 'qwen2.5:latest',
            content: 'YES, Greek yogurt works wonderfully as a swap for heavy cream in step 2. However, whisk it with a splash of warm gravy first and stir it in off the heat to prevent it from curdling.',
          );
        },
      );

      final service = AiSubstitutionService(ollamaClient: mockClient);
      final answer = await service.askChefQuestion(
        recipe: testRecipe,
        ingredient: testRecipe.ingredients[1],
        question: 'Can I use Greek yogurt instead of heavy cream?',
      );

      expect(answer.isUser, isFalse);
      expect(answer.isAffirmative, isTrue);
      expect(answer.directVerdict, equals('YES'));
      expect(answer.text, contains('prevent it from curdling'));
    });

    test('askChefQuestion formats negative NO answer when substitution fails culinary physics', () async {
      final mockClient = MockOllamaClient(
        onChat: (messages, forceJsonFormat) async {
          return const OllamaChatResponse(
            model: 'qwen2.5:latest',
            content: 'NO, do not substitute water for cream. It will thin out your tomato gravy, causing the sauce to separate and lose its velvety richness.',
          );
        },
      );

      final service = AiSubstitutionService(ollamaClient: mockClient);
      final answer = await service.askChefQuestion(
        recipe: testRecipe,
        ingredient: testRecipe.ingredients[1],
        question: 'Can I just use plain water instead of cream?',
      );

      expect(answer.isUser, isFalse);
      expect(answer.isAffirmative, isFalse);
      expect(answer.directVerdict, equals('NO'));
    });

    test('Ingredient helper getters correctly parse base notes and bracketed alternatives', () {
      const ingWithAlt = Ingredient(
        id: 'ing_test',
        recipeId: 'rec_test',
        name: 'Paneer',
        quantity: 200,
        unit: 'g',
        notes: 'finely cubed, or Firm Tofu',
      );

      expect(ingWithAlt.hasAlternative, isTrue);
      expect(ingWithAlt.alternativeName, equals('Firm Tofu'));
      expect(ingWithAlt.baseNotes, equals('finely cubed'));
      expect(ingWithAlt.fullDisplayText, equals('200 g Paneer (finely cubed, or Firm Tofu)'));

      const ingPlain = Ingredient(
        id: 'ing_plain',
        recipeId: 'rec_test',
        name: 'Butter',
        quantity: 2,
        unit: 'tbsp',
      );

      expect(ingPlain.hasAlternative, isFalse);
      expect(ingPlain.alternativeName, isNull);
      expect(ingPlain.baseNotes, isNull);
      expect(ingPlain.fullDisplayText, equals('2 tbsp Butter'));
    });
  });
}
