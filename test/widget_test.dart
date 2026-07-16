// ============================================================
// BIOSENSE — Widget Test Básico
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:phse_altea_garay/core/kalman_filter.dart';
import 'package:phse_altea_garay/core/dhsi_calculator.dart';
import 'package:phse_altea_garay/core/trend_detector.dart';
import 'package:phse_altea_garay/models/user_profile.dart';

void main() {

  group('KalmanFilter', () {
    test('converge hacia el valor medido', () {
      final kalman = KalmanFilter(initialState: 1.0);
      double result = 0.0;
      for (int i = 0; i < 50; i++) {
        result = kalman.filter(0.8);
      }
      expect(result, closeTo(0.8, 0.05));
    });

    test('estado inicial correcto', () {
      final kalman = KalmanFilter(initialState: 0.95);
      expect(kalman.currentState, closeTo(0.95, 0.001));
    });
  });

  group('DHSICalculator', () {
    test('calcula DHSI basal con ponderación estándar', () {
      final calc = DHSICalculator();
      final result = calc.calculateBasal(
        hrv: 1.0, temp: 1.0, resp: 1.0, gsr: 1.0,
        profile: UserProfile.adulto,
      );
      expect(result, closeTo(1.0, 0.01));
    });

    test('DHSI baja cuando HRV cae', () {
      final calc = DHSICalculator();
      final result = calc.calculateBasal(
        hrv: 0.7, temp: 1.0, resp: 1.0, gsr: 1.0,
        profile: UserProfile.adulto,
      );
      expect(result, lessThan(1.0));
    });

    test('normalización contra baseline', () {
      final calc = DHSICalculator();
      final result = calc.normalize(0.9, 1.0);
      expect(result, closeTo(0.9, 0.01));
    });
  });

  group('TrendDetector', () {
    test('detecta estado stable cuando DHSI es alto', () {
      final detector = TrendDetector(initialDhsi: 1.0);
      final result = detector.analyse(0.95,
        stableThr: 0.90, armThr: 0.76, critThr: 0.62);
      expect(result.statusKey, equals('stable'));
    });

    test('detecta fatigue cuando DHSI cae', () {
      final detector = TrendDetector(initialDhsi: 1.0);
      // Bajar gradualmente
      for (int i = 0; i < 5; i++) {
        detector.analyse(0.88,
          stableThr: 0.90, armThr: 0.76, critThr: 0.62);
      }
      final result = detector.analyse(0.87,
        stableThr: 0.90, armThr: 0.76, critThr: 0.62);
      expect(result.statusKey, equals('fatigue'));
    });

    test('jerk de tercer orden no es NaN', () {
      final detector = TrendDetector(initialDhsi: 1.0);
      TrendResult? last;
      for (int i = 0; i < 5; i++) {
        last = detector.analyse(0.9 - i * 0.01,
          stableThr: 0.90, armThr: 0.76, critThr: 0.62);
      }
      expect(last!.jerk.isNaN, isFalse);
      expect(last.jerk.isInfinite, isFalse);
    });
  });

  group('ProfileConfig', () {
    test('todos los perfiles tienen umbrales definidos', () {
      for (final profile in UserProfile.values) {
        final thr = ProfileConfig.forProfile(profile);
        expect(thr.stable, greaterThan(0.0));
        expect(thr.arm, greaterThan(0.0));
        expect(thr.critical, greaterThan(0.0));
        expect(thr.stable, greaterThan(thr.arm));
        expect(thr.arm, greaterThan(thr.critical));
      }
    });

    test('pesos suman 1.0 para todos los perfiles', () {
      for (final profile in UserProfile.values) {
        final weights = ProfileConfig.weightsFor(profile);
        final sum = weights.reduce((a, b) => a + b);
        expect(sum, closeTo(1.0, 0.001));
      }
    });
  });
}
