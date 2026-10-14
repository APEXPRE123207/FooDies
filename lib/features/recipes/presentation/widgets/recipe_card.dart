import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/models/recipe.dart';
import '../recipe_detail_screen.dart';
import 'recipe_placeholder_image.dart';

class RecipeFlashcard extends ConsumerWidget {
  final Recipe recipe;

  const RecipeFlashcard({
    super.key,
    required this.recipe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 30,
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

              // 2. Cinematic dark gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.cardOverlayGradient,
                ),
              ),

              // 3. Top Row: Platform badge and Favorite toggle
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (recipe.sourcePlatform != null)
                      _buildPlatformBadge(recipe.sourcePlatform!)
                    else
                      const SizedBox.shrink(),
                    _buildFavoriteButton(ref, context),
                  ],
                ),
              ),

              // 4. Bottom Content: Title, metadata pills, tags
              Positioned(
                bottom: 24,
                left: 22,
                right: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tags row
                    if (recipe.tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recipe.tags.take(3).map((tag) {
                          return StatusBadge(
                            label: '#${tag.name}',
                            color: AppColors.amber,
                            backgroundColor: Colors.black.withOpacity(0.55),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick metadata chips: Cook time, servings, calories (Wrap prevents overflow)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Cook time
                        _buildMetaItem(
                          icon: Icons.timer_outlined,
                          label: recipe.formattedTime,
                        ),

                        // Servings
                        _buildMetaItem(
                          icon: Icons.people_outline,
                          label: '${recipe.servingCount} servings',
                        ),

                        // Nutrition calorie estimate (if available)
                        if (recipe.nutrition.calories != null)
                          _buildMetaItem(
                            icon: Icons.local_fire_department_outlined,
                            label: '${recipe.nutrition.calories!.toInt()} kcal',
                            color: AppColors.primaryLight,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // "View Recipe" CTA indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${recipe.ingredients.length} ingredients • ${recipe.steps.length} steps',
                          style: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: AppColors.primaryLight,
                              ),
                            ],
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
    String name = 'Web';
    Color color = AppColors.textSecondary;

    if (platform == 'instagram') {
      icon = Icons.camera_alt_outlined;
      name = 'Instagram Reel';
      color = const Color(0xFFE1306C);
    } else if (platform == 'facebook') {
      icon = Icons.facebook;
      name = 'Facebook Reel';
      color = const Color(0xFF1877F2);
    } else if (platform == 'youtube') {
      icon = Icons.play_circle_outline;
      name = 'YouTube';
      color = const Color(0xFFFF0000);
    } else if (platform == 'tiktok') {
      icon = Icons.music_note;
      name = 'TikTok';
      color = Colors.cyanAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(WidgetRef ref, BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          shape: BoxShape.circle,
          border: Border.all(
            color: recipe.isFavorite
                ? AppColors.error.withOpacity(0.6)
                : AppColors.border,
            width: 1,
          ),
        ),
        child: Icon(
          recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: recipe.isFavorite ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
