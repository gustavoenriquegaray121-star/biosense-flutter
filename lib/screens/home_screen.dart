// ============================================================
// BIOSENSE OS — Home Screen v3.0 Premium
// Count-up animations, glassmorphism, critical mode, Inter font
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/quick_log_bar.dart';
import '../design/biosense_theme.dart';
import '../widgets/secure_link_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {

  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  double _readingMs = 0.0;
  int _sampleCount = 0;

  // Count-up animation
  late AnimationController _countUpCtrl;
  late Animation<double> _dhsiAnim;
  late Animation<double> _samplesAnim;

  // Fade-in for cards
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Pulse for status dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _initialized = false;

  // Historial DHSI 24h (144 puntos = cada 10 min)
  final List<double> _dhsi24h = List.generate(144, (i) {
    // Simulación realista: baja un poco en la madrugada, sube en el día
    final hour = (i * 10 / 60) % 24;
    if (hour < 6)  return 0.88 + (i % 5) * 0.005;
    if (hour < 12) return 0.92 + (i % 7) * 0.004;
    if (hour < 18) return 0.95 + (i % 4) * 0.003;
    return 0.91 + (i % 6) * 0.004;
  });

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _readingMs = (_readingMs + 0.1) % 10.0;
        if (_initialized) _sampleCount = 1248 + (_now.millisecond ~/ 5);
      });
    });

    // Count-up: DHSI de 0 a valor real
    _countUpCtrl = AnimationController(
      vsync: this, duration: BioSenseMotion.countUp);
    _dhsiAnim = Tween<double>(begin: 0, end: 1.0)
        .animate(CurvedAnimation(parent: _countUpCtrl, curve: Curves.easeOut));
    _samplesAnim = Tween<double>(begin: 0, end: 1248)
        .animate(CurvedAnimation(parent: _countUpCtrl, curve: Curves.easeOut));

    // Fade cards
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    // Pulse dot
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    // La velocidad del pulse depende del estado
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start sequence
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _fadeCtrl.forward();
      _countUpCtrl.forward();
      setState(() => _initialized = true);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _countUpCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app   = context.watch<AppStateProvider>();
    final state = app.healthState;
    final isEs  = app.language.name == 'es';
    final isCrit = BioSenseColor.isCritical(state.statusKey);
    final color  = BioSenseColor.forStatus(state.statusKey);

    // Modo crítico: scaffold rojo oscuro
    final scaffoldColor = isCrit
        ? BioSenseColor.criticalBg
        : BioSenseColor.bgPrimary;

    final timeStr =
      '${_now.hour.toString().padLeft(2,'0')}:'
      '${_now.minute.toString().padLeft(2,'0')}:'
      '${_now.second.toString().padLeft(2,'0')}';

    return AnimatedContainer(
      duration: BioSenseMotion.slow,
      color: scaffoldColor,
      child: CustomPaint(
        painter: _HexGridPainter(critical: isCrit),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(BioSenseSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      RichText(text: TextSpan(children: [
                        TextSpan(text: 'Bio',
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 26,
                            fontWeight: FontWeight.w300,
                            color: isCrit ? Colors.red[200] : BioSenseColor.primary,
                            letterSpacing: -0.5)),
                        TextSpan(text: 'Sense',
                          style: TextStyle(
                            fontFamily: 'Inter', fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isCrit ? Colors.red[400] : BioSenseColor.accent,
                            letterSpacing: -0.5)),
                      ])),
                      Text('Predictive Vital Monitoring System',
                        style: BioSenseText.caption.copyWith(
                          color: isCrit ? Colors.white38 : BioSenseColor.textMuted,
                          letterSpacing: 0.3)),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                      Text(timeStr, style: TextStyle(
                        fontFamily: 'Inter', fontSize: 22,
                        fontWeight: FontWeight.w200, letterSpacing: 2,
                        color: isCrit ? Colors.white70 : BioSenseColor.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                      Text(
                        isEs
                          ? 'Última lectura: ${_readingMs.toStringAsFixed(2)} s'
                          : 'Last reading: ${_readingMs.toStringAsFixed(2)} s',
                        style: BioSenseText.caption.copyWith(
                          color: isCrit ? Colors.white38 : null)),
                    ]),
                  ]),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── TARJETA ESTADO PRINCIPAL
                  BioSenseTheme.clinicalCard(
                    statusKey: state.statusKey,
                    glass: true,
                    padding: const EdgeInsets.all(BioSenseSpacing.xxl),
                    child: Column(children: [

                      // Punto pulsante animado
                      Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Opacity(
                            opacity: _pulseAnim.value,
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 10, spreadRadius: 2)]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEs ? 'ESTADO DEL SISTEMA' : 'SYSTEM STATUS',
                          style: BioSenseText.label.copyWith(
                            color: isCrit ? Colors.white54 : null)),
                      ]),
                      const SizedBox(height: BioSenseSpacing.md),

                      // Estado clínico — tamaño grande, protagonista
                      AnimatedDefaultTextStyle(
                        duration: BioSenseMotion.slow,
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 32,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          color: color),
                        child: Text(_statusLabel(state.statusKey, isEs))),
                      const SizedBox(height: BioSenseSpacing.sm),
                      Text(
                        _statusDesc(state.statusKey, isEs),
                        textAlign: TextAlign.center,
                        style: BioSenseText.body.copyWith(
                          color: isCrit ? Colors.white60 : null)),
                      const SizedBox(height: BioSenseSpacing.xxl),

                      // Índice — count-up de 0 a valor
                      Text(
                        isEs ? 'ÍNDICE HOMEOSTÁTICO' : 'HOMEOSTATIC INDEX',
                        style: BioSenseText.label.copyWith(
                          color: isCrit ? Colors.white38 : null)),
                      const SizedBox(height: BioSenseSpacing.sm),

                      AnimatedBuilder(
                        animation: _dhsiAnim,
                        builder: (_, __) {
                          final displayVal = (_dhsiAnim.value * state.dhsiPercentage).round();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                            Text('$displayVal',
                              style: TextStyle(
                                fontFamily: 'Inter', fontSize: 72,
                                fontWeight: FontWeight.w200,
                                letterSpacing: -3, color: color,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text('%',
                                style: BioSenseText.subtitle.copyWith(
                                  color: BioSenseColor.textMuted,
                                  fontSize: 20))),
                          ]);
                        },
                      ),
                      const SizedBox(height: BioSenseSpacing.md),

                      // Barra con gradiente verde
                      BioSenseTheme.gradientBar(
                        value: state.dhsi.clamp(0.0, 1.0), color: color),
                      const SizedBox(height: BioSenseSpacing.sm),

                      // Health Confidence — secundario, más pequeño
                      Text(
                        'Health Confidence: ${(state.confidenceLevel*100).toStringAsFixed(1)}%',
                        style: BioSenseText.caption.copyWith(
                          color: BioSenseColor.accent)),

                      if (!app.baselineLocked) ...[
                        const SizedBox(height: BioSenseSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: BioSenseSpacing.md,
                            vertical: BioSenseSpacing.sm),
                          decoration: BoxDecoration(
                            color: BioSenseColor.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(BioSenseRadius.sm)),
                          child: Text(
                            isEs
                              ? 'Aprendiendo tu línea base fisiológica...\n(${app.baselineSamples}/30 ciclos completados)'
                              : 'Learning your physiological baseline...\n(${app.baselineSamples}/30 cycles completed)',
                            style: BioSenseText.caption,
                            textAlign: TextAlign.center)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: BioSenseSpacing.md),

                  // ── ESTADO VIVO — tarjeta pequeña, jerarquía inferior
                  BioSenseTheme.clinicalCard(
                    animate: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BioSenseSpacing.lg,
                      vertical: BioSenseSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          isEs
                            ? 'Analizando tendencias fisiológicas...'
                            : 'Analyzing physiological trends...',
                          style: BioSenseText.caption.copyWith(
                            color: BioSenseColor.accent)),
                        Text(
                          isEs
                            ? 'PHSE activo  ·  Modelo actualizado'
                            : 'PHSE active  ·  Model updated',
                          style: BioSenseText.label.copyWith(
                            color: BioSenseColor.primary)),
                      ]),
                      AnimatedBuilder(
                        animation: _samplesAnim,
                        builder: (_, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                          Text(
                            _initialized
                              ? '$_sampleCount'
                              : '${_samplesAnim.value.round()}',
                            style: BioSenseText.metricS.copyWith(
                              color: BioSenseColor.primary)),
                          Text(
                            isEs ? 'muestras' : 'samples',
                            style: BioSenseText.caption),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── BITÁCORA
                  Text(
                    isEs ? 'REGISTRO DE FACTORES' : 'FACTOR LOG',
                    style: BioSenseText.label),
                  const SizedBox(height: BioSenseSpacing.md),
                  QuickLogBar(
                    eventLog: app.eventLog,
                    onEventAdded: () => setState(() {})),
                  const SizedBox(height: BioSenseSpacing.xl),

                  // ── CTA
                  SizedBox(height: 52,
                    child: ElevatedButton(
                      onPressed: () => _showHowIFeel(context, app),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCrit
                          ? BioSenseColor.alert
                          : BioSenseColor.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BioSenseRadius.md))),
                      child: Text(
                        isEs
                          ? 'Registrar Estado Subjetivo'
                          : 'Log Subjective Status',
                        style: BioSenseText.subtitle.copyWith(
                          color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── GRÁFICA DHSI 24 HORAS
                  _Dhsi24hCard(
                    data: _dhsi24h,
                    isEs: isEs,
                    isCrit: isCrit,
                    color: color),
                  const SizedBox(height: BioSenseSpacing.md),

                  // ── BOTÓN SOLICITAR AYUDA
                  _HelpButton(isEs: isEs, isCrit: isCrit),
                  const SizedBox(height: BioSenseSpacing.xxl),

                  // ── PHOENIX SECURELINK
                  SecureLinkCard(isEs: isEs, isCrit: isCrit),
                  const SizedBox(height: BioSenseSpacing.xxl),
                  BioSenseTheme.institutionalFooter(dark: isCrit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String key, bool isEs) {
    switch (key) {
      case 'fatigue':  return isEs ? 'VIGILANCIA' : 'WATCH';
      case 'alert':    return isEs ? 'PRE-ALERTA' : 'PRE-ALERT';
      case 'danger':   return isEs ? 'ALERTA' : 'ALERT';
      case 'critical': return isEs ? 'CRÍTICO' : 'CRITICAL';
      default:         return isEs ? 'ESTABLE' : 'STABLE';
    }
  }

  String _statusDesc(String key, bool isEs) {
    if (isEs) {
      switch (key) {
        case 'fatigue':  return 'Variación preventiva detectada. Ajustar actividad.';
        case 'alert':    return 'Desviación predictiva en desarrollo.';
        case 'danger':   return 'Intervención preventiva recomendada.';
        case 'critical': return 'Alerta crítica. Enlace con especialista requerido.';
        default:         return 'Sin desviaciones predictivas detectadas.';
      }
    } else {
      switch (key) {
        case 'fatigue':  return 'Preventive variation detected. Adjust activity.';
        case 'alert':    return 'Predictive deviation in development.';
        case 'danger':   return 'Preventive intervention recommended.';
        case 'critical': return 'Critical alert. Specialist contact required.';
        default:         return 'No predictive deviations detected.';
      }
    }
  }

  void _showHowIFeel(BuildContext context, AppStateProvider app) {
    final isEs = app.language.name == 'es';
    showModalBottomSheet(
      context: context,
      backgroundColor: BioSenseColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BioSenseRadius.lg))),
      builder: (_) {
        final options = [
          _SubjectiveOption(
            isEs ? 'Estado fisiológico óptimo'  : 'Optimal physiological state',
            0.0, BioSenseColor.accent,   Icons.sentiment_very_satisfied_outlined),
          _SubjectiveOption(
            isEs ? 'Parámetros dentro de rango' : 'Within parameters',
            0.05, BioSenseColor.accent,  Icons.sentiment_satisfied_outlined),
          _SubjectiveOption(
            isEs ? 'Fatiga leve detectada'       : 'Mild fatigue detected',
            0.10, BioSenseColor.warning, Icons.sentiment_neutral_outlined),
          _SubjectiveOption(
            isEs ? 'Fatiga moderada'             : 'Moderate fatigue',
            0.15, BioSenseColor.warning, Icons.sentiment_dissatisfied_outlined),
          _SubjectiveOption(
            isEs ? 'Malestar significativo'      : 'Significant discomfort',
            0.20, BioSenseColor.alert,   Icons.sentiment_very_dissatisfied_outlined),
        ];
        return Container(
          decoration: const BoxDecoration(
            color: BioSenseColor.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(BioSenseRadius.lg))),
          padding: const EdgeInsets.all(BioSenseSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 3,
              decoration: BoxDecoration(
                color: BioSenseColor.border,
                borderRadius: BorderRadius.circular(BioSenseRadius.full))),
            const SizedBox(height: BioSenseSpacing.lg),
            Text(
              isEs ? 'Estado Subjetivo Actual' : 'Current Subjective Status',
              style: BioSenseText.title),
            const SizedBox(height: 4),
            Text(
              isEs
                ? 'Su respuesta calibra el modelo adaptativo.'
                : 'Your response calibrates the adaptive model.',
              style: BioSenseText.caption, textAlign: TextAlign.center),
            const SizedBox(height: BioSenseSpacing.xl),
            ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: BioSenseSpacing.sm),
              child: GestureDetector(
                onTap: () {
                  app.setMockPerturbation(opt.value);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: BioSenseSpacing.lg,
                    vertical: BioSenseSpacing.md),
                  decoration: BoxDecoration(
                    color: opt.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(BioSenseRadius.md),
                    border: Border.all(color: opt.color.withOpacity(0.30))),
                  child: Row(children: [
                    Icon(opt.icon, color: opt.color, size: 22),
                    const SizedBox(width: BioSenseSpacing.md),
                    Text(opt.label,
                      style: BioSenseText.subtitle.copyWith(color: opt.color)),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: BioSenseSpacing.md),
          ]),
        );
      },
    );
  }
}



// ── Gráfica DHSI últimas 24 horas
class _Dhsi24hCard extends StatelessWidget {
  final List<double> data;
  final bool isEs, isCrit;
  final Color color;

  const _Dhsi24hCard({
    required this.data, required this.isEs,
    required this.isCrit, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: isCrit
        ? BioSenseColor.criticalCard
        : color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(color: color.withOpacity(0.22)),
      boxShadow: [BoxShadow(
        color: color.withOpacity(0.08),
        blurRadius: 16, offset: const Offset(0,4))]),
    padding: const EdgeInsets.all(BioSenseSpacing.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Icon(Icons.show_chart_outlined,
          color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          isEs
            ? 'ÍNDICE HOMEOSTÁTICO — ÚLTIMAS 24 H'
            : 'HOMEOSTATIC INDEX — LAST 24 H',
          style: BioSenseText.label.copyWith(color: color)),
      ]),
      const SizedBox(height: BioSenseSpacing.md),

      // Gráfica
      SizedBox(
        height: 80,
        child: BioSenseTheme.sparkline(
          data: data, color: color, height: 80)),
      const SizedBox(height: BioSenseSpacing.sm),

      // Etiquetas de tiempo
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Text('00:00', style: BioSenseText.caption),
        Text('06:00', style: BioSenseText.caption),
        Text('12:00', style: BioSenseText.caption),
        Text('18:00', style: BioSenseText.caption),
        Text(isEs ? 'Ahora' : 'Now',
          style: BioSenseText.caption.copyWith(
            color: color, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: BioSenseSpacing.md),

      // Stats rápidas
      Row(children: [
        _QuickStat(
          label: isEs ? 'Promedio' : 'Average',
          value: '${(data.reduce((a,b) => a+b) / data.length * 100).toStringAsFixed(1)}%',
          color: color),
        const SizedBox(width: BioSenseSpacing.sm),
        _QuickStat(
          label: isEs ? 'Mínimo' : 'Minimum',
          value: '${(data.reduce((a,b) => a<b?a:b) * 100).toStringAsFixed(1)}%',
          color: BioSenseColor.warning),
        const SizedBox(width: BioSenseSpacing.sm),
        _QuickStat(
          label: isEs ? 'Máximo' : 'Maximum',
          value: '${(data.reduce((a,b) => a>b?a:b) * 100).toStringAsFixed(1)}%',
          color: BioSenseColor.accentBright),
      ]),
    ]),
  );
}

class _QuickStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _QuickStat({required this.label, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BioSenseSpacing.sm, vertical: BioSenseSpacing.sm),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(color: color.withOpacity(0.20))),
    child: Column(children: [
      Text(value, style: TextStyle(
        fontFamily: 'Inter', fontSize: 14,
        fontWeight: FontWeight.w700, color: color),
        textAlign: TextAlign.center),
      Text(label, style: BioSenseText.caption,
        textAlign: TextAlign.center),
    ])));
}

// ── Botón Solicitar Ayuda
class _HelpButton extends StatelessWidget {
  final bool isEs, isCrit;
  const _HelpButton({required this.isEs, required this.isCrit});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showHelpDialog(context),
    child: AnimatedContainer(
      duration: BioSenseMotion.slow,
      padding: const EdgeInsets.all(BioSenseSpacing.lg),
      decoration: BoxDecoration(
        color: isCrit
          ? BioSenseColor.alert.withOpacity(0.15)
          : BioSenseColor.alert.withOpacity(0.07),
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        border: Border.all(
          color: BioSenseColor.alert.withOpacity(
            isCrit ? 0.6 : 0.30),
          width: isCrit ? 1.5 : 1.0)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: BioSenseColor.alert.withOpacity(0.15),
            shape: BoxShape.circle),
          child: const Icon(Icons.emergency_outlined,
            color: BioSenseColor.alert, size: 26)),
        const SizedBox(width: BioSenseSpacing.md),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            isEs ? 'Solicitar Ayuda' : 'Request Help',
            style: BioSenseText.subtitle.copyWith(
              color: BioSenseColor.alert,
              fontWeight: FontWeight.w800)),
          Text(
            isEs
              ? 'Notifica inmediatamente a tu Red de Acompañamiento Seguro'
              : 'Immediately notifies your Trusted Care Network',
            style: BioSenseText.caption),
        ])),
        Icon(Icons.chevron_right_outlined,
          color: BioSenseColor.alert.withOpacity(0.5)),
      ]),
    ),
  );

  void _showHelpDialog(BuildContext context) {
    final isEs = context.read<AppStateProvider>().language.name == 'es';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BioSenseColor.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.lg),
          side: const BorderSide(color: BioSenseColor.alert, width: 1.5)),
        icon: const Icon(Icons.emergency_outlined,
          color: BioSenseColor.alert, size: 36),
        title: Text(
          isEs ? 'Solicitar Ayuda' : 'Request Help',
          style: BioSenseText.title.copyWith(color: BioSenseColor.alert),
          textAlign: TextAlign.center),
        content: Text(
          isEs
            ? 'Se notificará a todos tus contactos de confianza con tu estado fisiológico actual y ubicación. ¿Confirmas?'
            : 'All your trusted contacts will be notified with your current physiological status and location. Confirm?',
          style: BioSenseText.body,
          textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: BioSenseColor.textMuted,
              side: const BorderSide(color: BioSenseColor.border)),
            child: Text(isEs ? 'Cancelar' : 'Cancel')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isEs
                  ? 'Alerta enviada a tu Red de Acompañamiento Seguro'
                  : 'Alert sent to your Trusted Care Network'),
                backgroundColor: BioSenseColor.alert,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BioSenseRadius.sm))));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BioSenseColor.alert),
            child: Text(isEs ? 'Enviar Ayuda' : 'Send Help')),
        ],
      ),
    );
  }
}


// ── Punto pulsante dinámico según estado
class _PulseDot extends StatefulWidget {
  final Color color;
  final String statusKey;
  const _PulseDot({required this.color, required this.statusKey});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  Duration get _duration {
    switch (widget.statusKey) {
      case 'fatigue':  return const Duration(milliseconds: 1500);
      case 'alert':    return const Duration(milliseconds: 1000);
      case 'danger':
      case 'critical': return const Duration(milliseconds: 500);
      default:         return const Duration(milliseconds: 2500);
    }
  }

  double get _minOpacity {
    switch (widget.statusKey) {
      case 'fatigue':  return 0.25;
      case 'alert':    return 0.15;
      case 'danger':
      case 'critical': return 0.10;
      default:         return 0.20;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _duration)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1.0, end: _minOpacity)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_PulseDot old) {
    super.didUpdateWidget(old);
    if (old.statusKey != widget.statusKey) {
      _ctrl.duration = _duration;
      _ctrl.repeat(reverse: true);
      _anim = Tween<double>(begin: 1.0, end: _minOpacity)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Opacity(
      opacity: _anim.value,
      child: Container(
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: widget.color, shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: widget.color.withOpacity(0.6),
              blurRadius: 16, spreadRadius: 4),
            BoxShadow(color: widget.color.withOpacity(0.3),
              blurRadius: 6, spreadRadius: 1),
          ]))));
}

class _SubjectiveOption {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _SubjectiveOption(this.label, this.value, this.color, this.icon);
}

// Fondo hexagonal premium
class _HexGridPainter extends CustomPainter {
  final bool critical;
  const _HexGridPainter({this.critical = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = critical
        ? const Color(0xFFE74C3C).withOpacity(0.04)
        : const Color(0xFF0A3D62).withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const r = 22.0;
    const hh = r * 1.732;
    int col = 0;
    for (double x = 0; x < size.width + r * 2; x += r * 1.5) {
      final offsetY = col.isOdd ? hh / 2 : 0.0;
      for (double y = -hh + offsetY; y < size.height + hh; y += hh) {
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60 - 30) * 3.14159265 / 180;
          final px = x + r * _c(angle);
          final py = y + r * _s(angle);
          if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
      col++;
    }
  }

  double _c(double a) {
    final t = a - (a / (2*3.14159265)).truncate() * 2*3.14159265;
    return 1 - t*t/2 + t*t*t*t/24 - t*t*t*t*t*t/720;
  }
  double _s(double a) => _c(a - 1.5707963);

  @override
  bool shouldRepaint(_HexGridPainter old) => old.critical != critical;
}
