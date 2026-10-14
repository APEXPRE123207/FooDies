import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/features/extraction/nutrition_calculator.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/nutrition_info.dart';

void main() {
  group('NutritionCalculator Tests', () {
    test('preserves creator stated nutrition without overriding', () {
      const creatorNutrition = NutritionInfo(
        calories: 450,
        proteinGrams: 35,
        carbsGrams: 20,
        fatGrams: 15,
        method: 'creator',
        confidence: 'high',
      );

      final result = NutritionCalculator.estimate(
        ingredients: [
          const Ingredient(id: '1', recipeId: 'r', name: 'chicken', quantity: 200, unit: 'g'),
        ],
        servingCount: 1,
        creatorNutrition: creatorNutrition,
      );

      expect(result.method, 'creator');
      expect(result.calories, 450);
      expect(result.proteinGrams, 35);
    });

    test('calculates nutritional estimates from recognized ingredients', () {
      final ingredients = [
        const Ingredient(id: '1', recipeId: 'r', name: 'chicken breast', quantity: 400, unit: 'g'),
        const Ingredient(id: '2', recipeId: 'r', name: 'olive oil', quantity: 2, unit: 'tbsp'),
      ];

      // 400g chicken breast ~ 660 kcal (165/100g), 124g protein
      // 2 tbsp olive oil (28g) ~ 247 kcal (884/100g), 28g fat
      // Total ~ 907 kcal. For 2 servings -> ~453 kcal each
      final result = NutritionCalculator.estimate(
        ingredients: ingredients,
        servingCount: 2,
      );

      expect(result.method, 'estimated');
      expect(result.calories, isNotNull);
      expect(result.calories! > 400 && result.calories! < 500, isTrue);
      expect(result.proteinGrams! > 50, isTrue);
      expect(result.fatGrams! > 10, isTrue);
      expect(result.confidence, isNotNull);
    });

    test('returns unavailable when ingredients cannot be calculated', () {
      final ingredients = [
        const Ingredient(id: '1', recipeId: 'r', name: 'special secret blend of herbs', quantity: null),
        const Ingredient(id: '2', recipeId: 'r', name: 'pinch of love', quantity: null),
      ];

      final result = NutritionCalculator.estimate(
        ingredients: ingredients,
        servingCount: 2,
      );

      expect(result.method, 'unavailable');
      expect(result.calories, isNull);
    });
  });
}
