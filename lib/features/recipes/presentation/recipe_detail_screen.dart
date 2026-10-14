import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/shared/widgets/status_badge.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/presentation/recipe_edit_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_placeholder_image.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
  });

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _adjustedServings;
  final Set<String> _checkedIngredientIds = {};

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(singleRecipeStreamProvider(widget.recipeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: recipeAsync.when(
        data: (recipe) {
          if (recipe == null) {
            return const Center(
              child: Text(
                'Recipe not found or has been deleted.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final currentServings = _adjustedServings ?? recipe.servingCount;
          final scaledIngredients = recipe.getScaledIngredients(currentServings);

          return CustomScrollView(
            slivers: [
              // 1. Hero Image App Bar
              _buildSliverAppBar(recipe),

              // 2. Body Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      if (recipe.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: recipe.tags.map((tag) {
                            return StatusBadge(
                              label: '#${tag.name}',
                              color: AppColors.primary,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Title
                      Text(
                        recipe.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Description
                      if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                        Text(
                          recipe.description!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Time & Meta Summary Row
                      _buildTimeStatsRow(recipe),
                      const SizedBox(height: 24),

                      // Servings Adjuster
                      _buildServingsAdjuster(recipe, currentServings),
                      const SizedBox(height: 24),

                      // Ingredients Checklist
                      _buildIngredientsSection(scaledIngredients, recipe),
                      const SizedBox(height: 28),

                      // Cooking Steps
                      _buildInstructionsSection(recipe),
                      const SizedBox(height: 28),

                      // Nutrition Breakdown Card
                      _buildNutritionCard(recipe, currentServings),
                      const SizedBox(height: 28),

                      // Source Link & Platform Card
                      if (recipe.sourceUrl != null) ...[
                        _buildSourceCard(recipe),
                        const SizedBox(height: 24),
                      ],

                      // Source Caption & Transcript Accordion
                      if (recipe.sourceCaption != null || recipe.transcript != null) ...[
                        _buildSourceContentAccordion(recipe),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading recipe: $err',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Recipe recipe) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: AppColors.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.65),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        // Favorite toggle
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.65),
          child: IconButton(
            icon: Icon(
              recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: recipe.isFavorite ? AppColors.error : Colors.white,
              size: 20,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(recipeRepositoryProvider).toggleFavorite(recipe.id);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Share
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.65),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white, size: 19),
            onPressed: () {
              // ignore: deprecated_member_use
              Share.share(
                'Check out this recipe for "${recipe.title}" on Foodies!${recipe.sourceUrl != null ? '\nSource: ${recipe.sourceUrl}' : ''}',
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Edit
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.65),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 19),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecipeEditScreen(recipe: recipe),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Delete
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.65),
          child: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 19),
            onPressed: () => _confirmDelete(recipe),
          ),
        ),
        const SizedBox(width: 14),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            RecipeCardImage(
              imagePath: recipe.imagePath,
              title: recipe.title,
              borderRadius: BorderRadius.zero,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.cardOverlayGradient,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStatsRow(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTimeStat('PREP', recipe.prepTimeMinutes != null ? '${recipe.prepTimeMinutes}m' : '--'),
          Container(width: 1, height: 32, color: AppColors.border),
          _buildTimeStat('COOK', recipe.cookTimeMinutes != null ? '${recipe.cookTimeMinutes}m' : '--'),
          Container(width: 1, height: 32, color: AppColors.border),
          _buildTimeStat('TOTAL', recipe.formattedTime),
        ],
      ),
    );
  }

  Widget _buildTimeStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildServingsAdjuster(Recipe recipe, int currentServings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Servings',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Ingredients scale automatically',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 22),
                onPressed: currentServings > 1
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _adjustedServings = currentServings - 1);
                      }
                    : null,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                alignment: Alignment.center,
                child: Text(
                  '$currentServings',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _adjustedServings = currentServings + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(List<Ingredient> ingredients, Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Ingredients',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${ingredients.length} items',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ingredients.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = ingredients[index];
              final isChecked = _checkedIngredientIds.contains(item.id);

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isChecked) {
                      _checkedIngredientIds.remove(item.id);
                    } else {
                      _checkedIngredientIds.add(item.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isChecked ? AppColors.success : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.fullDisplayText,
                          style: TextStyle(
                            color: isChecked ? AppColors.textMuted : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            decorationColor: AppColors.textMuted,
                          ),
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
    );
  }

  Widget _buildInstructionsSection(Recipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Instructions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              '${recipe.steps.length} steps',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recipe.steps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final step = recipe.steps[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppColors.flameGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${step.stepNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.instruction,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (step.durationMinutes != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: AppColors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${step.durationMinutes} minutes',
                                style: const TextStyle(
                                  color: AppColors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNutritionCard(Recipe recipe, int servings) {
    final nutrition = recipe.nutrition;
    final hasNutrition = nutrition.hasValues;

    String methodLabel = 'Unavailable';
    Color methodColor = AppColors.textMuted;
    if (nutrition.method == 'creator') {
      methodLabel = 'Verified by Creator';
      methodColor = AppColors.success;
    } else if (nutrition.method == 'estimated') {
      methodLabel = 'Composition Estimate (${nutrition.confidence ?? "standard"})';
      methodColor = AppColors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text(
                'Nutrition Per Serving',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              StatusBadge(
                label: methodLabel,
                color: methodColor,
                isPill: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasNutrition) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutrientStat('CALORIES', '${nutrition.calories?.toInt() ?? "--"}', 'kcal'),
                _buildNutrientStat('PROTEIN', '${nutrition.proteinGrams ?? "--"}', 'g'),
                _buildNutrientStat('CARBS', '${nutrition.carbsGrams ?? "--"}', 'g'),
                _buildNutrientStat('FAT', '${nutrition.fatGrams ?? "--"}', 'g'),
              ],
            ),
          ] else ...[
            const Text(
              'Specific nutritional breakdown could not be calculated from the provided ingredients.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Nutritional values are treated as estimates and may vary based on exact brands and preparation methods.',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.8),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientStat(String title, String value, String unit) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceCard(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Original Source Link',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recipe.sourceUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Reel', style: TextStyle(fontSize: 13)),
            onPressed: () async {
              final uri = Uri.parse(recipe.sourceUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceContentAccordion(Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: const Text(
          'Original Caption & Transcript',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textMuted,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (recipe.sourceCaption != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Original Caption:',
                style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              recipe.sourceCaption!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
          ],
          if (recipe.transcript != null) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Audio Transcript:',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              recipe.transcript!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(Recipe recipe) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Recipe', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${recipe.title}" from your library? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(recipeRepositoryProvider).deleteRecipe(recipe.id);
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
