// ============================================================
// BIOSENSE — Trend Detector
// Velocidad, jerk (3er orden real), y clasificación de tendencia
// Análogo a trend_velocity + jerk_accel de Phoenix-UCC v15.0
// ============================================================

class TrendResult {
  final double velocity;
  final double jerk;
  final String statusKey;
  final String trendKey;

  const TrendResult({
    required this.velocity,
    required this.jerk,
    required this.statusKey,
    required this.trendKey,
  });
}

class TrendDetector {
  double _previousDHSI;
  final List<double> _velocityHistory = [];

  TrendDetector({double initialDhsi = 1.0}) : _previousDHSI = initialDhsi;

  TrendResult analyse(double currentDHSI, {
    required double stableThr,
    required double armThr,
    required double critThr,
  }) {
    // Velocidad instantánea
    final double velocity = currentDHSI - _previousDHSI;
    _previousDHSI = currentDHSI;

    // Historial de velocidad para jerk de 3er orden real
    _velocityHistory.add(velocity);
    if (_velocityHistory.length > 3) _velocityHistory.removeAt(0);

    // Jerk = aceleración de la aceleración (3er orden real)
    // No solo "velocity actual - velocity anterior" sino la tendencia
    // completa de los últimos 3 valores de velocidad
    double jerk = 0.0;
    if (_velocityHistory.length >= 3) {
      // Diferencia de segundo orden: (v[2]-v[1]) - (v[1]-v[0])
      final d1 = _velocityHistory[2] - _velocityHistory[1];
      final d0 = _velocityHistory[1] - _velocityHistory[0];
      jerk = d1 - d0;
    } else if (_velocityHistory.length == 2) {
      jerk = _velocityHistory[1] - _velocityHistory[0];
    }

    // Clasificación de estado (statusKey usado por toda la app)
    String statusKey;
    if (currentDHSI < critThr) {
      statusKey = 'danger';
    } else if (currentDHSI < armThr) {
      statusKey = 'alert';
    } else if (currentDHSI < stableThr) {
      statusKey = 'fatigue';
    } else if (velocity < -0.0025 && jerk < -0.0008) {
      statusKey = 'fatigue';
    } else {
      statusKey = 'stable';
    }

    // Clasificación de tendencia (hacia dónde va, no solo dónde está)
    String trendKey;
    if (currentDHSI < armThr) {
      trendKey = 'critical';
    } else if (velocity < -0.004) {
      trendKey = 'falling';
    } else if (velocity < -0.0015) {
      trendKey = 'rising_concern';
    } else if (velocity < -0.0005) {
      trendKey = 'rising_mild';
    } else {
      trendKey = 'stable';
    }

    return TrendResult(
      velocity: velocity,
      jerk: jerk,
      statusKey: statusKey,
      trendKey: trendKey,
    );
  }

  void reset(double initialDhsi) {
    _previousDHSI = initialDhsi;
    _velocityHistory.clear();
  }
}
