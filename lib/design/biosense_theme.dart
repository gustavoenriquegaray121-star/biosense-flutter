// ============================================================
// BIOSENSE OS — Core Theme, Motion, Typography & Design Tokens
// Visual Identity v1.4
// Autor: Gustavo Enrique Garay | ALTEA-GARAY HTS
// USPTO Provisional Patent #63/914,860
// ============================================================

import 'package:flutter/material.dart';

// ============================================================
// MOTION — Sistema oficial de animaciones
// "La app respira, no parpadea."
// ============================================================
class BioSenseMotion {
  // Duraciones oficiales
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast    = Duration(milliseconds: 120); // Micro-feedback
  static const Duration normal  = Duration(milliseconds: 250); // Estándar UI
  static const Duration slow    = Duration(milliseconds: 450); // Transiciones críticas
  static const Duration slowest = Duration(milliseconds: 700); // Onboarding, drama

  // Curvas oficiales — personalidad del movimiento
  static const Curve enter   = Curves.easeOutCubic;   // Aparecer suave
  static const Curve exit    = Curves.easeInCubic;    // Desaparecer rápido
  static const Curve flow    = Curves.easeInOutCubic; // Cambios de estado DHSI
  static const Curve bounce  = Curves.elasticOut;     // Alertas, eventos ARM
  static const Curve precise = Curves.fastOutSlowIn;  // Datos numéricos
}

// ============================================================
// DESIGN TOKENS — Constantes exportables a cualquier plataforma
// Web / Android / iOS / Desktop / FPGA UI
// ============================================================
class BioSenseSpacing {
  static const double xs  =  4.0;
  static const double sm  =  8.0;
  static const double md  = 12.0; // cardSpacing
  static const double lg  = 16.0; // cardPadding
  static const double xl  = 20.0; // screenPadding
  static const double xxl = 28.0; // sectionSpacing
  static const double xxxl= 40.0; // hero sections
}

class BioSenseRadius {
  static const double sm   =  8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0; // cardRadius — valor primario
  static const double xl   = 32.0;
  static const double full = 999.0; // píldoras, badges
}

class BioSenseElevation {
  static const double flat    = 0.0; // Superficies base
  static const double level1  = 2.0; // Tarjetas flotantes
  static const double level2  = 4.0; // FAB, diálogos
  static const double level3  = 8.0; // Navegación, alertas críticas
}

// ============================================================
// COLOR — Paleta "Clinical-Tech"
// ============================================================
class BioSenseColor {
  // Fondos y superficies
  static const Color bgTitanium  = Color(0xFFF8FAFC);
  static const Color surface     = Color(0xFFFFFFFF);

  // Identidad
  static const Color primary     = Color(0xFF1E40AF); // Azul BioSense
  static const Color accent      = Color(0xFF3B82F6); // Indicadores

  // Estados fisiológicos — sincronizados con statusKey del DHSIEngine
  static const Color success     = Color(0xFF10B981); // ESTABLE
  static const Color warning     = Color(0xFFF59E0B); // VIGILANCIA / FATIGA
  static const Color danger      = Color(0xFFEF4444); // ALERTA
  static const Color critical    = Color(0xFF8B5CF6); // CRÍTICO

  // Texto
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textBody    = Color(0xFF334155);
  static const Color textMuted   = Color(0xFF64748B);
  static const Color textHint    = Color(0xFF94A3B8);

  // UI
  static const Color border      = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF3B82F6);

  // Mapeo directo desde statusKey del DHSIEngine
  static Color forStatus(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return warning;
      case 'alert':    return danger;
      case 'danger':   return danger;
      case 'critical': return critical;
      default:         return success;
    }
  }

  // Versión con opacidad para fondos de tarjetas
  static Color bgForStatus(String statusKey) =>
      forStatus(statusKey).withOpacity(0.08);
}

// ============================================================
// SHADOWS — Neumorfismo sutil de precisión quirúrgica
// ============================================================
class BioSenseShadow {
  // Sombra base: profundidad sin decoración
  static List<BoxShadow> get level1 => [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.015),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF1E293B).withOpacity(0.015),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // Sombra con tinte de estado fisiológico
  static List<BoxShadow> forStatus(String statusKey) => [
    BoxShadow(
      color: BioSenseColor.forStatus(statusKey).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    ...level1,
  ];

  // Sombra de alerta — llama la atención sin gritar
  static List<BoxShadow> get alert => [
    BoxShadow(
      color: BioSenseColor.danger.withOpacity(0.18),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 6),
    ),
    ...level1,
  ];
}

// ============================================================
// TYPOGRAPHY — Escala tipográfica clínica
// FontFeature.tabularFigures() para alinear números DHSI
// ============================================================
class BioSenseText {

  // ── DISPLAY — Números héroe ──────────────────────────────
  /// 92% en HomeScreen — el número más importante de la app
  static const TextStyle metricXL = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w900,
    letterSpacing: -2.0,
    height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// DHSI en cards clínicas
  static const TextStyle metricL = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.0,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// 38.2°C, 74 bpm en cards secundarias
  static const TextStyle metricM = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Valores en listas y tablas
  static const TextStyle metricS = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: BioSenseColor.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ── TEXTO — Jerarquía editorial ──────────────────────────
  /// "Mi Salud", "Historial" — títulos de pantalla
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: BioSenseColor.textPrimary,
  );

  /// "Últimas 24h", subtítulos de sección
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: BioSenseColor.textBody,
  );

  /// Texto descriptivo y mensajes cotidianos
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: BioSenseColor.textBody,
  );

  /// "Actualizado hace 2 min", notas de precisión
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: BioSenseColor.textMuted,
  );

  /// "HRV", "TEMP", "RESP" — etiquetas técnicas en mayúsculas
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: BioSenseColor.textMuted,
  );
}

// ============================================================
// THEME — ThemeData global de Flutter
// ============================================================
class BioSenseTheme {

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BioSenseColor.primary,
      brightness: Brightness.light,
      surface: BioSenseColor.surface,
    ),
    scaffoldBackgroundColor: BioSenseColor.bgTitanium,
    appBarTheme: AppBarTheme(
      backgroundColor: BioSenseColor.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: BioSenseText.title.copyWith(
        color: BioSenseColor.primary, fontSize: 18),
      iconTheme: const IconThemeData(color: BioSenseColor.primary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BioSenseColor.primary,
        foregroundColor: BioSenseColor.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.lg - 8)),
        textStyle: BioSenseText.subtitle.copyWith(
          color: BioSenseColor.surface, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BioSenseColor.primary,
        side: const BorderSide(color: BioSenseColor.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BioSenseColor.surface,
      indicatorColor: BioSenseColor.primary.withOpacity(0.12),
      elevation: 0,
      shadowColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
        BioSenseText.label.copyWith(letterSpacing: 0.5)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BioSenseColor.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BioSenseSpacing.lg,
        vertical: BioSenseSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(color: BioSenseColor.border)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(color: BioSenseColor.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        borderSide: const BorderSide(
          color: BioSenseColor.borderFocus, width: 2)),
    ),
    cardTheme: CardTheme(
      color: BioSenseColor.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BioSenseRadius.lg)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
          ? BioSenseColor.primary
          : BioSenseColor.textHint),
      trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected)
          ? BioSenseColor.primary.withOpacity(0.3)
          : BioSenseColor.border),
    ),
  );

  // ── Contenedor clínico estandarizado ──────────────────────
  /// Reemplaza Container() + BoxDecoration en toda la app.
  /// Automáticamente aplica la sombra y el color del estado DHSI.
  static Widget clinicalCard({
    required Widget child,
    String? statusKey,
    EdgeInsets? padding,
    Color? overrideColor,
    double? radius,
  }) {
    final shadows = statusKey != null
        ? BioSenseShadow.forStatus(statusKey)
        : BioSenseShadow.level1;
    final borderColor = statusKey != null
        ? BioSenseColor.forStatus(statusKey).withOpacity(0.25)
        : BioSenseColor.border;

    return AnimatedContainer(
      duration: BioSenseMotion.slow,
      curve: BioSenseMotion.flow,
      decoration: BoxDecoration(
        color: overrideColor ?? BioSenseColor.surface,
        borderRadius: BorderRadius.circular(radius ?? BioSenseRadius.lg),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? BioSenseRadius.lg),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(BioSenseSpacing.lg),
          child: child,
        ),
      ),
    );
  }

  // ── Estado de carga ────────────────────────────────────────
  static Widget shimmer({double width = double.infinity, double height = 60}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: BioSenseMotion.slowest,
      curve: BioSenseMotion.flow,
      builder: (_, v, __) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: BioSenseColor.border.withOpacity(v),
          borderRadius: BorderRadius.circular(BioSenseRadius.md)),
      ),
    );
  }
}
