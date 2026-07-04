// ============================================================
// BIOSENSE — Quick Log Bar (Bitácora Rápida)
// Un toque → registra el evento → el algoritmo lo descuenta
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../core/event_log.dart';

class QuickLogBar extends StatelessWidget {
  final EventLog eventLog;
  final VoidCallback onEventAdded;

  const QuickLogBar({
    super.key,
    required this.eventLog,
    required this.onEventAdded,
  });

  static List<_Btn> buttons(bool isEs) => [
    _Btn(EventType.cafe,      '☕', isEs ? 'Café'      : 'Coffee'),
    _Btn(EventType.ejercicio, '🏃', isEs ? 'Ejercicio' : 'Exercise'),
    _Btn(EventType.estres,    '⚡', isEs ? 'Estrés'    : 'Stress'),
    _Btn(EventType.medicina,  '💊', isEs ? 'Medicina'  : 'Medicine'),
    _Btn(EventType.comida,    '🍽️', isEs ? 'Comida'    : 'Food'),
    _Btn(EventType.suenoMal,  '😴', isEs ? 'Mal sueño' : 'Bad sleep'),
  ];

  @override
  Widget build(BuildContext context) {
    final isEs      = context.read<AppStateProvider>().language.name == 'es';
    final correction = eventLog.getActiveCorrection();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
          blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📋', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(child: Text(
            isEs ? '¿Qué hiciste hace poco?' : 'What did you do recently?',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: Color(0xFF1F4E79)))),
          if (correction.hasCorrection)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E75B6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Text('${correction.activeCount} activo${correction.activeCount > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF2E75B6),
                  fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        Text(
          isEs
            ? 'BioSense descuenta estos factores del análisis'
            : 'BioSense removes these factors from the analysis',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 12),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, childAspectRatio: 2.2,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          children: buttons(isEs).map((btn) {
            final isActive = eventLog.activeEvents.any((e) => e.type == btn.type);
            return GestureDetector(
              onTap: () async {
                await context.read<AppStateProvider>().toggleEvent(btn.type);
                onEventAdded();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEs ? '${btn.emoji} ${btn.label} registrado ✅' : '${btn.emoji} ${btn.label} logged ✅'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF1F4E79),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                    ? const Color(0xFF1F4E79).withOpacity(0.08)
                    : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                      ? const Color(0xFF1F4E79)
                      : const Color(0xFFE2E8F0),
                    width: isActive ? 1.5 : 1)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(btn.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Text(btn.label, style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                      ? const Color(0xFF1F4E79)
                      : const Color(0xFF374151))),
                ]),
              ),
            );
          }).toList(),
        ),

        if (correction.hasCorrection) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2E75B6).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E75B6).withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                isEs
                  ? isEs ? '🔬 BioSense está descontando:' : '🔬 BioSense is removing:'
                  : '🔬 BioSense is removing:',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFF2E75B6))),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4,
                children: correction.activeLabels.map((l) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E75B6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(l, style: const TextStyle(fontSize: 11,
                    color: Color(0xFF2E75B6))))).toList()),
              const SizedBox(height: 4),
              Text(
                isEs
                  ? isEs ? 'La alerta ya tiene estos factores eliminados.' : 'The alert already has these factors removed.'
                  : 'The alert already has these factors removed.',
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B),
                  fontStyle: FontStyle.italic)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Btn {
  final EventType type;
  final String emoji, label;
  const _Btn(this.type, this.emoji, this.label);
}
