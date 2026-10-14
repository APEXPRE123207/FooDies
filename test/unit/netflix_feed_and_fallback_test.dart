import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/nutrition_info.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/domain/models/recipe_step.dart';
import 'package:foodies/features/recipes/domain/models/recipe_tag.dart';
import 'package:foodies/features/recipes/presentation/home_feed_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_placeholder_image.dart';
import 'package:foodies/features/recipes/presentation/widgets/ring_carousel.dart';

void main() {
  group('RecipeCardImage Fallback Display Tests', () {
    testWidgets('shows emblem and recipe title instead of category tag when image is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: RecipeCardImage(
                imagePath: null,
                title: 'High Protein Chicken Stir Fry',
                category: 'Italian',
              ),
            ),
          ),
        ),
      );

      // Verify the dish title is displayed prominently
      expect(find.text('High Protein Chicken Stir Fry'), findsOneWidget);

      // Verify the emblem dish icon is displayed
      expect(find.byType(Icon), findsOneWidget);

      // Verify the old category tag text 'ITALIAN' is NOT displayed
      expect(find.text('ITALIAN'), findsNothing);
    });

    testWidgets('shows emblem on compact layouts without overflowing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: RecipeCardImage(
                imagePath: null,
                title: 'Egg Scramble',
                category: 'Breakfast',
              ),
            ),
          ),
        ),
      );

      // Compact layout should show dish icon cleanly
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('BREAKFAST'), findsNothing);
    });
  });

  group('HomeFeedScreen 3D Carousel & Netflix Shelves Tests', () {
    final now = DateTime.now();

    final List<Recipe> testRecipes = [
      Recipe(
        id: 'r1',
        title: 'Grilled Garlic Herb Chicken',
        totalTimeMinutes: 25,
        nutrition: const NutritionInfo(calories: 420, proteinGrams: 45),
        primaryBadge: '💪 45g Protein Muscle Fuel',
        createdAt: now,
        updatedAt: now,
        ingredients: [
          const Ingredient(id: 'i1', recipeId: 'r1', name: 'chicken breast', quantity: 300, unit: 'g'),
        ],
        steps: [
          const RecipeStep(id: 's1', recipeId: 'r1', stepNumber: 1, instruction: 'Grill chicken cutlets.'),
        ],
        tags: [
          const RecipeTag(id: 't1', name: 'Gym', category: 'diet'),
        ],
      ),
      Recipe(
        id: 'r2',
        title: 'Masala Egg Bhurji',
        totalTimeMinutes: 12,
        nutrition: const NutritionInfo(calories: 280, proteinGrams: 22),
        primaryBadge: '🥚 12-Min Quick Protein',
        createdAt: now,
        updatedAt: now,
        ingredients: [
          const Ingredient(id: 'i2', recipeId: 'r2', name: 'fresh egg', quantity: 3, unit: 'whole'),
        ],
        steps: [
          const RecipeStep(id: 's2', recipeId: 'r2', stepNumber: 1, instruction: 'Scramble eggs with onions and chili.'),
        ],
        tags: [
          const RecipeTag(id: 't2', name: 'Hostel', category: 'diet'),
        ],
      ),
    ];

    testWidgets('renders simple scrolling flashcard carousel with indicator and recipe cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allRecipesStreamProvider.overrideWith((ref) => Stream.value(testRecipes)),
            importJobsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: HomeFeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('FOODIES'), findsOneWidget);

      // Recipe count indicator
      expect(find.text('RECIPE 1 OF 2'), findsOneWidget);

      // Flashcard dish title is visible in the carousel
      expect(find.text('Grilled Garlic Herb Chicken'), findsWidgets);

      // Swipe horizontally to next card
      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      await tester.pumpAndSettle();

      // Second card is now active
      expect(find.text('Masala Egg Bhurji'), findsWidgets);
    });

    testWidgets('RingCarousel renders standalone with images list', (tester) async {
      final images = List.generate(
        4,
        (_) => const AssetImage('assets/images/logo.png'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RingCarousel(images: images),
          ),
        ),
      );

      expect(find.byType(RingCarousel), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}
