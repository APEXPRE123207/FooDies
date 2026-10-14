import 'dart:async';
import 'dart:math' as math;
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
import 'package:foodies/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:foodies/features/recipes/presentation/recipe_edit_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_placeholder_image.dart';
import 'package:foodies/shared/widgets/app_logo.dart';

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  late final ScrollController _verticalScrollController;
  late final PageController _carouselPageController;

  static const int kInitialVirtualPage = 600;
  double _scrollOffset = 0.0;
  double _currentPage = kInitialVirtualPage.toDouble();
  int _activeIndex = 0;
  StreamSubscription? _intentSub;

  // Warm Culinary Obsidian Palette
  static const Color kBgWarmObsidian = Color(0xFF0C0A09);
  static const Color kFlameOrange = Color(0xFFFF6E2E);

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _scrollOffset = _verticalScrollController.offset;
          });
        }
      });

    _carouselPageController = PageController(
      viewportFraction: 0.72,
      initialPage: kInitialVirtualPage,
    )..addListener(() {
        final page = _carouselPageController.page ?? kInitialVirtualPage.toDouble();
        final recipes = ref.read(allRecipesStreamProvider).asData?.value ?? <Recipe>[];
        if (recipes.isNotEmpty) {
          final int newIndex = (page.round() % recipes.length + recipes.length) % recipes.length;
          if (newIndex != _activeIndex) {
            HapticFeedback.selectionClick();
            _activeIndex = newIndex;
          }
        }
        if (mounted) {
          setState(() {
            _currentPage = page;
          });
        }
      });

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
    _verticalScrollController.dispose();
    _carouselPageController.dispose();
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

            // Main Content Area
            Expanded(
              child: recipesAsync.when(
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Ensure enough items to form a complete 3D disc
                  List<Recipe> carouselRecipes = recipes;
                  if (recipes.length < 5) {
                    final repeated = <Recipe>[];
                    while (repeated.length < 6) {
                      repeated.addAll(recipes);
                    }
                    carouselRecipes = repeated.take(6).toList();
                  }

                  // Group recipes into Netflix-style Tag and Ingredient Rows
                  final categories = <String, List<Recipe>>{
                    '💪 Gym & High-Protein': recipes.where((r) =>
                        (r.nutrition.proteinGrams != null && r.nutrition.proteinGrams! >= 25) ||
                        r.tags.any((t) => t.name.toLowerCase().contains('gym') || t.name.toLowerCase().contains('protein')) ||
                        (r.macroProfile?.toLowerCase().contains('protein') ?? false)
                    ).toList(),
                    '🍗 Chicken Specials': recipes.where((r) =>
                        r.ingredients.any((i) => i.name.toLowerCase().contains('chicken')) ||
                        r.title.toLowerCase().contains('chicken')
                    ).toList(),
                    '🥚 Quick Egg Meals': recipes.where((r) =>
                        r.ingredients.any((i) => i.name.toLowerCase().contains('egg')) ||
                        r.title.toLowerCase().contains('egg')
                    ).toList(),
                    '🧀 Paneer & Soya Specials': recipes.where((r) =>
                        r.ingredients.any((i) =>
                            i.name.toLowerCase().contains('paneer') ||
                            i.name.toLowerCase().contains('soya') ||
                            i.name.toLowerCase().contains('tofu')) ||
                        r.title.toLowerCase().contains('paneer') ||
                        r.title.toLowerCase().contains('tofu')
                    ).toList(),
                    '🏠 Hostel & 10-Min Lazy': recipes.where((r) =>
                        (r.effectiveTotalTime != null && r.effectiveTotalTime! <= 15) ||
                        r.tags.any((t) => t.name.toLowerCase().contains('hostel') || t.name.toLowerCase().contains('quick'))
                    ).toList(),
                    '🥗 Fat Loss & Clean Eating': recipes.where((r) =>
                        (r.nutrition.calories != null && r.nutrition.calories! <= 450) ||
                        r.tags.any((t) => t.name.toLowerCase().contains('fat loss') || t.name.toLowerCase().contains('clean'))
                    ).toList(),
                    '🍕 Cheat Meals & Favorites': recipes.where((r) =>
                        r.isFavorite || (r.nutrition.calories != null && r.nutrition.calories! > 600)
                    ).toList(),
                  };

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;

                      return CustomScrollView(
                        controller: _verticalScrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // 1. Morphing Stage:
                          // At top: 60-70% flashcards fill the screen (shelves are below the fold)
                          // On vertical scroll up: morphs into disc, spins, and disappears!
                          SliverPersistentHeader(
                            pinned: false,
                            delegate: _MorphingDiscHeaderDelegate(
                              maxExtentHeight: availableHeight,
                              minExtentHeight: 0.0,
                              scrollOffset: _scrollOffset,
                              currentPage: _currentPage,
                              pageController: _carouselPageController,
                              recipes: carouselRecipes,
                              onTapRecipe: (r) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)),
                                );
                              },
                            ),
                          ),

                          // 2. Section Divider Title
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: kFlameOrange,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'BROWSE BY CRAVING & GOAL',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFA8A29E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 3. Netflix-Style Category Rows
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final entry = categories.entries.elementAt(index);
                                if (entry.value.isEmpty) return const SizedBox.shrink();
                                return _NetflixCategoryRow(
                                  title: entry.key,
                                  recipes: entry.value,
                                  onTapRecipe: (r) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.id)),
                                    );
                                  },
                                );
                              },
                              childCount: categories.length,
                            ),
                          ),

                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      );
                    },
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
      suitabilityReason: 'Packed with 42g lean protein from chicken breast and healthy fats from olive oil.',
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
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 2, instruction: 'Heat olive oil in skillet. Sear chicken 5 mins per side until golden.', durationMinutes: 10),
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 3, instruction: 'Remove chicken. Add garlic, then heavy cream and simmer for 3 mins.', durationMinutes: 3),
        RecipeStep(id: uuid.v4(), recipeId: r1Id, stepNumber: 4, instruction: 'Stir in parmesan and fresh spinach. Return chicken and simmer 2 mins.', durationMinutes: 2),
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
      sourceCaption: 'Mastering authentic Neapolitan pizza at home.',
      prepTimeMinutes: 20,
      cookTimeMinutes: 10,
      totalTimeMinutes: 30,
      isTimeEstimated: true,
      servingCount: 2,
      isFavorite: false,
      primaryBadge: '🍕 Clean Cheat Meal',
      suitabilityReason: 'Slow-fermented dough paired with fresh San Marzano tomatoes and grass-fed mozzarella.',
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
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'flour', quantity: 2.5, unit: 'cups'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'mozzarella', quantity: 200, unit: 'g'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'tomato', quantity: 1, unit: 'cup'),
        Ingredient(id: uuid.v4(), recipeId: r2Id, name: 'olive oil', quantity: 1, unit: 'tbsp'),
      ],
      steps: [
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 1, instruction: 'Stretch pizza dough onto a floured peel.', durationMinutes: 5),
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 2, instruction: 'Spread crushed tomatoes, add mozzarella and olive oil.', durationMinutes: 3),
        RecipeStep(id: uuid.v4(), recipeId: r2Id, stepNumber: 3, instruction: 'Bake at highest temp for 7-9 mins until blistered.', durationMinutes: 8),
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
        const SnackBar(content: Text('Added demo recipes! Enjoy exploring your feed.')),
      );
    }
  }
}

// ============================================================================
// MORPHING DISC SLIVER HEADER: 60-70% FLASHCARDS -> 3D DISC -> DISAPPEARS
// ============================================================================
class _MorphingDiscHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double maxExtentHeight;
  final double minExtentHeight;
  final double scrollOffset;
  final double currentPage;
  final PageController pageController;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onTapRecipe;

  _MorphingDiscHeaderDelegate({
    required this.maxExtentHeight,
    required this.minExtentHeight,
    required this.scrollOffset,
    required this.currentPage,
    required this.pageController,
    required this.recipes,
    required this.onTapRecipe,
  });

  @override
  double get maxExtent => maxExtentHeight;

  @override
  double get minExtent => minExtentHeight;

  @override
  bool shouldRebuild(covariant _MorphingDiscHeaderDelegate oldDelegate) => true;

  double _diff(int i, double page, int n) {
    if (n <= 0) return 0.0;
    double p = page % n;
    if (p < 0) p += n;
    double diff = i.toDouble() - p;
    while (diff > n / 2.0) {
      diff -= n;
    }
    while (diff < -n / 2.0) {
      diff += n;
    }
    return diff;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final size = MediaQuery.of(context).size;
    final W = size.width;
    final H = maxExtentHeight;
    final n = recipes.length;
    if (n == 0) return const SizedBox.shrink();

    // Scroll progress: 0.0 (at top) -> 1.0 (scrolled up)
    // Over first 40% of scroll: folds into 3D disc
    final double tDisc = (shrinkOffset / (H * 0.40)).clamp(0.0, 1.0);
    // Over next 35% of scroll: disc shrinks and disappears as shelves glide up
    final double tHide = ((shrinkOffset - H * 0.40) / (H * 0.35)).clamp(0.0, 1.0);

    final double overallScale = lerpD(1.0, 0.0, tHide);
    final double overallOpacity = (1.0 - tHide).clamp(0.0, 1.0);

    final R = math.min(W, H) * 0.28; // ring radius
    final segW = 2 * math.pi * R / n * 0.92;
    final cardW0 = W * 0.72; // 60-70% flashcards!
    final cardH0 = math.min(H * 0.62, 400.0);

    // Draw far cards first so near ones overlap correctly
    final order = List.generate(n, (i) => i)
      ..sort((a, b) => _depth(b, currentPage, n).compareTo(_depth(a, currentPage, n)));

    return OverflowBox(
      minHeight: H,
      maxHeight: H,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: H,
        width: W,
        child: Opacity(
          opacity: overallOpacity,
          child: Transform.scale(
            scale: overallScale,
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Render 3D cards
                for (final i in order)
                  _buildCard(
                    i: i,
                    page: currentPage,
                    t: tDisc,
                    W: W,
                    H: H,
                    R: R,
                    segW: segW,
                    cardW0: cardW0,
                    cardH0: cardH0,
                    n: n,
                  ),

                // Bottom hint when at top (fades out as user scrolls)
                if (tDisc < 0.25)
                  Positioned(
                    bottom: 24,
                    child: Opacity(
                      opacity: (1.0 - tDisc * 4.0).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Color(0xFFA8A29E),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Scroll up for Cravings & Shelves',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Invisible PageView for side-scrolling while flat
                // Kept mounted so pageController position is never lost
                IgnorePointer(
                  ignoring: shrinkOffset > 60.0,
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: recipes.length * 1000,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index % recipes.length];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTapRecipe(recipe),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _depth(int i, double page, int n) {
    final diff = _diff(i, page, n);
    final th = 2 * math.pi * diff / n;
    return -math.cos(th); // top of ring (front) = smaller
  }

  Widget _buildCard({
    required int i,
    required double page,
    required double t,
    required double W,
    required double H,
    required double R,
    required double segW,
    required double cardW0,
    required double cardH0,
    required int n,
  }) {
    final recipe = recipes[i];
    final diff = _diff(i, page, n);
    final theta = 2 * math.pi * diff / n;

    // Size: 60-70% flashcard -> thin arc segment
    final w = lerpD(cardW0, segW, t);
    final h = lerpD(cardH0, R * 0.55, t);

    // Flat carousel horizontal offset: centered at W/2 when diff == 0!
    final dx = diff * (cardW0 + 16.0) * (1 - t);

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // perspective
      ..translate(W / 2, lerpD(H / 2 - 16.0, H * 0.44, t))
      ..rotateX(1.0 * t) // whole ring tilts forward
      ..rotateY(-0.35 * t) // slightly angled view for depth
      ..translate(dx, 0.0)
      ..rotateZ(theta * t) // place around the circle
      ..translate(0.0, -R * t) // push out to the radius
      ..rotateX(0.85 * t) // each block leans so tops meet
      ..translate(-w / 2, -h / 2);

    return Transform(
      transform: m,
      child: SizedBox(
        width: w,
        height: h,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(lerpD(24, 14, t)),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(t),
              width: 3 * t,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Recipe card image with fallback
              RecipeCardImage(
                imagePath: recipe.imagePath,
                title: recipe.title,
                category: recipe.tags.isNotEmpty ? recipe.tags.first.name : null,
              ),

              // Gradient scrim
              if (t < 0.40)
                Opacity(
                  opacity: (1.0 - t * 2.5).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.25),
                          Colors.transparent,
                          const Color(0xFF0C0A09).withOpacity(0.95),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

              // Card title, badges, macros (fades out as it becomes a disc)
              if (t < 0.40)
                Opacity(
                  opacity: (1.0 - t * 2.5).clamp(0.0, 1.0),
                  child: _buildCardOverlay(recipe),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardOverlay(Recipe recipe) {
    final badge = recipe.primaryBadge ??
        (recipe.nutrition.proteinGrams != null && recipe.nutrition.proteinGrams! >= 25
            ? '💪 ${recipe.nutrition.proteinGrams!.toInt()}g Protein'
            : 'Chef Pick');
    final calories = recipe.nutrition.calories?.toInt() ?? 0;
    final protein = recipe.nutrition.proteinGrams?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Bottom title and macro pills
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (calories > 0)
                    _macroPill('🔥 $calories kcal', const Color(0xFFFF6E2E)),
                  if (protein > 0)
                    _macroPill('💪 ${protein}g P', const Color(0xFF10B981)),
                  _macroPill('⏱ ${recipe.formattedTime}', const Color(0xFFFBBF24)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1C19).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  double lerpD(double a, double b, double t) => a + (b - a) * t;
}

// ============================================================================
// NETFLIX-STYLE HORIZONTAL CATEGORY RAIL
// ============================================================================
class _NetflixCategoryRow extends StatelessWidget {
  final String title;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onTapRecipe;

  const _NetflixCategoryRow({
    required this.title,
    required this.recipes,
    required this.onTapRecipe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${recipes.length} dishes →',
                  style: const TextStyle(
                    color: Color(0xFFFF6E2E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = recipes[index];
                final protein = item.nutrition.proteinGrams?.toInt() ?? 0;
                final calories = item.nutrition.calories?.toInt() ?? 0;

                return GestureDetector(
                  onTap: () => onTapRecipe(item),
                  child: Container(
                    width: 148,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161412),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF292524)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image with emblem + title fallback
                        RecipeCardImage(
                          imagePath: item.imagePath,
                          title: item.title,
                          category: item.tags.isNotEmpty ? item.tags.first.name : null,
                        ),

                        // Gradient scrim for text readability
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                const Color(0xFF0C0A09).withOpacity(0.92),
                              ],
                            ),
                          ),
                        ),

                        // Top Protein Pill
                        if (protein > 0)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '💪 ${protein}g P',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),

                        // Bottom Title & Meta
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '⏱ ${item.formattedTime}${calories > 0 ? ' • $calories kcal' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFA8A29E),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
