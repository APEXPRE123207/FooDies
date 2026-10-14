import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/recipe.dart';
import '../recipe_detail_screen.dart';
import 'recipe_placeholder_image.dart';

class RecipeFlashcard extends ConsumerWidget {
  final Recipe recipe;

  const RecipeFlashcard({
    super.key,
    required this.recipe,
  });

  Color _resolveBadgeColor(String badge) {
    final lower = badge.toLowerCase();
    if (lower.contains('protein') || lower.contains('muscle') || lower.contains('gym')) {
      return AppColors.macroProtein;
    }
    if (lower.contains('loss') || lower.contains('fat loss') || lower.contains('cut') || lower.contains('calorie')) {
      return AppColors.macroCalories;
    }
    if (lower.contains('carb') || lower.contains('energy') || lower.contains('pre-workout')) {
      return AppColors.macroCarbs;
    }
    if (lower.contains('keto') || lower.contains('high-fat') || lower.contains('fat')) {
      return AppColors.macroFats;
    }
    if (lower.contains('veg') || lower.contains('vegan') || lower.contains('plant') || lower.contains('clean')) {
      return AppColors.badgeVegetarian;
    }
    return AppColors.amber;
  }

  String? _resolveHeroBadge() {
    if (recipe.primaryBadge != null && recipe.primaryBadge!.trim().isNotEmpty) {
      return recipe.primaryBadge!.trim();
    }
    if (recipe.macroProfile != null && recipe.macroProfile!.trim().isNotEmpty) {
      return recipe.macroProfile!.trim();
    }
    if (recipe.nutrition.proteinGrams != null && recipe.nutrition.proteinGrams! >= 25) {
      return '💪 ${recipe.nutrition.proteinGrams!.toInt()}g Protein';
    }
    if (recipe.nutrition.calories != null && recipe.nutrition.calories! <= 450) {
      return '🔥 ${recipe.nutrition.calories!.toInt()} kcal';
    }
    if (recipe.effectiveTotalTime != null && recipe.effectiveTotalTime! <= 20) {
      return '⏱ ~${recipe.effectiveTotalTime} Min';
    }
    return null;
  }

  Color _resolveCardGlowColor(Recipe recipe) {
    final badge = (recipe.primaryBadge ?? '').toLowerCase();
    final macro = (recipe.macroProfile ?? '').toLowerCase();
    final title = recipe.title.toLowerCase();
    final tags = recipe.tags.map((t) => t.name.toLowerCase()).join(' ');

    // 1. High-Protein / Muscle / Chicken / Egg specials -> Vibrant Emerald Green
    if (badge.contains('protein') ||
        badge.contains('muscle') ||
        macro.contains('protein') ||
        title.contains('chicken') ||
        title.contains('egg') ||
        tags.contains('gym') ||
        (recipe.nutrition.proteinGrams != null && recipe.nutrition.proteinGrams! >= 25)) {
      return const Color(0xFF10B981); // Emerald
    }

    // 2. Fat Loss / Clean Eating / Low Calorie -> Electric Cyan
    if (badge.contains('fat loss') ||
        badge.contains('cut') ||
        tags.contains('clean') ||
        tags.contains('fat loss') ||
        (recipe.nutrition.calories != null && recipe.nutrition.calories! <= 450)) {
      return const Color(0xFF06B6D4); // Electric Cyan
    }

    // 3. Cheat Meal / Pizza / High Calorie -> Flame Orange
    if (badge.contains('cheat') ||
        title.contains('pizza') ||
        title.contains('burger') ||
        recipe.isFavorite ||
        (recipe.nutrition.calories != null && recipe.nutrition.calories! > 600)) {
      return const Color(0xFFFF6E2E); // Flame Orange
    }

    // 4. Vegetarian / Vegan / Paneer / Plant -> Fresh Mint Green
    if (badge.contains('veg') ||
        badge.contains('plant') ||
        title.contains('paneer') ||
        title.contains('tofu') ||
        tags.contains('veg') ||
        tags.contains('vegetarian')) {
      return const Color(0xFF22C55E); // Mint Green
    }

    // 5. Quick / Hostel / 10-Min -> Warm Amber Gold
    if (tags.contains('hostel') ||
        tags.contains('quick') ||
        (recipe.effectiveTotalTime != null && recipe.effectiveTotalTime! <= 15)) {
      return const Color(0xFFFBBF24); // Warm Amber Gold
    }

    // 6. Desserts / Sweet -> Berry Pink
    if (title.contains('sweet') || title.contains('dessert') || tags.contains('dessert')) {
      return const Color(0xFFEC4899); // Berry Pink
    }

    // 7. Deterministic culinary neon glow palette based on recipe id or title
    const vibrantGlows = [
      Color(0xFFFF6E2E), // Flame Orange
      Color(0xFF10B981), // Emerald
      Color(0xFF06B6D4), // Electric Cyan
      Color(0xFFF59E0B), // Warm Gold
      Color(0xFF8B5CF6), // Royal Purple
      Color(0xFFEC4899), // Neon Pink
    ];
    final seed = (recipe.id + recipe.title).hashCode.abs();
    return vibrantGlows[seed % vibrantGlows.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroBadge = _resolveHeroBadge();
    final badgeColor = heroBadge != null ? _resolveBadgeColor(heroBadge) : AppColors.amber;
    final glowColor = _resolveCardGlowColor(recipe);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: glowColor.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            // 1. Wide diffused ambient glow lighting up the dark obsidian backdrop
            BoxShadow(
              color: glowColor.withOpacity(0.32),
              blurRadius: 44,
              spreadRadius: 3,
              offset: const Offset(0, 10),
            ),
            // 2. Focused vibrant inner halo
            BoxShadow(
              color: glowColor.withOpacity(0.18),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            // 3. Grounding dark drop shadow for card depth
            BoxShadow(
              color: Colors.black.withOpacity(0.65),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background image or designed placeholder
              RecipeCardImage(
                imagePath: recipe.imagePath,
                title: recipe.title,
                category: recipe.tags.isNotEmpty ? recipe.tags.first.name : null,
              ),

              // 2. Warm culinary gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.cardOverlayGradient,
                ),
              ),

              // 3. ANCHOR 1 & 2: Top Row (Top-Left Hero Pill & Top-Right Source/Favorite)
              Positioned(
                top: 18,
                left: 18,
                right: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top-Left Glassmorphic Hero Badge
                    if (heroBadge != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: badgeColor.withOpacity(0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: badgeColor.withOpacity(0.6),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  heroBadge,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Top-Right Source Badge + Favorite Heart
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (recipe.sourcePlatform != null) ...[
                          _buildPlatformBadge(recipe.sourcePlatform!),
                          const SizedBox(width: 8),
                        ],
                        _buildFavoriteButton(ref, context),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. ANCHOR 3: Bottom Scrim (Editorial Title + Glanceable Meta)
              Positioned(
                bottom: 22,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dish Title in Editorial Serif font (Playfair Display)
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.editorialTitle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Glanceable Stats line with Tabular Monospace numbers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              // Time
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    recipe.formattedTime,
                                    style: AppTheme.tabularFigures(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),

                              // Dot separator
                              const Text('•', style: TextStyle(color: AppColors.textMuted)),

                              // Calories
                              if (recipe.nutrition.calories != null) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${recipe.nutrition.calories!.toInt()} kcal',
                                      style: AppTheme.tabularFigures(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text('•', style: TextStyle(color: AppColors.textMuted)),
                              ],

                              // Ingredients count
                              Text(
                                '${recipe.ingredients.length} ingr.',
                                style: AppTheme.tabularFigures(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // View button
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.55),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Cook',
                                    style: TextStyle(
                                      color: AppColors.primaryLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: AppColors.primaryLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(String platform) {
    IconData icon = Icons.link;
    Color color = AppColors.textSecondary;

    if (platform == 'instagram') {
      icon = Icons.camera_alt_outlined;
      color = const Color(0xFFE1306C);
    } else if (platform == 'facebook') {
      icon = Icons.facebook;
      color = const Color(0xFF1877F2);
    } else if (platform == 'youtube') {
      icon = Icons.play_circle_outline;
      color = const Color(0xFFFF0000);
    } else if (platform == 'tiktok') {
      icon = Icons.music_note;
      color = Colors.cyanAccent;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.5), width: 1),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(WidgetRef ref, BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              shape: BoxShape.circle,
              border: Border.all(
                color: recipe.isFavorite
                    ? AppColors.error.withOpacity(0.7)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 17,
              color: recipe.isFavorite ? AppColors.error : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
