import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';

void main() {
  group('Ingredient Scaling and Formatting Tests', () {
    test('scale properly doubles and halves quantities', () {
      const ing = Ingredient(
        id: '1',
        recipeId: 'r1',
        name: 'flour',
        quantity: 2.0,
        unit: 'cups',
      );

      // Double servings (factor 2.0)
      final doubled = ing.scale(2.0);
      expect(doubled.quantity, 4.0);

      // Halve servings (factor 0.5)
      final halved = ing.scale(0.5);
      expect(halved.quantity, 1.0);
    });

    test('scale handles null quantity gracefully', () {
      const ing = Ingredient(
        id: '2',
        recipeId: 'r1',
        name: 'salt to taste',
        quantity: null,
      );

      final scaled = ing.scale(3.0);
      expect(scaled.quantity, isNull);
      expect(scaled.name, 'salt to taste');
    });

    test('displayQuantity formats fractions beautifully for cooks', () {
      const ingHalf = Ingredient(id: '1', recipeId: 'r', name: 'sugar', quantity: 0.5, unit: 'cup');
      expect(ingHalf.displayQuantity, '½');

      const ingOneAndHalf = Ingredient(id: '2', recipeId: 'r', name: 'milk', quantity: 1.5, unit: 'cups');
      expect(ingOneAndHalf.displayQuantity, '1 ½');

      const ingQuarter = Ingredient(id: '3', recipeId: 'r', name: 'baking powder', quantity: 0.25, unit: 'tsp');
      expect(ingQuarter.displayQuantity, '¼');

      const ingThreeQuarters = Ingredient(id: '4', recipeId: 'r', name: 'butter', quantity: 0.75, unit: 'cup');
      expect(ingThreeQuarters.displayQuantity, '¾');

      const ingInteger = Ingredient(id: '5', recipeId: 'r', name: 'eggs', quantity: 3.0);
      expect(ingInteger.displayQuantity, '3');
    });

    test('fullDisplayText formats unit, name, notes, and optional status', () {
      const ing = Ingredient(
        id: '6',
        recipeId: 'r',
        name: 'parmesan cheese',
        quantity: 0.5,
        unit: 'cup',
        notes: 'freshly grated',
        isOptional: true,
      );

      expect(ing.fullDisplayText, '½ cup parmesan cheese (freshly grated) (optional)');
    });
  });
}
