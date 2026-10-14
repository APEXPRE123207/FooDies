import 'package:drift/drift.dart';

class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get sourcePlatform => text().nullable()(); // 'instagram', 'facebook', 'youtube', 'tiktok', 'web'
  TextColumn get sourceCaption => text().nullable()();
  TextColumn get transcript => text().nullable()();
  TextColumn get originalLanguage => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  IntColumn get prepTimeMinutes => integer().nullable()();
  IntColumn get cookTimeMinutes => integer().nullable()();
  IntColumn get totalTimeMinutes => integer().nullable()();
  IntColumn get servingCount => integer().withDefault(const Constant(2))();
  RealColumn get caloriesPerServing => real().nullable()();
  RealColumn get proteinGrams => real().nullable()();
  RealColumn get carbsGrams => real().nullable()();
  RealColumn get fatGrams => real().nullable()();
  TextColumn get nutritionMethod => text().nullable()(); // 'creator', 'estimated', 'unavailable'
  TextColumn get nutritionConfidence => text().nullable()(); // 'high', 'medium', 'low'
  TextColumn get primaryBadge => text().nullable()(); // e.g. "Post-Workout Recovery", "Quick 15-Min"
  TextColumn get suitabilityReason => text().nullable()(); // 1-sentence AI nutritional insight
  TextColumn get macroProfile => text().nullable()(); // "High-Protein", "Balanced", "Keto", etc.
  BoolColumn get isTimeEstimated => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  RealColumn get extractionConfidence => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Ingredients extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();
  BoolColumn get isEstimated => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class RecipeSteps extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get stepNumber => integer()();
  TextColumn get instruction => text()();
  IntColumn get durationMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get category => text().withDefault(const Constant('general'))(); // 'cuisine', 'meal_type', 'diet', 'method', 'general'

  @override
  Set<Column> get primaryKey => {id};
}

class RecipeTags extends Table {
  TextColumn get recipeId => text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {recipeId, tagId};
}

class ImportJobs extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId => text().nullable().references(Recipes, #id, onDelete: KeyAction.setNull)();
  TextColumn get sourceUrl => text()();
  TextColumn get currentStage => text()(); // 'queued', 'extracting', 'transcribing', 'structuring', 'ready', 'needs_input', 'retrying', 'failed', 'cancelled'
  TextColumn get status => text()(); // 'pending', 'in_progress', 'completed', 'failed', 'cancelled'
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(3))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get rawCaption => text().nullable()();
  TextColumn get rawTranscript => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
