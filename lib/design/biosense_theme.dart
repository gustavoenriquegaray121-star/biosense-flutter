// ============================================================
// BIOSENSE OS — Clinical Design System v2.0
// Paleta Professional Premium — "Medical Grade"
// Autor: Gustavo Enrique Garay | ALTEA-GARAY HTS
// USPTO Provisional #63/914,860
// ============================================================

import 'package:flutter/material.dart';

// ============================================================
// COLOR — Paleta Clinical Premium
// ============================================================
class BioSenseColor {
  // Fondos
  static const Color bgPrimary   = Color(0xFFF8FBFE); // Blanco azulado limpio
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceAlt  = Color(0xFFF0F4F8); // Cards alternadas

  // Identidad
  static const Color primary     = Color(0xFF0A3D62); // Azul marino profundo
  static const Color primaryLight= Color(0xFF1A5276); // Azul marino suave
  static const Color accent      = Color(0xFF10AC84); // Verde salud suave

  // Estados fisiológicos — graduales, no chillones
  static const Color stable      = Color(0xFF10AC84); // Verde salud
  static const Color warning     = Color(0xFFF39C12); // Naranja suave
  static const Color alert       = Color(0xFFE74C3C); // Rojo serio
  static const Color critical    = Color(0xFF8E44AD); // Morado contenido

  // Texto
  static const Color textPrimary = Color(0xFF2C3E50); // Gris oscuro
  static const Color textBody    = Color(0xFF566573); // Gris medio
  static const Color textMuted   = Color(0xFF95A5A6); // Gris claro
  static const Color textHint    = Color(0xFFBDC3C7);

  // UI
  static const Color border      = Color(0xFFE8EDF2);
  static const Color borderFocus = Color(0xFF0A3D62);
  static const Color divider     = Color(0xFFF0F4F8);

  // Mapeo directo desde statusKey del DHSIEngine
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
}

// ============================================================
// MOTION — Sistema oficial de animaciones
// ============================================================
class BioSenseMotion {
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast    = Duration(milliseconds: 150);
  static const Duration normal  = Duration(milliseconds: 300);
  static const Duration slow    = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 800);

  static const Curve enter   = Curves.easeOutCubic;
  static const Curve exit    = Curves.easeInCubic;
  static const Curve flow    = Curves.easeInOutCubic;
  static const Curve precise = Curves.fastOutSlowIn;
}

// ============================================================
// SPACING — Tokens de diseño
// ============================================================
class BioSenseSpacing {
  static const double xs   =  4.0;
  static const double sm   =  8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 28.0;
  static const double xxxl = 40.0;
}

// ============================================================
// RADIUS
// ============================================================
class BioSenseRadius {
  static const double sm   =  8.0;
  static const double md   = 12.0; // Cards — más contenido, menos redondo
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double full = 999.0;
}

// ============================================================
// SHADOWS — Neumorfismo sutil
// ============================================================
class BioSenseShadow {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF0A3D62).withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0A3D62).withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> forStatus(String statusKey) => [
    BoxShadow(
      color: BioSenseColor.forStatus(statusKey).withOpacity(0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    ...card,
  ];
}

// ============================================================
// TYPOGRAPHY — Escala clínica premium
// ============================================================
class BioSenseText {
  // Métricas numéricas — tabular figures para alineación
  static const TextStyle metricXL = TextStyle(
    fontSize: 64, fontWeight: FontWeight.w300,
    letterSpacing: -2.0, height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle metricL = TextStyle(
    fontSize: 40, fontWeight: FontWeight.w300,
    letterSpacing: -1.5, height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle metricM = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w500,
    letterSpacing: -0.5, height: 1.1,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle metricS = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Editorial
  static const TextStyle title = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    letterSpacing: -0.2, color: BioSenseColor.textPrimary,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    letterSpacing: 0.1, color: BioSenseColor.textBody,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.55, color: BioSenseColor.textBody,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.4, color: BioSenseColor.textMuted,
  );
  static const TextStyle label = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w700,
    letterSpacing: 1.2, color: BioSenseColor.textMuted,
  );
  // Firma institucional — pie de página
  static const TextStyle institutional = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w400,
    letterSpacing: 0.5, color: BioSenseColor.textHint,
    fontFamily: 'monospace',
  );
}

// ============================================================
// THEME DATA GLOBAL
// ============================================================
class BioSenseTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BioSenseColor.primary,
      brightness: Brightness.light,
      surface: BioSenseColor.surface,
    ),
    scaffoldBackgroundColor: BioSenseColor.bgPrimary,
    fontFamily: 'Inter',
    appBarTheme: AppBarTheme(
      backgroundColor: BioSenseColor.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: BioSenseColor.border,
      centerTitle: false,
      titleTextStyle: BioSenseText.title.copyWith(fontSize: 17),
      iconTheme: const IconThemeData(color: BioSenseColor.primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BioSenseColor.primary,
        foregroundColor: BioSenseColor.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md)),
        textStyle: BioSenseText.subtitle.copyWith(
          color: BioSenseColor.surface, letterSpacing: 0.2),
        padding: const EdgeInsets.symmetric(
          horizontal: BioSenseSpacing.xl, vertical: BioSenseSpacing.lg),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BioSenseColor.primary,
        side: const BorderSide(color: BioSenseColor.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BioSenseColor.surface,
      indicatorColor: BioSenseColor.primary.withOpacity(0.10),
      elevation: 0,
      height: 60,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return BioSenseText.label.copyWith(
          color: active ? BioSenseColor.primary : BioSenseColor.textMuted,
          letterSpacing: 0.5,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active ? BioSenseColor.primary : BioSenseColor.textMuted,
          size: 22,
        );
      }),
    ),
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
          color: BioSenseColor.borderFocus, width: 1.5)),
    ),
    dividerTheme: const DividerThemeData(
      color: BioSenseColor.divider, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
          ? BioSenseColor.primary : BioSenseColor.textHint),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
          ? BioSenseColor.primary.withOpacity(0.25)
          : BioSenseColor.border),
    ),
  );

  // ── Tarjeta clínica estandarizada
  static Widget clinicalCard({
    required Widget child,
    String? statusKey,
    EdgeInsets? padding,
    Color? color,
    double? radius,
    bool animate = true,
  }) {
    final borderColor = statusKey != null
        ? BioSenseColor.forStatus(statusKey).withOpacity(0.20)
        : BioSenseColor.border;
    final shadows = statusKey != null
        ? BioSenseShadow.forStatus(statusKey)
        : BioSenseShadow.card;

    final decoration = BoxDecoration(
      color: color ?? BioSenseColor.surface,
      borderRadius: BorderRadius.circular(radius ?? BioSenseRadius.md),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: shadows,
    );

    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? BioSenseRadius.md),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(BioSenseSpacing.lg),
        child: child,
      ),
    );

    if (animate) {
      return AnimatedContainer(
        duration: BioSenseMotion.slow,
        curve: BioSenseMotion.flow,
        decoration: decoration,
        child: inner,
      );
    }
    return Container(decoration: decoration, child: inner);
  }

  // ── Firma institucional (pie de cada pantalla)
  static Widget institutionalFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BioSenseSpacing.lg),
      child: Text(
        'BioSense v1.0  |  ALTEA-GARAY HTS  |  USPTO #63/914,860',
        textAlign: TextAlign.center,
        style: BioSenseText.institutional,
      ),
    );
  }

  // ── Sparkline widget para visualización en tiempo real
  static Widget sparkline({
    required List<double> data,
    required Color color,
    double height = 32,
  }) {
    if (data.length < 2) return SizedBox(height: height);
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SparklinePainter(data: data, color: color),
    );
  }

  // ── Anillo de estabilidad gradual
  static Widget stabilityRing({
    required double value, // 0.0 - 1.0
    required String statusKey,
    double size = 48,
  }) {
    final color = BioSenseColor.forStatus(statusKey);
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _StabilityRingPainter(value: value, color: color),
      ),
    );
  }
}

// ── Painter para sparklines en tiempo real
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - min) / range) * size.height * 0.85
                - size.height * 0.075;
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

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.data != data;
}

// ── Painter para anillos de estabilidad
class _StabilityRingPainter extends CustomPainter {
  final double value;
  final Color color;
  _StabilityRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;

    // Track
    canvas.drawCircle(center, radius, Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // Arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -π/2 (top)
      value * 6.2832,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StabilityRingPainter old) =>
      old.value != value || old.color != color;
}
