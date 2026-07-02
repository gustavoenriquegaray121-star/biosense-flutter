// ============================================================
// BIOSENSE — History Screen (📊 Historial)
// "Ayer estabas cansado" — lenguaje simple, sin gráficas técnicas.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';

    // En producción esto vendría de SharedPreferences / Firestore
    // con el historial real acumulado por HealthRepository
    final items = _mockHistory(isEs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isEs ? 'Historial' : 'History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _timelineCard(items[i], isEs, i == items.length - 1),
      ),
    );
  }

  List<_HistoryItem> _mockHistory(bool isEs) {
    if (isEs) {
      return [
        _HistoryItem('🟢', 'Hace 3 días', 'Estado normal', const Color(0xFF22C55E)),
        _HistoryItem('🟢', 'Hace 2 días', 'Estado normal', const Color(0xFF22C55E)),
        _HistoryItem('🟡', 'Ayer 3:00 pm', 'Te sentiste cansado', const Color(0xFFFBBF24)),
        _HistoryItem('🟡', 'Ayer 8:00 pm', 'Cansancio leve', const Color(0xFFFBBF24)),
        _HistoryItem('🟢', 'Hoy 8:00 am', 'Recuperado', const Color(0xFF22C55E)),
      ];
    }
    return [
      _HistoryItem('🟢', '3 days ago', 'Normal state', const Color(0xFF22C55E)),
      _HistoryItem('🟢', '2 days ago', 'Normal state', const Color(0xFF22C55E)),
      _HistoryItem('🟡', 'Yesterday 3pm', 'You felt tired', const Color(0xFFFBBF24)),
      _HistoryItem('🟡', 'Yesterday 8pm', 'Mild fatigue', const Color(0xFFFBBF24)),
      _HistoryItem('🟢', 'Today 8am', 'Recovered', const Color(0xFF22C55E)),
    ];
  }

  Widget _timelineCard(_HistoryItem item, bool isEs, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15), shape: BoxShape.circle),
              child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 16)))),
            if (!isLast)
              Expanded(child: Container(width: 2, color: const Color(0xFFE2E8F0))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
                  blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.time, style: const TextStyle(fontSize: 11,
                  color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(item.desc, style: const TextStyle(fontSize: 14,
                  color: Color(0xFF1E293B))),
              ]),
            ),
          )),
        ],
      ),
    );
  }
}

class _HistoryItem {
  final String emoji, time, desc;
  final Color color;
  const _HistoryItem(this.emoji, this.time, this.desc, this.color);
}
