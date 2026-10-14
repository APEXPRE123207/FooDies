import 'package:uuid/uuid.dart';
import '../domain/models/ingredient.dart';
import '../domain/models/nutrition_info.dart';
import '../domain/models/recipe.dart';
import '../domain/models/recipe_step.dart';
import '../domain/models/recipe_tag.dart';
import 'recipe_repository.dart';

class DemoRecipes {
  static Future<void> seed(RecipeRepository repo) async {
    const uuid = Uuid();
    final now = DateTime.now();

    final r1Id = uuid.v4();
    final recipe1 = Recipe(
      id: r1Id,
      title: 'Creamy Tuscan Garlic Chicken',
      description: 'Pan-seared chicken cutlets bathed in a silky sun-dried tomato and spinach cream sauce.',
      sourceUrl: 'https://www.instagram.com/reel/DEMO_TUSCAN_CHICKEN',
      sourcePlatform: 'instagram',
      sourceCaption: 'The absolute best weeknight chicken dinner! Ingredients and instructions in caption.',
      prepTimeMinutes: 15,
      cookTimeMinutes: 20,
      totalTimeMinutes: 35,
      isTimeEstimated: false,
      servingCount: 4,
      isFavorite: true,
      primaryBadge: '💪 42g Protein Muscle Fuel',
      suitabilityReason: 'Packed with 42g lean protein from chicken breast and healthy fats from olive oil, ideal for post-workout muscle synthesis.',
      macroProfile: 'High-Protein',
      nutrition: const NutritionInfo(
        calories: 520,
        proteinGrams: 42,
        carbsGrams: 8,
        fatGrams: 36,
        method: 'estimated',
        confidence: 'high',
      ),
      createdAt: now,
      updatedAt: now,
      ingredients: [
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'chicken breast', quantity: 2, unit: 'whole', notes: 'sliced horizontally'),
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'olive oil', quantity: 2, unit: 'tbsp'),
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'garlic', quantity: 4, unit: 'clove', notes: 'minced'),
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'heavy cream', quantity: 1, unit: 'cup', isEstimated: true),
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'spinach', quantity: 2, unit: 'cups', notes: 'fresh baby spinach'),
        Ingredient(id: uuid.v4(), recipeId: r1Id, name: 'parmesan', quantity: 0.5, unit: 'cup', notes: 'grated', isEstimated: true),
      ],
      steps: [
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 1, instruction: 'Season chicken cutlets with salt, pepper, and Italian seasoning.', durationMinutes: 5),
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 2, instruction: 'Heat olive oil in a large skillet over medium-high heat at 190°C. Sear chicken for 5 mins per side until golden.', durationMinutes: 10),
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 3, instruction: 'Remove chicken. Add garlic and cook until fragrant (1 min). Pour in heavy cream and simmer for 3 mins.', durationMinutes: 3),
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 4, instruction: 'Stir in parmesan and fresh spinach until wilted. Return chicken and simmer for 2 mins before serving.', durationMinutes: 2),
      ],
      tags: [
        RecipeTag(id: uuid.v4(), name: 'Italian', category: 'cuisine'),
        RecipeTag(id: uuid.v4(), name: 'Dinner', category: 'meal_type'),
        RecipeTag(id: uuid.v4(), name: 'High Protein', category: 'diet'),
      ],
    );

    final r2Id = uuid.v4();
    final recipe2 = Recipe(
      id: r2Id,
      title: 'Neapolitan Margherita Pizza',
      description: 'Crispy blistered crust topped with crushed San Marzano tomatoes, fresh mozzarella, and sweet basil.',
      sourceUrl: 'https://www.facebook.com/reel/DEMO_MARGHERITA_PIZZA',
      sourcePlatform: 'facebook',
      sourceCaption: 'Mastering the 48-hour fermented dough for authentic Neapolitan pizza at home.',
      prepTimeMinutes: 20,
      cookTimeMinutes: 10,
      totalTimeMinutes: 30,
      isTimeEstimated: true,
      servingCount: 2,
      isFavorite: false,
      primaryBadge: '🍕 Clean Cheat Meal',
      suitabilityReason: 'Slow-fermented dough paired with fresh lycopene-rich San Marzano tomatoes and grass-fed mozzarella.',
      macroProfile: 'Balanced',
      nutrition: const NutritionInfo(
        calories: 680,
        proteinGrams: 28,
        carbsGrams: 84,
        fatGrams: 24,
        method: 'estimated',
        confidence: 'high',
      ),
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 2)),
      ingredients: [
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'flour', quantity: 2.5, unit: 'cups', notes: 'Tipo 00 flour'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'mozzarella', quantity: 200, unit: 'g', notes: 'fresh fior di latte'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'tomato', quantity: 1, unit: 'cup', notes: 'crushed San Marzano'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'olive oil', quantity: 1, unit: 'tbsp', notes: 'extra virgin'),
      ],
      steps: [
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 1, instruction: 'Stretch pizza dough onto a floured peel, forming a 12-inch circle with an elevated cornicione crust.', durationMinutes: 5),
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 2, instruction: 'Spread crushed tomatoes evenly, tear fresh mozzarella over top, and drizzle extra virgin olive oil.', durationMinutes: 3),
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 3, instruction: 'Bake at highest oven temp on pre-heated pizza steel for 7-9 mins until bubbly and leopard-spotted.', durationMinutes: 8),
      ],
      tags: [
        RecipeTag(id: uuid.v4(), name: 'Italian', category: 'cuisine'),
        RecipeTag(id: uuid.v4(), name: 'Bake', category: 'method'),
        RecipeTag(id: uuid.v4(), name: 'Vegetarian', category: 'diet'),
      ],
    );

    await repo.insertRecipe(recipe1);
    await repo.insertRecipe(recipe2);
  }
}
