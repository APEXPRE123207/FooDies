import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/database/app_database.dart'
    hide Recipe, Ingredient, RecipeStep, RecipeTag, ImportJob;
import 'package:foodies/features/recipes/data/recipe_repository.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/nutrition_info.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/domain/models/recipe_step.dart';
import 'package:foodies/features/recipes/domain/models/recipe_tag.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecipeRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift SQLite Database & RecipeRepository Persistence Tests', () {
    test('insertRecipe stores recipe, ingredients, steps, and tags atomically', () async {
      final now = DateTime.now();
      final recipe = Recipe(
        id: 'rec_101',
        title: 'Authentic Carbonara',
        description: 'Traditional Roman pasta without cream',
        sourceUrl: 'https://www.instagram.com/reel/CARBONARA_101/?igsh=abc',
        sourcePlatform: 'instagram',
        sourceCaption: 'Guanciale, egg yolks, pecorino romano, black pepper.',
        prepTimeMinutes: 10,
        cookTimeMinutes: 15,
        servingCount: 2,
        nutrition: const NutritionInfo(
          calories: 650,
          proteinGrams: 28,
          carbsGrams: 70,
          fatGrams: 28,
          method: 'estimated',
          confidence: 'high',
        ),
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          Ingredient(id: 'ing_1', recipeId: 'rec_101', name: 'spaghetti', quantity: 200, unit: 'g'),
          Ingredient(id: 'ing_2', recipeId: 'rec_101', name: 'guanciale', quantity: 100, unit: 'g'),
          Ingredient(id: 'ing_3', recipeId: 'rec_101', name: 'egg yolks', quantity: 4, unit: 'whole'),
        ],
        steps: const [
          RecipeStep(id: 'stp_1', recipeId: 'rec_101', stepNumber: 1, instruction: 'Crisp guanciale in a skillet.', durationMinutes: 8),
          RecipeStep(id: 'stp_2', recipeId: 'rec_101', stepNumber: 2, instruction: 'Whisk yolks with grated pecorino.', durationMinutes: 3),
          RecipeStep(id: 'stp_3', recipeId: 'rec_101', stepNumber: 3, instruction: 'Combine pasta with guanciale fat off heat and emulsify with egg mixture.', durationMinutes: 4),
        ],
        tags: const [
          RecipeTag(id: 'tag_1', name: 'Italian', category: 'cuisine'),
          RecipeTag(id: 'tag_2', name: 'Pasta', category: 'meal_type'),
        ],
      );

      final saved = await repo.insertRecipe(recipe);

      expect(saved.id, 'rec_101');
      expect(saved.title, 'Authentic Carbonara');
      expect(saved.ingredients.length, 3);
      expect(saved.steps.length, 3);
      expect(saved.tags.length, 2);
      expect(saved.nutrition.calories, 650);

      // Verify retrieval
      final retrieved = await repo.getRecipeById('rec_101');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Authentic Carbonara');
      expect(retrieved.ingredients.first.name, 'spaghetti');
      expect(retrieved.steps.first.instruction, 'Crisp guanciale in a skillet.');
    });

    test('findRecipeBySourceUrl finds recipe even with different tracking parameters', () async {
      final now = DateTime.now();
      final recipe = Recipe(
        id: 'rec_102',
        title: 'Shakshuka',
        sourceUrl: 'https://www.instagram.com/reel/SHAKSHUKA/?igsh=ORIGINAL_QUERY',
        sourcePlatform: 'instagram',
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          Ingredient(id: 'ing_s1', recipeId: 'rec_102', name: 'eggs', quantity: 4, unit: 'whole'),
        ],
        steps: const [
          RecipeStep(id: 'stp_s1', recipeId: 'rec_102', stepNumber: 1, instruction: 'Poach eggs in spiced tomato sauce.'),
        ],
      );

      await repo.insertRecipe(recipe);

      // Search with different tracking query params
      final match = await repo.findRecipeBySourceUrl(
        'https://www.instagram.com/reel/SHAKSHUKA/?utm_source=copy_link&igsh=DIFFERENT_TOKEN',
      );

      expect(match, isNotNull);
      expect(match!.id, 'rec_102');
      expect(match.title, 'Shakshuka');
    });

    test('toggleFavorite updates favorite flag reactively', () async {
      final now = DateTime.now();
      final recipe = Recipe(
        id: 'rec_103',
        title: 'French Toast',
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          Ingredient(id: 'i1', recipeId: 'rec_103', name: 'bread', quantity: 2, unit: 'slices'),
        ],
        steps: const [
          RecipeStep(id: 's1', recipeId: 'rec_103', stepNumber: 1, instruction: 'Dip in egg custard and brown in butter.'),
        ],
      );

      await repo.insertRecipe(recipe);

      final isFav1 = await repo.toggleFavorite('rec_103');
      expect(isFav1, isTrue);

      final updated1 = await repo.getRecipeById('rec_103');
      expect(updated1!.isFavorite, isTrue);

      final isFav2 = await repo.toggleFavorite('rec_103');
      expect(isFav2, isFalse);

      final updated2 = await repo.getRecipeById('rec_103');
      expect(updated2!.isFavorite, isFalse);
    });

    test('deleteRecipe cascades and deletes associated ingredients, steps, and joins', () async {
      final now = DateTime.now();
      final recipe = Recipe(
        id: 'rec_104',
        title: 'Temporary Smoothie',
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          Ingredient(id: 'ing_t1', recipeId: 'rec_104', name: 'banana', quantity: 1, unit: 'whole'),
        ],
        steps: const [
          RecipeStep(id: 'stp_t1', recipeId: 'rec_104', stepNumber: 1, instruction: 'Blend until smooth.'),
        ],
      );

      await repo.insertRecipe(recipe);
      expect(await repo.getRecipeById('rec_104'), isNotNull);

      await repo.deleteRecipe('rec_104');
      expect(await repo.getRecipeById('rec_104'), isNull);
    });

    test('stores and retrieves rich AI metadata (primaryBadge, suitabilityReason, macroProfile, isTimeEstimated, isEstimated)', () async {
      final now = DateTime.now();
      final recipe = Recipe(
        id: 'rec_rich_105',
        title: 'High-Protein Paneer Stir Fry',
        description: 'Crispy paneer cubes with bell peppers and black pepper',
        totalTimeMinutes: 20,
        isTimeEstimated: true,
        primaryBadge: '💪 Post-Workout Recovery',
        suitabilityReason: 'Rich in slow-digesting casein protein from paneer, ideal for overnight recovery.',
        macroProfile: 'High-Protein',
        createdAt: now,
        updatedAt: now,
        ingredients: const [
          Ingredient(
            id: 'ing_r1',
            recipeId: 'rec_rich_105',
            name: 'paneer',
            quantity: 200,
            unit: 'g',
            isEstimated: false,
          ),
          Ingredient(
            id: 'ing_r2',
            recipeId: 'rec_rich_105',
            name: 'soy sauce',
            quantity: 1,
            unit: 'tbsp',
            isEstimated: true,
          ),
        ],
        steps: const [
          RecipeStep(
            id: 'stp_r1',
            recipeId: 'rec_rich_105',
            stepNumber: 1,
            instruction: 'Sear paneer at 200°C for 5 mins.',
            durationMinutes: 5,
          ),
        ],
      );

      await repo.insertRecipe(recipe);

      final retrieved = await repo.getRecipeById('rec_rich_105');
      expect(retrieved, isNotNull);
      expect(retrieved!.primaryBadge, equals('💪 Post-Workout Recovery'));
      expect(retrieved.suitabilityReason, contains('slow-digesting casein protein'));
      expect(retrieved.macroProfile, equals('High-Protein'));
      expect(retrieved.isTimeEstimated, isTrue);
      expect(retrieved.formattedTime, equals('~20 mins'));

      final ing1 = retrieved.ingredients.firstWhere((i) => i.id == 'ing_r1');
      expect(ing1.isEstimated, isFalse);
      expect(ing1.displayQuantity, equals('200'));

      final ing2 = retrieved.ingredients.firstWhere((i) => i.id == 'ing_r2');
      expect(ing2.isEstimated, isTrue);
      expect(ing2.displayQuantity, equals('~1'));

      // Test swapIngredient
      await repo.swapIngredient(
        ingredientId: 'ing_r1',
        newName: 'Firm Tofu',
        newNotes: 'vegan alternative',
      );

      final afterSwap = await repo.getRecipeById('rec_rich_105');
      final swappedIng = afterSwap!.ingredients.firstWhere((i) => i.id == 'ing_r1');
      expect(swappedIng.name, equals('Firm Tofu'));
      expect(swappedIng.notes, equals('vegan alternative'));
      expect(swappedIng.isEstimated, isTrue);

      // Test zero-destruction bracketed alternative: saves in brackets without overwriting original name
      await repo.saveIngredientAlternative(
        recipeId: 'rec_rich_105',
        ingredientId: 'ing_r2',
        alternativeName: 'Tamari',
      );

      final afterAlt = await repo.getRecipeById('rec_rich_105');
      final altIng = afterAlt!.ingredients.firstWhere((i) => i.id == 'ing_r2');
      // Original ingredient name MUST BE PRESERVED (zero destruction)
      expect(altIng.name, equals('soy sauce'));
      expect(altIng.hasAlternative, isTrue);
      expect(altIng.alternativeName, equals('Tamari'));
      expect(altIng.fullDisplayText, contains('soy sauce (or Tamari)'));

      // Test removing bracketed alternative reverts back to original
      await repo.removeIngredientAlternative(
        recipeId: 'rec_rich_105',
        ingredientId: 'ing_r2',
      );

      final afterRevert = await repo.getRecipeById('rec_rich_105');
      final revertedIng = afterRevert!.ingredients.firstWhere((i) => i.id == 'ing_r2');
      expect(revertedIng.name, equals('soy sauce'));
      expect(revertedIng.hasAlternative, isFalse);
      expect(revertedIng.alternativeName, isNull);
    });
  });
}
