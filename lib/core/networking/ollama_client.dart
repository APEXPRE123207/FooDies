import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../storage/secure_storage_service.dart';
import '../utils/logger.dart';
import 'ollama_models.dart';

class OllamaClientException implements Exception {
  final String message;
  final int? statusCode;

  OllamaClientException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class OllamaClient {
  final SecureStorageService _storage;
  final http.Client _httpClient;

  OllamaClient({
    required SecureStorageService storage,
    http.Client? httpClient,
  })  : _storage = storage,
        _httpClient = httpClient ?? http.Client();

  /// Tests connection to Ollama Cloud API and returns latency + available models if listed
  Future<OllamaConnectionResult> testConnection({
    String? apiKey,
    String? baseUrl,
    String? modelName,
  }) async {
    final key = apiKey ?? await _storage.getApiKey();
    final url = baseUrl ?? await _storage.getBaseUrl();
    final model = modelName ?? await _storage.getModelName();

    if (key == null || key.trim().isEmpty) {
      return const OllamaConnectionResult(
        isSuccess: false,
        errorMessage: 'Ollama Cloud API Key is missing. Please enter your API key.',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      // 1. First attempt /api/tags to list available models
      final tagsUri = Uri.parse('$url/tags');
      final tagsResponse = await _httpClient.get(
        tagsUri,
        headers: {
          'Authorization': 'Bearer $key',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      stopwatch.stop();

      if (tagsResponse.statusCode == 200) {
        final decoded = jsonDecode(tagsResponse.body) as Map<String, dynamic>;
        final modelsList = (decoded['models'] as List<dynamic>?)
                ?.map((m) => (m as Map<String, dynamic>)['name'] as String? ?? '')
                .where((name) => name.isNotEmpty)
                .toList() ??
            [];

        return OllamaConnectionResult(
          isSuccess: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          availableModels: modelsList,
        );
      } else if (tagsResponse.statusCode == 401) {
        return const OllamaConnectionResult(
          isSuccess: false,
          errorMessage: 'Invalid API Key. Please verify your credentials on ollama.com.',
        );
      } else if (tagsResponse.statusCode == 429) {
        return const OllamaConnectionResult(
          isSuccess: false,
          errorMessage: 'Rate limit exceeded on Ollama Cloud. Please wait a moment.',
        );
      }

      // 2. If /tags is not permitted or unsupported, perform a minimal lightweight chat ping
      final chatUri = Uri.parse('$url/chat');
      final pingResponse = await _httpClient.post(
        chatUri,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 15));

      if (pingResponse.statusCode == 200) {
        return OllamaConnectionResult(
          isSuccess: true,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        return OllamaConnectionResult(
          isSuccess: false,
          errorMessage: _formatStatusCodeError(pingResponse.statusCode),
        );
      }
    } on SocketException {
      return const OllamaConnectionResult(
        isSuccess: false,
        errorMessage: 'Network unavailable. Could not reach Ollama Cloud endpoint.',
      );
    } on TimeoutException {
      return const OllamaConnectionResult(
        isSuccess: false,
        errorMessage: 'Connection timed out while reaching Ollama Cloud.',
      );
    } catch (e) {
      AppLogger.error('Connection test error', error: e);
      return OllamaConnectionResult(
        isSuccess: false,
        errorMessage: 'Connection error: ${AppLogger.sanitize(e.toString())}',
      );
    }
  }

  /// Sends a structured or JSON-schema chat completion request to Ollama Cloud
  Future<OllamaChatResponse> chat({
    required List<Map<String, String>> messages,
    String? model,
    Map<String, dynamic>? schemaFormat,
    bool forceJsonFormat = true,
  }) async {
    final key = await _storage.getApiKey();
    final url = await _storage.getBaseUrl();
    final selectedModel = model ?? await _storage.getModelName();

    if (key == null || key.trim().isEmpty) {
      throw OllamaClientException('Ollama Cloud API Key is not configured.');
    }

    final endpoint = Uri.parse('$url/chat');
    final payload = <String, dynamic>{
      'model': selectedModel,
      'messages': messages,
      'stream': false,
      'options': {
        'temperature': 0, // strict adherence for extraction
      },
    };

    if (schemaFormat != null) {
      payload['format'] = schemaFormat;
    } else if (forceJsonFormat) {
      payload['format'] = 'json';
    }

    AppLogger.info('Calling Ollama Cloud chat endpoint with model $selectedModel');

    try {
      final response = await _httpClient.post(
        endpoint,
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return OllamaChatResponse.fromJson(decoded);
      }

      final errorMsg = _formatStatusCodeError(response.statusCode);
      AppLogger.error('Ollama Cloud returned status ${response.statusCode}: $errorMsg');
      throw OllamaClientException(errorMsg, statusCode: response.statusCode);
    } on SocketException catch (_) {
      throw OllamaClientException('Network unavailable. Unable to contact Ollama Cloud.');
    } on TimeoutException catch (_) {
      throw OllamaClientException('Ollama Cloud request timed out after 45 seconds.');
    } catch (e) {
      if (e is OllamaClientException) rethrow;
      throw OllamaClientException('Ollama request failed: ${AppLogger.sanitize(e.toString())}');
    }
  }

  String _formatStatusCodeError(int code) {
    switch (code) {
      case 401:
        return 'Invalid API key or unauthorized. Please check your Ollama Cloud credentials.';
      case 403:
        return 'Access forbidden. Your Ollama Cloud account may lack permissions for this model.';
      case 404:
        return 'Model or endpoint not found. Please confirm the model name in Settings.';
      case 429:
        return 'Rate limit reached or quota exhausted. Please try again later.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Ollama Cloud servers are temporarily unavailable ($code). Retrying will occur automatically.';
      default:
        return 'Ollama Cloud returned an unexpected HTTP error ($code).';
    }
  }
}
