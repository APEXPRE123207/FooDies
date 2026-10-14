import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/utils/logger.dart';
import '../../../core/utils/url_parser.dart';
import '../domain/models/ingredient.dart';
import '../domain/models/nutrition_info.dart';
import '../domain/models/recipe.dart';
import '../domain/models/recipe_step.dart';
import '../domain/models/recipe_tag.dart';

class RecipeRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  RecipeRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Watch all recipes in descending order of creation
  Stream<List<Recipe>> watchAllRecipes() {
    return _database.select(_database.recipes).watch().asyncMap((recipeRows) async {
      final recipes = <Recipe>[];
      for (final row in recipeRows) {
        final fullRecipe = await _populateRecipeDetails(row);
        recipes.add(fullRecipe);
      }
      return recipes;
    });
  }

  /// Get all recipes once
  Future<List<Recipe>> getAllRecipes() async {
    final rows = await (_database.select(_database.recipes)
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();

    final recipes = <Recipe>[];
    for (final row in rows) {
      recipes.add(await _populateRecipeDetails(row));
    }
    return recipes;
  }

  /// Watch single recipe by id
  Stream<Recipe?> watchRecipeById(String id) {
    final query = _database.select(_database.recipes)..where((r) => r.id.equals(id));
    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      return _populateRecipeDetails(row);
    });
  }

  /// Get single recipe by id
  Future<Recipe?> getRecipeById(String id) async {
    final row = await (_database.select(_database.recipes)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();

    if (row == null) return null;
    return _populateRecipeDetails(row);
  }

  /// Check if a recipe exists with a matching source URL
  Future<Recipe?> findRecipeBySourceUrl(String rawUrl) async {
    final normalized = UrlParser.normalizeUrl(rawUrl);
    final all = await _database.select(_database.recipes).get();
    for (final row in all) {
      if (row.sourceUrl != null &&
          UrlParser.normalizeUrl(row.sourceUrl!) == normalized) {
        return _populateRecipeDetails(row);
      }
    }
    return null;
  }

  /// Insert a recipe with its ingredients, steps, and tags atomically
  Future<Recipe> insertRecipe(Recipe recipe) async {
    final recipeId = recipe.id.isEmpty ? _uuid.v4() : recipe.id;
    final now = DateTime.now();

    await _database.transaction(() async {
      // 1. Insert Recipe row
      await _database.into(_database.recipes).insert(
            db.RecipesCompanion(
              id: Value(recipeId),
              title: Value(recipe.title),
              description: Value(recipe.description),
              sourceUrl: Value(recipe.sourceUrl),
              sourcePlatform: Value(recipe.sourcePlatform),
              sourceCaption: Value(recipe.sourceCaption),
              transcript: Value(recipe.transcript),
              originalLanguage: Value(recipe.originalLanguage),
              imagePath: Value(recipe.imagePath),
              prepTimeMinutes: Value(recipe.prepTimeMinutes),
              cookTimeMinutes: Value(recipe.cookTimeMinutes),
              totalTimeMinutes: Value(recipe.totalTimeMinutes),
              isTimeEstimated: Value(recipe.isTimeEstimated),
              servingCount: Value(recipe.servingCount),
              caloriesPerServing: Value(recipe.nutrition.calories),
              proteinGrams: Value(recipe.nutrition.proteinGrams),
              carbsGrams: Value(recipe.nutrition.carbsGrams),
              fatGrams: Value(recipe.nutrition.fatGrams),
              nutritionMethod: Value(recipe.nutrition.method),
              nutritionConfidence: Value(recipe.nutrition.confidence),
              primaryBadge: Value(recipe.primaryBadge),
              suitabilityReason: Value(recipe.suitabilityReason),
              macroProfile: Value(recipe.macroProfile),
              isFavorite: Value(recipe.isFavorite),
              extractionConfidence: Value(recipe.extractionConfidence),
              createdAt: Value(recipe.createdAt),
              updatedAt: Value(now),
            ),
          );

      // 2. Insert Ingredients
      for (var i = 0; i < recipe.ingredients.length; i++) {
        final ing = recipe.ingredients[i];
        final ingId = ing.id.isEmpty ? _uuid.v4() : ing.id;
        await _database.into(_database.ingredients).insert(
              db.IngredientsCompanion(
                id: Value(ingId),
                recipeId: Value(recipeId),
                name: Value(ing.name),
                quantity: Value(ing.quantity),
                unit: Value(ing.unit),
                notes: Value(ing.notes),
                isOptional: Value(ing.isOptional),
                isEstimated: Value(ing.isEstimated),
                sortOrder: Value(i),
              ),
            );
      }

      // 3. Insert Steps
      for (var i = 0; i < recipe.steps.length; i++) {
        final step = recipe.steps[i];
        final stepId = step.id.isEmpty ? _uuid.v4() : step.id;
        await _database.into(_database.recipeSteps).insert(
              db.RecipeStepsCompanion(
                id: Value(stepId),
                recipeId: Value(recipeId),
                stepNumber: Value(step.stepNumber),
                instruction: Value(step.instruction),
                durationMinutes: Value(step.durationMinutes),
              ),
            );
      }

      // 4. Insert Tags and join entries
      for (final tag in recipe.tags) {
        final existingTag = await (_database.select(_database.tags)
              ..where((t) => t.name.equals(tag.name.toLowerCase().trim())))
            .getSingleOrNull();

        String tagId;
        if (existingTag != null) {
          tagId = existingTag.id;
        } else {
          tagId = tag.id.isEmpty ? _uuid.v4() : tag.id;
          await _database.into(_database.tags).insert(
                db.TagsCompanion(
                  id: Value(tagId),
                  name: Value(tag.name.toLowerCase().trim()),
                  category: Value(tag.category),
                ),
              );
        }

        await _database.into(_database.recipeTags).insert(
              db.RecipeTagsCompanion(
                recipeId: Value(recipeId),
                tagId: Value(tagId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    AppLogger.info('Inserted recipe $recipeId: ${recipe.title}');
    return (await getRecipeById(recipeId))!;
  }

  /// Update recipe details atomically
  Future<Recipe> updateRecipe(Recipe recipe) async {
    final now = DateTime.now();

    await _database.transaction(() async {
      // 1. Update recipe row
      await (_database.update(_database.recipes)..where((r) => r.id.equals(recipe.id)))
          .write(
        db.RecipesCompanion(
          title: Value(recipe.title),
          description: Value(recipe.description),
          sourceUrl: Value(recipe.sourceUrl),
          sourcePlatform: Value(recipe.sourcePlatform),
          sourceCaption: Value(recipe.sourceCaption),
          transcript: Value(recipe.transcript),
          originalLanguage: Value(recipe.originalLanguage),
          imagePath: Value(recipe.imagePath),
          prepTimeMinutes: Value(recipe.prepTimeMinutes),
          cookTimeMinutes: Value(recipe.cookTimeMinutes),
          totalTimeMinutes: Value(recipe.totalTimeMinutes),
          isTimeEstimated: Value(recipe.isTimeEstimated),
          servingCount: Value(recipe.servingCount),
          caloriesPerServing: Value(recipe.nutrition.calories),
          proteinGrams: Value(recipe.nutrition.proteinGrams),
          carbsGrams: Value(recipe.nutrition.carbsGrams),
          fatGrams: Value(recipe.nutrition.fatGrams),
          nutritionMethod: Value(recipe.nutrition.method),
          nutritionConfidence: Value(recipe.nutrition.confidence),
          primaryBadge: Value(recipe.primaryBadge),
          suitabilityReason: Value(recipe.suitabilityReason),
          macroProfile: Value(recipe.macroProfile),
          isFavorite: Value(recipe.isFavorite),
          extractionConfidence: Value(recipe.extractionConfidence),
          updatedAt: Value(now),
        ),
      );

      // 2. Replace ingredients
      await (_database.delete(_database.ingredients)
            ..where((i) => i.recipeId.equals(recipe.id)))
          .go();
      for (var i = 0; i < recipe.ingredients.length; i++) {
        final ing = recipe.ingredients[i];
        await _database.into(_database.ingredients).insert(
              db.IngredientsCompanion(
                id: Value(ing.id.isEmpty ? _uuid.v4() : ing.id),
                recipeId: Value(recipe.id),
                name: Value(ing.name),
                quantity: Value(ing.quantity),
                unit: Value(ing.unit),
                notes: Value(ing.notes),
                isOptional: Value(ing.isOptional),
                isEstimated: Value(ing.isEstimated),
                sortOrder: Value(i),
              ),
            );
      }

      // 3. Replace steps
      await (_database.delete(_database.recipeSteps)
            ..where((s) => s.recipeId.equals(recipe.id)))
          .go();
      for (var i = 0; i < recipe.steps.length; i++) {
        final step = recipe.steps[i];
        await _database.into(_database.recipeSteps).insert(
              db.RecipeStepsCompanion(
                id: Value(step.id.isEmpty ? _uuid.v4() : step.id),
                recipeId: Value(recipe.id),
                stepNumber: Value(step.stepNumber),
                instruction: Value(step.instruction),
                durationMinutes: Value(step.durationMinutes),
              ),
            );
      }

      // 4. Update tags
      await (_database.delete(_database.recipeTags)
            ..where((rt) => rt.recipeId.equals(recipe.id)))
          .go();
      for (final tag in recipe.tags) {
        final cleanName = tag.name.toLowerCase().trim();
        final existingTag = await (_database.select(_database.tags)
              ..where((t) => t.name.equals(cleanName)))
            .getSingleOrNull();

        String tagId;
        if (existingTag != null) {
          tagId = existingTag.id;
        } else {
          tagId = tag.id.isEmpty ? _uuid.v4() : tag.id;
          await _database.into(_database.tags).insert(
                db.TagsCompanion(
                  id: Value(tagId),
                  name: Value(cleanName),
                  category: Value(tag.category),
                ),
              );
        }

        await _database.into(_database.recipeTags).insert(
              db.RecipeTagsCompanion(
                recipeId: Value(recipe.id),
                tagId: Value(tagId),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    AppLogger.info('Updated recipe ${recipe.id}: ${recipe.title}');
    return (await getRecipeById(recipe.id))!;
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String recipeId) async {
    final existing = await getRecipeById(recipeId);
    if (existing == null) return false;
    final newFavorite = !existing.isFavorite;

    await (_database.update(_database.recipes)..where((r) => r.id.equals(recipeId))).write(
      db.RecipesCompanion(
        isFavorite: Value(newFavorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return newFavorite;
  }

  /// Delete recipe and cascade delete ingredients, steps, and join rows
  Future<void> deleteRecipe(String recipeId) async {
    await (_database.delete(_database.recipes)..where((r) => r.id.equals(recipeId))).go();
    AppLogger.info('Deleted recipe $recipeId');
  }

  /// Search recipes with filters and comprehensive multi-token matching
  Future<List<Recipe>> searchRecipes({
    String? query,
    List<String>? tagNames,
    bool? onlyFavorites,
    int? maxCookTime,
  }) async {
    final all = await getAllRecipes();
    return all.where((r) {
      if (onlyFavorites == true && !r.isFavorite) return false;
      if (maxCookTime != null) {
        final time = r.effectiveTotalTime;
        if (time == null || time > maxCookTime) return false;
      }
      if (tagNames != null && tagNames.isNotEmpty) {
        final recipeTagNames = r.tags.map((t) => t.name.toLowerCase().trim()).toSet();
        final matchesTag = tagNames.any((t) => recipeTagNames.contains(t.toLowerCase().trim()));
        if (!matchesTag) return false;
      }
      if (query != null && query.trim().isNotEmpty) {
        final clean = query.trim().toLowerCase();
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
          ...r.ingredients.map((i) => i.name.toLowerCase()),
          ...r.ingredients.map((i) => i.notes?.toLowerCase() ?? ''),
          ...r.tags.map((t) => t.name.toLowerCase()),
          ...r.tags.map((t) => t.category.toLowerCase()),
          ...r.steps.map((s) => s.instruction.toLowerCase()),
        ];

        final matchesAllTokens = tokens.every((token) {
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

        if (!matchesAllTokens) return false;
      }
      return true;
    }).toList();
  }

  /// Swap an ingredient with an alternative (overwriting)
  Future<void> swapIngredient({
    required String ingredientId,
    required String newName,
    double? newQuantity,
    String? newUnit,
    String? newNotes,
  }) async {
    await (_database.update(_database.ingredients)..where((i) => i.id.equals(ingredientId)))
        .write(
      db.IngredientsCompanion(
        name: Value(newName),
        quantity: newQuantity != null ? Value(newQuantity) : const Value.absent(),
        unit: newUnit != null ? Value(newUnit) : const Value.absent(),
        notes: newNotes != null ? Value(newNotes) : const Value.absent(),
        isEstimated: const Value(true),
      ),
    );
  }

  /// Keep an alternative swap in brackets without modifying the original ingredient name or quantity.
  /// E.g. original name remains "Paneer", notes becomes "or Firm Tofu", displaying "200 g Paneer (or Firm Tofu)".
  Future<void> saveIngredientAlternative({
    required String recipeId,
    required String ingredientId,
    required String alternativeName,
  }) async {
    final current = await (_database.select(_database.ingredients)
          ..where((i) => i.id.equals(ingredientId)))
        .getSingleOrNull();
    if (current == null) return;

    // Clean any previous bracketed "or ..." from notes
    String baseNotes = (current.notes ?? '').trim();
    baseNotes = baseNotes
        .replaceAll(RegExp(r'\s*\(?or\s+[^)]+\)?', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*$'), '')
        .trim();

    final newNotes = baseNotes.isEmpty
        ? 'or $alternativeName'
        : '$baseNotes, or $alternativeName';

    await (_database.update(_database.ingredients)..where((i) => i.id.equals(ingredientId)))
        .write(
      db.IngredientsCompanion(
        notes: Value(newNotes),
      ),
    );

    // Touch the parent recipe's updatedAt so reactive Stream subscribers immediately re-emit
    await (_database.update(_database.recipes)..where((r) => r.id.equals(recipeId)))
        .write(
      db.RecipesCompanion(
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Remove a saved bracketed alternative and restore the original ingredient's base notes
  Future<void> removeIngredientAlternative({
    required String recipeId,
    required String ingredientId,
  }) async {
    final current = await (_database.select(_database.ingredients)
          ..where((i) => i.id.equals(ingredientId)))
        .getSingleOrNull();
    if (current == null) return;

    String baseNotes = (current.notes ?? '').trim();
    baseNotes = baseNotes
        .replaceAll(RegExp(r'\s*\(?or\s+[^)]+\)?', caseSensitive: false), '')
        .replaceAll(RegExp(r',\s*$'), '')
        .trim();

    await (_database.update(_database.ingredients)..where((i) => i.id.equals(ingredientId)))
        .write(
      db.IngredientsCompanion(
        notes: Value(baseNotes.isEmpty ? null : baseNotes),
      ),
    );

    // Touch parent recipe updatedAt to re-emit
    await (_database.update(_database.recipes)..where((r) => r.id.equals(recipeId)))
        .write(
      db.RecipesCompanion(
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Populate full Recipe domain entity with ingredients, steps, and tags
  Future<Recipe> _populateRecipeDetails(db.Recipe row) async {
    // 1. Ingredients
    final ingredientRows = await (_database.select(_database.ingredients)
          ..where((i) => i.recipeId.equals(row.id))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();

    final ingredients = ingredientRows.map((i) {
      return Ingredient(
        id: i.id,
        recipeId: i.recipeId,
        name: i.name,
        quantity: i.quantity,
        unit: i.unit,
        notes: i.notes,
        isOptional: i.isOptional,
        isEstimated: i.isEstimated,
        sortOrder: i.sortOrder,
      );
    }).toList();

    // 2. Steps
    final stepRows = await (_database.select(_database.recipeSteps)
          ..where((s) => s.recipeId.equals(row.id))
          ..orderBy([(s) => OrderingTerm.asc(s.stepNumber)]))
        .get();

    final steps = stepRows.map((s) {
      return RecipeStep(
        id: s.id,
        recipeId: s.recipeId,
        stepNumber: s.stepNumber,
        instruction: s.instruction,
        durationMinutes: s.durationMinutes,
      );
    }).toList();

    // 3. Tags
    final recipeTagRows = await (_database.select(_database.recipeTags)
          ..where((rt) => rt.recipeId.equals(row.id)))
        .get();
    final tagIds = recipeTagRows.map((rt) => rt.tagId).toList();

    final tagRows = await (_database.select(_database.tags)
          ..where((t) => t.id.isIn(tagIds)))
        .get();

    final tags = tagRows.map((t) {
      return RecipeTag(
        id: t.id,
        name: t.name,
        category: t.category,
      );
    }).toList();

    return Recipe(
      id: row.id,
      title: row.title,
      description: row.description,
      sourceUrl: row.sourceUrl,
      sourcePlatform: row.sourcePlatform,
      sourceCaption: row.sourceCaption,
      transcript: row.transcript,
      originalLanguage: row.originalLanguage,
      imagePath: row.imagePath,
      prepTimeMinutes: row.prepTimeMinutes,
      cookTimeMinutes: row.cookTimeMinutes,
      totalTimeMinutes: row.totalTimeMinutes,
      isTimeEstimated: row.isTimeEstimated,
      servingCount: row.servingCount,
      nutrition: NutritionInfo(
        calories: row.caloriesPerServing,
        proteinGrams: row.proteinGrams,
        carbsGrams: row.carbsGrams,
        fatGrams: row.fatGrams,
        method: row.nutritionMethod ?? 'unavailable',
        confidence: row.nutritionConfidence,
      ),
      primaryBadge: row.primaryBadge,
      suitabilityReason: row.suitabilityReason,
      macroProfile: row.macroProfile,
      isFavorite: row.isFavorite,
      extractionConfidence: row.extractionConfidence,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
    );
  }
}
