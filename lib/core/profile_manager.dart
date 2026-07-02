// ============================================================
// BIOSENSE — Profile Manager
// Gestiona el perfil activo y expone los umbrales correspondientes
// ============================================================

import '../models/user_profile.dart';

class ProfileManager {
  UserProfile _currentProfile = UserProfile.adulto;

  UserProfile get currentProfile => _currentProfile;

  ProfileThresholds get currentThresholds =>
      ProfileConfig.forProfile(_currentProfile);

  List<double> get currentWeights =>
      ProfileConfig.weightsFor(_currentProfile);

  void setProfile(UserProfile profile) {
    _currentProfile = profile;
  }

  double get hrvBaselineFactor => currentThresholds.hrvBaseline;
}
