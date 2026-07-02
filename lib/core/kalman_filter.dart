// ============================================================
// BIOSENSE — Kalman Filter
// Matemática pura. Cero dependencias de Flutter.
// Reutilizable en Swift, FPGA, Raspberry Pi, lo que sea.
// Análogo al filtro usado en PredictiveCryoMonitor (Phoenix-UCC)
// ============================================================

class KalmanFilter {
  final double _q; // Ruido de proceso
  final double _r; // Ruido de medición
  double _x;       // Estado estimado
  double _p;       // Covarianza del error

  KalmanFilter({
    double q = 0.002,
    double r = 0.015,
    double initialState = 1.0,
  })  : _q = q,
        _r = r,
        _x = initialState,
        _p = 1.0;

  /// Filtra la señal cruda para eliminar ruido (movimiento, artefactos)
  double filter(double measurement) {
    _p = _p + _q;
    final double k = _p / (_p + _r);
    _x = _x + k * (measurement - _x);
    _p = (1.0 - k) * _p;
    return _x;
  }

  double get currentState => _x;
  double get covariance => _p;

  void reset(double initialState) {
    _x = initialState;
    _p = 1.0;
  }
}
