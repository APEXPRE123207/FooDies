import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import '../../core/utils/logger.dart';

class LocalWhisperTranscriptionService {
  static const MethodChannel _audioChannel = MethodChannel('foodies/video_transcriber');
  late final Whisper _whisper;
  bool _isInitialized = false;

  /// Initialize Whisper with tiny model
  Future<void> init() async {
    if (_isInitialized) return;
    _whisper = const Whisper(model: WhisperModel.tiny);
    _isInitialized = true;
  }

  /// Transcribe a video URL completely offline on-device
  Future<String?> transcribeReelAudio(String videoUrl) async {
    if (kIsWeb) return null;
    try {
      await init();

      AppLogger.info('Extracting 16kHz WAV from video URL: $videoUrl');
      // 1. Tell native Android code to download the .mp4 and extract a 16kHz mono PCM .wav file
      final String? wavFilePath = await _audioChannel.invokeMethod<String>(
        'extractWavFromVideoUrl',
        {'videoUrl': videoUrl},
      );

      if (wavFilePath == null || !File(wavFilePath).existsSync()) {
        AppLogger.warn('WAV extraction returned null or non-existent file path: $wavFilePath');
        return null;
      }

      AppLogger.info('Running offline Whisper transcription on $wavFilePath...');
      // 2. Pass the local .wav file into on-device Whisper C++ FFI
      final request = TranscribeRequest(
        audio: wavFilePath,
        isTranslate: false,
        isNoTimestamps: true,
        splitOnWord: false,
      );

      final WhisperTranscribeResponse response = await _whisper.transcribe(
        transcribeRequest: request,
      );

      // 3. Cleanup temp wav file
      try {
        final f = File(wavFilePath);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (err) {
        AppLogger.warn('Failed to cleanup temp WAV file: $err');
      }

      final text = response.text.trim();
      AppLogger.info('Local Whisper transcription complete (${text.length} chars)');
      return text.isNotEmpty ? text : null;
    } catch (e, stack) {
      AppLogger.error('Local Whisper transcription error: $e', error: e, stackTrace: stack);
      return null;
    }
  }
}
