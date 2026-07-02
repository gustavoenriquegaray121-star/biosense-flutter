// ============================================================
// BIOSENSE — Health Repository
// El puente ciego entre el hardware (BLE) y el motor matemático.
// Al frontend no le importa de dónde vienen los números.
// ============================================================

import 'dart:async';
import '../core/dhsi_engine.dart';
import '../services/ble_service.dart';
import '../models/user_profile.dart';
import '../core/event_log.dart';

abstract class IHealthRepository {
  Stream<Map<String, dynamic>> get healthAnalysisStream;
  void updateActiveProfile(UserProfile profile);
  void connectHardware();
  void connectMock({double perturbation});
  void stopTelemetry();
  EventLog get eventLog;
  DHSIEngine get engine;
  BleService get bleService;
}

class HealthRepository implements IHealthRepository {
  final DHSIEngine _dhsiEngine;
  final BleService _bleService;
  final EventLog _eventLog;

  StreamSubscription? _rawSub;
  final _analysisController = StreamController<Map<String, dynamic>>.broadcast();

  HealthRepository({
    DHSIEngine? dhsiEngine,
    BleService? bleService,
    EventLog? eventLog,
  })  : _dhsiEngine = dhsiEngine ?? DHSIEngine(),
        _bleService = bleService ?? BleService(),
        _eventLog   = eventLog ?? EventLog() {
    _listenRawMetrics();
  }

  @override
  DHSIEngine get engine => _dhsiEngine;

  @override
  EventLog get eventLog => _eventLog;

  void _listenRawMetrics() {
    _rawSub = _bleService.rawMetricsStream.listen((raw) {
      // Aplicar corrección de confusión activa desde la bitácora
      final correction = _eventLog.getActiveCorrection();
      _dhsiEngine.activeConfHrv  = correction.hrv;
      _dhsiEngine.activeConfTemp = correction.temp;
      _dhsiEngine.activeConfResp = correction.resp;
      _dhsiEngine.activeConfGsr  = correction.gsr;

      final result = _dhsiEngine.executeAnalysisPhase(
        rawHrv:  raw['hrv']!,
        rawTemp: raw['temp']!,
        rawResp: raw['resp']!,
        rawGsr:  raw['gsr']!,
      );

      _analysisController.add(result);
    });
  }

  @override
  Stream<Map<String, dynamic>> get healthAnalysisStream =>
      _analysisController.stream;

  @override
  void updateActiveProfile(UserProfile profile) {
    _dhsiEngine.setProfile(profile);
  }

  @override
  void connectHardware() {
    _bleService.startScan();
  }

  @override
  void connectMock({double perturbation = 0.0}) {
    _bleService.startMockMode(perturbation: perturbation);
  }

  @override
  void stopTelemetry() {
    _bleService.disconnectDevice();
  }

  BleService get bleService => _bleService;

  void dispose() {
    _rawSub?.cancel();
    _analysisController.close();
    _bleService.dispose();
  }
}
