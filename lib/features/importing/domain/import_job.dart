enum ImportStage {
  queued,
  extracting,
  transcribing,
  structuring,
  ready,
  needs_input,
  retrying,
  failed,
  cancelled;

  String get displayName {
    switch (this) {
      case ImportStage.queued:
        return 'Queued';
      case ImportStage.extracting:
        return 'Extracting Caption';
      case ImportStage.transcribing:
        return 'Transcribing Audio';
      case ImportStage.structuring:
        return 'AI Structuring';
      case ImportStage.ready:
        return 'Ready';
      case ImportStage.needs_input:
        return 'Needs Input';
      case ImportStage.retrying:
        return 'Retrying';
      case ImportStage.failed:
        return 'Failed';
      case ImportStage.cancelled:
        return 'Cancelled';
    }
  }

  static ImportStage fromString(String stage) {
    for (final s in ImportStage.values) {
      if (s.name.toLowerCase() == stage.toLowerCase()) return s;
    }
    return ImportStage.queued;
  }
}

enum JobStatus {
  pending,
  in_progress,
  completed,
  failed,
  cancelled;

  static JobStatus fromString(String status) {
    for (final s in JobStatus.values) {
      if (s.name.toLowerCase() == status.toLowerCase()) return s;
    }
    return JobStatus.pending;
  }
}

class ImportJobEntity {
  final String id;
  final String? recipeId;
  final String sourceUrl;
  final ImportStage currentStage;
  final JobStatus status;
  final int attemptCount;
  final int maxRetries;
  final DateTime? nextRetryAt;
  final String? lastError;
  final String? rawCaption;
  final String? rawTranscript;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ImportJobEntity({
    required this.id,
    this.recipeId,
    required this.sourceUrl,
    this.currentStage = ImportStage.queued,
    this.status = JobStatus.pending,
    this.attemptCount = 0,
    this.maxRetries = 3,
    this.nextRetryAt,
    this.lastError,
    this.rawCaption,
    this.rawTranscript,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isTerminal =>
      currentStage == ImportStage.ready ||
      currentStage == ImportStage.cancelled ||
      (currentStage == ImportStage.failed && attemptCount >= maxRetries);

  bool get canRetry =>
      currentStage == ImportStage.failed ||
      currentStage == ImportStage.needs_input;

  ImportJobEntity copyWith({
    String? id,
    String? recipeId,
    String? sourceUrl,
    ImportStage? currentStage,
    JobStatus? status,
    int? attemptCount,
    int? maxRetries,
    DateTime? nextRetryAt,
    String? lastError,
    String? rawCaption,
    String? rawTranscript,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ImportJobEntity(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      maxRetries: maxRetries ?? this.maxRetries,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      rawCaption: rawCaption ?? this.rawCaption,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
