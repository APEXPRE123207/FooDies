class OllamaChatResponse {
  final String model;
  final String content;
  final bool done;
  final int? promptEvalCount;
  final int? evalCount;

  const OllamaChatResponse({
    required this.model,
    required this.content,
    this.done = true,
    this.promptEvalCount,
    this.evalCount,
  });

  factory OllamaChatResponse.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    String content = '';
    if (rawMessage is Map<String, dynamic>) {
      content = rawMessage['content'] as String? ?? '';
    } else if (rawMessage is Map) {
      content = rawMessage['content']?.toString() ?? '';
    } else if (rawMessage is String) {
      content = rawMessage;
    } else if (json['response'] != null) {
      content = json['response'].toString();
    }

    return OllamaChatResponse(
      model: json['model'] as String? ?? '',
      content: content,
      done: json['done'] as bool? ?? true,
      promptEvalCount: json['prompt_eval_count'] as int?,
      evalCount: json['eval_count'] as int?,
    );
  }
}

class OllamaModelInfo {
  final String name;
  final String? modifiedAt;
  final int? size;

  const OllamaModelInfo({
    required this.name,
    this.modifiedAt,
    this.size,
  });

  factory OllamaModelInfo.fromJson(Map<String, dynamic> json) {
    return OllamaModelInfo(
      name: json['name'] as String? ?? json['model'] as String? ?? '',
      modifiedAt: json['modified_at'] as String?,
      size: json['size'] as int?,
    );
  }
}

class OllamaConnectionResult {
  final bool isSuccess;
  final int? latencyMs;
  final String? errorMessage;
  final List<String> availableModels;

  const OllamaConnectionResult({
    required this.isSuccess,
    this.latencyMs,
    this.errorMessage,
    this.availableModels = const [],
  });
}
