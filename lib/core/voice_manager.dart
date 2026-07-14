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

  VoiceManager() {
    _init();
  }

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
  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minInterval = Duration(seconds: 60);

  Future<void> speakStatus(String statusKey, String message) async {
    if (!_enabled) return;
    final now = DateTime.now();
    final sameStatus = statusKey == _lastStatusKey;
    final tooSoon = now.difference(_lastSpeakTime) < _minInterval;
    // Silencio si: mismo estado Y menos de 60 segundos desde última vez
    if (sameStatus && tooSoon) return;
    _lastStatusKey = statusKey;
    _lastSpeakTime = now;
    await _speak(message);
  }

  Future<void> speakNow(String text) async {
    if (!_enabled) return;
    await _speak(text);
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async => _tts.stop();

  void dispose() => _tts.stop();
}
