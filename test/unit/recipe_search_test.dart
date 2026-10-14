import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/database/app_database.dart'
    hide Recipe, Ingredient, RecipeStep, RecipeTag, ImportJob;
import 'package:foodies/features/recipes/data/demo_recipes.dart';
import 'package:foodies/features/recipes/data/recipe_repository.dart';
import 'package:foodies/features/search/presentation/search_screen.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecipeRepository(db);
    // Seed demo recipes into database for realistic search testing
    await DemoRecipes.seed(repo);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecipeRepository.searchRecipes Multi-Token & Tag Search Tests', () {
    test('searches by single title word: "chicken"', () async {
      final results = await repo.searchRecipes(query: 'chicken');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches by multi-word token query across title & ingredients: "tuscan chicken"', () async {
      final results = await repo.searchRecipes(query: 'tuscan chicken');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches by ingredient name: "parmesan"', () async {
      final results = await repo.searchRecipes(query: 'parmesan');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches by ingredient: "mozzarella"', () async {
      final results = await repo.searchRecipes(query: 'mozzarella');
      expect(results.length, 1);
      expect(results.first.title, contains('Neapolitan Margherita Pizza'));
    });

    test('searches by cuisine tag: "italian" matches both recipes', () async {
      final results = await repo.searchRecipes(query: 'italian');
      expect(results.length, 2);
    });

    test('searches with hashtag: "#Italian"', () async {
      final results = await repo.searchRecipes(query: '#Italian');
      expect(results.length, 2);
    });

    test('searches by macroProfile and badge: "high protein"', () async {
      final results = await repo.searchRecipes(query: 'high protein');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches by hyphenated badge: "high-protein"', () async {
      final results = await repo.searchRecipes(query: 'high-protein');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches by cooking instruction keyword: "skillet"', () async {
      final results = await repo.searchRecipes(query: 'skillet');
      expect(results.length, 1);
      expect(results.first.title, contains('Tuscan Garlic Chicken'));
    });

    test('searches with tag filter array', () async {
      final results = await repo.searchRecipes(tagNames: ['Vegetarian']);
      expect(results.length, 1);
      expect(results.first.title, contains('Neapolitan Margherita Pizza'));
    });

    test('empty query returns all recipes', () async {
      final results = await repo.searchRecipes(query: '');
      expect(results.length, 2);
    });
  });

  group('SearchScreen Widget Tests', () {
    testWidgets('renders SearchScreen, types search query, and filters results live', (tester) async {
      final testRecipes = await repo.getAllRecipes();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allRecipesStreamProvider.overrideWith((ref) => Stream.value(testRecipes)),
            recipeRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify search input field exists
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Verify both recipes appear initially
      expect(find.text('Creamy Tuscan Garlic Chicken'), findsOneWidget);
      expect(find.text('Neapolitan Margherita Pizza'), findsOneWidget);

      // Type "pizza" into search bar
      await tester.enterText(searchField, 'pizza');
      await tester.pumpAndSettle();

      // Only pizza should be visible
      expect(find.text('Neapolitan Margherita Pizza'), findsOneWidget);
      expect(find.text('Creamy Tuscan Garlic Chicken'), findsNothing);

      // Type "spinach" into search bar
      await tester.enterText(searchField, 'spinach');
      await tester.pumpAndSettle();

      // Only chicken should be visible
      expect(find.text('Creamy Tuscan Garlic Chicken'), findsOneWidget);
      expect(find.text('Neapolitan Margherita Pizza'), findsNothing);
      expect(find.text('Has spinach'), findsOneWidget);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Both recipes return
      expect(find.text('Creamy Tuscan Garlic Chicken'), findsOneWidget);
      expect(find.text('Neapolitan Margherita Pizza'), findsOneWidget);
    });

    testWidgets('pasting video URL displays quick import action card', (tester) async {
      final testRecipes = await repo.getAllRecipes();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allRecipesStreamProvider.overrideWith((ref) => Stream.value(testRecipes)),
            recipeRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'https://www.instagram.com/reel/DEMO_URL');
      await tester.pumpAndSettle();

      expect(find.text('Video Link Detected'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });
  });
}
