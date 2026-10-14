import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/utils/logger.dart';

class AudioTranscriptionService {
  final stt.SpeechToText _speechToText;
  bool _isInitialized = false;

  AudioTranscriptionService({stt.SpeechToText? speechToText})
      : _speechToText = speechToText ?? stt.SpeechToText();

  /// Initialize multilingual speech engine
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) => AppLogger.info('Speech error: ${val.errorMsg}'),
        onStatus: (val) => AppLogger.info('Speech status: $val'),
      );
      return _isInitialized;
    } catch (e) {
      AppLogger.error('Failed to initialize speech to text', error: e);
      return false;
    }
  }

  /// Get supported locales for multilingual recognition
  Future<List<stt.LocaleName>> getLocales() async {
    try {
      if (!_isInitialized) await initialize();
      return await _speechToText.locales();
    } catch (e) {
      AppLogger.error('Error fetching locales', error: e);
      return [];
    }
  }

  /// Transcribe live speech (e.g. user narrating or recording reel playback)
  Future<String?> transcribeAudioSession({
    Duration timeout = const Duration(seconds: 45),
    String? localeId,
  }) async {
    final ok = await initialize();
    if (!ok) return null;

    final completer = Completer<String?>();
    var recognizedWords = '';

    await _speechToText.listen(
      onResult: (result) {
        recognizedWords = result.recognizedWords;
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(recognizedWords);
        }
      },
      localeId: localeId,
      listenFor: timeout,
      pauseFor: const Duration(seconds: 5),
    );

    // Safety timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        _speechToText.stop();
        completer.complete(recognizedWords.isNotEmpty ? recognizedWords : null);
      }
    });

    return completer.future;
  }

  void stop() {
    _speechToText.stop();
  }
}
