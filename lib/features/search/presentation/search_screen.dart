import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/core/utils/url_parser.dart';
import 'package:foodies/features/importing/presentation/import_sheet.dart';
import 'package:foodies/features/recipes/data/demo_recipes.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_placeholder_image.dart';
import 'package:foodies/shared/widgets/status_badge.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _onlyFavorites = false;
  int? _maxCookTime;
  final Set<String> _selectedTags = {};
  bool _isSeeding = false;

  final List<String> _popularTags = [
    'Italian',
    'Mexican',
    'Quick',
    'Dinner',
    'Vegetarian',
    'High Protein',
    'Dessert',
    'Bake',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _onlyFavorites = false;
      _maxCookTime = null;
      _selectedTags.clear();
    });
  }

  Future<void> _seedDemoRecipes() async {
    setState(() => _isSeeding = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      await DemoRecipes.seed(repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                SizedBox(width: 8),
                Text('Loaded 2 chef demo recipes!', style: TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load demo recipes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  bool _matchesQuery(Recipe r, String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return true;

    // Split query by whitespace for token-based multi-keyword matching
    final tokens = clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return true;

    final searchableStrings = <String>[
      r.title.toLowerCase(),
      if (r.description != null) r.description!.toLowerCase(),
      if (r.sourceCaption != null) r.sourceCaption!.toLowerCase(),
      if (r.primaryBadge != null) r.primaryBadge!.toLowerCase(),
      if (r.macroProfile != null) r.macroProfile!.toLowerCase(),
      if (r.suitabilityReason != null) r.suitabilityReason!.toLowerCase(),
      if (r.sourcePlatform != null) r.sourcePlatform!.toLowerCase(),
      r.formattedTime.toLowerCase(),
      ...r.ingredients.map((i) => i.name.toLowerCase()),
      ...r.ingredients.map((i) => i.notes?.toLowerCase() ?? ''),
      ...r.ingredients.map((i) => i.unit?.toLowerCase() ?? ''),
      ...r.tags.map((t) => t.name.toLowerCase()),
      ...r.tags.map((t) => t.category.toLowerCase()),
      ...r.steps.map((s) => s.instruction.toLowerCase()),
    ];

    // AND logic: Every token must match in at least one searchable field
    return tokens.every((token) {
      final rawToken = token.startsWith('#') ? token.substring(1) : token;
      if (rawToken.isEmpty) return true;
      final alphaNumeric = rawToken.replaceAll(RegExp(r'[^a-z0-9]'), '');

      return searchableStrings.any((field) {
        if (field.contains(rawToken)) return true;
        if (alphaNumeric.isNotEmpty &&
            field.replaceAll(RegExp(r'[^a-z0-9]'), '').contains(alphaNumeric)) {
          return true;
        }
        return false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final allRecipesAsync = ref.watch(allRecipesStreamProvider);
    final trimmedQuery = _query.trim();
    final isUrl = trimmedQuery.startsWith('http://') ||
        trimmedQuery.startsWith('https://') ||
        UrlParser.isValidUrl(trimmedQuery);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Recipes'),
        actions: [
          if (_query.isNotEmpty || _onlyFavorites || _maxCookTime != null || _selectedTags.isNotEmpty)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.primary,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              onSubmitted: (val) {
                setState(() => _query = val);
                FocusScope.of(context).unfocus();
              },
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Search title, ingredient, cuisine, #tag...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // URL Detected Quick Import Card
          if (isUrl)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.18), AppColors.surfaceElevated],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.download_rounded, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Video Link Detected',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14),
                ),
                subtitle: Text(
                  trimmedQuery,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ImportSheet(initialUrl: trimmedQuery),
                  );
                },
              ),
            ),

          // Filter Chips Horizontal Scroll
          allRecipesAsync.maybeWhen(
            data: (recipes) {
              final dynamicTags = <String>{..._popularTags};
              for (final r in recipes) {
                for (final t in r.tags) {
                  final name = t.name.trim();
                  if (name.isNotEmpty) dynamicTags.add(name);
                }
              }

              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Favorites filter chip
                    FilterChip(
                      selected: _onlyFavorites,
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, size: 14, color: AppColors.error),
                          SizedBox(width: 4),
                          Text('Favorites'),
                        ],
                      ),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.error.withOpacity(0.2),
                      side: BorderSide(
                        color: _onlyFavorites ? AppColors.error : AppColors.border,
                      ),
                      onSelected: (val) => setState(() => _onlyFavorites = val),
                    ),
                    const SizedBox(width: 8),

                    // Under 30 mins
                    FilterChip(
                      selected: _maxCookTime == 30,
                      label: const Text('Under 30m'),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      side: BorderSide(
                        color: _maxCookTime == 30 ? AppColors.primary : AppColors.border,
                      ),
                      onSelected: (val) => setState(() => _maxCookTime = val ? 30 : null),
                    ),
                    const SizedBox(width: 8),

                    // Category & Recipe tags
                    ...dynamicTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag.toLowerCase());
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text('#$tag'),
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.amber.withOpacity(0.2),
                          side: BorderSide(
                            color: isSelected ? AppColors.amber : AppColors.border,
                          ),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedTags.add(tag.toLowerCase());
                              } else {
                                _selectedTags.remove(tag.toLowerCase());
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),

          const SizedBox(height: 8),

          // Results list or empty states
          Expanded(
            child: allRecipesAsync.when(
              data: (recipes) {
                // Case 1: Database has zero recipes saved
                if (recipes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 64, color: AppColors.primary.withOpacity(0.7)),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Recipe Box is Empty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Search finds recipes saved to your device. Load chef demo recipes or paste a reel link to start cooking!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _isSeeding ? null : _seedDemoRecipes,
                            icon: _isSeeding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Add Demo Recipes'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Import from Reel URL'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const ImportSheet(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filtering recipes
                final filtered = recipes.where((r) {
                  if (_onlyFavorites && !r.isFavorite) return false;

                  if (_maxCookTime != null) {
                    final time = r.effectiveTotalTime;
                    if (time == null || time > _maxCookTime!) return false;
                  }

                  if (_selectedTags.isNotEmpty) {
                    final rTagNames = r.tags.map((t) => t.name.toLowerCase().trim()).toSet();
                    final rTagCategories = r.tags.map((t) => t.category.toLowerCase().trim()).toSet();
                    final rBadge = (r.primaryBadge ?? '').toLowerCase();
                    final rMacro = (r.macroProfile ?? '').toLowerCase();

                    final matchesAnyTag = _selectedTags.any((tag) {
                      final s = tag.toLowerCase().trim();
                      final sAlpha = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
                      if (rTagNames.contains(s)) return true;
                      if (rTagNames.any((t) => t.contains(s) || (sAlpha.isNotEmpty && t.replaceAll(RegExp(r'[^a-z0-9]'), '').contains(sAlpha)))) return true;
                      if (rTagCategories.contains(s)) return true;
                      if (rBadge.contains(s) || rMacro.contains(s)) return true;
                      return false;
                    });
                    if (!matchesAnyTag) return false;
                  }

                  if (!_matchesQuery(r, trimmedQuery)) return false;

                  return true;
                }).toList();

                // Case 2: Recipes exist, but no recipe matches active filters / search
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 58, color: AppColors.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 14),
                          Text(
                            trimmedQuery.isNotEmpty
                                ? 'No Recipes Match "$trimmedQuery"'
                                : 'No Recipes Match Selected Filters',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try searching for a different ingredient, dish name, or clear your tag filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Clear Filters & Search'),
                            onPressed: _clearAllFilters,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: const Text('Import Recipe from Reel'),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ImportSheet(
                                  initialUrl: isUrl ? trimmedQuery : null,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Case 3: Matches found!
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trimmedQuery.isNotEmpty || _onlyFavorites || _maxCookTime != null || _selectedTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? 'recipe' : 'recipes'} found',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final recipe = filtered[index];
                          return _buildSearchResultCard(context, recipe, trimmedQuery);
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text('Error loading recipes: $err', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(BuildContext context, Recipe recipe, String query) {
    // Find matching ingredient snippet if applicable
    String? matchedIngredient;
    if (query.isNotEmpty) {
      final qLower = query.toLowerCase();
      final match = recipe.ingredients.cast<dynamic>().firstWhere(
            (i) => i.name.toLowerCase().contains(qLower),
            orElse: () => null,
          );
      if (match != null) {
        matchedIngredient = match.name;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        );
      },
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail
            SizedBox(
              width: 108,
              height: 122,
              child: RecipeCardImage(
                imagePath: recipe.imagePath,
                title: recipe.title,
                height: 122,
                width: 108,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 3),
                              Text(
                                recipe.formattedTime,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Text(
                            '${recipe.ingredients.length} ing.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                          if (recipe.nutrition.calories != null)
                            Text(
                              '${recipe.nutrition.calories!.toInt()} kcal',
                              style: const TextStyle(color: AppColors.primaryLight, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (recipe.primaryBadge != null && recipe.primaryBadge!.isNotEmpty)
                            StatusBadge(
                              label: recipe.primaryBadge!,
                              color: AppColors.primaryLight,
                              isPill: false,
                            )
                          else if (recipe.tags.isNotEmpty)
                            StatusBadge(
                              label: '#${recipe.tags.first.name}',
                              color: AppColors.amber,
                              isPill: false,
                            ),
                          if (matchedIngredient != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Has $matchedIngredient',
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (recipe.isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.favorite, color: AppColors.error, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
