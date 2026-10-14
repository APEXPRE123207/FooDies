import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/database/app_database.dart'
    hide Recipe, Ingredient, RecipeStep, RecipeTag, ImportJob;
import 'package:foodies/core/networking/ollama_client.dart';
import 'package:foodies/core/networking/ollama_models.dart';
import 'package:foodies/core/storage/secure_storage_service.dart';
import 'package:foodies/features/extraction/content_extractor.dart';
import 'package:foodies/features/extraction/recipe_structurer.dart';
import 'package:foodies/features/importing/data/import_pipeline_coordinator.dart';
import 'package:foodies/features/importing/data/import_repository.dart';
import 'package:foodies/features/importing/domain/import_job.dart';
import 'package:foodies/features/recipes/data/recipe_repository.dart';

class MockOllamaClientIntegration extends OllamaClient {
  MockOllamaClientIntegration() : super(storage: SecureStorageService());

  @override
  Future<OllamaChatResponse> chat({
    required List<Map<String, String>> messages,
    String? model,
    Map<String, dynamic>? schemaFormat,
    bool forceJsonFormat = true,
  }) async {
    final responsePayload = {
      'title': 'Avocado Toast with Poached Egg',
      'description': 'Crispy sourdough topped with creamy smashed avocado and a runny poached egg.',
      'originalLanguage': 'en',
      'prepTimeMinutes': 5,
      'cookTimeMinutes': 5,
      'totalTimeMinutes': 10,
      'servingCount': 1,
      'tags': ['Breakfast', 'Quick', 'Vegetarian'],
      'ingredients': [
        {'name': 'sourdough bread', 'quantity': 1, 'unit': 'slice'},
        {'name': 'avocado', 'quantity': 0.5, 'unit': 'whole', 'notes': 'ripe'},
        {'name': 'egg', 'quantity': 1, 'unit': 'whole', 'notes': 'poached'},
        {'name': 'olive oil', 'quantity': 1, 'unit': 'tsp'},
      ],
      'steps': [
        {'stepNumber': 1, 'instruction': 'Toast sourdough bread until golden and crisp.', 'durationMinutes': 3},
        {'stepNumber': 2, 'instruction': 'Mash avocado with salt, pepper, and olive oil. Spread over toast.', 'durationMinutes': 2},
        {'stepNumber': 3, 'instruction': 'Top with a warm poached egg and red pepper flakes.', 'durationMinutes': 1},
      ],
    };

    return OllamaChatResponse(
      model: model ?? 'llama3.2',
      content: jsonEncode(responsePayload),
    );
  }
}

void main() {
  late AppDatabase db;
  late RecipeRepository recipeRepo;
  late ImportRepository importRepo;
  late ContentExtractor extractor;
  late RecipeStructurer structurer;
  late ImportPipelineCoordinator coordinator;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recipeRepo = RecipeRepository(db);
    importRepo = ImportRepository(db);
    extractor = ContentExtractor();
    structurer = RecipeStructurer(ollamaClient: MockOllamaClientIntegration());

    coordinator = ImportPipelineCoordinator(
      importRepo: importRepo,
      recipeRepo: recipeRepo,
      extractor: extractor,
      structurer: structurer,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Import Pipeline Integration Tests', () {
    test('End-to-end import: starts job, calls Ollama, and persists recipe in SQLite', () async {
      const url = 'https://www.instagram.com/reel/AVOCADO_TOAST/?igsh=123';
      const caption = 'The easiest aesthetic breakfast! Sourdough, smashed avocado, poached egg, olive oil. Full method in video.';

      // Start import pipeline
      final initialJob = await coordinator.startImport(
        rawInput: url,
        manualCaption: caption,
      );

      expect(initialJob.status, JobStatus.pending);

      // Await job processing
      await coordinator.processJob(initialJob.id);

      // Check persistent job status
      final completedJob = await importRepo.getJobById(initialJob.id);
      expect(completedJob!.currentStage, ImportStage.ready);
      expect(completedJob.status, JobStatus.completed);
      expect(completedJob.recipeId, isNotNull);

      // Verify recipe in local database
      final recipe = await recipeRepo.getRecipeById(completedJob.recipeId!);
      expect(recipe, isNotNull);
      expect(recipe!.title, 'Avocado Toast with Poached Egg');
      expect(recipe.ingredients.length, 4);
      expect(recipe.steps.length, 3);
      expect(recipe.tags.length, 3);
      expect(recipe.effectiveTotalTime, 10);
      expect(recipe.sourcePlatform, 'instagram');
    });

    test('Duplicate import detection returns existing recipe without re-calling AI API', () async {
      const url = 'https://www.instagram.com/reel/DUPLICATE_CHECK';
      const caption = 'Quick pasta recipe...';

      // 1st import
      final job1 = await coordinator.startImport(rawInput: url, manualCaption: caption);
      await coordinator.processJob(job1.id);

      final recipeCountBefore = (await recipeRepo.getAllRecipes()).length;
      expect(recipeCountBefore, 1);

      // 2nd import with same URL (even with different query param)
      const urlWithTracking = 'https://www.instagram.com/reel/DUPLICATE_CHECK/?utm_source=share';
      final job2 = await coordinator.startImport(rawInput: urlWithTracking);

      expect(job2.currentStage, ImportStage.ready);
      expect(job2.recipeId, equals((await importRepo.getJobById(job1.id))!.recipeId));

      // Confirm no duplicate recipe was inserted into database
      final recipeCountAfter = (await recipeRepo.getAllRecipes()).length;
      expect(recipeCountAfter, 1);
    });

    test('Saved recipes remain accessible offline without internet connection', () async {
      // Seed a recipe in local database
      const url = 'https://www.facebook.com/reel/OFFLINE_TEST';
      final job = await coordinator.startImport(
        rawInput: url,
        manualCaption: 'Offline test recipe ingredients and steps...',
      );
      await coordinator.processJob(job.id);

      // Query database as if completely offline
      final offlineRecipes = await recipeRepo.getAllRecipes();
      expect(offlineRecipes.isNotEmpty, isTrue);
      expect(offlineRecipes.first.title, contains('Avocado Toast'));
    });
  });
}
