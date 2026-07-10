// ============================================================
// BIOSENSE OS — Home Screen v3.0 Premium
// Count-up animations, glassmorphism, critical mode, Inter font
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/quick_log_bar.dart';
import '../design/biosense_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  double _readingMs = 0.0;
  int _sampleCount = 0;

  // Count-up animation
  late AnimationController _countUpCtrl;
  late Animation<double> _dhsiAnim;
  late Animation<double> _samplesAnim;

  // Fade-in for cards
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Pulse for status dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _readingMs = (_readingMs + 0.1) % 10.0;
        if (_initialized) _sampleCount = 1248 + (_now.millisecond ~/ 5);
      });
    });

    // Count-up: DHSI de 0 a valor real
    _countUpCtrl = AnimationController(
      vsync: this, duration: BioSenseMotion.countUp);
    _dhsiAnim = Tween<double>(begin: 0, end: 1.0)
        .animate(CurvedAnimation(parent: _countUpCtrl, curve: Curves.easeOut));
    _samplesAnim = Tween<double>(begin: 0, end: 1248)
        .animate(CurvedAnimation(parent: _countUpCtrl, curve: Curves.easeOut));

    // Fade cards
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Pulse dot
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start sequence
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _fadeCtrl.forward();
      _countUpCtrl.forward();
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _countUpCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';
    final isCrit = BioSenseColor.isCritical(state.statusKey);
    final color  = BioSenseColor.forStatus(state.statusKey);

    // Modo crítico: scaffold rojo oscuro
    final scaffoldColor = isCrit
        ? BioSenseColor.criticalBg
        : BioSenseColor.bgPrimary;

    final timeStr =
      '${_now.hour.toString().padLeft(2,'0')}:'
      '${_now.minute.toString().padLeft(2,'0')}:'
      '${_now.second.toString().padLeft(2,'0')}';

    return AnimatedContainer(
      duration: BioSenseMotion.slow,
      color: scaffoldColor,
      child: CustomPaint(
        painter: _HexGridPainter(critical: isCrit),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BioSenseSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      RichText(text: TextSpan(children: [
                        TextSpan(text: 'Bio',
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 26,
                            fontWeight: FontWeight.w300,
                            color: isCrit ? Colors.red[200] : BioSenseColor.primary,
                            letterSpacing: -0.5)),
                        TextSpan(text: 'Sense',
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isCrit ? Colors.red[400] : BioSenseColor.accent,
                            letterSpacing: -0.5)),
                      ])),
                      Text('Predictive Vital Monitoring System',
                        style: BioSenseText.caption.copyWith(
                          color: isCrit ? Colors.white38 : BioSenseColor.textMuted,
                          letterSpacing: 0.3)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      Text(timeStr, style: TextStyle(
                        fontFamily: 'Inter', fontSize: 22,
                        fontWeight: FontWeight.w200, letterSpacing: 2,
                        color: isCrit ? Colors.white70 : BioSenseColor.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(
                        isEs
                          ? 'Última lectura: ${_readingMs.toStringAsFixed(2)} s'
                          : 'Last reading: ${_readingMs.toStringAsFixed(2)} s',
                        style: BioSenseText.caption.copyWith(
                          color: isCrit ? Colors.white38 : null)),
                    ]),
                  ]),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── TARJETA ESTADO PRINCIPAL
                  BioSenseTheme.clinicalCard(
                    statusKey: state.statusKey,
                    glass: true,
                    padding: const EdgeInsets.all(BioSenseSpacing.xxl),
                    child: Column(children: [

                      // Punto pulsante animado
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 10, spreadRadius: 2)]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEs ? 'ESTADO DEL SISTEMA' : 'SYSTEM STATUS',
                          style: BioSenseText.label.copyWith(
                            color: isCrit ? Colors.white54 : null)),
                      ]),
                      const SizedBox(height: BioSenseSpacing.md),

                      // Estado clínico — tamaño grande, protagonista
                      AnimatedDefaultTextStyle(
                        duration: BioSenseMotion.slow,
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 32,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          color: color),
                        child: Text(_statusLabel(state.statusKey, isEs))),
                      const SizedBox(height: BioSenseSpacing.sm),
                      Text(
                        _statusDesc(state.statusKey, isEs),
                        textAlign: TextAlign.center,
                        style: BioSenseText.body.copyWith(
                          color: isCrit ? Colors.white60 : null)),
                      const SizedBox(height: BioSenseSpacing.xxl),

                      // Índice — count-up de 0 a valor
                      Text(
                        isEs ? 'ÍNDICE HOMEOSTÁTICO' : 'HOMEOSTATIC INDEX',
                        style: BioSenseText.label.copyWith(
                          color: isCrit ? Colors.white38 : null)),
                      const SizedBox(height: BioSenseSpacing.sm),

                      AnimatedBuilder(
                        animation: _dhsiAnim,
                        builder: (_, __) {
                          final displayVal = (_dhsiAnim.value * state.dhsiPercentage).round();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                            Text('$displayVal',
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 72,
                                fontWeight: FontWeight.w200,
                                letterSpacing: -3, color: color,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text('%',
                                style: BioSenseText.subtitle.copyWith(
                                  color: BioSenseColor.textMuted,
                                  fontSize: 20))),
                          ]);
                        },
                      ),
                      const SizedBox(height: BioSenseSpacing.md),

                      // Barra con gradiente verde
                      BioSenseTheme.gradientBar(
                        value: state.dhsi.clamp(0.0, 1.0), color: color),
                      const SizedBox(height: BioSenseSpacing.sm),

                      // Health Confidence — secundario, más pequeño
                      Text(
                        'Health Confidence: ${(state.confidenceLevel*100).toStringAsFixed(1)}%',
                        style: BioSenseText.caption.copyWith(
                          color: BioSenseColor.accent)),

                      if (!app.baselineLocked) ...[
                        const SizedBox(height: BioSenseSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BioSenseSpacing.md,
                            vertical: BioSenseSpacing.sm),
                          decoration: BoxDecoration(
                            color: BioSenseColor.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(BioSenseRadius.sm)),
                          child: Text(
                            isEs
                              ? 'Aprendiendo tu línea base fisiológica...\n(${app.baselineSamples}/30 ciclos completados)'
                              : 'Learning your physiological baseline...\n(${app.baselineSamples}/30 cycles completed)',
                            style: BioSenseText.caption,
                            textAlign: TextAlign.center)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: BioSenseSpacing.md),

                  // ── ESTADO VIVO — tarjeta pequeña, jerarquía inferior
                  BioSenseTheme.clinicalCard(
                    animate: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BioSenseSpacing.lg,
                      vertical: BioSenseSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          isEs
                            ? 'Analizando tendencias fisiológicas...'
                            : 'Analyzing physiological trends...',
                          style: BioSenseText.caption.copyWith(
                            color: BioSenseColor.accent)),
                        Text(
                          isEs
                            ? 'PHSE activo  ·  Modelo actualizado'
                            : 'PHSE active  ·  Model updated',
                          style: BioSenseText.label.copyWith(
                            color: BioSenseColor.primary)),
                      ]),
                      AnimatedBuilder(
                        animation: _samplesAnim,
                        builder: (_, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                          Text(
                            _initialized
                              ? '$_sampleCount'
                              : '${_samplesAnim.value.round()}',
                            style: BioSenseText.metricS.copyWith(
                              color: BioSenseColor.primary)),
                          Text(
                            isEs ? 'muestras' : 'samples',
                            style: BioSenseText.caption),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── BITÁCORA
                  Text(
                    isEs ? 'REGISTRO DE FACTORES' : 'FACTOR LOG',
                    style: BioSenseText.label),
                  const SizedBox(height: BioSenseSpacing.md),
                  QuickLogBar(
                    eventLog: app.eventLog,
                    onEventAdded: () => setState(() {})),
                  const SizedBox(height: BioSenseSpacing.xl),

                  // ── CTA
                  SizedBox(height: 52,
                    child: ElevatedButton(
                      onPressed: () => _showHowIFeel(context, app),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCrit
                          ? BioSenseColor.alert
                          : BioSenseColor.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BioSenseRadius.md))),
                      child: Text(
                        isEs
                          ? 'Registrar Estado Subjetivo'
                          : 'Log Subjective Status',
                        style: BioSenseText.subtitle.copyWith(
                          color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: BioSenseSpacing.xxl),
                  BioSenseTheme.institutionalFooter(dark: isCrit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String key, bool isEs) {
    switch (key) {
      case 'fatigue':  return isEs ? 'VIGILANCIA' : 'WATCH';
      case 'alert':    return isEs ? 'PRE-ALERTA' : 'PRE-ALERT';
      case 'danger':   return isEs ? 'ALERTA' : 'ALERT';
      case 'critical': return isEs ? 'CRÍTICO' : 'CRITICAL';
      default:         return isEs ? 'ESTABLE' : 'STABLE';
    }
  }

  String _statusDesc(String key, bool isEs) {
    if (isEs) {
      switch (key) {
        case 'fatigue':  return 'Variación preventiva detectada. Ajustar actividad.';
        case 'alert':    return 'Desviación predictiva en desarrollo.';
        case 'danger':   return 'Intervención preventiva recomendada.';
        case 'critical': return 'Alerta crítica. Enlace con especialista requerido.';
        default:         return 'Sin desviaciones predictivas detectadas.';
      }
    } else {
      switch (key) {
        case 'fatigue':  return 'Preventive variation detected. Adjust activity.';
        case 'alert':    return 'Predictive deviation in development.';
        case 'danger':   return 'Preventive intervention recommended.';
        case 'critical': return 'Critical alert. Specialist contact required.';
        default:         return 'No predictive deviations detected.';
      }
    }
  }

  void _showHowIFeel(BuildContext context, AppStateProvider app) {
    final isEs = app.language.name == 'es';
    showModalBottomSheet(
      context: context,
      backgroundColor: BioSenseColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BioSenseRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(BioSenseSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 3,
            decoration: BoxDecoration(
              color: BioSenseColor.border,
              borderRadius: BorderRadius.circular(BioSenseRadius.full))),
          const SizedBox(height: BioSenseSpacing.lg),
          Text(
            isEs ? 'Estado Subjetivo Actual' : 'Current Subjective Status',
            style: BioSenseText.title),
          const SizedBox(height: 4),
          Text(
            isEs
              ? 'Su respuesta calibra el modelo adaptativo.'
              : 'Your response calibrates the adaptive model.',
            style: BioSenseText.caption, textAlign: TextAlign.center),
          const SizedBox(height: BioSenseSpacing.xl),
          ...{
            isEs ? 'Estado fisiológico óptimo'   : 'Optimal physiological state': 0.0,
            isEs ? 'Parámetros dentro de rango'  : 'Within parameters': 0.05,
            isEs ? 'Fatiga leve detectada'        : 'Mild fatigue detected': 0.10,
            isEs ? 'Fatiga moderada'              : 'Moderate fatigue': 0.15,
            isEs ? 'Malestar significativo'       : 'Significant discomfort': 0.20,
          }.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: BioSenseSpacing.sm),
            child: SizedBox(width: double.infinity, height: 44,
              child: OutlinedButton(
                onPressed: () {
                  app.setMockPerturbation(e.value);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: BioSenseColor.primary,
                  side: const BorderSide(color: BioSenseColor.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BioSenseRadius.sm))),
                child: Text(e.key,
                  style: BioSenseText.body.copyWith(
                    color: BioSenseColor.primary)),
              ),
            ),
          )),
          const SizedBox(height: BioSenseSpacing.md),
        ]),
      ),
    );
  }
}

// Fondo hexagonal premium
class _HexGridPainter extends CustomPainter {
  final bool critical;
  const _HexGridPainter({this.critical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = critical
        ? const Color(0xFFE74C3C).withOpacity(0.04)
        : const Color(0xFF0A3D62).withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const r = 22.0;
    const hh = r * 1.732;
    int col = 0;
    for (double x = 0; x < size.width + r * 2; x += r * 1.5) {
      final offsetY = col.isOdd ? hh / 2 : 0.0;
      for (double y = -hh + offsetY; y < size.height + hh; y += hh) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60 - 30) * 3.14159265 / 180;
          final px = x + r * _c(angle);
          final py = y + r * _s(angle);
          if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      col++;
    }
  }

  double _c(double a) {
    final t = a - (a / (2*3.14159265)).truncate() * 2*3.14159265;
    return 1 - t*t/2 + t*t*t*t/24 - t*t*t*t*t*t/720;
  }
  double _s(double a) => _c(a - 1.5707963);

  @override
  bool shouldRepaint(_HexGridPainter old) => old.critical != critical;
}
