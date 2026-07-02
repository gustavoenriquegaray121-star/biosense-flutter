// ============================================================
// BIOSENSE — My Health Screen (❤️ Mi Salud)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/health_state.dart';

class MyHealthScreen extends StatelessWidget {
  const MyHealthScreen({super.key});

  Color _statusColor(ChannelStatus s) {
    switch (s) {
      case ChannelStatus.normal:   return const Color(0xFF22C55E);
      case ChannelStatus.leve:     return const Color(0xFFFBBF24);
      case ChannelStatus.moderado: return const Color(0xFFF97316);
      case ChannelStatus.alto:     return const Color(0xFFEF4444);
    }
  }

  String _statusLabel(ChannelStatus s, bool isEs) {
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

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isEs ? 'Mi Salud' : 'My Health')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(isEs ? '¿Qué está viendo BioSense?' : 'What is BioSense seeing?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: Color(0xFF1F4E79))),
          const SizedBox(height: 16),

          _channelCard('❤️', isEs ? 'Corazón' : 'Heart',
            isEs ? 'Qué tan variable es tu pulso' : 'How variable your pulse is',
            state.hrv.status, isEs),
          _channelCard('🌡️', isEs ? 'Temperatura' : 'Temperature',
            isEs ? 'Temperatura de tu cuerpo' : 'Your body temperature',
            state.temp.status, isEs),
          _channelCard('🫁', isEs ? 'Respiración' : 'Breathing',
            isEs ? 'Cómo estás respirando' : 'How you are breathing',
            state.resp.status, isEs),
          _channelCard('💧', isEs ? 'Estrés' : 'Stress',
            isEs ? 'Nivel de estrés en tu piel' : 'Stress level in your skin',
            state.gsr.status, isEs),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Text('ℹ️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isEs
                  ? 'BioSense compara contigo mismo, no con otras personas. Así detecta cambios reales en tu cuerpo.'
                  : 'BioSense compares you with yourself, not with other people. This way it detects real changes in your body.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E40AF)))),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _channelCard(String emoji, String title, String desc,
      ChannelStatus status, bool isEs) {
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
          blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16,
              fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(_statusLabel(status, isEs),
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
