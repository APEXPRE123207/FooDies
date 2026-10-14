import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart'
    hide Recipe, Ingredient, RecipeStep, RecipeTag, ImportJob;
import '../networking/ollama_client.dart';
import '../storage/secure_storage_service.dart';
import '../../features/extraction/audio_transcription_service.dart';
import '../../features/extraction/content_extractor.dart';
import '../../features/extraction/recipe_structurer.dart';
import '../../features/importing/data/import_pipeline_coordinator.dart';
import '../../features/importing/data/import_repository.dart';
import '../../features/importing/domain/import_job.dart';
import '../../features/recipes/data/recipe_repository.dart';
import '../../features/recipes/domain/models/recipe.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return RecipeRepository(db);
});

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ImportRepository(db);
});

final ollamaClientProvider = Provider<OllamaClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return OllamaClient(storage: storage);
});

final contentExtractorProvider = Provider<ContentExtractor>((ref) {
  return ContentExtractor();
});

final recipeStructurerProvider = Provider<RecipeStructurer>((ref) {
  final client = ref.watch(ollamaClientProvider);
  return RecipeStructurer(ollamaClient: client);
});

final audioTranscriptionServiceProvider = Provider<AudioTranscriptionService>((ref) {
  return AudioTranscriptionService();
});

final importCoordinatorProvider = Provider<ImportPipelineCoordinator>((ref) {
  final importRepo = ref.watch(importRepositoryProvider);
  final recipeRepo = ref.watch(recipeRepositoryProvider);
  final extractor = ref.watch(contentExtractorProvider);
  final structurer = ref.watch(recipeStructurerProvider);

  final coordinator = ImportPipelineCoordinator(
    importRepo: importRepo,
    recipeRepo: recipeRepo,
    extractor: extractor,
    structurer: structurer,
  );

  // Trigger background job recovery
  coordinator.recoverPendingJobs();

  return coordinator;
});

/// Streams
final allRecipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchAllRecipes();
});

final singleRecipeStreamProvider = StreamProvider.family<Recipe?, String>((ref, id) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchRecipeById(id);
});

final importJobsStreamProvider = StreamProvider<List<ImportJobEntity>>((ref) {
  final repo = ref.watch(importRepositoryProvider);
  return repo.watchAllJobs();
});

final isApiKeyConfiguredProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final key = await storage.getApiKey();
  return key != null && key.trim().isNotEmpty;
});
