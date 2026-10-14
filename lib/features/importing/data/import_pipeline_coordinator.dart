import 'dart:async';
import 'dart:math';
import 'package:foodies/core/networking/ollama_client.dart';
import 'package:foodies/core/utils/logger.dart';
import 'package:foodies/core/utils/url_parser.dart';
import 'package:foodies/features/extraction/content_extractor.dart';
import 'package:foodies/features/extraction/recipe_structurer.dart';
import 'package:foodies/features/recipes/data/recipe_repository.dart';
import 'package:foodies/features/importing/domain/import_job.dart';
import 'package:foodies/features/importing/data/import_repository.dart';

class ImportPipelineCoordinator {
  final ImportRepository _importRepo;
  final RecipeRepository _recipeRepo;
  final ContentExtractor _extractor;
  final RecipeStructurer _structurer;

  final Map<String, Future<void>> _inFlightFutures = {};

  ImportPipelineCoordinator({
    required ImportRepository importRepo,
    required RecipeRepository recipeRepo,
    required ContentExtractor extractor,
    required RecipeStructurer structurer,
  })  : _importRepo = importRepo,
        _recipeRepo = recipeRepo,
        _extractor = extractor,
        _structurer = structurer;

  /// Start a new import pipeline from a URL or shared text
  Future<ImportJobEntity> startImport({
    required String rawInput,
    String? manualCaption,
    String? manualTranscript,
  }) async {
    final extractedUrl = UrlParser.extractUrl(rawInput);
    final urlToUse = extractedUrl ?? rawInput.trim();

    // 1. Check duplicate URL in saved recipes
    final existingRecipe = await _recipeRepo.findRecipeBySourceUrl(urlToUse);
    if (existingRecipe != null) {
      AppLogger.info('Duplicate recipe found for $urlToUse: ${existingRecipe.title}');
      // Return a completed pseudo-job pointing to the recipe
      return _importRepo.createJob(
        sourceUrl: urlToUse,
        recipeId: existingRecipe.id,
        rawCaption: manualCaption,
        rawTranscript: manualTranscript,
      ).then((job) async {
        await _importRepo.updateStage(
          jobId: job.id,
          stage: ImportStage.ready,
          recipeId: existingRecipe.id,
        );
        return (await _importRepo.getJobById(job.id))!;
      });
    }

    // 2. Create persistent import job
    final job = await _importRepo.createJob(
      sourceUrl: urlToUse,
      rawCaption: manualCaption,
      rawTranscript: manualTranscript,
    );

    // 3. Kick off async processing without blocking caller
    unawaited(processJob(job.id, manualTranscript: manualTranscript));

    return job;
  }

  /// Recover and run any pending or retrying jobs from database
  Future<void> recoverPendingJobs() async {
    final pending = await _importRepo.getPendingOrRetryableJobs();
    for (final job in pending) {
      if (!_inFlightFutures.containsKey(job.id)) {
        AppLogger.info('Recovering pending job ${job.id} for ${job.sourceUrl}');
        unawaited(processJob(job.id));
      }
    }
  }

  /// Core job state machine
  Future<void> processJob(String jobId, {String? manualTranscript}) {
    if (_inFlightFutures.containsKey(jobId)) {
      return _inFlightFutures[jobId]!;
    }
    final future = _executeJob(jobId, manualTranscript: manualTranscript);
    _inFlightFutures[jobId] = future;
    return future.whenComplete(() => _inFlightFutures.remove(jobId));
  }

  Future<void> _executeJob(String jobId, {String? manualTranscript}) async {

    try {
      final job = await _importRepo.getJobById(jobId);
      if (job == null || job.currentStage == ImportStage.cancelled) return;

      final url = job.sourceUrl;
      final platform = UrlParser.identifyPlatform(url);

      String? caption = job.rawCaption;
      String? transcript = manualTranscript ?? job.rawTranscript;
      String? thumbnailUrl;

      // Stage A & B: Extraction & Completeness
      if (caption == null || caption.trim().isEmpty) {
        await _importRepo.updateStage(
          jobId: jobId,
          stage: ImportStage.extracting,
          status: JobStatus.in_progress,
        );

        final result = await _extractor.extract(url);
        caption = result.caption;
        thumbnailUrl = result.thumbnailUrl;
        if (result.transcript != null && result.transcript!.trim().isNotEmpty) {
          transcript = result.transcript!.trim();
        }

        // If extraction is blocked by platform (e.g. login wall) and no caption or transcript available
        if ((caption == null || caption.trim().isEmpty) && (transcript == null || transcript.trim().isEmpty)) {
          await _importRepo.updateStage(
            jobId: jobId,
            stage: ImportStage.needs_input,
            error: 'Social platform requires login or blocked automated caption extraction. Please paste the caption or transcript manually.',
            status: JobStatus.pending,
          );
          return;
        }

        await _importRepo.updateStage(
          jobId: jobId,
          stage: ImportStage.extracting,
          rawCaption: caption,
          rawTranscript: transcript,
        );
      }


      // Stage D: Structuring with Ollama Cloud
      await _importRepo.updateStage(
        jobId: jobId,
        stage: ImportStage.structuring,
        status: JobStatus.in_progress,
      );

      final recipe = await _structurer.structureRecipe(
        caption: caption,
        transcript: transcript,
        sourceUrl: url,
        sourcePlatform: platform,
        imagePath: thumbnailUrl,
      );

      // Stage E: Persistence
      final savedRecipe = await _recipeRepo.insertRecipe(recipe);

      await _importRepo.updateStage(
        jobId: jobId,
        stage: ImportStage.ready,
        status: JobStatus.completed,
        recipeId: savedRecipe.id,
      );
    } on OllamaClientException catch (e) {
      AppLogger.error('Ollama Cloud error on job $jobId: $e');
      await _handleJobFailure(jobId, e.toString(), isTransient: e.statusCode != 401 && e.statusCode != 403);
    } on RecipeValidationException catch (e) {
      AppLogger.error('Recipe validation error on job $jobId: $e');
      await _importRepo.updateStage(
        jobId: jobId,
        stage: ImportStage.needs_input,
        status: JobStatus.pending,
        error: e.message,
      );
    } catch (e, stack) {
      AppLogger.error('Unexpected error processing job $jobId', error: e, stackTrace: stack);
      await _handleJobFailure(jobId, 'Failed to process recipe: ${AppLogger.sanitize(e.toString())}', isTransient: true);
    }
  }

  Future<void> _handleJobFailure(String jobId, String error, {required bool isTransient}) async {
    final job = await _importRepo.getJobById(jobId);
    if (job == null) return;

    if (isTransient && job.attemptCount < job.maxRetries) {
      final backoffSeconds = (15 * pow(2, job.attemptCount)).toInt();
      final nextRetry = DateTime.now().add(Duration(seconds: min(backoffSeconds, 300)));

      await _importRepo.updateStage(
        jobId: jobId,
        stage: ImportStage.retrying,
        status: JobStatus.pending,
        error: '$error (Scheduled retry in ${backoffSeconds}s)',
        nextRetryAt: nextRetry,
        incrementAttempt: true,
      );
    } else {
      await _importRepo.updateStage(
        jobId: jobId,
        stage: ImportStage.failed,
        status: JobStatus.failed,
        error: error,
        incrementAttempt: true,
      );
    }
  }

  /// Manually provide caption or transcript for a job in needs_input or failed state
  Future<void> submitManualInput(
    String jobId, {
    String? caption,
    String? transcript,
  }) async {
    await _importRepo.updateStage(
      jobId: jobId,
      stage: ImportStage.queued,
      status: JobStatus.pending,
      rawCaption: caption,
      rawTranscript: transcript,
    );
    unawaited(processJob(jobId, manualTranscript: transcript));
  }

  /// Manually retry a failed or stuck job
  Future<void> retryJob(String jobId) async {
    await _importRepo.updateStage(
      jobId: jobId,
      stage: ImportStage.queued,
      status: JobStatus.pending,
      nextRetryAt: null,
    );
    unawaited(processJob(jobId));
  }

  /// Cancel an ongoing or failed job
  Future<void> cancelJob(String jobId) async {
    await _importRepo.updateStage(
      jobId: jobId,
      stage: ImportStage.cancelled,
      status: JobStatus.cancelled,
    );
  }
}
