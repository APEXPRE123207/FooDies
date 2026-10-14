import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/core/utils/url_parser.dart';
import 'package:foodies/features/importing/presentation/import_jobs_screen.dart';
import 'package:foodies/features/importing/presentation/import_sheet.dart';
import 'package:foodies/features/search/presentation/search_screen.dart';
import 'package:foodies/features/settings/presentation/settings_screen.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/nutrition_info.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/domain/models/recipe_step.dart';
import 'package:foodies/features/recipes/domain/models/recipe_tag.dart';
import 'package:foodies/features/recipes/presentation/recipe_edit_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_card.dart';
import 'package:foodies/shared/widgets/app_logo.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  late PageController _pageController;
  int _virtualPage = 5000;
  int _currentIndex = 0;
  StreamSubscription? _intentSub;

  // Warm Obsidian Palette
  static const Color kBgWarmObsidian = Color(0xFF0C0A09);
  static const Color kFlameOrange = Color(0xFFFF6E2E);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _virtualPage,
      viewportFraction: 0.90,
    );
    _initShareIntentListener();
  }

  /// Android Share Intent Listener: receives shared URLs from Instagram, Facebook, browsers
  void _initShareIntentListener() {
    try {
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        if (value.isNotEmpty) {
          final sharedText = value.first.path;
          _handleSharedText(sharedText);
        }
      }, onError: (_) {});

      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) {
          final sharedText = value.first.path;
          _handleSharedText(sharedText);
          ReceiveSharingIntent.instance.reset();
        }
      });
    } catch (_) {}
  }

  void _handleSharedText(String text) {
    final url = UrlParser.extractUrl(text) ?? text;
    if (UrlParser.isValidUrl(url)) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ImportSheet(initialUrl: url),
      );
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(allRecipesStreamProvider);
    final jobsAsync = ref.watch(importJobsStreamProvider);

    final activeJobsCount = jobsAsync.maybeWhen(
      data: (jobs) => jobs.where((j) => !j.isTerminal).length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: kBgWarmObsidian,
      body: SafeArea(
        child: Column(
          children: [
            // Pinned Top Navigation Bar (compact, overflow-free)
            _buildTopBar(activeJobsCount),

            // Main Body: Looping Recipe Feed or Empty State
            Expanded(
              child: recipesAsync.when(
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return _buildEmptyState();
                  }

                  final total = recipes.length;
                  return Column(
                    children: [
                      // Card count indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RECIPE ${_currentIndex + 1} OF $total',
                              style: const TextStyle(
                                color: Color(0xFFA8A29E),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Row(
                              children: [
                                Icon(Icons.swipe, size: 14, color: Color(0xFFA8A29E)),
                                SizedBox(width: 4),
                                Text(
                                  'Swipe to loop',
                                  style: TextStyle(
                                    color: Color(0xFFA8A29E),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Looping PageView of Flashcards
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (page) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _virtualPage = page;
                              _currentIndex = page % total;
                            });
                          },
                          itemBuilder: (context, index) {
                            final recipeIndex = index % total;
                            final recipe = recipes[recipeIndex];
                            return RecipeFlashcard(recipe: recipe);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: kFlameOrange),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading recipes: $err', style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(int activeJobsCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(
                size: 28,
                borderRadius: 9,
                padding: 2,
              ),
              const SizedBox(width: 6),
              ShaderMask(
                shaderCallback: (bounds) => AppColors.flameGradient.createShader(bounds),
                child: const Text(
                  'FOODIES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons: Search, Active Jobs Sync, Settings, Add Recipe
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.search, color: AppColors.textPrimary, size: 20),
                tooltip: 'Search recipes',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.sync, color: AppColors.textPrimary, size: 20),
                    tooltip: 'Import activity',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImportJobsScreen()),
                      );
                    },
                  ),
                  if (activeJobsCount > 0)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: kFlameOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$activeJobsCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.tune, color: AppColors.textPrimary, size: 19),
                tooltip: 'Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: AppColors.flameGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: kFlameOrange.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  tooltip: 'Import or add recipe',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ImportSheet(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(
              size: 112,
              borderRadius: 32,
              padding: 14,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Recipe Library is Empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Save Instagram and Facebook reels to transform them into clean, searchable, offline-ready recipes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.link, size: 19),
                label: const Text('Import Social Reel Link'),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const ImportSheet(),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 18, color: AppColors.amber),
                label: const Text('Load Demo Recipes', style: TextStyle(color: AppColors.amber)),
                onPressed: _seedDemoRecipes,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.edit_note, size: 18, color: AppColors.textSecondary),
              label: const Text('Or write a recipe manually', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecipeEditScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedDemoRecipes() async {
    final repo = ref.read(recipeRepositoryProvider);
    final uuid = const Uuid();
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added 2 demo recipes! Enjoy swiping through your feed.')),
      );
    }
  }
}
