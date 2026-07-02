// ============================================================
// BIOSENSE — Trend Arrow Widget
// "Eso es donde está la magia de BioSense.
//  No describe el presente. Describe la tendencia."
// ============================================================

import 'package:flutter/material.dart';

class TrendArrow extends StatelessWidget {
  final String trendKey; // 'stable' | 'rising_mild' | 'rising_concern' | 'falling' | 'critical'
  final double size;

  const TrendArrow({super.key, required this.trendKey, this.size = 28});

  (String, Color) _visual() {
    switch (trendKey) {
      case 'stable':
        return ('🟢', const Color(0xFF22C55E));
      case 'rising_mild':
        return ('🟡↗', const Color(0xFFFBBF24));
      case 'rising_concern':
        return ('🟠↗', const Color(0xFFF97316));
      case 'falling':
        return ('🟠↘', const Color(0xFFF97316));
      case 'critical':
        return ('🔴', const Color(0xFFEF4444));
      default:
        return ('🟢', const Color(0xFF22C55E));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = _visual();
    return Container(
      width: size + 16, height: size + 16,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.6)),
      ),
    );
  }
}
