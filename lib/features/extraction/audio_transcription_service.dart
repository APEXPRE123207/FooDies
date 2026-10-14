import 'package:flutter/services.dart';
import '../../core/utils/logger.dart';

class AudioTranscriptionService {
  static const MethodChannel _channel = MethodChannel('foodies/video_transcriber');

  /// Transcribes spoken audio directly from the extracted MP4 video stream
  /// without using the device microphone or any external paid API.
  Future<String?> transcribeVideoStream(String? videoUrl, {String language = 'en-IN'}) async {
    if (videoUrl == null || videoUrl.trim().isEmpty) return null;

    try {
      AppLogger.info('Transcribing video audio stream via native hardware pipe');
      final String? transcript = await _channel.invokeMethod<String>(
        'transcribeVideoUrl',
        {
          'videoUrl': videoUrl.trim(),
          'language': language,
        },
      );

      if (transcript != null && transcript.trim().isNotEmpty) {
        AppLogger.info('Native video transcription succeeded (${transcript.length} characters)');
        return transcript.trim();
      }
      return null;
    } on PlatformException catch (e) {
      AppLogger.info('Native video transcription error: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      AppLogger.info('Native video transcription unexpected error: $e');
      return null;
    }
  }
}
