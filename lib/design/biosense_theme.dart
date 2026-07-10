// ============================================================
// BIOSENSE OS — Clinical Design System v3.0
// Inter font, glassmorphism, deep greens, critical mode
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';

// ============================================================
// COLOR SYSTEM
// ============================================================
class BioSenseColor {
  // Fondos
  static const Color bgPrimary   = Color(0xFFEBF7F3);
  static const Color surface     = Color(0xFFF0FAF7);
  static const Color surfaceAlt  = Color(0xFFE4F5F0);

  // Identidad
  static const Color primary      = Color(0xFF0A3D62);
  static const Color primaryLight = Color(0xFF1A5276);
  static const Color accent       = Color(0xFF10AC84);
  static const Color accentDark   = Color(0xFF0E8C6C);
  static const Color accentBright = Color(0xFF2ECC71);

  // Estados clínicos
  static const Color stable   = Color(0xFF10AC84);
  static const Color warning  = Color(0xFFF39C12);
  static const Color alert    = Color(0xFFE74C3C);
  static const Color critical = Color(0xFF8E44AD);

  // Modo crítico
  static const Color criticalBg     = Color(0xFF1A0000);
  static const Color criticalCard   = Color(0xFF2D0000);
  static const Color criticalBorder = Color(0xFFE74C3C);

  // Texto
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textBody    = Color(0xFF4A5568);
  static const Color textMuted   = Color(0xFF8896A5);
  static const Color textHint    = Color(0xFFBDC9D7);

  // UI
  static const Color border      = Color(0xFFE2EAF2);
  static const Color borderFocus = Color(0xFF0A3D62);
  static const Color divider     = Color(0xFFF0F5FA);

  static Color forStatus(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return warning;
      case 'alert':    return alert;
      case 'danger':   return alert;
      case 'critical': return critical;
      default:         return stable;
    }
  }

  static Color bgForStatus(String statusKey) =>
      forStatus(statusKey).withOpacity(0.06);

  static bool isCritical(String statusKey) =>
      statusKey == 'danger' || statusKey == 'critical';
}

// ============================================================
// MOTION
// ============================================================
class BioSenseMotion {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 300);
  static const Duration slow    = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 800);
  static const Duration countUp = Duration(milliseconds: 1200);

  static const Curve enter   = Curves.easeOutCubic;
  static const Curve exit    = Curves.easeInCubic;
  static const Curve flow    = Curves.easeInOutCubic;
  static const Curve precise = Curves.fastOutSlowIn;
}

// ============================================================
// SPACING
// ============================================================
class BioSenseSpacing {
  static const double xs   =  4.0;
  static const double sm   =  8.0;
  static const double md   = 14.0;
  static const double lg   = 20.0;
  static const double xl   = 24.0;
  static const double xxl  = 32.0;
  static const double xxxl = 48.0;
}

// ============================================================
// RADIUS
// ============================================================
class BioSenseRadius {
  static const double sm   =  8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double full = 999.0;
}

// ============================================================
// SHADOWS
// ============================================================
class BioSenseShadow {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF0A3D62).withOpacity(0.07),
      blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(
      color: const Color(0xFF0A3D62).withOpacity(0.03),
      blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> forStatus(String key) => [
    BoxShadow(
      color: BioSenseColor.forStatus(key).withOpacity(0.12),
      blurRadius: 20, offset: const Offset(0, 6)),
    ...card,
  ];

  static List<BoxShadow> get critical => [
    const BoxShadow(
      color: Color(0x33E74C3C),
      blurRadius: 24, offset: Offset(0, 8), spreadRadius: 2),
  ];
}

// ============================================================
// TYPOGRAPHY — Inter font
// ============================================================
class BioSenseText {
  static const String _font = 'Inter';

  static const TextStyle metricXL = TextStyle(
    fontFamily: _font, fontSize: 64, fontWeight: FontWeight.w200,
    letterSpacing: -2.0, height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()]);

  static const TextStyle metricL = TextStyle(
    fontFamily: _font, fontSize: 40, fontWeight: FontWeight.w300,
    letterSpacing: -1.5, height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()]);

  static const TextStyle metricM = TextStyle(
    fontFamily: _font, fontSize: 24, fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()]);

  static const TextStyle metricS = TextStyle(
    fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()]);

  static const TextStyle title = TextStyle(
    fontFamily: _font, fontSize: 20, fontWeight: FontWeight.w700,
    letterSpacing: -0.3, color: BioSenseColor.textPrimary);

  static const TextStyle subtitle = TextStyle(
    fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: 0.0, color: BioSenseColor.textBody);

  static const TextStyle body = TextStyle(
    fontFamily: _font, fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.55, color: BioSenseColor.textBody);

  static const TextStyle caption = TextStyle(
    fontFamily: _font, fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.4, color: BioSenseColor.textMuted);

  static const TextStyle label = TextStyle(
    fontFamily: _font, fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 1.2, color: BioSenseColor.textMuted);

  static const TextStyle institutional = TextStyle(
    fontFamily: _font, fontSize: 10, fontWeight: FontWeight.w400,
    letterSpacing: 0.5, color: BioSenseColor.textHint);
}

// ============================================================
// THEME DATA GLOBAL
// ============================================================
class BioSenseTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: BioSenseColor.primary,
      brightness: Brightness.light,
      surface: BioSenseColor.surface),
    scaffoldBackgroundColor: BioSenseColor.bgPrimary,
    appBarTheme: const AppBarTheme(
      backgroundColor: BioSenseColor.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700,
        color: BioSenseColor.textPrimary, letterSpacing: -0.2),
      iconTheme: IconThemeData(color: BioSenseColor.primary)),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BioSenseColor.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md)),
        textStyle: const TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w700,
          fontSize: 14, letterSpacing: 0.2),
        padding: const EdgeInsets.symmetric(
          horizontal: BioSenseSpacing.xl,
          vertical: BioSenseSpacing.md))),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BioSenseColor.primary,
        side: const BorderSide(color: BioSenseColor.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md)))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BioSenseColor.surface,
      indicatorColor: BioSenseColor.primary.withOpacity(0.10),
      elevation: 0, height: 62,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return BioSenseText.label.copyWith(
          color: active ? BioSenseColor.primary : BioSenseColor.textMuted,
          letterSpacing: 0.5, fontSize: 9);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active ? BioSenseColor.primary : BioSenseColor.textMuted,
          size: 22);
      })),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: BioSenseColor.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BioSenseSpacing.lg, vertical: BioSenseSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(color: BioSenseColor.border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(color: BioSenseColor.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(
          color: BioSenseColor.borderFocus, width: 1.5))),
    dividerTheme: const DividerThemeData(
      color: BioSenseColor.divider, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
          ? BioSenseColor.primary : BioSenseColor.textHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
          ? BioSenseColor.primary.withOpacity(0.25)
          : BioSenseColor.border)));

  // ── Tarjeta clínica con glassmorphism opcional
  static Widget clinicalCard({
    required Widget child,
    String? statusKey,
    EdgeInsets? padding,
    Color? color,
    double? radius,
    bool animate = true,
    bool glass = false,
  }) {
    final isCrit = statusKey != null && BioSenseColor.isCritical(statusKey);
    final borderColor = isCrit
        ? BioSenseColor.criticalBorder.withOpacity(0.5)
        : statusKey != null
          ? BioSenseColor.forStatus(statusKey).withOpacity(0.20)
          : BioSenseColor.border;
    final bgColor = isCrit
        ? BioSenseColor.criticalCard
        : color ?? BioSenseColor.surface;
    final shadows = isCrit
        ? BioSenseShadow.critical
        : statusKey != null
          ? BioSenseShadow.forStatus(statusKey)
          : BioSenseShadow.card;
    final r = radius ?? BioSenseRadius.md;

    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(BioSenseSpacing.lg),
        child: child));

    if (glass) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(BioSenseSpacing.lg),
            child: child)));
    }

    final decoration = BoxDecoration(
      color: glass
        ? bgColor.withOpacity(0.85)
        : bgColor,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: shadows);

    if (animate) {
      return AnimatedContainer(
        duration: BioSenseMotion.slow,
        curve: BioSenseMotion.flow,
        decoration: decoration,
        child: inner);
    }
    return Container(decoration: decoration, child: inner);
  }

  // ── Firma institucional
  static Widget institutionalFooter({bool dark = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: BioSenseSpacing.lg),
    child: Text(
      'BioSense v1.0  |  ALTEA-GARAY HTS  |  USPTO #63/914,860',
      textAlign: TextAlign.center,
      style: BioSenseText.institutional.copyWith(
        color: dark ? Colors.white24 : BioSenseColor.textHint)));

  // ── Sparkline
  static Widget sparkline({
    required List<double> data,
    required Color color,
    double height = 36,
    bool gradient = true,
  }) {
    if (data.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SparklinePainter(
          data: data, color: color, gradient: gradient)));
  }

  // ── Anillo de estabilidad
  static Widget stabilityRing({
    required double value,
    required String statusKey,
    double size = 44,
  }) {
    final color = BioSenseColor.forStatus(statusKey);
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _StabilityRingPainter(value: value, color: color)));
  }

  // ── Barra de progreso con gradiente verde
  static Widget gradientBar({
    required double value,
    required Color color,
    double height = 4,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(BioSenseRadius.full),
    child: Stack(children: [
      Container(height: height, color: BioSenseColor.border),
      FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: BioSenseMotion.slow,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                BioSenseColor.accentBright,
                color,
              ])))),
    ]));
}

// ── Sparkline painter con gradiente
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool gradient;
  _SparklinePainter({required this.data, required this.color,
    this.gradient = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height -
          ((data[i] - min) / range) * size.height * 0.82 -
          size.height * 0.09;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    if (gradient) {
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)])
            .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.data != data;
}

// ── Stability ring painter
class _StabilityRingPainter extends CustomPainter {
  final double value;
  final Color color;
  _StabilityRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;

    canvas.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      value * 6.2832,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_StabilityRingPainter old) =>
      old.value != value || old.color != color;
}
