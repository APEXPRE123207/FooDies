import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/core/theme/app_theme.dart';
import 'package:foodies/shared/widgets/status_badge.dart';
import 'package:foodies/features/recipes/domain/models/ingredient.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/presentation/recipe_edit_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/ingredient_swap_modal.dart';
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

  // Hands-free Cooking Mode & Wakelock
  bool _isCookingMode = false;

  // Floating Dynamic Island Countdown Timer
  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalTimerSeconds = 0;
  bool _isTimerRunning = false;
  String _timerLabel = '';

  @override
  void dispose() {
    _timer?.cancel();
    if (_isCookingMode) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  void _toggleCookingMode() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isCookingMode = !_isCookingMode;
      if (_isCookingMode) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(
              _isCookingMode ? Icons.outdoor_grill : Icons.kitchen,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isCookingMode
                    ? 'Cooking Mode Active: Screen stay-awake enabled & large step text!'
                    : 'Standard Browsing Mode restored.',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTimer(int minutes, String label) {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() {
      _totalTimerSeconds = minutes * 60;
      _remainingSeconds = _totalTimerSeconds;
      _isTimerRunning = true;
      _timerLabel = label;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        setState(() => _isTimerRunning = false);
        HapticFeedback.vibrate();
        _showTimerFinishedDialog(label);
      }
    });
  }

  void _pauseResumeTimer() {
    HapticFeedback.selectionClick();
    if (_isTimerRunning) {
      _timer?.cancel();
      setState(() => _isTimerRunning = false);
    } else {
      setState(() => _isTimerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          t.cancel();
          setState(() => _isTimerRunning = false);
          HapticFeedback.vibrate();
          _showTimerFinishedDialog(_timerLabel);
        }
      });
    }
  }

  void _cancelTimer() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _remainingSeconds = 0;
      _totalTimerSeconds = 0;
      _isTimerRunning = false;
      _timerLabel = '';
    });
  }

  void _showTimerFinishedDialog(String label) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.alarm_on, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('Timer Finished!', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          label.isNotEmpty ? '$label is done cooking!' : 'Your cooking timer has elapsed.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

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

          return Stack(
            children: [
              CustomScrollView(
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
                          // Hero Primary Badge & Tags
                          _buildBadgesHeader(recipe),
                          const SizedBox(height: 12),

                          // Editorial Title in Serif font
                          Text(
                            recipe.title,
                            style: AppTheme.editorialTitle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.22,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Suitability Reason / AI Nutritional Insight Card
                          if (recipe.suitabilityReason != null && recipe.suitabilityReason!.isNotEmpty) ...[
                            _buildSuitabilityCard(recipe.suitabilityReason!),
                            const SizedBox(height: 14),
                          ],

                          // Description
                          if (recipe.description != null && recipe.description!.isNotEmpty) ...[
                            Text(
                              recipe.description!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Time & Cooking Mode Action Row
                          _buildTimeStatsRow(recipe),
                          const SizedBox(height: 20),

                          // Servings Adjuster
                          _buildServingsAdjuster(recipe, currentServings),
                          const SizedBox(height: 24),

                          // Ingredients Checklist with Inline ✨ Swap
                          _buildIngredientsSection(scaledIngredients, recipe),
                          const SizedBox(height: 28),

                          // Cooking Steps with Kitchen Distance sizing
                          _buildInstructionsSection(recipe),
                          const SizedBox(height: 28),

                          // Nutrition Breakdown Card with Semantic Colors
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

                          // Bottom padding for floating timer
                          if (_totalTimerSeconds > 0) const SizedBox(height: 70),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Floating Dynamic Island Timer Bar
              if (_totalTimerSeconds > 0)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: _buildFloatingTimerBar(),
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

  Widget _buildBadgesHeader(Recipe recipe) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Primary Hero Badge
        if (recipe.primaryBadge != null && recipe.primaryBadge!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _resolveBadgeColor(recipe.primaryBadge!).withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _resolveBadgeColor(recipe.primaryBadge!).withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  size: 14,
                  color: _resolveBadgeColor(recipe.primaryBadge!),
                ),
                const SizedBox(width: 6),
                Text(
                  recipe.primaryBadge!,
                  style: TextStyle(
                    color: _resolveBadgeColor(recipe.primaryBadge!),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Macro Profile Pill
        if (recipe.macroProfile != null && recipe.macroProfile!.isNotEmpty) ...[
          StatusBadge(
            label: recipe.macroProfile!,
            color: AppColors.macroProtein,
            isPill: true,
          ),
        ],

        // Tags
        ...recipe.tags.map((tag) {
          return StatusBadge(
            label: '#${tag.name}',
            color: AppColors.amber,
          );
        }),
      ],
    );
  }

  Widget _buildSuitabilityCard(String reason) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTimeStat('PREP', recipe.prepTimeMinutes != null ? '${recipe.prepTimeMinutes}m' : '--'),
                Container(width: 1, height: 26, color: AppColors.border),
                _buildTimeStat('COOK', recipe.cookTimeMinutes != null ? '${recipe.cookTimeMinutes}m' : '--'),
                Container(width: 1, height: 26, color: AppColors.border),
                _buildTimeStat('TOTAL', recipe.formattedTime),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Cooking Mode Action Chip
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isCookingMode ? AppColors.primary : AppColors.surfaceElevated,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _isCookingMode ? AppColors.primaryLight : AppColors.borderLight,
                ),
              ),
            ),
            icon: Icon(
              _isCookingMode ? Icons.outdoor_grill : Icons.kitchen_outlined,
              size: 15,
              color: _isCookingMode ? Colors.white : AppColors.primary,
            ),
            label: Text(
              _isCookingMode ? 'Cooking' : 'Cook Mode',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            onPressed: _toggleCookingMode,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStat(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.tabularFigures(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildServingsAdjuster(Recipe recipe, int currentServings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_outline, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
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
                constraints: const BoxConstraints(minWidth: 28),
                alignment: Alignment.center,
                child: Text(
                  '$currentServings',
                  style: AppTheme.tabularFigures(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
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

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Checkbox tap target
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
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
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isChecked ? AppColors.success : AppColors.textMuted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Ingredient Text with Tabular Quantity & Estimated Indicator
                    Expanded(
                      child: InkWell(
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
                        child: RichText(
                          text: TextSpan(
                            children: [
                              if (item.displayQuantity.isNotEmpty) ...[
                                TextSpan(
                                  text: '${item.displayQuantity} ',
                                  style: AppTheme.tabularFigures(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isChecked ? AppColors.textMuted : AppColors.primary,
                                  ),
                                ),
                              ],
                              if (item.unit != null && item.unit!.isNotEmpty) ...[
                                TextSpan(
                                  text: '${item.unit!} ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isChecked ? AppColors.textMuted : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                              TextSpan(
                                text: item.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isChecked ? AppColors.textMuted : AppColors.textPrimary,
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item.baseNotes != null && item.baseNotes!.isNotEmpty) ...[
                                TextSpan(
                                  text: ' (${item.baseNotes})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (item.hasAlternative) ...[
                                TextSpan(
                                  text: ' (or ${item.alternativeName})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.saffronGold,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (item.isEstimated) ...[
                                const TextSpan(
                                  text: ' ~est',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Inline ✨ Swap Trigger
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.all(4),
                      tooltip: item.hasAlternative
                          ? 'Swap: or ${item.alternativeName}'
                          : 'Swap with substitute',
                      icon: Icon(
                        item.hasAlternative ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                        size: 16,
                        color: item.hasAlternative ? AppColors.saffronGold : AppColors.amber,
                      ),
                      onPressed: () => _showIngredientSwapSheet(recipe, item),
                    ),
                  ],
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
              padding: EdgeInsets.all(_isCookingMode ? 20 : 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isCookingMode ? AppColors.primary.withOpacity(0.3) : AppColors.border,
                  width: _isCookingMode ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _isCookingMode ? 36 : 30,
                    height: _isCookingMode ? 36 : 30,
                    decoration: BoxDecoration(
                      gradient: AppColors.flameGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${step.stepNumber}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: _isCookingMode ? 17 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step Instruction with Kitchen Distance formatting & inline highlights
                        _buildHighlightedInstruction(step.instruction),

                        if (step.durationMinutes != null) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _startTimer(step.durationMinutes!, 'Step ${step.stepNumber}'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.amber.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.amber),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${step.durationMinutes} mins timer',
                                    style: AppTheme.tabularFigures(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.play_arrow, size: 14, color: AppColors.amber),
                                ],
                              ),
                            ),
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

  /// Highlight temperatures (200°C, 350°F) and durations (10 mins, 5 minutes) inline in #FF6E2E
  Widget _buildHighlightedInstruction(String text) {
    final regex = RegExp(r'(\b\d+\s*°\s*[CFcf]\b|\b\d+\s*(?:mins?|minutes?|secs?|seconds?|hours?)\b)', caseSensitive: false);
    final spans = <TextSpan>[];
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: _isCookingMode
                ? AppTheme.kitchenDistanceInstruction(fontSize: 19)
                : const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.45),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: _isCookingMode ? 19 : 15,
            height: _isCookingMode ? 1.6 : 1.45,
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: _isCookingMode
              ? AppTheme.kitchenDistanceInstruction(fontSize: 19)
              : const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.45),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildNutritionCard(Recipe recipe, int servings) {
    final nutrition = recipe.nutrition;
    final hasNutrition = nutrition.hasValues;

    String methodLabel = 'Unavailable';
    Color methodColor = AppColors.textMuted;
    if (nutrition.method == 'creator') {
      methodLabel = 'Creator Verified';
      methodColor = AppColors.success;
    } else if (nutrition.method == 'estimated') {
      methodLabel = 'AI Estimate';
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                _buildNutrientStat('CALORIES', '${nutrition.calories?.toInt() ?? "--"}', 'kcal', AppColors.macroCalories),
                _buildNutrientStat('PROTEIN', '${nutrition.proteinGrams?.toInt() ?? "--"}', 'g', AppColors.macroProtein),
                _buildNutrientStat('CARBS', '${nutrition.carbsGrams?.toInt() ?? "--"}', 'g', AppColors.macroCarbs),
                _buildNutrientStat('FAT', '${nutrition.fatGrams?.toInt() ?? "--"}', 'g', AppColors.macroFats),
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
        ],
      ),
    );
  }

  Widget _buildNutrientStat(String title, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppTheme.tabularFigures(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
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

  Widget _buildFloatingTimerBar() {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final progress = _totalTimerSeconds > 0 ? (_totalTimerSeconds - _remainingSeconds) / _totalTimerSeconds : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Circular mini progress
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const Center(
                      child: Icon(Icons.timer, size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Timer text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timerLabel.isNotEmpty ? _timerLabel : 'Cooking Timer',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      timeStr,
                      style: AppTheme.tabularFigures(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Controls
              IconButton(
                icon: Icon(
                  _isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: AppColors.primary,
                  size: 28,
                ),
                onPressed: _pauseResumeTimer,
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                onPressed: _cancelTimer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIngredientSwapSheet(Recipe recipe, Ingredient item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => IngredientSwapModal(
        recipe: recipe,
        ingredient: item,
      ),
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
              if (recipe.sourceUrl == null || recipe.sourceUrl!.trim().isEmpty) return;
              final uri = Uri.parse(recipe.sourceUrl!.trim());
              try {
                final launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                }
              } catch (_) {
                try {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open link: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSourceContentAccordion(Recipe recipe) {
    final hasTranscript = recipe.transcript != null && recipe.transcript!.trim().isNotEmpty;
    final hasCaption = recipe.sourceCaption != null && recipe.sourceCaption!.trim().isNotEmpty;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(
            hasTranscript ? Icons.graphic_eq : Icons.notes_rounded,
            color: hasTranscript ? AppColors.saffronGold : AppColors.textMuted,
            size: 22,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  hasTranscript ? 'Caption & Audio Transcript' : 'Original Post Caption',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasTranscript
                      ? AppColors.badgeVegetarian.withValues(alpha: 0.15)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasTranscript
                        ? AppColors.badgeVegetarian.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTranscript) ...[
                      const Icon(Icons.check, size: 12, color: AppColors.badgeVegetarian),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      hasTranscript ? 'Audio Captured' : 'Caption Only',
                      style: TextStyle(
                        color: hasTranscript ? AppColors.badgeVegetarian : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textMuted,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),

            if (hasCaption) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 14, color: AppColors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Original Written Caption:',
                      style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  recipe.sourceCaption!,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (hasTranscript) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_outlined, size: 14, color: AppColors.saffronGold),
                    SizedBox(width: 6),
                    Text(
                      'Spoken Audio Transcript (from video):',
                      style: TextStyle(color: AppColors.saffronGold, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.saffronGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.saffronGold.withValues(alpha: 0.2)),
                ),
                child: Text(
                  recipe.transcript!,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.45),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No spoken audio transcript was captured for this video. The recipe steps and ingredients were structured directly from the creator\'s post caption.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
