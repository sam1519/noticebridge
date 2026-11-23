import 'package:flutter_tts/flutter_tts.dart';

import '../config.dart';

/// Read-aloud helper. Fails silently if the device has no voice for the language.
class Speech {
  Speech._();
  static final Speech I = Speech._();
  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text, String langCode) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(ttsLocale(langCode));
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
