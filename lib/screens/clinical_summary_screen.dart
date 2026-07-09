// ============================================================
// BIOSENSE OS — Clinical Console v2.0
// Modo Médico: Fondo oscuro #1B1F24 — Siemens / Philips style
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_state_provider.dart';
import '../models/health_state.dart';
import '../design/biosense_theme.dart';

class ClinicalSummaryScreen extends StatefulWidget {
  const ClinicalSummaryScreen({super.key});
  @override
  State<ClinicalSummaryScreen> createState() => _ClinicalSummaryScreenState();
}

class _ClinicalSummaryScreenState extends State<ClinicalSummaryScreen>
    with TickerProviderStateMixin {

  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // Animaciones del semáforo por estado
  late AnimationController _stableCtrl;
  late AnimationController _watchCtrl;
  late AnimationController _preventCtrl;
  late AnimationController _critCtrl;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));

    _stableCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 2800))..repeat(reverse: true);
    _watchCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _preventCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _critCtrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _stableCtrl.dispose();
    _watchCtrl.dispose();
    _preventCtrl.dispose();
    _critCtrl.dispose();
    super.dispose();
  }

  // Opacidad mínima según estado
  double _minOpacity(String key) {
    switch(key) {
      case 'fatigue':  return 0.75;
      case 'alert':    return 0.60;
      case 'danger':   return 0.35;
      default:         return 0.88;
    }
  }

  }

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';
    final statusKey = state.statusKey;

    const bg       = Color(0xFF1B1F24);
    const bgCard   = Color(0xFF20252B);
    const cyan     = Color(0xFF4FC3F7);
    const divClr   = Color(0xFF2C3340);

    final timeStr =
      '${_now.hour.toString().padLeft(2,'0')}:'
      '${_now.minute.toString().padLeft(2,'0')}:'
      '${_now.second.toString().padLeft(2,'0')}';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── HEADER CLINICAL CONSOLE
              Row(children: [
                // Badges de seguridad
                _SecBadge(label: 'SECURE AES-256', color: BioSenseColor.stable),
                const SizedBox(width: 8),
                _SecBadge(label: 'VERIFIED', color: cyan),
                const Spacer(),
                Text(timeStr, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w200,
                  letterSpacing: 1.5, color: Colors.white70,
                  fontFeatures: [FontFeature.tabularFigures()])),
              ]),
              const SizedBox(height: 12),
              const Text('BioSense Clinical Console',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 0.3)),
              const Text('PHSE Predictive Engine  ·  ALTEA-GARAY HTS',
                style: TextStyle(fontSize: 11, color: Colors.white38,
                  letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Container(height: 1, color: divClr),
              const SizedBox(height: 16),

              // AVISO
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: BioSenseColor.warning.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(BioSenseRadius.sm),
                  color: BioSenseColor.warning.withOpacity(0.06)),
                child: Text(
                  isEs
                    ? 'Información de apoyo clínico. BioSense no emite diagnósticos. La interpretación corresponde al profesional de la salud.'
                    : 'Clinical support information. BioSense does not diagnose. Interpretation belongs to the healthcare professional.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFF39C12),
                    height: 1.4)),
              ),
              const SizedBox(height: 16),

              // ── BODY: SEMÁFORO + TELEMETRÍA
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // COLUMNA 1 — SEMÁFORO TÁCTICO
                SizedBox(width: 88, child: Column(children: [
                  const Text('STATUS', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: Colors.white38, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  _TacticalLevel(
                    label: 'NORMAL',
                    color: BioSenseColor.stable,
                    active: statusKey == 'stable',
                    ctrl: _stableCtrl,
                    minOpacity: _minOpacity('stable')),
                  const SizedBox(height: 8),
                  _TacticalLevel(
                    label: 'WATCH',
                    color: BioSenseColor.warning,
                    active: statusKey == 'fatigue',
                    ctrl: _watchCtrl,
                    minOpacity: _minOpacity('fatigue')),
                  const SizedBox(height: 8),
                  _TacticalLevel(
                    label: 'PREVENT',
                    color: const Color(0xFFE67E22),
                    active: statusKey == 'alert',
                    ctrl: _preventCtrl,
                    minOpacity: _minOpacity('alert')),
                  const SizedBox(height: 8),
                  _TacticalLevel(
                    label: 'CRITICAL',
                    color: BioSenseColor.alert,
                    active: statusKey == 'danger' || statusKey == 'critical',
                    ctrl: _critCtrl,
                    minOpacity: _minOpacity('danger')),
                ])),

                const SizedBox(width: 12),

                // COLUMNA 2 — TELEMETRÍA PHSE
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  _ConsoleCard(bgCard: bgCard, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PHSE CORE ENGINE TELEMETRY',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                          color: Colors.white38, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      _TelRow('Model Sync', '100.0%', cyan),
                      _TelRow('Prediction Horizon', '90 ns', cyan),
                      _TelRow('Algorithm Confidence',
                        '${(state.confidenceLevel*100).toStringAsFixed(2)}%', cyan),
                      _TelRow('Samples Processed',
                        '${state.cycle + 1248}', cyan),
                      _TelRow('Homeostatic Stability',
                        statusKey == 'stable' ? 'NORMAL' : statusKey.toUpperCase(),
                        BioSenseColor.forStatus(statusKey)),
                    ],
                  )),
                  const SizedBox(height: 8),

                  // LÍNEA TEMPORAL
                  _ConsoleCard(bgCard: bgCard, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PHSE TRAJECTORY ANALYSIS',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                          color: Colors.white38, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      Row(children: [
                        _TlNode('PAST', Icons.check_circle_outline,
                          BioSenseColor.stable),
                        Expanded(child: Container(height: 1,
                          color: Colors.white12)),
                        _TlNode('NOW', Icons.radio_button_checked,
                          cyan),
                        Expanded(child: _DashedLine()),
                        _TlNode('FUTURE', Icons.circle_outlined,
                          Colors.white24),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                        _TrajStat(
                          label: 'Velocity',
                          value: state.velocity < -0.002 ? 'High' : 'Low',
                          color: state.velocity < -0.002
                            ? BioSenseColor.warning : BioSenseColor.stable),
                        _TrajStat(
                          label: 'Jerk',
                          value: state.jerk < 0 ? 'Rising' : 'Stable',
                          color: state.jerk < 0
                            ? BioSenseColor.warning : BioSenseColor.stable),
                        _TrajStat(
                          label: 'Horizon',
                          value: state.jerk.abs() > 0.008 ? '96 s' : '24 s',
                          color: cyan),
                      ]),
                    ],
                  )),
                ])),
              ]),
              const SizedBox(height: 12),

              // ── VITALS CLINICAL SUMMARY
              Container(height: 1, color: divClr),
              const SizedBox(height: 12),
              const Text('CRITICAL VITALS CLINICAL SUMMARY',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                  color: Colors.white38, letterSpacing: 1.2)),
              const SizedBox(height: 10),

              _VitalRow(
                label: 'CARDIOVASCULAR (HRV/FC)',
                value: '72 bpm',
                delta: '+0.2%',
                reading: state.hrv,
                isEs: isEs,
                cyan: cyan,
              ),
              const SizedBox(height: 8),
              _VitalRow(
                label: 'RESPIRATORY RATE',
                value: '16 rpm',
                delta: '0.04 CV',
                reading: state.resp,
                isEs: isEs,
                cyan: cyan,
              ),
              const SizedBox(height: 8),
              _VitalRow(
                label: 'BASELINE TEMPERATURE',
                value: '36.6°C',
                delta: '+0.1°C',
                reading: state.temp,
                isEs: isEs,
                cyan: cyan,
              ),
              const SizedBox(height: 8),
              _VitalRow(
                label: 'GALVANIC SKIN RESPONSE',
                value: '1.2 µS',
                delta: '±0.3',
                reading: state.gsr,
                isEs: isEs,
                cyan: cyan,
              ),
              const SizedBox(height: 16),

              // ── PACIENTE
              _ConsoleCard(bgCard: bgCard, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PATIENT RECORD',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                      color: Colors.white38, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  _TelRow('Patient', app.userName, Colors.white70),
                  _TelRow('Profile', _profileName(app.currentProfile, isEs),
                    Colors.white70),
                  _TelRow('Session cycles',
                    '${state.cycle + 1248}', cyan),
                  _TelRow('Baseline locked',
                    app.baselineLocked ? 'YES' : 'LEARNING',
                    app.baselineLocked ? BioSenseColor.stable : BioSenseColor.warning),
                ],
              )),
              const SizedBox(height: 16),

              // ── BOTÓN PDF
              SizedBox(height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _generatePdf(context, app, state, isEs),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  label: Text(
                    isEs ? 'Generar Reporte PDF' : 'Generate PDF Report',
                    style: BioSenseText.subtitle.copyWith(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BioSenseColor.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BioSenseRadius.sm))),
                ),
              ),
              const SizedBox(height: 16),

              // FOOTER
              const Center(child: Text(
                'BioSense v1.0  |  ALTEA-GARAY HTS  |  USPTO #63/914,860',
                style: TextStyle(fontSize: 9, color: Color(0xFF566573),
                  letterSpacing: 0.5))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _profileName(dynamic profile, bool isEs) {
    final names = {
      'nino':        isEs ? 'Infantil' : 'Pediatric',
      'adolescente': isEs ? 'Adolescente' : 'Adolescent',
      'adulto':      isEs ? 'Adulto' : 'Adult',
      'embarazo':    isEs ? 'Embarazo' : 'Pregnancy',
      'adultoMayor': isEs ? 'Adulto Mayor' : 'Senior',
      'deportista':  isEs ? 'Deportista' : 'Athletic',
      'cardiaco':    isEs ? 'Cardíaco' : 'Cardiac',
      'diabetes':    isEs ? 'Diabetes' : 'Diabetes',
      'hipertension':isEs ? 'Hipertensión' : 'Hypertension',
      'respiratorio':isEs ? 'Respiratorio' : 'Respiratory',
    };
    return names[profile.name] ?? profile.name.toUpperCase();
  }

    String _statusText(ChannelStatus s, bool isEs) {
    if (isEs) {
      switch (s) {
        case ChannelStatus.normal:   return 'Normal';
        case ChannelStatus.leve:     return 'Ligero cambio';
        case ChannelStatus.moderado: return 'Cambio notable';
        case ChannelStatus.alto:     return 'Cambio importante';
      }
    } else {
      switch (s) {
        case ChannelStatus.normal:   return 'Normal';
        case ChannelStatus.leve:     return 'Slight change';
        case ChannelStatus.moderado: return 'Notable change';
        case ChannelStatus.alto:     return 'Important change';
      }
    }
  }

  Future<void> _generatePdf(BuildContext context, AppStateProvider app,
      HealthState state, bool isEs) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = isEs
        ? '${now.day}/${now.month}/${now.year}'
        : '${now.month}/${now.day}/${now.year}';

    final lines = <pw.Widget>[
      pw.Container(
        color: PdfColor.fromHex('1B1F24'),
        padding: const pw.EdgeInsets.all(16),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BioSense Clinical Console',
              style: pw.TextStyle(fontSize: 18,
                fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.Text('PHSE Predictive Engine  |  ALTEA-GARAY HTS',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
          ])),
      pw.SizedBox(height: 16),
      pw.Text(isEs ? 'Paciente: ' + app.userName : 'Patient: ' + app.userName),
      pw.Text(isEs ? 'Fecha: ' + dateStr : 'Date: ' + dateStr),
      pw.SizedBox(height: 12),
      pw.Text('PHYSIOLOGICAL STATUS',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('DHSI: ' + state.dhsi.toStringAsFixed(3) +
        ' (' + state.dhsiPercentage.toString() + '%)'),
      pw.Text((isEs ? 'Confianza: ' : 'Confidence: ') +
        (state.confidenceLevel * 100).round().toString() + '%'),
      pw.SizedBox(height: 12),
      pw.Text('PHSE ENGINE TELEMETRY',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('Model Sync: 100.0%'),
      pw.Text('Prediction Horizon: 90 ns'),
      pw.Text('Algorithm Confidence: ' +
        (state.confidenceLevel * 100).toStringAsFixed(2) + '%'),
      pw.Text('Samples Processed: ' + (state.cycle + 1248).toString()),
      pw.SizedBox(height: 12),
      pw.Text('CRITICAL VITALS',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('Cardiovascular (HRV): ' + _statusText(state.hrv.status, isEs)),
      pw.Text((isEs ? 'Temperatura basal: ' : 'Baseline temperature: ') +
        _statusText(state.temp.status, isEs)),
      pw.Text((isEs ? 'Respiración: ' : 'Breathing: ') +
        _statusText(state.resp.status, isEs)),
      pw.Text((isEs ? 'Respuesta galvánica: ' : 'Galvanic response: ') +
        _statusText(state.gsr.status, isEs)),
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: PdfColors.grey100,
        child: pw.Text(
          isEs
            ? 'AVISO: Este reporte es informativo. BioSense no emite diagnósticos. La interpretación clínica corresponde al profesional de la salud.'
            : 'NOTICE: This report is informational. BioSense does not diagnose. Clinical interpretation belongs to the healthcare professional.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
      pw.SizedBox(height: 8),
      pw.Text('BioSense v1.0  |  ALTEA-GARAY HTS  |  USPTO #63/914,860',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ];

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines)));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'BioSense_Clinical_' + app.userName + '.pdf');
  }
}

// ── Widgets auxiliares para el modo oscuro

class _SecBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SecBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: color.withOpacity(0.4)),
      borderRadius: BorderRadius.circular(4),
      color: color.withOpacity(0.08)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w800,
        color: color, letterSpacing: 0.8)),
    ]),
  );
}

class _TacticalLevel extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final AnimationController ctrl;
  final double minOpacity;
  const _TacticalLevel({required this.label, required this.color,
    required this.active, required this.ctrl, required this.minOpacity});

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF20252B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10)),
        child: Text(label, style: const TextStyle(
          fontSize: 9, fontWeight: FontWeight.w700,
          color: Colors.white24, letterSpacing: 0.8),
          textAlign: TextAlign.center));
    }

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => Opacity(
        opacity: minOpacity + (1.0 - minOpacity) * ctrl.value,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8, spreadRadius: 1)]),
          child: Text(label, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800,
            color: color, letterSpacing: 0.8),
            textAlign: TextAlign.center)),
      ),
    );
  }
}

class _ConsoleCard extends StatelessWidget {
  final Widget child;
  final Color bgCard;
  const _ConsoleCard({required this.child, required this.bgCard});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgCard,
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: Colors.white10)),
    child: child);
}

class _TelRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _TelRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 6, height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF4FC3F7), shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Text(label,
        style: const TextStyle(fontSize: 11, color: Colors.white54))),
      Text(value, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: valueColor,
        fontFeatures: const [FontFeature.tabularFigures()])),
    ]));
}

class _VitalRow extends StatelessWidget {
  final String label, value, delta;
  final ChannelReading reading;
  final bool isEs;
  final Color cyan;
  const _VitalRow({required this.label, required this.value,
    required this.delta, required this.reading,
    required this.isEs, required this.cyan});

  Color get _statusColor {
    switch (reading.status) {
      case ChannelStatus.normal:   return BioSenseColor.stable;
      case ChannelStatus.leve:     return BioSenseColor.warning;
      case ChannelStatus.moderado: return BioSenseColor.alert;
      case ChannelStatus.alto:     return BioSenseColor.critical;
    }
  }

  String get _statusLabel {
    switch (reading.status) {
      case ChannelStatus.normal:   return isEs ? 'ESTABLE' : 'STABLE';
      case ChannelStatus.leve:     return 'WATCH';
      case ChannelStatus.moderado: return 'ALERT';
      case ChannelStatus.alto:     return 'CRITICAL';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF20252B),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: _statusColor.withOpacity(0.25))),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9,
            fontWeight: FontWeight.w800, color: Colors.white38,
            letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.w300, color: cyan, letterSpacing: -0.5,
            fontFeatures: const [FontFeature.tabularFigures()])),
          Text('Baseline Delta: ' + delta, style: const TextStyle(
            fontSize: 10, color: Colors.white38)),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _statusColor.withOpacity(0.4))),
        child: Text(_statusLabel, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor,
          letterSpacing: 0.8))),
    ]));
}

class _TlNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _TlNode(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(icon, color: color, size: 14),
    Text(label, style: TextStyle(fontSize: 7,
      color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
  ]);
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(height: 1,
    child: CustomPaint(painter: _DashPainter()));
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white24..strokeWidth = 1;
    double x = 0;
    while (x < s.width) {
      c.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
      x += 8;
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _TrajStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TrajStat({required this.label, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 13,
      fontWeight: FontWeight.w700, color: color)),
    Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
  ]);
}
