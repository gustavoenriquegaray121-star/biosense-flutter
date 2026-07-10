// ============================================================
// BIOSENSE OS — History Screen v3.0 Premium
// Timeline elegante con colores semánticos por estado
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
            child: Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BioSenseColor.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(BioSenseRadius.full),
                border: Border.all(color: BioSenseColor.primary.withOpacity(0.2))),
              child: Text(
                isEs ? 'Últimos 7 días' : 'Last 7 days',
                style: BioSenseText.caption.copyWith(
                  color: BioSenseColor.primary, fontWeight: FontWeight.w700))))),
        ],
      ),
      body: CustomPaint(
        painter: _HexBgPainter(),
        child: Column(children: [
          // Header descriptivo
          Container(
            color: BioSenseColor.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: BioSenseSpacing.xl,
              vertical: BioSenseSpacing.md),
            child: Row(children: [
              Container(width: 3, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [BioSenseColor.accentBright, BioSenseColor.accent]),
                  borderRadius: BorderRadius.circular(BioSenseRadius.full)),
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
              ])),
              // Estadística rápida
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${items.length}',
                  style: BioSenseText.metricM.copyWith(
                    color: BioSenseColor.primary)),
                Text(
                  isEs ? 'eventos' : 'events',
                  style: BioSenseText.caption),
              ]),
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
                index: i),
            ),
          ),
          BioSenseTheme.institutionalFooter(),
        ]),
      ),
    );
  }

  List<_HistItem> _mockHistory(bool isEs) {
    if (isEs) return [
      _HistItem('ESTABLE', 'Hace 3 días  08:00',
        'Sin desviaciones predictivas. Parámetros fisiológicos dentro de rango óptimo.',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
      _HistItem('ESTABLE', 'Hace 2 días  08:00',
        'Estado homeostático óptimo. Sin variaciones relevantes. DHSI: 98.7%',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
      _HistItem('VIGILANCIA', 'Ayer  14:30',
        'Variación preventiva detectada por PHSE. Fatiga leve — se recomendó ajuste de actividad.',
        BioSenseColor.warning, Icons.warning_amber_outlined, 'fatigue'),
      _HistItem('VIGILANCIA', 'Ayer  20:15',
        'Fatiga moderada persistente. Trayectoria descendente detectada. Descanso prioritario.',
        BioSenseColor.warning, Icons.warning_amber_outlined, 'fatigue'),
      _HistItem('ESTABLE', 'Hoy  08:00',
        'Recuperación confirmada por PHSE. Homeostasis restablecida. DHSI: 97.2%',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
    ];
    return [
      _HistItem('STABLE', '3 days ago  08:00',
        'No predictive deviations. Physiological parameters within optimal range.',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
      _HistItem('STABLE', '2 days ago  08:00',
        'Optimal homeostatic state. No relevant variations. DHSI: 98.7%',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
      _HistItem('WATCH', 'Yesterday  14:30',
        'Preventive variation detected by PHSE. Mild fatigue — activity adjustment recommended.',
        BioSenseColor.warning, Icons.warning_amber_outlined, 'fatigue'),
      _HistItem('WATCH', 'Yesterday  20:15',
        'Moderate persistent fatigue. Downward trajectory detected. Priority rest.',
        BioSenseColor.warning, Icons.warning_amber_outlined, 'fatigue'),
      _HistItem('STABLE', 'Today  08:00',
        'Recovery confirmed by PHSE. Homeostasis reestablished. DHSI: 97.2%',
        BioSenseColor.stable, Icons.check_circle_outline, 'stable'),
    ];
  }
}

class _TimelineItem extends StatelessWidget {
  final _HistItem item;
  final bool isLast;
  final int index;
  const _TimelineItem({required this.item, required this.isLast,
    required this.index});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Línea temporal
        SizedBox(width: 52, child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
          const SizedBox(height: 14),
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(
              color: item.color, shape: BoxShape.circle,
              border: Border.all(color: BioSenseColor.surface, width: 2.5),
              boxShadow: [BoxShadow(
                color: item.color.withOpacity(0.35),
                blurRadius: 8, spreadRadius: 1)])),
          if (!isLast)
            Expanded(child: Center(child: Container(
              width: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [item.color.withOpacity(0.5), Colors.transparent]))))),
        ])),

        // Tarjeta de evento
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(BioSenseRadius.md),
              border: Border.all(color: item.color.withOpacity(0.22)),
              boxShadow: [BoxShadow(
                color: item.color.withOpacity(0.08),
                blurRadius: 12, offset: const Offset(0,3))]),
            padding: const EdgeInsets.all(BioSenseSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(children: [
                Icon(item.icon, color: item.color, size: 16),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(BioSenseRadius.full),
                    border: Border.all(color: item.color.withOpacity(0.3))),
                  child: Text(item.status, style: TextStyle(
                    fontFamily: 'Inter', fontSize: 9,
                    fontWeight: FontWeight.w800, color: item.color,
                    letterSpacing: 0.8))),
                const Spacer(),
                Text(item.time, style: BioSenseText.caption),
              ]),
              const SizedBox(height: BioSenseSpacing.sm),
              Text(item.desc, style: BioSenseText.body),
            ]),
          ),
        )),
      ]),
    );
  }
}

class _HistItem {
  final String status, time, desc, statusKey;
  final Color color;
  final IconData icon;
  const _HistItem(this.status, this.time, this.desc,
    this.color, this.icon, this.statusKey);
}

class _HexBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF0A3D62).withOpacity(0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const r = 22.0;
    const h = r * 1.732;
    int col = 0;
    for (double x = 0; x < size.width+r*2; x += r*1.5) {
      final oy = col.isOdd ? h/2 : 0.0;
      for (double y = -h+oy; y < size.height+h; y += h) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i*60-30)*3.14159265/180;
          final px = x + r*_c(a);
          final py = y + r*_s(a);
          if (i==0) path.moveTo(px,py); else path.lineTo(px,py);
        }
        path.close();
        canvas.drawPath(path, p);
      }
      col++;
    }
  }
  double _c(double a) {
    final t = a % (2*3.14159265);
    return 1-t*t/2+t*t*t*t/24-t*t*t*t*t*t/720;
  }
  double _s(double a) => _c(a-1.5707963);
  @override
  bool shouldRepaint(_HexBgPainter _) => false;
}
