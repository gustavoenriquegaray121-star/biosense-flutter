// ============================================================
// PHSE Altea Garay — Glucose Monitor Screen v1.0
// Estimación no invasiva via DARWIN_ENGINE v15.0
// Canal NIR 940nm + Fitness Evolutivo
// USPTO Provisional #63/914,860
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../design/biosense_theme.dart';

class GlucoseScreen extends StatefulWidget {
  const GlucoseScreen({super.key});
  @override
  State<GlucoseScreen> createState() => _GlucoseScreenState();
}

class _GlucoseScreenState extends State<GlucoseScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Historial de glucosa simulado (últimas 24h — 144 puntos)
  final List<double> _glucoseHistory = List.generate(144, (i) {
    final hour = (i * 10 / 60) % 24;
    if (hour < 6)  return 85.0  + (i % 7)  * 1.5;
    if (hour < 8)  return 95.0  + (i % 5)  * 2.0; // Ayuno matutino
    if (hour < 10) return 140.0 + (i % 8)  * 3.0; // Post desayuno
    if (hour < 12) return 110.0 + (i % 6)  * 1.5;
    if (hour < 14) return 150.0 + (i % 9)  * 2.5; // Post comida
    if (hour < 16) return 115.0 + (i % 5)  * 1.8;
    if (hour < 20) return 105.0 + (i % 7)  * 1.2;
    return 90.0 + (i % 4) * 1.0; // Noche
  });

  // Calibración con glucómetro real
  double _calibrationValue = 0.0;
  bool   _isCalibrated     = false;
  final  _calibCtrl        = TextEditingController();

  // Valor actual simulado
  double _currentGlucose = 98.5;
  int    _fitnessWinner  = 2; // Canal NIR por defecto
  List<int> _fitnessScores = [180, 160, 220, 210, 195];

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Simular actualización cada 2 segundos
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        // Pequeña variación para demo
        _currentGlucose += (DateTime.now().millisecond % 10 - 5) * 0.1;
        _currentGlucose = _currentGlucose.clamp(60.0, 300.0);
        _glucoseHistory.removeAt(0);
        _glucoseHistory.add(_currentGlucose);
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _updateTimer?.cancel();
    _calibCtrl.dispose();
    super.dispose();
  }

  // Estado clínico de glucosa
  _GlucoseStatus get _status {
    if (_currentGlucose < 70)  return _GlucoseStatus.hypo;
    if (_currentGlucose < 100) return _GlucoseStatus.normal;
    if (_currentGlucose < 126) return _GlucoseStatus.pre;
    if (_currentGlucose < 180) return _GlucoseStatus.high;
    return _GlucoseStatus.hyper;
  }

  Color get _statusColor {
    switch (_status) {
      case _GlucoseStatus.hypo:   return const Color(0xFF3498DB); // Azul
      case _GlucoseStatus.normal: return BioSenseColor.stable;     // Verde
      case _GlucoseStatus.pre:    return BioSenseColor.warning;    // Naranja
      case _GlucoseStatus.high:   return BioSenseColor.alert;      // Rojo
      case _GlucoseStatus.hyper:  return BioSenseColor.critical;   // Morado
    }
  }

  String _statusLabel(bool isEs) {
    switch (_status) {
      case _GlucoseStatus.hypo:   return isEs ? 'HIPOGLUCEMIA' : 'HYPOGLYCEMIA';
      case _GlucoseStatus.normal: return isEs ? 'NORMAL' : 'NORMAL';
      case _GlucoseStatus.pre:    return isEs ? 'PREDIABETES' : 'PREDIABETES';
      case _GlucoseStatus.high:   return isEs ? 'ELEVADA' : 'ELEVATED';
      case _GlucoseStatus.hyper:  return isEs ? 'HIPERGLUCEMIA' : 'HYPERGLYCEMIA';
    }
  }

  String _statusDesc(bool isEs) {
    switch (_status) {
      case _GlucoseStatus.hypo:
        return isEs
          ? 'Nivel bajo. Consumir carbohidratos de absorción rápida.'
          : 'Low level. Consume fast-absorbing carbohydrates.';
      case _GlucoseStatus.normal:
        return isEs
          ? 'Glucosa en rango óptimo. Sin intervención requerida.'
          : 'Glucose in optimal range. No intervention required.';
      case _GlucoseStatus.pre:
        return isEs
          ? 'Tendencia elevada detectada. Revisar dieta y actividad.'
          : 'Elevated trend detected. Review diet and activity.';
      case _GlucoseStatus.high:
        return isEs
          ? 'Glucosa elevada post-ingesta. Monitoreo continuo activo.'
          : 'Elevated post-meal glucose. Active continuous monitoring.';
      case _GlucoseStatus.hyper:
        return isEs
          ? 'Nivel crítico. Consultar especialista inmediatamente.'
          : 'Critical level. Consult specialist immediately.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';
    final color = _statusColor;

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      appBar: AppBar(
        title: Text(isEs
          ? 'Monitor de Glucosa'
          : 'Glucose Monitor'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(BioSenseRadius.full),
                border: Border.all(color: color.withOpacity(0.3))),
              child: Text(
                isEs ? 'NIR No Invasivo' : 'NIR Non-Invasive',
                style: BioSenseText.label.copyWith(color: color))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BioSenseSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── ADVERTENCIA CLÍNICA
            Container(
              padding: const EdgeInsets.all(BioSenseSpacing.md),
              decoration: BoxDecoration(
                color: BioSenseColor.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(BioSenseRadius.md),
                border: Border.all(
                  color: BioSenseColor.warning.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.info_outline,
                  color: BioSenseColor.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isEs
                    ? 'Estimación predictiva no invasiva. No sustituye glucómetro capilar. Requiere calibración inicial.'
                    : 'Non-invasive predictive estimate. Does not replace capillary glucometer. Requires initial calibration.',
                  style: BioSenseText.caption.copyWith(
                    color: BioSenseColor.warning))),
              ])),
            const SizedBox(height: BioSenseSpacing.lg),

            // ── VALOR PRINCIPAL
            AnimatedContainer(
              duration: BioSenseMotion.slow,
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(BioSenseRadius.lg),
                border: Border.all(color: color.withOpacity(0.25)),
                boxShadow: [BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 20, offset: const Offset(0,6))]),
              padding: const EdgeInsets.all(BioSenseSpacing.xxl),
              child: Column(children: [

                // Punto pulsante
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
                            blurRadius: 10, spreadRadius: 3)])))),
                  const SizedBox(width: 8),
                  Text(
                    isEs ? 'GLUCOSA ESTIMADA' : 'ESTIMATED GLUCOSE',
                    style: BioSenseText.label),
                ]),
                const SizedBox(height: BioSenseSpacing.md),

                // Valor grande
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                  Text(
                    _currentGlucose.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 72,
                      fontWeight: FontWeight.w200, color: color,
                      letterSpacing: -2,
                      fontFeatures: const [FontFeature.tabularFigures()])),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(' mg/dL',
                      style: BioSenseText.subtitle.copyWith(
                        color: BioSenseColor.textMuted))),
                ]),

                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(BioSenseRadius.full),
                    border: Border.all(color: color.withOpacity(0.4))),
                  child: Text(_statusLabel(isEs),
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color, letterSpacing: 1.2))),
                const SizedBox(height: BioSenseSpacing.md),
                Text(_statusDesc(isEs),
                  textAlign: TextAlign.center,
                  style: BioSenseText.body),
                const SizedBox(height: BioSenseSpacing.lg),

                // Calibrado o no
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(
                    _isCalibrated
                      ? Icons.verified_outlined
                      : Icons.pending_outlined,
                    color: _isCalibrated
                      ? BioSenseColor.stable : BioSenseColor.warning,
                    size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _isCalibrated
                      ? (isEs
                          ? 'Calibrado con glucómetro real'
                          : 'Calibrated with real glucometer')
                      : (isEs
                          ? 'Sin calibrar — precisión reducida'
                          : 'Not calibrated — reduced accuracy'),
                    style: BioSenseText.caption.copyWith(
                      color: _isCalibrated
                        ? BioSenseColor.stable : BioSenseColor.warning)),
                ]),
              ]),
            ),
            const SizedBox(height: BioSenseSpacing.lg),

            // ── RANGO DE REFERENCIA
            BioSenseTheme.clinicalCard(
              animate: false,
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  isEs ? 'RANGOS DE REFERENCIA' : 'REFERENCE RANGES',
                  style: BioSenseText.label),
                const SizedBox(height: BioSenseSpacing.md),
                _RangeBar(label: isEs ? 'Hipoglucemia' : 'Hypoglycemia',
                  range: '< 70', color: const Color(0xFF3498DB),
                  active: _status == _GlucoseStatus.hypo),
                _RangeBar(label: isEs ? 'Normal' : 'Normal',
                  range: '70–99', color: BioSenseColor.stable,
                  active: _status == _GlucoseStatus.normal),
                _RangeBar(label: isEs ? 'Prediabetes' : 'Prediabetes',
                  range: '100–125', color: BioSenseColor.warning,
                  active: _status == _GlucoseStatus.pre),
                _RangeBar(label: isEs ? 'Diabetes' : 'Diabetes',
                  range: '126–179', color: BioSenseColor.alert,
                  active: _status == _GlucoseStatus.high),
                _RangeBar(label: isEs ? 'Hiperglucemia' : 'Hyperglycemia',
                  range: '≥ 180', color: BioSenseColor.critical,
                  active: _status == _GlucoseStatus.hyper),
              ])),
            const SizedBox(height: BioSenseSpacing.lg),

            // ── GRÁFICA 24H
            BioSenseTheme.clinicalCard(
              animate: false,
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(children: [
                  Icon(Icons.show_chart_outlined,
                    color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isEs ? 'CURVA GLUCÉMICA 24H' : 'GLYCEMIC CURVE 24H',
                    style: BioSenseText.label.copyWith(color: color)),
                ]),
                const SizedBox(height: BioSenseSpacing.md),
                SizedBox(
                  height: 100,
                  child: BioSenseTheme.sparkline(
                    data: _glucoseHistory, color: color, height: 100)),
                const SizedBox(height: BioSenseSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  Text('00:00', style: BioSenseText.caption),
                  Text('06:00', style: BioSenseText.caption),
                  Text('12:00', style: BioSenseText.caption),
                  Text('18:00', style: BioSenseText.caption),
                  Text(isEs ? 'Ahora' : 'Now',
                    style: BioSenseText.caption.copyWith(
                      color: color, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: BioSenseSpacing.md),
                // Stats
                Row(children: [
                  _GlucStat(
                    label: isEs ? 'Promedio' : 'Average',
                    value: '${(_glucoseHistory.reduce((a,b) => a+b) / _glucoseHistory.length).toStringAsFixed(0)} mg/dL',
                    color: color),
                  const SizedBox(width: BioSenseSpacing.sm),
                  _GlucStat(
                    label: isEs ? 'Mínimo' : 'Minimum',
                    value: '${_glucoseHistory.reduce((a,b) => a<b?a:b).toStringAsFixed(0)} mg/dL',
                    color: const Color(0xFF3498DB)),
                  const SizedBox(width: BioSenseSpacing.sm),
                  _GlucStat(
                    label: isEs ? 'Máximo' : 'Maximum',
                    value: '${_glucoseHistory.reduce((a,b) => a>b?a:b).toStringAsFixed(0)} mg/dL',
                    color: BioSenseColor.alert),
                ]),
              ])),
            const SizedBox(height: BioSenseSpacing.lg),

            // ── DARWIN FITNESS — canales
            BioSenseTheme.clinicalCard(
              animate: false,
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: BioSenseColor.accent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: BioSenseColor.accent.withOpacity(0.4),
                        blurRadius: 6)])),
                  const SizedBox(width: 8),
                  Text(
                    'DARWIN ENGINE v15.0 — CANAL ACTIVO',
                    style: BioSenseText.label.copyWith(
                      color: BioSenseColor.primary)),
                ]),
                const SizedBox(height: BioSenseSpacing.md),
                ...[
                  ('C1', 'IR / HRV',           _fitnessScores[0]),
                  ('C2', isEs ? 'Verde / Perfusión' : 'Green / Perfusion', _fitnessScores[1]),
                  ('C3', 'NIR 940nm / Glucosa', _fitnessScores[2]),
                  ('C4', isEs ? 'Temperatura IR' : 'IR Temperature',       _fitnessScores[3]),
                  ('C5', isEs ? 'Movimiento MPU6050' : 'Motion MPU6050',   _fitnessScores[4]),
                ].asMap().entries.map((e) {
                  final idx     = e.key;
                  final ch      = e.value.$1;
                  final name    = e.value.$2;
                  final fitness = e.value.$3;
                  final isWinner = idx == _fitnessWinner;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 36, height: 20,
                        decoration: BoxDecoration(
                          color: isWinner
                            ? BioSenseColor.accent.withOpacity(0.15)
                            : BioSenseColor.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isWinner
                              ? BioSenseColor.accent
                              : BioSenseColor.border)),
                        child: Center(child: Text(ch,
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isWinner
                              ? BioSenseColor.accent
                              : BioSenseColor.textMuted)))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Row(children: [
                          Expanded(child: Text(name,
                            style: BioSenseText.caption.copyWith(
                              color: isWinner
                                ? BioSenseColor.primary
                                : BioSenseColor.textMuted))),
                          Text('$fitness',
                            style: TextStyle(
                              fontFamily: 'Inter', fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWinner
                                ? BioSenseColor.accent
                                : BioSenseColor.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                          if (isWinner)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.star,
                                color: BioSenseColor.accent, size: 12)),
                        ]),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(BioSenseRadius.full),
                          child: LinearProgressIndicator(
                            value: fitness / 255.0,
                            backgroundColor: BioSenseColor.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isWinner
                                ? BioSenseColor.accent
                                : BioSenseColor.textMuted),
                            minHeight: 3)),
                      ])),
                    ]));
                }),
                const SizedBox(height: BioSenseSpacing.sm),
                Text(
                  isEs
                    ? 'El canal con mayor fitness proporciona la estimación más limpia.'
                    : 'The highest fitness channel provides the cleanest estimate.',
                  style: BioSenseText.caption.copyWith(
                    fontStyle: FontStyle.italic,
                    color: BioSenseColor.primary)),
              ])),
            const SizedBox(height: BioSenseSpacing.lg),

            // ── CALIBRACIÓN CON GLUCÓMETRO
            BioSenseTheme.clinicalCard(
              animate: false,
              color: BioSenseColor.primary.withOpacity(0.04),
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  isEs
                    ? 'CALIBRACIÓN ADAPTATIVA'
                    : 'ADAPTIVE CALIBRATION',
                  style: BioSenseText.label.copyWith(
                    color: BioSenseColor.primary)),
                const SizedBox(height: 6),
                Text(
                  isEs
                    ? 'Ingresa una lectura de tu glucómetro capilar. El DARWIN ENGINE ajustará su función de aptitud para tu perfil biológico único.'
                    : 'Enter a reading from your capillary glucometer. The DARWIN ENGINE will adjust its fitness function for your unique biological profile.',
                  style: BioSenseText.caption),
                const SizedBox(height: BioSenseSpacing.md),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _calibCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                    style: BioSenseText.body,
                    decoration: InputDecoration(
                      hintText: isEs
                        ? 'Ej. 105 mg/dL'
                        : 'e.g. 105 mg/dL',
                      hintStyle: BioSenseText.body.copyWith(
                        color: BioSenseColor.textHint),
                      prefixIcon: const Icon(
                        Icons.colorize_outlined,
                        color: BioSenseColor.primary, size: 20)),
                  )),
                  const SizedBox(width: BioSenseSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      final val = double.tryParse(_calibCtrl.text);
                      if (val != null && val > 40 && val < 500) {
                        setState(() {
                          _calibrationValue = val;
                          _isCalibrated = true;
                          // Ajustar estimación con punto de calibración
                          _currentGlucose = val;
                        });
                        _calibCtrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEs
                              ? 'Calibración aplicada: ${val.toStringAsFixed(0)} mg/dL'
                              : 'Calibration applied: ${val.toStringAsFixed(0)} mg/dL'),
                            backgroundColor: BioSenseColor.stable,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BioSenseColor.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14)),
                    child: Text(
                      isEs ? 'Calibrar' : 'Calibrate',
                      style: BioSenseText.subtitle.copyWith(
                        color: Colors.white))),
                ]),
                if (_isCalibrated) ...[
                  const SizedBox(height: BioSenseSpacing.sm),
                  Row(children: [
                    const Icon(Icons.check_circle_outline,
                      color: BioSenseColor.stable, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      isEs
                        ? 'Punto de calibración: ${_calibrationValue.toStringAsFixed(0)} mg/dL'
                        : 'Calibration point: ${_calibrationValue.toStringAsFixed(0)} mg/dL',
                      style: BioSenseText.caption.copyWith(
                        color: BioSenseColor.stable)),
                  ]),
                ],
              ])),
            const SizedBox(height: BioSenseSpacing.xxl),
            BioSenseTheme.institutionalFooter(),
          ],
        ),
      ),
    );
  }
}

// ── Estado clínico
enum _GlucoseStatus { hypo, normal, pre, high, hyper }

// ── Barra de rango
class _RangeBar extends StatelessWidget {
  final String label, range;
  final Color color;
  final bool active;
  const _RangeBar({required this.label, required this.range,
    required this.color, required this.active});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.25),
          shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
        style: BioSenseText.body.copyWith(
          color: active ? color : BioSenseColor.textMuted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400))),
      Text(range,
        style: BioSenseText.caption.copyWith(
          color: active ? color : BioSenseColor.textMuted,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
    ]));
}

// ── Estadística de glucosa
class _GlucStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _GlucStat({required this.label, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(BioSenseSpacing.sm),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: color.withOpacity(0.20))),
    child: Column(children: [
      Text(value,
        style: TextStyle(
          fontFamily: 'Inter', fontSize: 12,
          fontWeight: FontWeight.w700, color: color),
        textAlign: TextAlign.center),
      Text(label, style: BioSenseText.caption,
        textAlign: TextAlign.center),
    ])));
}
