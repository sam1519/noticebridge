import 'package:flutter/foundation.dart';

/// Default backend address. You can also change it inside the app
/// (Login screen -> "Server settings") without editing code.
String defaultBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:5000';
  // Android emulator reaches your laptop through 10.0.2.2
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5000';
  return 'http://127.0.0.1:5000';
}

/// Languages supported for translation + read-aloud: code, name, TTS locale.
const List<Map<String, String>> kLanguages = [
  {'code': 'en', 'name': 'English', 'tts': 'en-IN'},
  {'code': 'hi', 'name': 'हिन्दी (Hindi)', 'tts': 'hi-IN'},
  {'code': 'ta', 'name': 'தமிழ் (Tamil)', 'tts': 'ta-IN'},
  {'code': 'te', 'name': 'తెలుగు (Telugu)', 'tts': 'te-IN'},
  {'code': 'kn', 'name': 'ಕನ್ನಡ (Kannada)', 'tts': 'kn-IN'},
  {'code': 'ml', 'name': 'മലയാളം (Malayalam)', 'tts': 'ml-IN'},
  {'code': 'bn', 'name': 'বাংলা (Bengali)', 'tts': 'bn-IN'},
  {'code': 'mr', 'name': 'मराठी (Marathi)', 'tts': 'mr-IN'},
  {'code': 'gu', 'name': 'ગુજરાતી (Gujarati)', 'tts': 'gu-IN'},
  {'code': 'pa', 'name': 'ਪੰਜਾਬੀ (Punjabi)', 'tts': 'pa-IN'},
  {'code': 'ur', 'name': 'اردو (Urdu)', 'tts': 'ur-IN'},
];

String languageName(String code) =>
    kLanguages.firstWhere((l) => l['code'] == code, orElse: () => {'name': code})['name']!;

String ttsLocale(String code) =>
    kLanguages.firstWhere((l) => l['code'] == code, orElse: () => {'tts': 'en-IN'})['tts']!;
