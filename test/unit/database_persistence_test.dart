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
  });
}
