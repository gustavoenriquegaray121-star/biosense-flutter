// ============================================================
// BIOSENSE — DHSI Gauge Widget
// Barra horizontal de colores planos. Sin decimales. Sin ruido.
// ============================================================

import 'package:flutter/material.dart';

class DHSIGauge extends StatelessWidget {
  final int percentage;
  final double height;

  const DHSIGauge({super.key, required this.percentage, this.height = 18});

  Color _colorFor(int pct) {
    if (pct >= 90) return const Color(0xFF22C55E);
    if (pct >= 76) return const Color(0xFFFBBF24);
    if (pct >= 62) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final progress = percentage / 100.0;
    final color = _colorFor(percentage);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(children: [
        Container(height: height, color: const Color(0xFFE2E8F0)),
        AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(height: height, color: color),
        ),
      ]),
    );
  }
}
