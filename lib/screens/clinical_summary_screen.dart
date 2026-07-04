// ============================================================
// BIOSENSE — Clinical Summary Screen (👨‍⚕️ Médico)
// Botón gigante: "Resumen Clínico (30 segundos)"
// Luego, si el médico quiere, va al detalle completo.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_state_provider.dart';
import '../models/health_state.dart';

class ClinicalSummaryScreen extends StatelessWidget {
  const ClinicalSummaryScreen({super.key});

  Color _statusColor(String key) {
    switch (key) {
      case 'fatigue':  return const Color(0xFFFBBF24);
      case 'alert':    return const Color(0xFFF97316);
      case 'danger':   return const Color(0xFFEF4444);
      case 'critical': return const Color(0xFF9333EA);
      default:         return const Color(0xFF22C55E);
    }
  }

  String _emoji(String key) {
    switch (key) {
      case 'fatigue':  return '🟡';
      case 'alert':    return '🟠';
      case 'danger':   return '🔴';
      case 'critical': return '🚨';
      default:         return '🟢';
    }
  }

  String _channelLabel(String ch, bool isEs) {
    const es = {'hrv': 'Variabilidad cardíaca', 'temp': 'Temperatura',
      'resp': 'Respiración', 'gsr': 'Respuesta de la piel'};
    const en = {'hrv': 'Heart variability', 'temp': 'Temperature',
      'resp': 'Breathing', 'gsr': 'Skin response'};
    return (isEs ? es : en)[ch]!;
  }

  String _dominantChannel(HealthState s) {
    final deltas = {
      'hrv':  (s.hrv.value - 1.0).abs(),
      'temp': (s.temp.value - 1.0).abs(),
      'resp': (s.resp.value - 1.0).abs(),
      'gsr':  (s.gsr.value - 1.0).abs(),
    };
    return deltas.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';
    final color = _statusColor(state.statusKey);
    final dominant = _dominantChannel(state);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isEs ? 'Para el médico' : 'For the doctor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B))),
            child: Text(
              isEs
                ? '⚠️ Información de apoyo. BioSense no diagnostica. La interpretación clínica corresponde al profesional de la salud.'
                : '⚠️ Supporting information. BioSense does not diagnose. Clinical interpretation belongs to the healthcare professional.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
          ),
          const SizedBox(height: 16),

          // RESUMEN CLÍNICO 30 SEGUNDOS
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.10), Colors.white],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.4), width: 2)),
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('⏱️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  isEs ? 'Resumen Clínico (30 segundos)' : 'Clinical Summary (30 seconds)',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79))),
              ]),
              const SizedBox(height: 18),
              _summaryRow(isEs ? 'Paciente' : 'Patient', app.userName),
              _summaryRow(isEs ? 'Estado' : 'Status', '${_emoji(state.statusKey)} ${state.dhsiPercentage}%'),
              _summaryRow(isEs ? 'Inicio de desviación' : 'Deviation onset',
                isEs ? 'Hace ~${_hoursAgo(state)} horas' : '~${_hoursAgo(state)} hours ago'),
              _summaryRow(isEs ? 'Canal dominante' : 'Dominant channel',
                _channelLabel(dominant, isEs)),
              _summaryRow(isEs ? 'Velocidad' : 'Velocity',
                state.velocity < -0.002
                  ? (isEs ? 'Alta' : 'High')
                  : state.velocity < -0.0005
                    ? (isEs ? 'Media' : 'Medium')
                    : (isEs ? 'Baja' : 'Low')),
              _summaryRow(isEs ? 'Jerk' : 'Jerk',
                state.jerk < 0
                  ? (isEs ? 'Ascendente ↗' : 'Ascending ↗')
                  : (isEs ? 'Estable →' : 'Stable →')),
              _summaryRow(isEs ? 'Nivel de confianza' : 'Confidence level',
                '${(state.confidenceLevel * 100).round()}%'),
            ]),
          ),
          const SizedBox(height: 16),

          // POR QUÉ
          Container(
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isEs ? '¿Por qué BioSense emitió esta evaluación?'
                       : 'Why did BioSense issue this evaluation?',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(0xFF1F4E79))),
              const SizedBox(height: 10),
              ..._reasons(state, isEs).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF2E75B6),
                    fontWeight: FontWeight.bold)),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 13,
                    color: Color(0xFF374151), height: 1.4))),
                ]),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _generatePdf(context, app, state, isEs),
              icon: const Text('📄', style: TextStyle(fontSize: 20)),
              label: Text(isEs ? 'Generar Reporte PDF' : 'Generate PDF Report',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  int _hoursAgo(HealthState s) {
    // Estimación simple basada en velocidad de deriva
    if (s.velocity >= 0) return 0;
    final est = (1.0 - s.dhsi) / s.velocity.abs() / 10;
    return est.clamp(1, 72).round();
  }

  List<String> _reasons(HealthState s, bool isEs) {
    final List<String> r = [];
    if (s.hrv.status != ChannelStatus.normal) {
      r.add(isEs
        ? 'Reducción de la variabilidad de la frecuencia cardíaca respecto a la línea base'
        : 'Reduced heart rate variability compared to baseline');
    }
    if (s.temp.status != ChannelStatus.normal) {
      r.add(isEs
        ? 'Incremento de la temperatura corporal basal'
        : 'Increase in baseline body temperature');
    }
    if (s.resp.status != ChannelStatus.normal) {
      r.add(isEs
        ? 'Alteración del patrón respiratorio'
        : 'Altered breathing pattern');
    }
    if (s.gsr.status != ChannelStatus.normal) {
      r.add(isEs
        ? 'Incremento sostenido de la respuesta galvánica de la piel'
        : 'Sustained increase in galvanic skin response');
    }
    if (r.isEmpty) {
      r.add(isEs ? 'Parámetros dentro de rangos normales' : 'Parameters within normal ranges');
    }
    return r;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B))),
      ]),
    );
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
        color: PdfColor.fromHex('1F4E79'),
        padding: const pw.EdgeInsets.all(16),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BioSense Clinical Report',
              style: pw.TextStyle(fontSize: 20,
                fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.Text('ALTEA-GARAY HTS',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
          ])),
      pw.SizedBox(height: 16),
      pw.Text(isEs ? 'Paciente: ' + app.userName : 'Patient: ' + app.userName),
      pw.Text(isEs ? 'Fecha: ' + dateStr : 'Date: ' + dateStr),
      pw.SizedBox(height: 12),
      pw.Text(isEs ? 'ESTADO FISIOLÓGICO' : 'PHYSIOLOGICAL STATUS',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('DHSI: ' + state.dhsi.toStringAsFixed(3) + ' (' + state.dhsiPercentage.toString() + '%)'),
      pw.Text((isEs ? 'Confianza del modelo: ' : 'Model confidence: ') + (state.confidenceLevel * 100).round().toString() + '%'),
      pw.SizedBox(height: 12),
      pw.Text(isEs ? 'VARIABLES MONITORIZADAS' : 'MONITORED VARIABLES',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text((isEs ? 'Variabilidad FC (HRV): ' : 'Heart Rate Variability: ') + state.hrv.label),
      pw.Text((isEs ? 'Temperatura basal: ' : 'Baseline temperature: ') + state.temp.label),
      pw.Text((isEs ? 'Patrón respiratorio: ' : 'Breathing pattern: ') + state.resp.label),
      pw.Text((isEs ? 'Respuesta galvánica (GSR): ' : 'Galvanic skin response: ') + state.gsr.label),
      pw.SizedBox(height: 12),
      pw.Text(isEs ? 'FACTORES DETECTADOS' : 'DETECTED FACTORS',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
    ];

    for (final r in _reasons(state, isEs)) {
      lines.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text('• ' + r, style: pw.TextStyle(fontSize: 11))));
    }

    lines.addAll([
      pw.SizedBox(height: 16),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: PdfColors.grey100,
        child: pw.Text(
          isEs
            ? 'AVISO: Este reporte es informativo. BioSense no emite diagnósticos médicos. La interpretación clínica corresponde exclusivamente al profesional de la salud.'
            : 'NOTICE: This report is informational. BioSense does not issue medical diagnoses. Clinical interpretation belongs exclusively to the healthcare professional.',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
      pw.SizedBox(height: 8),
      pw.Text('USPTO #63/914,860 | ALTEA-GARAY HTS',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ]);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: lines)));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'BioSense_Report_' + app.userName + '.pdf',
    );
  }
}
