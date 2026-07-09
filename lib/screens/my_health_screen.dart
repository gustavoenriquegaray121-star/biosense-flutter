// ============================================================
// BIOSENSE OS — My Health Screen v2.0
// Modo Usuario: Monitoreo Premium con Estado Vivo
// "Del monitoreo a la anticipación"
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
  int _sampleCount = 0;
  double _lastReadingMs = 0;

  // Sparkline data por canal (últimas 20 muestras)
  final List<double> _hrvData  = List.filled(20, 1.0);
  final List<double> _tempData = List.filled(20, 1.0);
  final List<double> _respData = List.filled(20, 1.0);
  final List<double> _gsrData  = List.filled(20, 1.0);
  final List<double> _dhsiData = List.filled(20, 1.0);

  // Animación del punto de status
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _now = DateTime.now();
        _lastReadingMs = (_lastReadingMs + 0.1).clamp(0, 9.9);
        if (_lastReadingMs >= 0.9) {
          _lastReadingMs = 0.0;
          _sampleCount++;
          _updateSparklines();
        }
      });
    });

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  void _updateSparklines() {
    final app = context.read<AppStateProvider>();
    final state = app.healthState;
    void shift(List<double> list, double val) {
      list.removeAt(0); list.add(val);
    }
    shift(_hrvData,  state.hrv.value);
    shift(_tempData, state.temp.value);
    shift(_respData, state.resp.value);
    shift(_gsrData,  state.gsr.value);
    shift(_dhsiData, state.dhsi);
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
    final timeStr = '${_now.hour.toString().padLeft(2,'0')}:'
                   '${_now.minute.toString().padLeft(2,'0')}:'
                   '${_now.second.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      body: CustomPaint(
        painter: _HexGridPainter(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(BioSenseSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── HEADER: reloj + última lectura
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(timeStr,
                        style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w200,
                          letterSpacing: 2, color: BioSenseColor.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()])),
                      Text(
                        isEs
                          ? 'Última lectura: ${_lastReadingMs.toStringAsFixed(2)} s'
                          : 'Last reading: ${_lastReadingMs.toStringAsFixed(2)} s',
                        style: BioSenseText.caption),
                    ]),
                    // Isotipo + nombre
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('BioSense',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [BioSenseColor.primary, BioSenseColor.accent])
                            .createShader(const Rect.fromLTWH(0,0,120,20)),
                        )),
                      const Text('ALTEA-GARAY HTS',
                        style: TextStyle(fontSize: 9, letterSpacing: 1.5,
                          color: BioSenseColor.textMuted)),
                    ]),
                  ],
                ),
                const SizedBox(height: BioSenseSpacing.xl),

                // ── ESTADO PRINCIPAL
                BioSenseTheme.clinicalCard(
                  statusKey: state.statusKey,
                  padding: const EdgeInsets.all(BioSenseSpacing.xl),
                  child: Column(children: [
                    // Punto pulsante + estado
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8, spreadRadius: 2)]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEs ? 'ESTADO DEL SISTEMA' : 'SYSTEM STATUS',
                        style: BioSenseText.label),
                    ]),
                    const SizedBox(height: BioSenseSpacing.md),

                    Text(
                      _statusLabel(state.statusKey, isEs),
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700,
                        letterSpacing: -0.5, color: color)),
                    const SizedBox(height: BioSenseSpacing.sm),
                    Text(
                      _statusDesc(state.statusKey, isEs),
                      textAlign: TextAlign.center,
                      style: BioSenseText.body),
                    const SizedBox(height: BioSenseSpacing.xl),

                    // Índice DHSI
                    Text(
                      isEs ? 'Índice Homeostático' : 'Homeostatic Index',
                      style: BioSenseText.label),
                    const SizedBox(height: BioSenseSpacing.sm),
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('${state.dhsiPercentage}',
                        style: BioSenseText.metricXL.copyWith(color: color)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('%', style: BioSenseText.subtitle
                            .copyWith(color: BioSenseColor.textMuted))),
                    ]),
                    const SizedBox(height: BioSenseSpacing.md),

                    // Barra delgada 4px
                    ClipRRect(
                      borderRadius: BorderRadius.circular(BioSenseRadius.full),
                      child: Stack(children: [
                        Container(height: 4, color: BioSenseColor.border),
                        FractionallySizedBox(
                          widthFactor: state.dhsi.clamp(0.0, 1.0),
                          child: AnimatedContainer(
                            duration: BioSenseMotion.slow,
                            height: 4, color: color)),
                      ]),
                    ),

                    if (!app.baselineLocked) ...[
                      const SizedBox(height: BioSenseSpacing.md),
                      Text(
                        isEs
                          ? 'Aprendiendo línea base... (${app.baselineSamples}/30)'
                          : 'Learning baseline... (${app.baselineSamples}/30)',
                        style: BioSenseText.caption.copyWith(
                          color: BioSenseColor.accent)),
                    ],
                  ]),
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // ── ESTADO VIVO DEL SISTEMA
                BioSenseTheme.clinicalCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          isEs ? 'Analizando tendencias...' : 'Analyzing trends...',
                          style: BioSenseText.caption.copyWith(
                            color: BioSenseColor.accent)),
                        const SizedBox(height: 2),
                        Text(
                          isEs ? 'PHSE activo • Modelo actualizado'
                               : 'PHSE active • Model updated',
                          style: BioSenseText.label.copyWith(
                            color: BioSenseColor.primary)),
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                        Text(
                          '${(_sampleCount + 1248).toString()} ${isEs ? "muestras" : "samples"}',
                          style: BioSenseText.metricS.copyWith(
                            color: BioSenseColor.primary)),
                        Text(
                          isEs ? 'procesadas' : 'processed',
                          style: BioSenseText.caption),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: BioSenseSpacing.xxl),

                // ── ENCABEZADO CANALES
                Text(
                  isEs
                    ? 'TELEMETRÍA FISIOLÓGICA EN TIEMPO REAL'
                    : 'REAL-TIME PHYSIOLOGICAL TELEMETRY',
                  style: BioSenseText.label),
                const SizedBox(height: BioSenseSpacing.md),

                // ── CANAL: CARDIOVASCULAR
                _VitalCard(
                  icon: Icons.favorite_outline,
                  label: isEs ? 'Cardiovascular' : 'Cardiovascular',
                  value: '72', unit: 'bpm',
                  sublabel: isEs ? 'Variabilidad HRV' : 'HRV variability',
                  reading: state.hrv,
                  sparkData: _hrvData,
                  confidence: (state.confidenceLevel * 100).clamp(0, 100),
                  isEs: isEs,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // ── CANAL: TEMPERATURA
                _VitalCard(
                  icon: Icons.thermostat_outlined,
                  label: isEs ? 'Temperatura Basal' : 'Baseline Temperature',
                  value: '36.6', unit: '°C',
                  sublabel: isEs ? 'Temperatura corporal' : 'Body temperature',
                  reading: state.temp,
                  sparkData: _tempData,
                  confidence: (state.confidenceLevel * 99.5).clamp(0, 100),
                  isEs: isEs,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // ── CANAL: RESPIRACIÓN
                _VitalCard(
                  icon: Icons.air_outlined,
                  label: isEs ? 'Respiración' : 'Respiratory Rate',
                  value: '16', unit: 'rpm',
                  sublabel: isEs ? 'Frecuencia respiratoria' : 'Respiratory frequency',
                  reading: state.resp,
                  sparkData: _respData,
                  confidence: (state.confidenceLevel * 99.2).clamp(0, 100),
                  isEs: isEs,
                ),
                const SizedBox(height: BioSenseSpacing.md),

                // ── CANAL: GSR/EDA
                _VitalCard(
                  icon: Icons.water_drop_outlined,
                  label: isEs ? 'Respuesta Galvánica' : 'Galvanic Response',
                  value: '1.2', unit: 'µS',
                  sublabel: isEs ? 'Conductancia de la piel' : 'Skin conductance',
                  reading: state.gsr,
                  sparkData: _gsrData,
                  confidence: (state.confidenceLevel * 98.8).clamp(0, 100),
                  isEs: isEs,
                ),
                const SizedBox(height: BioSenseSpacing.xxl),

                // ── MOTOR PREDICTIVO PHSE
                _PhseCard(
                  dhsiData: _dhsiData,
                  confidence: state.confidenceLevel,
                  velocity: state.velocity,
                  jerk: state.jerk,
                  statusKey: state.statusKey,
                  isEs: isEs,
                ),
                const SizedBox(height: BioSenseSpacing.xxl),

                BioSenseTheme.institutionalFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String key, bool isEs) {
    if (isEs) {
      switch (key) {
        case 'fatigue':  return 'VIGILANCIA';
        case 'alert':    return 'PRE-ALERTA';
        case 'danger':   return 'ALERTA';
        case 'critical': return 'CRÍTICO';
        default:         return 'ESTABLE';
      }
    } else {
      switch (key) {
        case 'fatigue':  return 'WATCH';
        case 'alert':    return 'PRE-ALERT';
        case 'danger':   return 'ALERT';
        case 'critical': return 'CRITICAL';
        default:         return 'STABLE';
      }
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
}

// ── Tarjeta de canal vital con sparkline + anillo + confianza
class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label, value, unit, sublabel;
  final ChannelReading reading;
  final List<double> sparkData;
  final double confidence;
  final bool isEs;

  const _VitalCard({
    required this.icon, required this.label,
    required this.value, required this.unit,
    required this.sublabel, required this.reading,
    required this.sparkData, required this.confidence,
    required this.isEs,
  });

  Color get _statusColor {
    switch (reading.status) {
      case ChannelStatus.normal:   return BioSenseColor.stable;
      case ChannelStatus.leve:     return BioSenseColor.warning;
      case ChannelStatus.moderado: return BioSenseColor.alert;
      case ChannelStatus.alto:     return BioSenseColor.critical;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BioSenseTheme.clinicalCard(
      padding: const EdgeInsets.all(BioSenseSpacing.lg),
      child: Column(children: [
        Row(children: [
          // Anillo de estabilidad
          BioSenseTheme.stabilityRing(
            value: reading.status == ChannelStatus.normal ? 1.0
                 : reading.status == ChannelStatus.leve ? 0.75
                 : reading.status == ChannelStatus.moderado ? 0.50 : 0.25,
            statusKey: reading.status == ChannelStatus.normal ? 'stable'
                     : reading.status == ChannelStatus.leve ? 'fatigue'
                     : 'alert',
            size: 44,
          ),
          const SizedBox(width: BioSenseSpacing.md),
          // Etiqueta + métrica
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: BioSenseText.label),
              const SizedBox(height: 2),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value, style: BioSenseText.metricL.copyWith(
                  color: _statusColor)),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 6),
                  child: Text(unit, style: BioSenseText.caption)),
              ]),
              Text(sublabel, style: BioSenseText.caption),
            ],
          )),
          // Icono
          Icon(icon, color: _statusColor.withOpacity(0.4), size: 28),
        ]),
        const SizedBox(height: BioSenseSpacing.md),

        // Sparkline
        SizedBox(height: 36,
          child: BioSenseTheme.sparkline(
            data: sparkData, color: _statusColor)),
        const SizedBox(height: BioSenseSpacing.sm),

        // Barra de confianza
        Row(children: [
          Text(
            isEs ? 'Confianza de lectura:' : 'Reading confidence:',
            style: BioSenseText.caption),
          const Spacer(),
          Text('${confidence.toStringAsFixed(1)}%',
            style: BioSenseText.caption.copyWith(
              color: BioSenseColor.primary, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Motor Predictivo PHSE Card
class _PhseCard extends StatelessWidget {
  final List<double> dhsiData;
  final double confidence, velocity, jerk;
  final String statusKey;
  final bool isEs;

  const _PhseCard({
    required this.dhsiData, required this.confidence,
    required this.velocity, required this.jerk,
    required this.statusKey, required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return BioSenseTheme.clinicalCard(
      color: BioSenseColor.primary.withOpacity(0.03),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(
              color: BioSenseColor.accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            isEs ? 'MOTOR PREDICTIVO PHSE' : 'PHSE PREDICTIVE ENGINE',
            style: BioSenseText.label.copyWith(color: BioSenseColor.primary)),
        ]),
        const SizedBox(height: BioSenseSpacing.lg),

        // Línea temporal
        Row(children: [
          _TimelineNode(
            label: isEs ? 'PASADO' : 'PAST',
            icon: Icons.check_circle_outline,
            color: BioSenseColor.accent, active: false),
          Expanded(child: Container(height: 1, color: BioSenseColor.border)),
          _TimelineNode(
            label: isEs ? 'AHORA' : 'NOW',
            icon: Icons.radio_button_checked,
            color: BioSenseColor.primary, active: true),
          Expanded(child: Container(height: 1,
            color: BioSenseColor.border,
            child: CustomPaint(painter: _DashedLinePainter()))),
          _TimelineNode(
            label: isEs ? 'FUTURO' : 'FUTURE',
            icon: Icons.circle_outlined,
            color: BioSenseColor.textMuted, active: false),
        ]),
        const SizedBox(height: BioSenseSpacing.lg),

        // Sparkline DHSI
        BioSenseTheme.sparkline(data: dhsiData, color: BioSenseColor.primary,
          height: 48),
        const SizedBox(height: BioSenseSpacing.lg),

        // Métricas del motor
        Row(children: [
          _PhseMetric(
            label: isEs ? 'Precisión' : 'Accuracy',
            value: '${(confidence * 100).toStringAsFixed(2)}%',
            color: BioSenseColor.accent),
          const SizedBox(width: BioSenseSpacing.md),
          _PhseMetric(
            label: isEs ? 'Tendencia' : 'Trend',
            value: velocity < -0.002
              ? (isEs ? 'Descendente' : 'Declining')
              : (isEs ? 'Estable' : 'Stable'),
            color: velocity < -0.002
              ? BioSenseColor.warning : BioSenseColor.accent),
          const SizedBox(width: BioSenseSpacing.md),
          _PhseMetric(
            label: isEs ? 'Horizonte' : 'Horizon',
            value: jerk.abs() > 0.008 ? '96 s'
                 : jerk.abs() > 0.003 ? '48 s' : '24 s',
            color: BioSenseColor.primary),
        ]),
        const SizedBox(height: BioSenseSpacing.sm),
        Text(
          isEs
            ? 'Del monitoreo a la anticipación.'
            : 'From monitoring to foresight.',
          style: BioSenseText.caption.copyWith(
            fontStyle: FontStyle.italic, color: BioSenseColor.primary)),
      ]),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  const _TimelineNode({required this.label, required this.icon,
    required this.color, required this.active});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: active ? 22 : 16),
    const SizedBox(height: 4),
    Text(label, style: BioSenseText.label.copyWith(
      color: color, fontSize: 8)),
  ]);
}

class _PhseMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PhseMetric({required this.label, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(BioSenseSpacing.md),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: color.withOpacity(0.15))),
    child: Column(children: [
      Text(value, style: BioSenseText.metricS.copyWith(color: color),
        textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label, style: BioSenseText.caption, textAlign: TextAlign.center),
    ]),
  ));
}

// ── Fondo: retícula hexagonal casi invisible
class _HexGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A3D62).withOpacity(0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const r = 24.0;
    const h = r * 1.732;
    int col = 0;
    for (double x = 0; x < size.width + r * 2; x += r * 1.5) {
      final offsetY = col.isOdd ? h / 2 : 0.0;
      for (double y = -h + offsetY; y < size.height + h; y += h) {
        _drawHex(canvas, paint, Offset(x, y), r);
      }
      col++;
    }
  }

  void _drawHex(Canvas canvas, Paint paint, Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * 3.14159 / 180;
      final px = center.dx + r * _cos(angle);
      final py = center.dy + r * _sin(angle);
      if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  double _cos(double a) => (a < 1.5708 ? 1 - a*a/2 + a*a*a*a/24
    : a < 3.14159 ? -(1-(3.14159-a)*(3.14159-a)/2) : -_cos(a-3.14159));
  double _sin(double a) => _cos(a - 1.5708);


  @override
  bool shouldRepaint(_HexGridPainter _) => false;
}

// ── Línea punteada para el futuro
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BioSenseColor.border
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
      x += 8;
    }
  }
  @override
  bool shouldRepaint(_DashedLinePainter _) => false;
}
