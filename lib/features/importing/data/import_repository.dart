import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart' as db;
import '../../../core/utils/logger.dart';
import '../domain/import_job.dart';

class ImportRepository {
  final db.AppDatabase _database;
  final Uuid _uuid;

  ImportRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Watch all import jobs in reverse chronological order
  Stream<List<ImportJobEntity>> watchAllJobs() {
    return (_database.select(_database.importJobs)
          ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  /// Get all import jobs
  Future<List<ImportJobEntity>> getAllJobs() async {
    final rows = await (_database.select(_database.importJobs)
          ..orderBy([(j) => OrderingTerm.desc(j.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Watch a specific job
  Stream<ImportJobEntity?> watchJobById(String id) {
    return (_database.select(_database.importJobs)..where((j) => j.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _fromRow(row) : null);
  }

  /// Get single job
  Future<ImportJobEntity?> getJobById(String id) async {
    final row = await (_database.select(_database.importJobs)..where((j) => j.id.equals(id)))
        .getSingleOrNull();
    return row != null ? _fromRow(row) : null;
  }

  /// Find active job for URL
  Future<ImportJobEntity?> findActiveJobForUrl(String url) async {
    final rows = await (_database.select(_database.importJobs)
          ..where((j) => j.sourceUrl.equals(url)))
        .get();
    for (final row in rows) {
      final job = _fromRow(row);
      if (!job.isTerminal) return job;
    }
    return null;
  }

  /// Create a new import job
  Future<ImportJobEntity> createJob({
    required String sourceUrl,
    String? recipeId,
    String? rawCaption,
    String? rawTranscript,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.importJobs).insert(
          db.ImportJobsCompanion(
            id: Value(id),
            recipeId: Value(recipeId),
            sourceUrl: Value(sourceUrl),
            currentStage: const Value('queued'),
            status: const Value('pending'),
            attemptCount: const Value(0),
            maxRetries: const Value(3),
            rawCaption: Value(rawCaption),
            rawTranscript: Value(rawTranscript),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    AppLogger.job(jobId: id, stage: 'queued', message: 'Created job for $sourceUrl');
    return (await getJobById(id))!;
  }

  /// Transition job stage and persist state immediately
  Future<void> updateStage({
    required String jobId,
    required ImportStage stage,
    JobStatus? status,
    String? error,
    String? recipeId,
    String? rawCaption,
    String? rawTranscript,
    DateTime? nextRetryAt,
    bool incrementAttempt = false,
  }) async {
    final now = DateTime.now();
    final existing = await getJobById(jobId);
    if (existing == null) return;

    final newAttempt = incrementAttempt ? existing.attemptCount + 1 : existing.attemptCount;

    JobStatus finalStatus = status ?? existing.status;
    if (stage == ImportStage.ready) {
      finalStatus = JobStatus.completed;
    } else if (stage == ImportStage.failed) {
      finalStatus = JobStatus.failed;
    } else if (stage == ImportStage.cancelled) {
      finalStatus = JobStatus.cancelled;
    } else if (stage != ImportStage.queued && stage != ImportStage.needs_input) {
      finalStatus = JobStatus.in_progress;
    }

    await (_database.update(_database.importJobs)..where((j) => j.id.equals(jobId))).write(
      db.ImportJobsCompanion(
        currentStage: Value(stage.name),
        status: Value(finalStatus.name),
        attemptCount: Value(newAttempt),
        lastError: Value(error ?? existing.lastError),
        recipeId: recipeId != null ? Value(recipeId) : Value(existing.recipeId),
        rawCaption: rawCaption != null ? Value(rawCaption) : Value(existing.rawCaption),
        rawTranscript: rawTranscript != null ? Value(rawTranscript) : Value(existing.rawTranscript),
        nextRetryAt: Value(nextRetryAt),
        updatedAt: Value(now),
      ),
    );

    AppLogger.job(
      jobId: jobId,
      stage: stage.name,
      message: 'Status: ${finalStatus.name}${error != null ? ', Error: $error' : ''}',
    );
  }

  /// Get pending / queued / retryable jobs (useful on app recovery)
  Future<List<ImportJobEntity>> getPendingOrRetryableJobs() async {
    final now = DateTime.now();
    final rows = await (_database.select(_database.importJobs)
          ..where((j) =>
              j.currentStage.equals('queued') |
              j.currentStage.equals('retrying') |
              j.status.equals('in_progress')))
        .get();

    return rows
        .map(_fromRow)
        .where((job) =>
            job.nextRetryAt == null || job.nextRetryAt!.isBefore(now))
        .toList();
  }

  /// Delete a job
  Future<void> deleteJob(String jobId) async {
    await (_database.delete(_database.importJobs)..where((j) => j.id.equals(jobId))).go();
  }

  ImportJobEntity _fromRow(db.ImportJob row) {
    return ImportJobEntity(
      id: row.id,
      recipeId: row.recipeId,
      sourceUrl: row.sourceUrl,
      currentStage: ImportStage.fromString(row.currentStage),
      status: JobStatus.fromString(row.status),
      attemptCount: row.attemptCount,
      maxRetries: row.maxRetries,
      nextRetryAt: row.nextRetryAt,
      lastError: row.lastError,
      rawCaption: row.rawCaption,
      rawTranscript: row.rawTranscript,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
