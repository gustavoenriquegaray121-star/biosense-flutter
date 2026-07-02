// ============================================================
// BIOSENSE — Tips Screen (💡 Consejos)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';
    final tips = _tipsFor(app.healthState.statusKey, isEs);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(isEs ? 'Consejos' : 'Tips')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: tips.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 6)]),
          child: Row(children: [
            Text(tips[i].emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tips[i].title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(tips[i].desc,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B),
                    height: 1.4)),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  List<_Tip> _tipsFor(String statusKey, bool isEs) {
    if (isEs) {
      if (statusKey == 'stable') return [
        _Tip('💧', 'Hidrátate bien', 'Toma al menos 8 vasos de agua al día. Tu cuerpo lo agradece.'),
        _Tip('😴', 'Duerme bien', 'Intenta dormir entre 7 y 8 horas. El sueño es cuando tu cuerpo se repara.'),
        _Tip('🚶', 'Muévete', 'Una caminata de 20 minutos al día hace una gran diferencia.'),
        _Tip('🥦', 'Come bien', 'Incluye frutas y verduras en cada comida.'),
        _Tip('😊', 'Cuida tu mente', 'El estrés también afecta tu cuerpo. Respira, tómate pausas.'),
      ];
      return [
        _Tip('💧', 'Toma agua ahora', 'Hidrátate de inmediato. La deshidratación empeora cualquier malestar.'),
        _Tip('🛋️', 'Descansa', 'Tu cuerpo necesita energía para recuperarse. No te esfuerces hoy.'),
        _Tip('🌡️', 'Observa síntomas', 'Si aparece fiebre, dolor o malestar, consulta a un médico.'),
        _Tip('🍊', 'Come ligero', 'Frutas, caldo, algo suave. Nada pesado por ahora.'),
        _Tip('📞', 'Avisa a alguien', 'Dile a alguien de confianza cómo te sientes hoy.'),
      ];
    }
    if (statusKey == 'stable') return [
      _Tip('💧', 'Stay hydrated', 'Drink at least 8 glasses of water a day.'),
      _Tip('😴', 'Sleep well', 'Aim for 7-8 hours. Sleep is when your body repairs itself.'),
      _Tip('🚶', 'Move around', 'A 20-minute walk daily makes a big difference.'),
      _Tip('🥦', 'Eat well', 'Include fruits and vegetables in every meal.'),
      _Tip('😊', 'Mind your stress', 'Stress affects your body too. Breathe, take breaks.'),
    ];
    return [
      _Tip('💧', 'Drink water now', 'Hydrate immediately. Dehydration worsens any discomfort.'),
      _Tip('🛋️', 'Rest', 'Your body needs energy to recover. Do not push yourself today.'),
      _Tip('🌡️', 'Watch for symptoms', 'If fever, pain or discomfort appears, see a doctor.'),
      _Tip('🍊', 'Eat light', 'Fruits, broth, something gentle. Nothing heavy for now.'),
      _Tip('📞', 'Tell someone', 'Let someone you trust know how you feel today.'),
    ];
  }
}

class _Tip {
  final String emoji, title, desc;
  const _Tip(this.emoji, this.title, this.desc);
}
