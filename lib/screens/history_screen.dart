// ============================================================
// BIOSENSE OS — History Screen v2.0
// Registro de variaciones fisiológicas — Sin emojis decorativos
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../design/biosense_theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';
    final items = _mockHistory(isEs);

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      appBar: AppBar(
        title: Text(isEs ? 'Historial Fisiológico' : 'Physiological History'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(
              isEs ? 'Últimos 7 días' : 'Last 7 days',
              style: BioSenseText.caption)),
          ),
        ],
      ),
      body: Column(children: [
        // Header descriptivo
        Container(
          color: BioSenseColor.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: BioSenseSpacing.xl, vertical: BioSenseSpacing.md),
          child: Row(children: [
            Container(width: 3, height: 40,
              color: BioSenseColor.primary,
              margin: const EdgeInsets.only(right: BioSenseSpacing.md)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs
                    ? 'Registro de variaciones fisiológicas'
                    : 'Physiological variation log',
                  style: BioSenseText.subtitle),
                Text(
                  isEs
                    ? 'Detectadas por el motor PHSE en tiempo real'
                    : 'Detected by the PHSE engine in real time',
                  style: BioSenseText.caption),
              ],
            )),
          ]),
        ),
        const Divider(height: 1),

        // Timeline
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(BioSenseSpacing.xl),
            itemCount: items.length,
            itemBuilder: (_, i) => _TimelineItem(
              item: items[i],
              isLast: i == items.length - 1,
            ),
          ),
        ),

        BioSenseTheme.institutionalFooter(),
      ]),
    );
  }

  List<_HistItem> _mockHistory(bool isEs) {
    if (isEs) return [
      _HistItem('ESTABLE',    '#0A3D62', 'Hace 3 días  08:00',
        'Sin desviaciones predictivas. Parámetros dentro de rango.',
        BioSenseColor.stable),
      _HistItem('ESTABLE',    '#0A3D62', 'Hace 2 días  08:00',
        'Estado fisiológico óptimo. Sin variaciones relevantes.',
        BioSenseColor.stable),
      _HistItem('VIGILANCIA', '#F39C12', 'Ayer  14:30',
        'Variación preventiva detectada. PHSE emitió alerta temprana.',
        BioSenseColor.warning),
      _HistItem('VIGILANCIA', '#F39C12', 'Ayer  20:15',
        'Fatiga leve persistente. Se recomendó descanso.',
        BioSenseColor.warning),
      _HistItem('ESTABLE',    '#0A3D62', 'Hoy  08:00',
        'Recuperación confirmada. Homeostasis restablecida.',
        BioSenseColor.stable),
    ];
    return [
      _HistItem('STABLE',   '#0A3D62', '3 days ago  08:00',
        'No predictive deviations. Parameters within range.',
        BioSenseColor.stable),
      _HistItem('STABLE',   '#0A3D62', '2 days ago  08:00',
        'Optimal physiological state. No relevant variations.',
        BioSenseColor.stable),
      _HistItem('WATCH',    '#F39C12', 'Yesterday  14:30',
        'Preventive variation detected. PHSE issued early alert.',
        BioSenseColor.warning),
      _HistItem('WATCH',    '#F39C12', 'Yesterday  20:15',
        'Mild persistent fatigue. Rest recommended.',
        BioSenseColor.warning),
      _HistItem('STABLE',   '#0A3D62', 'Today  08:00',
        'Recovery confirmed. Homeostasis reestablished.',
        BioSenseColor.stable),
    ];
  }
}

class _TimelineItem extends StatelessWidget {
  final _HistItem item;
  final bool isLast;
  const _TimelineItem({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Línea temporal
        SizedBox(width: 48, child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 12, height: 12,
              margin: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                color: item.color, shape: BoxShape.circle,
                border: Border.all(color: BioSenseColor.surface, width: 2),
                boxShadow: [BoxShadow(
                  color: item.color.withOpacity(0.3), blurRadius: 4)]),
            ),
            if (!isLast)
              Expanded(child: Center(child: Container(
                width: 1, color: BioSenseColor.border))),
          ],
        )),

        // Contenido
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: BioSenseTheme.clinicalCard(
            animate: false,
            padding: const EdgeInsets.all(BioSenseSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
                      border: Border.all(
                        color: item.color.withOpacity(0.25))),
                    child: Text(item.status,
                      style: BioSenseText.label.copyWith(color: item.color))),
                  const Spacer(),
                  Text(item.time, style: BioSenseText.caption),
                ]),
                const SizedBox(height: BioSenseSpacing.sm),
                Text(item.desc, style: BioSenseText.body),
              ],
            ),
          ),
        )),
      ]),
    );
  }
}

class _HistItem {
  final String status, hex, time, desc;
  final Color color;
  const _HistItem(this.status, this.hex, this.time, this.desc, this.color);
}
