// ============================================================
// BIOSENSE — DHSI Calculator
// Solo fórmulas. Solo ponderaciones. Sin estado, sin Flutter.
// ============================================================

import '../models/user_profile.dart';

class DHSICalculator {

  /// Calcula el DHSI bruto ponderado según el perfil.
  /// hrv ya viene normalizado donde 1.0 = basal, <1.0 = reducido.
  /// temp, resp, gsr vienen donde 1.0 = basal, >1.0 = elevado.
  double calculateBasal({
    required double hrv,
    required double temp,
    required double resp,
    required double gsr,
    required UserProfile profile,
  }) {
    final weights = ProfileConfig.weightsFor(profile);

    // Normalizar temp/resp/gsr: valores elevados son "peores"
    // así que invertimos para que 1.0 siga siendo "óptimo"
    final tempNorm = temp > 1.0 ? 2.0 - temp : temp;
    final respNorm = resp > 1.0 ? 2.0 - resp : resp;
    final gsrNorm  = gsr  > 1.0 ? 2.0 - gsr  : gsr;

    final raw = hrv      * weights[0]
              + tempNorm  * weights[1]
              + respNorm  * weights[2]
              + gsrNorm   * weights[3];

    return raw.clamp(0.0, 1.0);
  }

  /// Normaliza el DHSI bruto contra la línea base personal
  double normalize(double raw, double baseline) {
    if (baseline <= 0) return raw;
    return (raw / baseline).clamp(0.0, 1.0);
  }
}
