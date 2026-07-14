// ============================================================
// BIOSENSE — App State Provider
// La ÚNICA capa que conoce tanto el HealthRepository (lógica
// pura) como Flutter (ChangeNotifier). El algoritmo de abajo
// nunca sabe que Flutter existe.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/health_state.dart';
import '../models/user_profile.dart';
import '../repositories/health_repository.dart';
import '../core/voice_manager.dart';
import '../core/localization_manager.dart';
import '../core/event_log.dart';
import '../services/ble_service.dart';

class AppStateProvider extends ChangeNotifier {
  final IHealthRepository _healthRepository;
  final VoiceManager _voiceManager;
  final LocalizationManager _localization;

  StreamSubscription<Map<String, dynamic>>? _healthSub;
  StreamSubscription<BleConnectionStatus>? _bleStatusSub;

  HealthState _currentHealthState = HealthState.initial();
  bool _isConnecting = false;
  BleConnectionStatus _bleStatus = BleConnectionStatus.disconnected;
  bool _voiceEnabled = true;
  String _userName = '';

  AppStateProvider({
    required IHealthRepository healthRepository,
    required VoiceManager voiceManager,
    required LocalizationManager localization,
  })  : _healthRepository = healthRepository,
        _voiceManager = voiceManager,
        _localization = localization {
    _startListening();
  }

  // ── Getters expuestos a la UI ──────────────────────────────
  HealthState get healthState => _currentHealthState;
  bool get isConnecting => _isConnecting;
  BleConnectionStatus get bleStatus => _bleStatus;
  AppLanguage get language => _localization.current;
  bool get voiceEnabled => _voiceEnabled;
  String get userName => _userName.isEmpty
      ? (_localization.current == AppLanguage.es ? 'amigo' : 'friend')
      : _userName;
  EventLog get eventLog => _healthRepository.eventLog;
  bool get baselineLocked => _healthRepository.engine.baselineLocked;
  int get baselineSamples => _healthRepository.engine.baselineSamplesCount;
  UserProfile get currentProfile => _healthRepository.engine.currentProfile;

  String t(String key) => _localization.t(key);

  // Control de voz — solo habla cuando cambia el estado
  String _lastSpokenStatus = '';
  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minVoiceInterval = Duration(minutes: 3);

  // ── Inicia la escucha del stream de análisis ───────────────
  void _startListening() {
    _healthSub = _healthRepository.healthAnalysisStream.listen((data) {
      final channels = data['channels'] as Map<String, double>;

      _currentHealthState = HealthState(
        dhsi: data['dhsi'] as double,
        velocity: data['velocity'] as double,
        jerk: data['jerk'] as double,
        statusKey: data['status_key'] as String,
        confidenceLevel: data['confidence_level'] as double,
        timestamp: data['timestamp'] as int,
        cycle: data['cycle'] as int,
        hrv:  _channelReading(channels['hrv']!,  inverted: true),
        temp: _channelReading(channels['temp']!, inverted: false),
        resp: _channelReading(channels['resp']!, inverted: false),
        gsr:  _channelReading(channels['gsr']!,  inverted: false),
      );

      _triggerVoiceIfNeeded();
      notifyListeners();
    });

    _bleStatusSub = _healthRepository.bleService.statusStream.listen((status) {
      _bleStatus = status;
      notifyListeners();
    });
  }

  ChannelReading _channelReading(double value, {required bool inverted}) {
    final delta = value - 1.0;
    ChannelStatus status;
    if (inverted) {
      if (delta > -0.03) {
        status = ChannelStatus.normal;
      } else if (delta > -0.08) {
        status = ChannelStatus.leve;
      } else if (delta > -0.14) {
        status = ChannelStatus.moderado;
      } else {
        status = ChannelStatus.alto;
      }
    } else {
      if (delta < 0.03) {
        status = ChannelStatus.normal;
      } else if (delta < 0.08) {
        status = ChannelStatus.leve;
      } else if (delta < 0.14) {
        status = ChannelStatus.moderado;
      } else {
        status = ChannelStatus.alto;
      }
    }
    return ChannelReading(value: value, status: status);
  }

  // ── Conexión ────────────────────────────────────────────────
  void connectHardware() {
    _isConnecting = true;
    notifyListeners();
    _healthRepository.connectHardware();
  }

  void connectMockMode({double perturbation = 0.0}) {
    _healthRepository.connectMock(perturbation: perturbation);
  }

  void setMockPerturbation(double p) {
    _healthRepository.bleService.setMockPerturbation(p);
  }

  // ── Perfil ──────────────────────────────────────────────────
  void changeProfile(UserProfile profile) {
    _healthRepository.updateActiveProfile(profile);
    notifyListeners();
  }

  // ── Idioma ──────────────────────────────────────────────────
  void toggleLanguage(AppLanguage lang) {
    _localization.setLanguage(lang);
    _voiceManager.setLanguage(lang);
    notifyListeners();
  }

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  // ── Voz ─────────────────────────────────────────────────────
  void setVoiceEnabled(bool v) {
    _voiceEnabled = v;
    _voiceManager.setEnabled(v);
    notifyListeners();
  }

  void _triggerVoiceIfNeeded() {
    if (!_voiceEnabled) return;
    final key = _currentHealthState.statusKey;
    final now = DateTime.now();

    // Solo hablar si:
    // 1. El estado cambió, O
    // 2. Han pasado al menos 3 minutos desde la última vez
    final stateChanged = key != _lastSpokenStatus;
    final enoughTimePassed = now.difference(_lastSpokenTime) >= _minVoiceInterval;

    // En estado crítico o alerta, hablar siempre que cambie
    // En estado estable, solo cada 3 minutos como máximo
    final isCritical = key == 'danger' || key == 'critical' || key == 'alert';

    // Lógica simple: si no cambió Y no pasaron 3 min -> silencio
    if (!stateChanged && !enoughTimePassed) return;

    _lastSpokenStatus = key;
    _lastSpokenTime = now;

    // Si hay café activo y todo está estable, mensaje especial
    final hasActiveCoffee = eventLog.activeEvents
        .any((e) => e.type == EventType.cafe);

    final voiceKey = switch (key) {
      'fatigue' => 'voice_fatigue',
      'alert'   => 'voice_alert',
      'danger'  => 'voice_danger',
      'critical'=> 'voice_critical',
      _ => hasActiveCoffee ? 'voice_coffee' : 'voice_stable',
    };

    _voiceManager.speakStatus(key, _localization.t(voiceKey));
  }

  // ── Bitácora rápida ─────────────────────────────────────────
  Future<void> logEvent(EventType type) async {
    await eventLog.addEvent(type);
    notifyListeners();
  }

  Future<void> toggleEvent(EventType type) async {
    await eventLog.toggleEvent(type);
    notifyListeners();
  }

  @override
  void dispose() {
    _healthSub?.cancel();
    _bleStatusSub?.cancel();
    _healthRepository.stopTelemetry();
    _voiceManager.dispose();
    super.dispose();
  }
}
