// ============================================================
// BIOSENSE — User Profile Model
// Los perfiles modifican SOLO umbrales y pesos.
// El algoritmo DHSI nunca cambia.
// ============================================================

enum UserProfile {
  nino,
  adolescente,
  adulto,
  embarazo,
  adultoMayor,
  deportista,
  cardiaco,
  diabetes,
  hipertension,
  respiratorio,
}

class ProfileThresholds {
  final double stable;
  final double arm;
  final double critical;
  final double hrvBaseline; // Factor de ajuste de HRV basal

  const ProfileThresholds({
    required this.stable,
    required this.arm,
    required this.critical,
    required this.hrvBaseline,
  });
}

class ProfileConfig {
  static const Map<UserProfile, ProfileThresholds> thresholds = {
    UserProfile.nino:         ProfileThresholds(stable: 0.92, arm: 0.80, critical: 0.65, hrvBaseline: 0.95),
    UserProfile.adolescente:  ProfileThresholds(stable: 0.91, arm: 0.78, critical: 0.63, hrvBaseline: 1.00),
    UserProfile.adulto:       ProfileThresholds(stable: 0.90, arm: 0.76, critical: 0.62, hrvBaseline: 1.00),
    UserProfile.embarazo:     ProfileThresholds(stable: 0.93, arm: 0.82, critical: 0.68, hrvBaseline: 0.98),
    UserProfile.adultoMayor:  ProfileThresholds(stable: 0.88, arm: 0.74, critical: 0.60, hrvBaseline: 0.85),
    UserProfile.deportista:   ProfileThresholds(stable: 0.88, arm: 0.72, critical: 0.58, hrvBaseline: 1.15),
    UserProfile.cardiaco:     ProfileThresholds(stable: 0.93, arm: 0.82, critical: 0.68, hrvBaseline: 0.90),
    UserProfile.diabetes:     ProfileThresholds(stable: 0.91, arm: 0.79, critical: 0.65, hrvBaseline: 0.95),
    UserProfile.hipertension: ProfileThresholds(stable: 0.92, arm: 0.80, critical: 0.66, hrvBaseline: 0.95),
    UserProfile.respiratorio: ProfileThresholds(stable: 0.91, arm: 0.78, critical: 0.64, hrvBaseline: 0.95),
  };

  static ProfileThresholds forProfile(UserProfile p) => thresholds[p]!;

  /// Pesos de los canales — el perfil cardíaco da más peso al HRV
  static List<double> weightsFor(UserProfile p) {
    if (p == UserProfile.cardiaco) {
      return [0.50, 0.20, 0.15, 0.15]; // hrv, temp, resp, gsr
    }
    if (p == UserProfile.respiratorio) {
      return [0.25, 0.20, 0.40, 0.15]; // más peso a respiración
    }
    if (p == UserProfile.diabetes) {
      return [0.30, 0.30, 0.20, 0.20]; // más peso a temperatura
    }
    return [0.35, 0.25, 0.20, 0.20]; // ponderación estándar universal
  }
}
