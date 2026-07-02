// ============================================================
// BIOSENSE — DHSI Engine (Facade Pattern)
// El ÚNICO punto de entrada al motor analítico.
// No sabe ni le importa si lo invoca Flutter, Swift, un test
// unitario, una FPGA o una terminal de comandos.
//
// Flutter → AppStateProvider → HealthRepository → DHSIEngine
//                                                      │
//                                    ┌─────────────────┼─────────────────┐
//                                    ▼                 ▼                 ▼
//                              KalmanFilter      DHSICalculator   TrendDetector
//
// USPTO Provisional #63/914,860 | ALTEA-GARAY HTS
// ============================================================

import 'kalman_filter.dart';
import 'dhsi_calculator.dart';
import 'trend_detector.dart';
import 'profile_manager.dart';
import '../models/user_profile.dart';

class DHSIEngine {
  final KalmanFilter _hrvFilter;
  final KalmanFilter _tempFilter;
  final KalmanFilter _respFilter;
  final KalmanFilter _gsrFilter;
  final DHSICalculator _calculator;
  final TrendDetector _detector;
  final ProfileManager _profileManager;

  // Línea base personal
  final List<double> _baselineSamples = [];
  bool   _baselineLocked = false;
  double _baselineVal    = 1.0;
  static const int baselineLen = 30;

  int _cycle = 0;
  double _confidence = 0.0;

  // Corrección activa por eventos (bitácora rápida)
  double activeConfHrv = 0, activeConfTemp = 0, activeConfResp = 0, activeConfGsr = 0;

  DHSIEngine({
    double q = 0.002,
    double r = 0.015,
    ProfileManager? profileManager,
  })  : _hrvFilter  = KalmanFilter(q: q, r: r, initialState: 1.0),
        _tempFilter = KalmanFilter(q: q, r: r, initialState: 1.0),
        _respFilter = KalmanFilter(q: q, r: r, initialState: 1.0),
        _gsrFilter  = KalmanFilter(q: q, r: r, initialState: 1.0),
        _calculator = DHSICalculator(),
        _detector   = TrendDetector(initialDhsi: 1.0),
        _profileManager = profileManager ?? ProfileManager();

  // ── API pública ──────────────────────────────────────────

  void setProfile(UserProfile profile) {
    _profileManager.setProfile(profile);
    reset();
  }

  UserProfile get currentProfile => _profileManager.currentProfile;
  bool   get baselineLocked => _baselineLocked;
  double get baselineVal    => _baselineVal;
  int    get baselineSamplesCount => _baselineSamples.length;

  void reset() {
    _hrvFilter.reset(1.0);
    _tempFilter.reset(1.0);
    _respFilter.reset(1.0);
    _gsrFilter.reset(1.0);
    _baselineSamples.clear();
    _baselineLocked = false;
    _baselineVal    = 1.0;
    _detector.reset(1.0);
    _cycle = 0;
    _confidence = 0.0;
  }

  /// Entrada: señales fisiológicas crudas.
  /// Salida: estructura de datos universal (Map), sin dependencias de Flutter.
  Map<String, dynamic> executeAnalysisPhase({
    required double rawHrv,
    required double rawTemp,
    required double rawResp,
    required double rawGsr,
  }) {
    _cycle++;
    final hb = _profileManager.hrvBaselineFactor;

    // 1. Filtrado cinemático (Kalman) con corrección de confusión activa
    final cleanHrv  = _hrvFilter.filter(rawHrv * hb + activeConfHrv);
    final cleanTemp = _tempFilter.filter(rawTemp + activeConfTemp);
    final cleanResp = _respFilter.filter(rawResp + activeConfResp);
    final cleanGsr  = _gsrFilter.filter(rawGsr + activeConfGsr);

    // 2. DHSI bruto ponderado según perfil
    final rawDhsi = _calculator.calculateBasal(
      hrv: cleanHrv, temp: cleanTemp, resp: cleanResp, gsr: cleanGsr,
      profile: _profileManager.currentProfile,
    );

    // 3. Línea base personal (aprendizaje)
    if (!_baselineLocked) {
      _baselineSamples.add(rawDhsi);
      if (_baselineSamples.length >= baselineLen) {
        _baselineVal    = _baselineSamples.reduce((a, b) => a + b) / baselineLen;
        _baselineLocked = true;
      }
    }
    final currentDhsi = _baselineLocked
        ? _calculator.normalize(rawDhsi, _baselineVal)
        : rawDhsi;

    // 4. Análisis de tendencia (velocidad + jerk de 3er orden)
    final thr = _profileManager.currentThresholds;
    final trend = _detector.analyse(
      currentDhsi,
      stableThr: thr.stable, armThr: thr.arm, critThr: thr.critical,
    );

    // 5. Confidence score
    final covSum = _hrvFilter.covariance + _tempFilter.covariance
                 + _respFilter.covariance + _gsrFilter.covariance;
    final kConf = (1.0 - covSum / 0.4).clamp(0.0, 1.0);
    final cConf = (_cycle / 60.0).clamp(0.0, 1.0);
    final bConf = _baselineLocked ? 1.0 : _baselineSamples.length / baselineLen;
    _confidence = (kConf * 0.5 + cConf * 0.25 + bConf * 0.25).clamp(0.0, 1.0);

    return {
      'dhsi':             currentDhsi,
      'velocity':         trend.velocity,
      'jerk':             trend.jerk,
      'status_key':       trend.statusKey,
      'trend_key':        trend.trendKey,
      'confidence_level': _confidence,
      'timestamp':        DateTime.now().millisecondsSinceEpoch,
      'cycle':            _cycle,
      'baseline_locked':  _baselineLocked,
      'baseline_value':   _baselineVal,
      'channels': {
        'hrv':  cleanHrv,
        'temp': cleanTemp,
        'resp': cleanResp,
        'gsr':  cleanGsr,
      },
    };
  }
}
