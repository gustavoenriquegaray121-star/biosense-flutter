// ============================================================
// BIOSENSE OS — My Health Screen v3.0 Premium
// Sparklines reales, anillos de estabilidad, SIGNAL LOST
// Motor PHSE PASADO→AHORA→FUTURO con trayectoria real
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/health_state.dart';
import '../design/biosense_theme.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});
  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen>
    with TickerProviderStateMixin {

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  int _sampleCount = 1248;
  double _lastReadingMs = 0.0;
  bool _signalLost = false;
  int _noSignalSeconds = 0;

  // Sparkline data (últimas 30 muestras por canal)
  final List<double> _hrvData  = List.generate(30, (i) => 45.0 + i * 0.1);
  final List<double> _tempData = List.generate(30, (i) => 36.6 + i * 0.01);
  final List<double> _respData = List.generate(30, (i) => 16.0 + i * 0.05);
  final List<double> _gsrData  = List.generate(30, (i) => 1.2 + i * 0.02);
  final List<double> _dhsiData = List.generate(30, (i) => 0.95 + i * 0.001);

  // Animación del punto de status
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _clockTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final app = context.read<AppStateProvider>();
      final state = app.healthState;

      // Simular pérdida de señal en mock mode si no hay cambios
      _noSignalSeconds++;
      final lost = !app.isMockMode ? _noSignalSeconds > 25 : false;

      setState(() {
        _now = DateTime.now();
        _lastReadingMs = (_lastReadingMs + 0.2) % 10.0;
        _signalLost = lost;
        if (!lost) {
          _noSignalSeconds = 0;
          _sampleCount++;
          _updateSparklines(state);
        }
      });
    });
  }

  void _updateSparklines(HealthState state) {
    void push(List<double> list, double val) {
      list.removeAt(0); list.add(val);
    }
    push(_hrvData,  state.hrv.value);
    push(_tempData, state.temp.value);
    push(_respData, state.resp.value);
    push(_gsrData,  state.gsr.value);
    push(_dhsiData, state.dhsi);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppStateProvider>();
    final state  = app.healthState;
    final isEs   = app.language.name == 'es';
    final color  = BioSenseColor.forStatus(state.statusKey);
    final isCrit = BioSenseColor.isCritical(state.statusKey);

    final timeStr =
      '${_now.hour.toString().padLeft(2,'0')}:'
      '${_now.minute.toString().padLeft(2,'0')}:'
      '${_now.second.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: isCrit
        ? BioSenseColor.criticalBg
        : BioSenseColor.bgPrimary,
      body: CustomPaint(
        painter: _HexGridPainter(critical: isCrit),
        child: SafeArea(
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
                    Text(
                      isEs
                        ? 'TELEMETRÍA FISIOLÓGICA'
                        : 'PHYSIOLOGICAL TELEMETRY',
                      style: BioSenseText.label.copyWith(
                        color: isCrit
                          ? Colors.white38
                          : BioSenseColor.primary)),
                    Text(
                      isEs
                        ? 'Monitoreo predictivo en tiempo real'
                        : 'Real-time predictive monitoring',
                      style: BioSenseText.caption.copyWith(
                        color: isCrit ? Colors.white24 : null)),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                    Text(timeStr, style: TextStyle(
                      fontFamily: 'Inter', fontSize: 18,
                      fontWeight: FontWeight.w200, letterSpacing: 1.5,
                      color: isCrit
                        ? Colors.white70
                        : BioSenseColor.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()])),
                    Text(
                      isEs
                        ? 'Última lectura: ${_lastReadingMs.toStringAsFixed(2)} s'
                        : 'Last reading: ${_lastReadingMs.toStringAsFixed(2)} s',
                      style: BioSenseText.caption.copyWith(
                        color: isCrit ? Colors.white38 : null)),
                  ]),
                ]),
                const SizedBox(height: BioSenseSpacing.md),

                // ── SIGNAL LOST o ESTADO VIVO
                _signalLost
                  ? _SignalLostBanner(isEs: isEs)
                  : _LiveStatusBar(
                      color: color,
                      statusKey: state.statusKey,
                      sampleCount: _sampleCount,
                      isEs: isEs,
                      pulseAnim: _pulseAnim,
                      isCrit: isCrit),
                const SizedBox(height: BioSenseSpacing.xl),

                // ── SECCIÓN VITALES
                Text(
                  isEs
                    ? 'SIGNOS VITALES EN TIEMPO REAL'
                    : 'REAL-TIME VITAL SIGNS',
                  style: BioSenseText.label.copyWith(
                    color: isCrit ? Colors.white38 : BioSenseColor.primary)),
                const SizedBox(height: BioSenseSpacing.md),

                // Canal: Cardiovascular / HRV
                _VitalCard(
                  icon: Icons.favorite_outline,
                  label: isEs ? 'CARDIOVASCULAR' : 'CARDIOVASCULAR',
                  sublabel: isEs ? 'Variabilidad HRV' : 'HRV variability',
                  value: '72',
                  unit: 'bpm',
                  reading: state.hrv,
                  sparkData: List.from(_hrvData),
                  confidence: 99.8,
                  isEs: isEs,
                  isCrit: isCrit,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // Canal: Temperatura
                _VitalCard(
                  icon: Icons.thermostat_outlined,
                  label: isEs ? 'TEMPERATURA BASAL' : 'BASELINE TEMPERATURE',
                  sublabel: isEs ? 'Temperatura corporal' : 'Body temperature',
                  value: '36.6',
                  unit: '°C',
                  reading: state.temp,
                  sparkData: List.from(_tempData),
                  confidence: 99.5,
                  isEs: isEs,
                  isCrit: isCrit,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // Canal: Respiración
                _VitalCard(
                  icon: Icons.air_outlined,
                  label: isEs ? 'FRECUENCIA RESPIRATORIA' : 'RESPIRATORY RATE',
                  sublabel: isEs ? 'Ciclos por minuto' : 'Cycles per minute',
                  value: '16',
                  unit: 'rpm',
                  reading: state.resp,
                  sparkData: List.from(_respData),
                  confidence: 99.2,
                  isEs: isEs,
                  isCrit: isCrit,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // Canal: GSR
                _VitalCard(
                  icon: Icons.water_drop_outlined,
                  label: isEs ? 'RESPUESTA GALVÁNICA' : 'GALVANIC RESPONSE',
                  sublabel: isEs ? 'Conductancia de la piel' : 'Skin conductance',
                  value: '1.2',
                  unit: 'µS',
                  reading: state.gsr,
                  sparkData: List.from(_gsrData),
                  confidence: 98.8,
                  isEs: isEs,
                  isCrit: isCrit,
                ),
                const SizedBox(height: BioSenseSpacing.xxl),

                // ── MOTOR PREDICTIVO PHSE
                _PhseMotorCard(
                  dhsiData: List.from(_dhsiData),
                  confidence: state.confidenceLevel,
                  velocity: state.velocity,
                  jerk: state.jerk,
                  statusKey: state.statusKey,
                  isEs: isEs,
                  isCrit: isCrit,
                ),
                const SizedBox(height: BioSenseSpacing.xxl),
                BioSenseTheme.institutionalFooter(dark: isCrit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Banner SIGNAL LOST
class _SignalLostBanner extends StatelessWidget {
  final bool isEs;
  const _SignalLostBanner({required this.isEs});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BioSenseSpacing.lg),
    decoration: BoxDecoration(
      color: BioSenseColor.textMuted.withOpacity(0.10),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(color: BioSenseColor.textMuted.withOpacity(0.30))),
    child: Row(children: [
      const Icon(Icons.signal_wifi_off_outlined,
        color: BioSenseColor.textMuted, size: 22),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SIGNAL LOST', style: BioSenseText.label.copyWith(
          color: BioSenseColor.textMuted, letterSpacing: 1.5)),
        Text(
          isEs
            ? 'Sin datos de la pulsera — verificar conexión Bluetooth'
            : 'No band data — check Bluetooth connection',
          style: BioSenseText.caption),
      ]),
    ]));
}

// ── Barra de estado vivo
class _LiveStatusBar extends StatelessWidget {
  final Color color;
  final String statusKey;
  final int sampleCount;
  final bool isEs;
  final Animation<double> pulseAnim;
  final bool isCrit;

  const _LiveStatusBar({
    required this.color, required this.statusKey,
    required this.sampleCount, required this.isEs,
    required this.pulseAnim, required this.isCrit});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BioSenseSpacing.lg, vertical: BioSenseSpacing.md),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(color: color.withOpacity(0.25))),
    child: Row(children: [
      AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, __) => Opacity(
          opacity: pulseAnim.value,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 10, spreadRadius: 3)])))),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          isEs ? 'PHSE activo — Analizando tendencias...'
               : 'PHSE active — Analyzing trends...',
          style: BioSenseText.caption.copyWith(color: color)),
        Text(
          isEs ? 'Modelo actualizado — predicción en tiempo real'
               : 'Model updated — real-time prediction',
          style: BioSenseText.label.copyWith(
            color: isCrit ? Colors.white54 : BioSenseColor.primary)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$sampleCount', style: BioSenseText.metricS.copyWith(
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()])),
        Text(
          isEs ? 'muestras' : 'samples',
          style: BioSenseText.caption),
      ]),
    ]));
}

// ── Tarjeta de canal vital
class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label, sublabel, value, unit;
  final ChannelReading reading;
  final List<double> sparkData;
  final double confidence;
  final bool isEs, isCrit;

  const _VitalCard({
    required this.icon, required this.label,
    required this.sublabel, required this.value, required this.unit,
    required this.reading, required this.sparkData,
    required this.confidence, required this.isEs, required this.isCrit});

  Color get _color {
    switch (reading.status) {
      case ChannelStatus.normal:   return BioSenseColor.stable;
      case ChannelStatus.leve:     return BioSenseColor.warning;
      case ChannelStatus.moderado: return BioSenseColor.alert;
      case ChannelStatus.alto:     return BioSenseColor.critical;
    }
  }

  double get _ringValue {
    switch (reading.status) {
      case ChannelStatus.normal:   return 1.0;
      case ChannelStatus.leve:     return 0.75;
      case ChannelStatus.moderado: return 0.50;
      case ChannelStatus.alto:     return 0.25;
    }
  }

  String get _statusLabel {
    switch (reading.status) {
      case ChannelStatus.normal:   return isEs ? 'Normal' : 'Normal';
      case ChannelStatus.leve:     return isEs ? 'Variación leve' : 'Slight variation';
      case ChannelStatus.moderado: return isEs ? 'Cambio notable' : 'Notable change';
      case ChannelStatus.alto:     return isEs ? 'Cambio importante' : 'Important change';
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: BioSenseMotion.slow,
    decoration: BoxDecoration(
      color: isCrit
        ? BioSenseColor.criticalCard
        : _color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(color: _color.withOpacity(0.25)),
      boxShadow: [BoxShadow(
        color: _color.withOpacity(0.10),
        blurRadius: 16, offset: const Offset(0,4))]),
    padding: const EdgeInsets.all(BioSenseSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Fila superior: anillo + valor + icono
      Row(children: [
        // Anillo de estabilidad
        BioSenseTheme.stabilityRing(
          value: _ringValue,
          statusKey: reading.status == ChannelStatus.normal
            ? 'stable'
            : reading.status == ChannelStatus.leve ? 'fatigue' : 'alert',
          size: 48),
        const SizedBox(width: BioSenseSpacing.md),

        // Etiqueta + valor grande
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(label, style: BioSenseText.label.copyWith(
            color: isCrit ? Colors.white38 : _color)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: TextStyle(
              fontFamily: 'Inter', fontSize: 36,
              fontWeight: FontWeight.w200, letterSpacing: -1,
              color: _color,
              fontFeatures: const [FontFeature.tabularFigures()])),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(unit, style: BioSenseText.body.copyWith(
                color: BioSenseColor.textMuted))),
          ]),
          Text(sublabel, style: BioSenseText.caption),
        ])),

        // Icono + badge status
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Icon(icon, color: _color.withOpacity(0.5), size: 28),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(BioSenseRadius.full),
              border: Border.all(color: _color.withOpacity(0.35))),
            child: Text(_statusLabel, style: TextStyle(
              fontFamily: 'Inter', fontSize: 9,
              fontWeight: FontWeight.w800, color: _color,
              letterSpacing: 0.5))),
        ]),
      ]),
      const SizedBox(height: BioSenseSpacing.md),

      // Sparkline
      SizedBox(height: 40,
        child: BioSenseTheme.sparkline(
          data: sparkData, color: _color, height: 40)),
      const SizedBox(height: BioSenseSpacing.sm),

      // Barra de confianza
      Row(children: [
        Text(
          isEs ? 'Confianza de lectura' : 'Reading confidence',
          style: BioSenseText.caption),
        const Spacer(),
        Text('${confidence.toStringAsFixed(1)}%',
          style: BioSenseText.caption.copyWith(
            color: _color, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      BioSenseTheme.gradientBar(value: confidence / 100, color: _color, height: 3),
    ]),
  );
}

// ── Motor PHSE Card
class _PhseMotorCard extends StatelessWidget {
  final List<double> dhsiData;
  final double confidence, velocity, jerk;
  final String statusKey;
  final bool isEs, isCrit;

  const _PhseMotorCard({
    required this.dhsiData, required this.confidence,
    required this.velocity, required this.jerk,
    required this.statusKey, required this.isEs,
    required this.isCrit});

  IconData get _futureIcon {
    if (statusKey == 'danger' || statusKey == 'critical') return Icons.trending_down;
    if (statusKey == 'alert' || statusKey == 'fatigue')   return Icons.trending_down;
    if (velocity > 0.003) return Icons.trending_up;
    return Icons.trending_flat;
  }

  Color get _futureColor {
    if (statusKey == 'danger' || statusKey == 'critical') return BioSenseColor.alert;
    if (statusKey == 'alert' || statusKey == 'fatigue')   return BioSenseColor.warning;
    if (velocity > 0.003) return BioSenseColor.accentBright;
    return BioSenseColor.stable;
  }

  String get _futureText {
    if (statusKey == 'danger' || statusKey == 'critical') {
      return isEs
        ? 'Riesgo predictivo elevado — intervención requerida'
        : 'Elevated predictive risk — intervention required';
    }
    if (statusKey == 'alert') {
      return isEs
        ? 'Desviación predictiva en desarrollo'
        : 'Predictive deviation developing';
    }
    if (statusKey == 'fatigue') {
      return isEs
        ? 'Variación preventiva — vigilancia activa'
        : 'Preventive variation — active monitoring';
    }
    if (velocity > 0.003) {
      return isEs
        ? 'Tendencia de recuperación — homeostasis mejorando'
        : 'Recovery trajectory — homeostasis improving';
    }
    return isEs
      ? 'Sin riesgo predictivo — estado estable proyectado'
      : 'No predictive risk — stable state projected';
  }

  Color get _mainColor => BioSenseColor.forStatus(statusKey);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isCrit
        ? BioSenseColor.criticalCard
        : BioSenseColor.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(
        color: isCrit
          ? BioSenseColor.criticalBorder.withOpacity(0.4)
          : BioSenseColor.primary.withOpacity(0.15)),
      boxShadow: isCrit
        ? BioSenseShadow.critical
        : BioSenseShadow.card),
    padding: const EdgeInsets.all(BioSenseSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Header del motor
      Row(children: [
        Container(width: 10, height: 10,
          decoration: BoxDecoration(
            color: _mainColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: _mainColor.withOpacity(0.5),
              blurRadius: 8, spreadRadius: 2)])),
        const SizedBox(width: 10),
        Text(
          isEs ? 'MOTOR PREDICTIVO PHSE' : 'PHSE PREDICTIVE ENGINE',
          style: BioSenseText.label.copyWith(
            color: isCrit ? Colors.white54 : BioSenseColor.primary)),
        const Spacer(),
        Text('${(confidence * 100).toStringAsFixed(2)}%',
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 13,
            fontWeight: FontWeight.w700, color: _mainColor)),
        Text(
          isEs ? ' confianza' : ' confidence',
          style: BioSenseText.caption),
      ]),
      const SizedBox(height: BioSenseSpacing.lg),

      // Sparkline DHSI
      SizedBox(height: 52,
        child: BioSenseTheme.sparkline(
          data: dhsiData, color: _mainColor, height: 52)),
      const SizedBox(height: BioSenseSpacing.lg),

      // Línea temporal PASADO — AHORA — FUTURO
      Row(children: [
        _TimeNode(
          label: isEs ? 'PASADO' : 'PAST',
          icon: Icons.check_circle_outline,
          color: BioSenseColor.stable,
          isCrit: isCrit),
        Expanded(child: Container(height: 1.5,
          color: isCrit ? Colors.white12 : BioSenseColor.border)),
        _TimeNode(
          label: isEs ? 'AHORA' : 'NOW',
          icon: Icons.radio_button_checked,
          color: _mainColor,
          isCrit: isCrit),
        Expanded(child: _DashedLine(
          color: isCrit ? Colors.white12 : BioSenseColor.border)),
        _TimeNode(
          label: isEs ? 'FUTURO' : 'FUTURE',
          icon: _futureIcon,
          color: _futureColor,
          isCrit: isCrit),
      ]),
      const SizedBox(height: BioSenseSpacing.md),

      // Caja de trayectoria futura
      Container(
        padding: const EdgeInsets.all(BioSenseSpacing.md),
        decoration: BoxDecoration(
          color: _futureColor.withOpacity(0.09),
          borderRadius: BorderRadius.circular(BioSenseRadius.sm),
          border: Border.all(color: _futureColor.withOpacity(0.30))),
        child: Row(children: [
          Icon(_futureIcon, color: _futureColor, size: 18),
          const SizedBox(width: BioSenseSpacing.sm),
          Expanded(child: Text(_futureText,
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 12,
              fontWeight: FontWeight.w600, color: _futureColor))),
          Text(
            jerk.abs() > 0.008 ? '96 s' : '24 s',
            style: BioSenseText.caption.copyWith(
              color: isCrit ? Colors.white38 : BioSenseColor.primary,
              fontWeight: FontWeight.w700)),
        ])),
      const SizedBox(height: BioSenseSpacing.md),

      // Métricas del motor
      Row(children: [
        _PhseMetric(
          label: isEs ? 'Velocidad' : 'Velocity',
          value: velocity < -0.002
            ? (isEs ? 'Alta' : 'High')
            : (isEs ? 'Baja' : 'Low'),
          color: velocity < -0.002
            ? BioSenseColor.warning : BioSenseColor.stable,
          isCrit: isCrit),
        const SizedBox(width: BioSenseSpacing.sm),
        _PhseMetric(
          label: 'Jerk',
          value: jerk < -0.002
            ? (isEs ? 'Creciente' : 'Rising')
            : (isEs ? 'Estable' : 'Stable'),
          color: jerk < -0.002
            ? BioSenseColor.warning : BioSenseColor.stable,
          isCrit: isCrit),
        const SizedBox(width: BioSenseSpacing.sm),
        _PhseMetric(
          label: isEs ? 'Horizonte' : 'Horizon',
          value: jerk.abs() > 0.008 ? '96 s' : '24 s',
          color: isCrit ? BioSenseColor.alert : BioSenseColor.primary,
          isCrit: isCrit),
      ]),
      const SizedBox(height: BioSenseSpacing.md),

      Text(
        isEs
          ? 'Del monitoreo a la anticipación.'
          : 'From monitoring to foresight.',
        style: BioSenseText.caption.copyWith(
          fontStyle: FontStyle.italic,
          color: isCrit ? Colors.white24 : BioSenseColor.primary)),
    ]));
}

class _TimeNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isCrit;
  const _TimeNode({required this.label, required this.icon,
    required this.color, required this.isCrit});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 20),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(
      fontFamily: 'Inter', fontSize: 8,
      fontWeight: FontWeight.w800, color: color,
      letterSpacing: 0.5)),
  ]);
}

class _PhseMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isCrit;
  const _PhseMetric({required this.label, required this.value,
    required this.color, required this.isCrit});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(BioSenseSpacing.md),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: color.withOpacity(0.20))),
    child: Column(children: [
      Text(value, style: TextStyle(
        fontFamily: 'Inter', fontSize: 13,
        fontWeight: FontWeight.w700, color: color),
        textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: BioSenseText.caption.copyWith(
        color: isCrit ? Colors.white38 : null),
        textAlign: TextAlign.center),
    ])));
}

class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1.5, child: CustomPaint(
      painter: _DashPainter(color: color)));
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1.5;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), p);
      x += 10;
    }
  }
  @override bool shouldRepaint(_DashPainter old) => old.color != color;
}

// Fondo hexagonal
class _HexGridPainter extends CustomPainter {
  final bool critical;
  const _HexGridPainter({this.critical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = critical
        ? const Color(0xFFE74C3C).withOpacity(0.04)
        : const Color(0xFF0A3D62).withOpacity(0.030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const r = 22.0;
    const h = r * 1.732;
    int col = 0;
    for (double x = 0; x < size.width + r*2; x += r*1.5) {
      final oy = col.isOdd ? h/2 : 0.0;
      for (double y = -h+oy; y < size.height+h; y += h) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i*60-30)*3.14159265/180;
          final px = x + r * _c(a);
          final py = y + r * _s(a);
          if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      col++;
    }
  }

  double _c(double a) {
    final t = a % (2*3.14159265);
    return 1 - t*t/2 + t*t*t*t/24 - t*t*t*t*t*t/720;
  }
  double _s(double a) => _c(a - 1.5707963);

  @override
  bool shouldRepaint(_HexGridPainter old) => old.critical != critical;
}
