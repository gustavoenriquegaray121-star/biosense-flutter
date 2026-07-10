// ============================================================
// BIOSENSE OS — Tips Screen v2.0
// Recomendaciones para el bienestar — Sin emojis decorativos
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../design/biosense_theme.dart';

class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';
    final tips = _tipsFor(app.healthState.statusKey, isEs);

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      appBar: AppBar(
        title: Text(isEs
          ? 'Recomendaciones para tu Bienestar'
          : 'Wellness Recommendations'),
      ),
      body: Column(children: [
        Container(
          color: BioSenseColor.surface,
          padding: const EdgeInsets.symmetric(
            horizontal: BioSenseSpacing.xl, vertical: BioSenseSpacing.md),
          child: Row(children: [
            Container(width: 3, height: 40, color: BioSenseColor.accent,
              margin: const EdgeInsets.only(right: BioSenseSpacing.md)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs
                    ? 'Basadas en tu estado predictivo actual'
                    : 'Based on your current predictive status',
                  style: BioSenseText.subtitle),
                Text(
                  isEs
                    ? 'El motor PHSE adapta las recomendaciones en tiempo real'
                    : 'The PHSE engine adapts recommendations in real time',
                  style: BioSenseText.caption),
              ],
            )),
          ]),
        ),
        const Divider(height: 1),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(BioSenseSpacing.xl),
            itemCount: tips.length,
            separatorBuilder: (_, __) =>
              const SizedBox(height: BioSenseSpacing.md),
            itemBuilder: (_, i) {
              final colors = [
                BioSenseColor.accent,
                BioSenseColor.primary,
                BioSenseColor.warning,
                BioSenseColor.accentDark,
                BioSenseColor.primaryLight,
              ];
              final c = colors[i % colors.length];
              return Container(
                decoration: BoxDecoration(
                  color: c.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(BioSenseRadius.md),
                  border: Border.all(color: c.withOpacity(0.25)),
                  boxShadow: [BoxShadow(
                    color: c.withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0,4))]),
                padding: const EdgeInsets.all(BioSenseSpacing.lg),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
                      border: Border.all(color: c.withOpacity(0.3))),
                    child: Icon(tips[i].icon, color: c, size: 24)),
                  const SizedBox(width: BioSenseSpacing.md),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tips[i].title,
                        style: BioSenseText.subtitle.copyWith(color: c)),
                      const SizedBox(height: 4),
                      Text(tips[i].desc, style: BioSenseText.body),
                    ])),
                ]),
              );
            },
          ),
        ),
        BioSenseTheme.institutionalFooter(),
      ]),
    );
  }

  List<_Tip> _tipsFor(String statusKey, bool isEs) {
    if (isEs) {
      if (statusKey == 'stable') return [
        _Tip(Icons.water_drop_outlined, 'Hidratación adecuada',
          'Se recomiendan al menos 8 vasos de agua al día para el correcto funcionamiento de su organismo.'),
        _Tip(Icons.nightlight_outlined, 'Ciclo de sueño reparador',
          'Un ciclo de sueño de 7 a 8 horas es fundamental para la regeneración celular y la estabilidad homeostática.'),
        _Tip(Icons.directions_walk_outlined, 'Actividad física moderada',
          'Una caminata de 20 a 30 minutos activa la circulación y favorece la variabilidad de la frecuencia cardíaca.'),
        _Tip(Icons.spa_outlined, 'Gestión del estrés',
          'Las técnicas de respiración diafragmática reducen la activación simpática y estabilizan la respuesta galvánica.'),
        _Tip(Icons.eco_outlined, 'Nutrición equilibrada',
          'Una dieta rica en micronutrientes favorece la estabilidad de los marcadores fisiológicos monitorizados.'),
      ];
      return [
        _Tip(Icons.water_drop_outlined, 'Hidratación inmediata',
          'Ingiera agua de forma inmediata. La deshidratación acelera la desviación homeostática detectada.'),
        _Tip(Icons.bed_outlined, 'Descanso prioritario',
          'El sistema requiere recuperación. Evite el esfuerzo físico hasta que el índice DHSI retorne a rango estable.'),
        _Tip(Icons.thermostat_outlined, 'Monitoreo de temperatura',
          'Observe si aparece elevación térmica. El canal de temperatura es el primer marcador de proceso inflamatorio.'),
        _Tip(Icons.restaurant_outlined, 'Alimentación ligera',
          'Priorice alimentos de fácil digestión. El esfuerzo metabólico postprandial puede agravar la desviación.'),
        _Tip(Icons.phone_outlined, 'Notificación a su red de apoyo',
          'Considere informar a su red de acompañamiento seguro sobre su estado fisiológico actual.'),
      ];
    }
    if (statusKey == 'stable') return [
      _Tip(Icons.water_drop_outlined, 'Adequate hydration',
        'At least 8 glasses of water per day are recommended for proper organ function.'),
      _Tip(Icons.nightlight_outlined, 'Restorative sleep cycle',
        'A 7 to 8 hour sleep cycle is essential for cellular regeneration and homeostatic stability.'),
      _Tip(Icons.directions_walk_outlined, 'Moderate physical activity',
        'A 20 to 30 minute walk improves circulation and heart rate variability.'),
      _Tip(Icons.spa_outlined, 'Stress management',
        'Diaphragmatic breathing techniques reduce sympathetic activation and stabilize galvanic response.'),
      _Tip(Icons.eco_outlined, 'Balanced nutrition',
        'A micronutrient-rich diet supports the stability of monitored physiological markers.'),
    ];
    return [
      _Tip(Icons.water_drop_outlined, 'Immediate hydration',
        'Drink water immediately. Dehydration accelerates the detected homeostatic deviation.'),
      _Tip(Icons.bed_outlined, 'Priority rest',
        'System recovery required. Avoid physical exertion until DHSI returns to stable range.'),
      _Tip(Icons.thermostat_outlined, 'Temperature monitoring',
        'Observe for thermal elevation. Temperature is the primary marker of inflammatory processes.'),
      _Tip(Icons.restaurant_outlined, 'Light nutrition',
        'Prioritize easily digestible foods. Postprandial metabolic effort may worsen the deviation.'),
      _Tip(Icons.phone_outlined, 'Notify your support network',
        'Consider informing your trusted care network about your current physiological status.'),
    ];
  }
}

class _Tip {
  final IconData icon;
  final String title, desc;
  const _Tip(this.icon, this.title, this.desc);
}
