// ============================================================
// BIOSENSE — Voice Manager
// "Altea te habla cuando no puedes ver la pantalla"
// El paletero, el albañil, el invidente — todos escuchan.
// ============================================================

import 'package:flutter_tts/flutter_tts.dart';
import 'localization_manager.dart';

class VoiceManager {
  // Singleton — garantiza que _lastStatusKey nunca se resetea
  static final VoiceManager _instance = VoiceManager._internal();
  factory VoiceManager() => _instance;
  VoiceManager._internal();
  final FlutterTts _tts = FlutterTts();
  String _lastStatusKey = '';
  bool _enabled = true;

  Future<void> _init() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(0.85);
    await _tts.setPitch(1.0);
  }

  void setLanguage(AppLanguage lang) {
    _tts.setLanguage(lang == AppLanguage.es ? 'es-MX' : 'en-US');
  }

  void setEnabled(bool v) => _enabled = v;
  bool get isEnabled => _enabled;

  /// Habla solo si el statusKey CAMBIÓ — evita repetir cada segundo
  Future<void> speakStatus(String statusKey, String message) async {
    if (!_enabled) return;
    if (_isSpeaking) return;
    // Solo hablar si el estado CAMBIÓ
    if (statusKey == _lastStatusKey) return;
    _lastStatusKey = statusKey;
    _lastSpeakTime = DateTime.now();
    await _speak(message);
  }

  Future<void> speakNow(String text) async {
    if (!_enabled) return;
    await _speak(text);
  }

  bool _isSpeaking = false;

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
