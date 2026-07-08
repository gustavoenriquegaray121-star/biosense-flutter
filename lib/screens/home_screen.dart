// ============================================================
// BIOSENSE OS — Home Screen v2.0
// Modo Usuario Premium — Sin emojis decorativos
// Identidad clínica profesional
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/dhsi_gauge.dart';
import '../widgets/quick_log_bar.dart';
import '../design/biosense_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  double _readingMs = 0.0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _now = DateTime.now();
        _readingMs = (_readingMs + 0.1) % 10.0;
      });
    });
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.82)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';
    final color = BioSenseColor.forStatus(state.statusKey);
    final timeStr =
      '${_now.hour.toString().padLeft(2,'0')}:'
      '${_now.minute.toString().padLeft(2,'0')}:'
      '${_now.second.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BioSenseSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── HEADER INSTITUCIONAL
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RichText(text: TextSpan(children: [
                    TextSpan(text: 'Bio',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w300,
                        color: BioSenseColor.primary, letterSpacing: -0.5)),
                    TextSpan(text: 'Sense',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: BioSenseColor.accent, letterSpacing: -0.5)),
                  ])),
                  Text('Predictive Vital Monitoring System',
                    style: BioSenseText.caption.copyWith(
                      letterSpacing: 0.3)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(timeStr, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w200,
                    letterSpacing: 1.5, color: BioSenseColor.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()])),
                  Text(
                    isEs
                      ? 'Última lectura: ${_readingMs.toStringAsFixed(2)} s'
                      : 'Last reading: ${_readingMs.toStringAsFixed(2)} s',
                    style: BioSenseText.caption),
                ]),
              ]),
              const SizedBox(height: BioSenseSpacing.xxl),

              // ── ESTADO PRINCIPAL
              BioSenseTheme.clinicalCard(
                statusKey: state.statusKey,
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  // Indicador vivo
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: _pulseAnim.value,
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6, spreadRadius: 1)]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEs ? 'ESTADO DEL SISTEMA' : 'SYSTEM STATUS',
                      style: BioSenseText.label),
                  ]),
                  const SizedBox(height: 12),

                  // Estado en texto clínico
                  Text(_statusLabel(state.statusKey, isEs),
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700,
                      letterSpacing: 1, color: color)),
                  const SizedBox(height: 6),
                  Text(_statusDesc(state.statusKey, isEs),
                    textAlign: TextAlign.center,
                    style: BioSenseText.body),
                  const SizedBox(height: 20),

                  // Índice
                  Text(
                    isEs ? 'ÍNDICE HOMEOSTÁTICO' : 'HOMEOSTATIC INDEX',
                    style: BioSenseText.label),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                    Text('${state.dhsiPercentage}',
                      style: BioSenseText.metricXL.copyWith(color: color,
                        fontWeight: FontWeight.w200)),
                    Padding(padding: const EdgeInsets.only(bottom: 8),
                      child: Text('%', style: BioSenseText.subtitle
                          .copyWith(color: BioSenseColor.textMuted))),
                  ]),
                  const SizedBox(height: 12),
                  DHSIGauge(percentage: state.dhsiPercentage),
                  const SizedBox(height: 8),
                  Text(
                    isEs
                      ? 'Health Confidence: ${(state.confidenceLevel*100).toStringAsFixed(1)}%'
                      : 'Health Confidence: ${(state.confidenceLevel*100).toStringAsFixed(1)}%',
                    style: BioSenseText.caption.copyWith(
                      color: BioSenseColor.accent)),

                  if (!app.baselineLocked) ...[
                    const SizedBox(height: 8),
                    Text(
                      isEs
                        ? 'Aprendiendo línea base fisiológica... (${app.baselineSamples}/30)'
                        : 'Learning physiological baseline... (${app.baselineSamples}/30)',
                      style: BioSenseText.caption,
                      textAlign: TextAlign.center),
                  ],
                ]),
              ),
              const SizedBox(height: BioSenseSpacing.md),

              // ── ESTADO VIVO
              BioSenseTheme.clinicalCard(
                animate: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: BioSenseSpacing.lg, vertical: BioSenseSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      isEs ? 'Analizando tendencias fisiológicas...'
                           : 'Analyzing physiological trends...',
                      style: BioSenseText.caption.copyWith(
                        color: BioSenseColor.accent)),
                    Text(
                      isEs ? 'PHSE activo  ·  Modelo actualizado'
                           : 'PHSE active  ·  Model updated',
                      style: BioSenseText.label.copyWith(
                        color: BioSenseColor.primary)),
                  ]),
                  Text('${state.cycle + 1248} ${isEs ? "muestras" : "samples"}',
                    style: BioSenseText.metricS.copyWith(
                      color: BioSenseColor.primary)),
                ]),
              ),
              const SizedBox(height: BioSenseSpacing.xxl),

              // ── BITÁCORA RÁPIDA
              Text(
                isEs ? 'REGISTRO DE FACTORES' : 'FACTOR LOG',
                style: BioSenseText.label),
              const SizedBox(height: BioSenseSpacing.md),
              QuickLogBar(
                eventLog: app.eventLog,
                onEventAdded: () => setState(() {})),
              const SizedBox(height: BioSenseSpacing.xl),

              // ── BOTÓN PRINCIPAL
              SizedBox(height: 52,
                child: ElevatedButton(
                  onPressed: () => _showHowIFeel(context, app),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BioSenseColor.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BioSenseRadius.md))),
                  child: Text(
                    isEs
                      ? 'Registrar Estado Subjetivo'
                      : 'Log Subjective Status',
                    style: BioSenseText.subtitle.copyWith(
                      color: Colors.white, letterSpacing: 0.3)),
                ),
              ),
              const SizedBox(height: BioSenseSpacing.xxl),
              BioSenseTheme.institutionalFooter(),
            ],
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
        case 'alert':    return 'Desviación predictiva en desarrollo. Restricción preventiva.';
        case 'danger':   return 'Intervención preventiva recomendada. Aviso a red segura.';
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
            isEs
              ? 'Estado Subjetivo Actual'
              : 'Current Subjective Status',
            style: BioSenseText.title),
          Text(
            isEs
              ? 'Su respuesta calibra el modelo adaptativo.'
              : 'Your response calibrates the adaptive model.',
            style: BioSenseText.caption,
            textAlign: TextAlign.center),
          const SizedBox(height: BioSenseSpacing.xl),
          ...{
            isEs ? 'Estado fisiológico óptimo'   : 'Optimal physiological state': 0.0,
            isEs ? 'Estado dentro de parámetros' : 'Within parameters': 0.05,
            isEs ? 'Fatiga leve detectada'       : 'Mild fatigue detected': 0.10,
            isEs ? 'Fatiga moderada'             : 'Moderate fatigue': 0.15,
            isEs ? 'Malestar significativo'      : 'Significant discomfort': 0.20,
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
                child: Text(e.key, style: BioSenseText.body.copyWith(
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
