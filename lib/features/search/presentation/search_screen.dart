import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodies/core/config/providers.dart';
import 'package:foodies/core/theme/app_colors.dart';
import 'package:foodies/shared/widgets/status_badge.dart';
import 'package:foodies/features/recipes/domain/models/recipe.dart';
import 'package:foodies/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:foodies/features/recipes/presentation/widgets/recipe_placeholder_image.dart';

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

  @override
  Widget build(BuildContext context) {
    final allRecipesAsync = ref.watch(allRecipesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Recipes'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search by title, ingredient, cuisine...',
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

          // Filter chips
          SizedBox(
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

                // Popular category tags
                ..._popularTags.map((tag) {
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
          ),
          const SizedBox(height: 12),

          // Results list
          Expanded(
            child: allRecipesAsync.when(
              data: (recipes) {
                final filtered = recipes.where((r) {
                  if (_onlyFavorites && !r.isFavorite) return false;
                  if (_maxCookTime != null) {
                    final time = r.effectiveTotalTime;
                    if (time == null || time > _maxCookTime!) return false;
                  }
                  if (_selectedTags.isNotEmpty) {
                    final rTagNames = r.tags.map((t) => t.name.toLowerCase()).toSet();
                    if (!_selectedTags.any((t) => rTagNames.contains(t))) return false;
                  }
                  if (_query.isNotEmpty) {
                    final q = _query.toLowerCase();
                    final inTitle = r.title.toLowerCase().contains(q);
                    final inDesc = r.description?.toLowerCase().contains(q) ?? false;
                    final inIng = r.ingredients.any((i) => i.name.toLowerCase().contains(q));
                    if (!inTitle && !inDesc && !inIng) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 54, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 14),
                        const Text(
                          'No Recipes Match Your Filters',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try clearing search keywords or selecting different tags.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final recipe = filtered[index];
                    return _buildSearchResultCard(context, recipe);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppColors.error)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(BuildContext context, Recipe recipe) {
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
        height: 108,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 108,
              height: 108,
              child: RecipeCardImage(
                imagePath: recipe.imagePath,
                title: recipe.title,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          recipe.formattedTime,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${recipe.ingredients.length} ing.',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        if (recipe.nutrition.calories != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${recipe.nutrition.calories!.toInt()} kcal',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (recipe.tags.isNotEmpty)
                      StatusBadge(
                        label: '#${recipe.tags.first.name}',
                        color: AppColors.amber,
                        isPill: false,
                      ),
                  ],
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
