import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Recipes,
    Ingredients,
    RecipeSteps,
    Tags,
    RecipeTags,
    ImportJobs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(name: 'foodies_db'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(recipes, recipes.primaryBadge);
            await m.addColumn(recipes, recipes.suitabilityReason);
            await m.addColumn(recipes, recipes.macroProfile);
            await m.addColumn(recipes, recipes.isTimeEstimated);
            await m.addColumn(ingredients, ingredients.isEstimated);
          }
        },
      );
}
