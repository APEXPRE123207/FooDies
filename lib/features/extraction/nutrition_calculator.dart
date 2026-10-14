import '../recipes/domain/models/ingredient.dart';
import '../recipes/domain/models/nutrition_info.dart';

class FoodNutrientProfile {
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const FoodNutrientProfile({
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });
}

class NutritionCalculator {
  // Common food composition per 100 grams
  static const Map<String, FoodNutrientProfile> _foodDatabase = {
    'flour': FoodNutrientProfile(caloriesPer100g: 364, proteinPer100g: 10.3, carbsPer100g: 76.3, fatPer100g: 1.0),
    'sugar': FoodNutrientProfile(caloriesPer100g: 387, proteinPer100g: 0.0, carbsPer100g: 100.0, fatPer100g: 0.0),
    'brown sugar': FoodNutrientProfile(caloriesPer100g: 380, proteinPer100g: 0.1, carbsPer100g: 98.0, fatPer100g: 0.0),
    'honey': FoodNutrientProfile(caloriesPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82.4, fatPer100g: 0.0),
    'butter': FoodNutrientProfile(caloriesPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.1, fatPer100g: 81.1),
    'olive oil': FoodNutrientProfile(caloriesPer100g: 884, proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 100.0),
    'oil': FoodNutrientProfile(caloriesPer100g: 884, proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 100.0),
    'vegetable oil': FoodNutrientProfile(caloriesPer100g: 884, proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 100.0),
    'egg': FoodNutrientProfile(caloriesPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5),
    'eggs': FoodNutrientProfile(caloriesPer100g: 143, proteinPer100g: 12.6, carbsPer100g: 0.7, fatPer100g: 9.5),
    'milk': FoodNutrientProfile(caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3),
    'heavy cream': FoodNutrientProfile(caloriesPer100g: 340, proteinPer100g: 2.8, carbsPer100g: 2.7, fatPer100g: 36.1),
    'cream': FoodNutrientProfile(caloriesPer100g: 340, proteinPer100g: 2.8, carbsPer100g: 2.7, fatPer100g: 36.1),
    'chicken': FoodNutrientProfile(caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0.0, fatPer100g: 3.6),
    'chicken breast': FoodNutrientProfile(caloriesPer100g: 165, proteinPer100g: 31.0, carbsPer100g: 0.0, fatPer100g: 3.6),
    'chicken thigh': FoodNutrientProfile(caloriesPer100g: 209, proteinPer100g: 26.0, carbsPer100g: 0.0, fatPer100g: 10.9),
    'beef': FoodNutrientProfile(caloriesPer100g: 250, proteinPer100g: 26.0, carbsPer100g: 0.0, fatPer100g: 17.0),
    'ground beef': FoodNutrientProfile(caloriesPer100g: 250, proteinPer100g: 26.0, carbsPer100g: 0.0, fatPer100g: 17.0),
    'salmon': FoodNutrientProfile(caloriesPer100g: 208, proteinPer100g: 20.4, carbsPer100g: 0.0, fatPer100g: 13.4),
    'pasta': FoodNutrientProfile(caloriesPer100g: 371, proteinPer100g: 13.0, carbsPer100g: 74.0, fatPer100g: 1.5),
    'rice': FoodNutrientProfile(caloriesPer100g: 365, proteinPer100g: 7.1, carbsPer100g: 80.0, fatPer100g: 0.7),
    'cheese': FoodNutrientProfile(caloriesPer100g: 402, proteinPer100g: 25.0, carbsPer100g: 1.3, fatPer100g: 33.1),
    'parmesan': FoodNutrientProfile(caloriesPer100g: 431, proteinPer100g: 38.5, carbsPer100g: 4.1, fatPer100g: 28.6),
    'mozzarella': FoodNutrientProfile(caloriesPer100g: 280, proteinPer100g: 28.0, carbsPer100g: 3.1, fatPer100g: 17.0),
    'cheddar': FoodNutrientProfile(caloriesPer100g: 403, proteinPer100g: 24.9, carbsPer100g: 1.3, fatPer100g: 33.8),
    'garlic': FoodNutrientProfile(caloriesPer100g: 149, proteinPer100g: 6.4, carbsPer100g: 33.1, fatPer100g: 0.5),
    'onion': FoodNutrientProfile(caloriesPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9.3, fatPer100g: 0.1),
    'tomato': FoodNutrientProfile(caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2),
    'potato': FoodNutrientProfile(caloriesPer100g: 77, proteinPer100g: 2.0, carbsPer100g: 17.5, fatPer100g: 0.1),
    'carrot': FoodNutrientProfile(caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 9.6, fatPer100g: 0.2),
    'mushrooms': FoodNutrientProfile(caloriesPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3),
    'spinach': FoodNutrientProfile(caloriesPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4),
    'avocado': FoodNutrientProfile(caloriesPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 8.5, fatPer100g: 14.7),
  };

  /// Calculates nutritional values per serving from a list of ingredients
  static NutritionInfo estimate({
    required List<Ingredient> ingredients,
    required int servingCount,
    NutritionInfo? creatorNutrition,
  }) {
    // If the creator explicitly stated verified nutrition, preserve it
    if (creatorNutrition != null &&
        creatorNutrition.hasValues &&
        creatorNutrition.method == 'creator') {
      return creatorNutrition;
    }

    if (ingredients.isEmpty || servingCount <= 0) {
      return const NutritionInfo(method: 'unavailable');
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    int matchedCount = 0;

    for (final ing in ingredients) {
      if (ing.quantity == null || ing.quantity! <= 0) continue;

      final profile = _findNutrientProfile(ing.name);
      if (profile != null) {
        final weightInGrams = _convertToGrams(ing.quantity!, ing.unit, ing.name);
        if (weightInGrams != null && weightInGrams > 0) {
          final factor = weightInGrams / 100.0;
          totalCalories += profile.caloriesPer100g * factor;
          totalProtein += profile.proteinPer100g * factor;
          totalCarbs += profile.carbsPer100g * factor;
          totalFat += profile.fatPer100g * factor;
          matchedCount++;
        }
      }
    }

    // Determine confidence based on ingredient coverage
    if (matchedCount == 0) {
      return const NutritionInfo(method: 'unavailable');
    }

    final coverageRatio = matchedCount / ingredients.length;
    String confidence = 'low';
    if (coverageRatio >= 0.7 && matchedCount >= 3) {
      confidence = 'high';
    } else if (coverageRatio >= 0.4) {
      confidence = 'medium';
    }

    final perServingCalories = (totalCalories / servingCount).roundToDouble();
    final perServingProtein = ((totalProtein / servingCount) * 10).round() / 10.0;
    final perServingCarbs = ((totalCarbs / servingCount) * 10).round() / 10.0;
    final perServingFat = ((totalFat / servingCount) * 10).round() / 10.0;

    return NutritionInfo(
      calories: perServingCalories,
      proteinGrams: perServingProtein,
      carbsGrams: perServingCarbs,
      fatGrams: perServingFat,
      method: 'estimated',
      confidence: confidence,
    );
  }

  static FoodNutrientProfile? _findNutrientProfile(String ingredientName) {
    final lower = ingredientName.toLowerCase().trim();
    for (final key in _foodDatabase.keys) {
      if (lower.contains(key)) {
        return _foodDatabase[key];
      }
    }
    return null;
  }

  static double? _convertToGrams(double quantity, String? rawUnit, String ingredientName) {
    final unit = (rawUnit ?? '').toLowerCase().trim();
    final ing = ingredientName.toLowerCase();

    if (unit.isEmpty || unit == 'piece' || unit == 'item' || unit == 'whole') {
      if (ing.contains('egg')) return quantity * 50.0; // 1 medium egg ~ 50g
      if (ing.contains('chicken breast')) return quantity * 200.0;
      if (ing.contains('onion')) return quantity * 150.0;
      if (ing.contains('potato')) return quantity * 180.0;
      if (ing.contains('tomato')) return quantity * 120.0;
      if (ing.contains('garlic') && (ing.contains('clove') || unit == 'clove')) {
        return quantity * 5.0; // 1 clove ~ 5g
      }
      return quantity * 100.0; // generic estimated default
    }

    switch (unit) {
      case 'g':
      case 'gram':
      case 'grams':
        return quantity;
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return quantity * 1000.0;
      case 'oz':
      case 'ounce':
      case 'ounces':
        return quantity * 28.35;
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return quantity * 453.59;
      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        if (ing.contains('oil') || ing.contains('butter')) return quantity * 14.0;
        if (ing.contains('flour')) return quantity * 8.0;
        if (ing.contains('sugar')) return quantity * 12.5;
        return quantity * 15.0;
      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return quantity * 5.0;
      case 'cup':
      case 'cups':
        if (ing.contains('flour')) return quantity * 125.0;
        if (ing.contains('sugar')) return quantity * 200.0;
        if (ing.contains('butter')) return quantity * 227.0;
        if (ing.contains('oil') || ing.contains('milk') || ing.contains('water')) {
          return quantity * 240.0;
        }
        if (ing.contains('rice')) return quantity * 185.0;
        return quantity * 150.0;
      case 'ml':
      case 'milliliter':
      case 'milliliters':
        return quantity * 1.0; // approx 1g/ml
      case 'l':
      case 'liter':
      case 'liters':
        return quantity * 1000.0;
      case 'clove':
      case 'cloves':
        return quantity * 5.0;
      case 'pinch':
        return 0.5;
      default:
        return null;
    }
  }
}
