import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodies/core/database/app_database.dart';
import 'package:foodies/features/importing/data/import_repository.dart';
import 'package:foodies/features/importing/domain/import_job.dart';

void main() {
  late AppDatabase db;
  late ImportRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ImportRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ImportJob Repository & State Machine Tests', () {
    test('createJob initializes job in queued stage and pending status', () async {
      final job = await repo.createJob(
        sourceUrl: 'https://www.instagram.com/reel/TEST_REEL',
      );

      expect(job.currentStage, ImportStage.queued);
      expect(job.status, JobStatus.pending);
      expect(job.attemptCount, 0);
      expect(job.maxRetries, 3);
      expect(job.isTerminal, isFalse);
    });

    test('updateStage transitions through extracting, structuring, and ready', () async {
      final job = await repo.createJob(sourceUrl: 'https://www.facebook.com/reel/123');

      // 1. Transition to extracting
      await repo.updateStage(
        jobId: job.id,
        stage: ImportStage.extracting,
      );
      var current = await repo.getJobById(job.id);
      expect(current!.currentStage, ImportStage.extracting);
      expect(current.status, JobStatus.in_progress);

      // 2. Transition to structuring with caption
      await repo.updateStage(
        jobId: job.id,
        stage: ImportStage.structuring,
        rawCaption: '2 cups flour, 1 cup sugar, bake 20 mins',
      );
      current = await repo.getJobById(job.id);
      expect(current!.currentStage, ImportStage.structuring);
      expect(current.rawCaption, isNotNull);

      // 3. Transition to ready with recipe ID
      await repo.updateStage(
        jobId: job.id,
        stage: ImportStage.ready,
        recipeId: 'rec_completed_1',
      );
      current = await repo.getJobById(job.id);
      expect(current!.currentStage, ImportStage.ready);
      expect(current.status, JobStatus.completed);
      expect(current.recipeId, 'rec_completed_1');
      expect(current.isTerminal, isTrue);
    });

    test('updateStage handles retrying backoff and attempt count', () async {
      final job = await repo.createJob(sourceUrl: 'https://example.com/reel');
      final retryTime = DateTime.now().add(const Duration(seconds: 30));

      await repo.updateStage(
        jobId: job.id,
        stage: ImportStage.retrying,
        error: 'Rate limit reached on Ollama Cloud',
        nextRetryAt: retryTime,
        incrementAttempt: true,
      );

      final current = await repo.getJobById(job.id);
      expect(current!.currentStage, ImportStage.retrying);
      expect(current.attemptCount, 1);
      expect(current.lastError, contains('Rate limit'));
      expect(current.nextRetryAt, isNotNull);
      expect(current.isTerminal, isFalse);
    });

    test('updateStage marks needs_input and allows user recovery', () async {
      final job = await repo.createJob(sourceUrl: 'https://instagram.com/reel/private');

      await repo.updateStage(
        jobId: job.id,
        stage: ImportStage.needs_input,
        error: 'Instagram login required. Please paste caption.',
        status: JobStatus.pending,
      );

      final current = await repo.getJobById(job.id);
      expect(current!.currentStage, ImportStage.needs_input);
      expect(current.canRetry, isTrue);
    });
  });
}
