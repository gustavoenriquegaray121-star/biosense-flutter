// ============================================================
// BIOSENSE — Voice Manager
// "Altea te habla cuando no puedes ver la pantalla"
// Singleton — solo habla cuando el estado CAMBIA
// ============================================================

import 'package:flutter_tts/flutter_tts.dart';
import 'localization_manager.dart';

class VoiceManager {
  static final VoiceManager _instance = VoiceManager._internal();
  factory VoiceManager() => _instance;
  VoiceManager._internal();

  final FlutterTts _tts = FlutterTts();
  String _lastStatusKey = '';
  bool _enabled = true;
  bool _isSpeaking = false;

  static Future<VoiceManager> create() async {
    await _instance._tts.setLanguage('es-MX');
    await _instance._tts.setSpeechRate(0.48);
    await _instance._tts.setVolume(0.85);
    await _instance._tts.setPitch(1.0);
    return _instance;
  }

  void setLanguage(AppLanguage lang) {
    _tts.setLanguage(lang == AppLanguage.es ? 'es-MX' : 'en-US');
  }

  void setEnabled(bool v) => _enabled = v;
  bool get isEnabled => _enabled;

  // Solo habla cuando el estado CAMBIA y no está hablando
  Future<void> speakStatus(String statusKey, String message) async {
    if (!_enabled) return;
    if (_isSpeaking) return;
    if (statusKey == _lastStatusKey) return;
    _lastStatusKey = statusKey;
    await _speak(message);
  }

  Future<void> speakNow(String text) async {
    if (!_enabled) return;
    await _speak(text);
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    await _tts.stop();
    await _tts.speak(text);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) => _isSpeaking = false);
  }

  Future<void> stop() async => _tts.stop();
  void dispose() => _tts.stop();
}
