// ============================================================
// BIOSENSE — Home Screen (🏠 Inicio)
// Lenguaje cotidiano. Sin tecnicismos. Para todos.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/dhsi_gauge.dart';
import '../widgets/trend_arrow.dart';
import '../widgets/quick_log_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _heartScale = Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  String _greeting(bool isEs) {
    final h = DateTime.now().hour;
    if (isEs) {
      if (h < 12) return 'Buenos días';
      if (h < 19) return 'Buenas tardes';
      return 'Buenas noches';
    } else {
      if (h < 12) return 'Good morning';
      if (h < 19) return 'Good afternoon';
      return 'Good evening';
    }
  }

  Color _levelColor(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return const Color(0xFFFBBF24);
      case 'alert':    return const Color(0xFFF97316);
      case 'danger':   return const Color(0xFFEF4444);
      case 'critical': return const Color(0xFF9333EA);
      default:         return const Color(0xFF22C55E);
    }
  }

  String _levelEmoji(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return '😟';
      case 'alert':    return '😓';
      case 'danger':   return '🤒';
      case 'critical': return '🚨';
      default:         return '😊';
    }
  }

  String _titleKey(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return 'fatigue_title';
      case 'alert':    return 'alert_title';
      case 'danger':   return 'danger_title';
      case 'critical': return 'critical_title';
      default:         return 'stable_title';
    }
  }

  String _msgKey(String statusKey) {
    switch (statusKey) {
      case 'fatigue':  return 'fatigue_msg';
      case 'alert':    return 'alert_msg';
      case 'danger':   return 'danger_msg';
      case 'critical': return 'critical_msg';
      default:         return 'stable_msg';
    }
  }

  String _trendKeyFor(double velocity, String statusKey) {
    if (statusKey == 'danger' || statusKey == 'critical') return 'critical';
    if (velocity < -0.004) return 'falling';
    if (velocity < -0.0015) return 'rising_concern';
    if (velocity < -0.0005) return 'rising_mild';
    return 'stable';
  }

  String _trendMsgKey(String trendKey) {
    const map = {
      'stable': 'trend_stable', 'rising_mild': 'trend_leve',
      'rising_concern': 'trend_concern', 'falling': 'trend_falling',
      'critical': 'trend_critical',
    };
    return map[trendKey]!;
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppStateProvider>();
    final state  = app.healthState;
    final color  = _levelColor(state.statusKey);
    final isEs   = app.language.name == 'es';
    final trendKey = _trendKeyFor(state.velocity, state.statusKey);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('${_greeting(isEs)}, ${app.userName} 👋',
          style: const TextStyle(color: Color(0xFF1F4E79),
            fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Container(width: 10, height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E), shape: BoxShape.circle))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4), width: 2)),
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                ScaleTransition(
                  scale: state.statusKey == 'stable'
                      ? _heartScale : const AlwaysStoppedAnimation(1.0),
                  child: Text(_levelEmoji(state.statusKey),
                    style: const TextStyle(fontSize: 72))),
                const SizedBox(height: 12),
                Text(app.t(_titleKey(state.statusKey)),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 8),
                Text(app.t(_msgKey(state.statusKey)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF374151), height: 1.4)),
              ]),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEs ? '¿Cómo está tu cuerpo ahora?' : 'How is your body now?',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${state.dhsiPercentage}',
                    style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: color)),
                  const Text('%', style: TextStyle(fontSize: 24, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 8),
                DHSIGauge(percentage: state.dhsiPercentage),
                if (!app.baselineLocked) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: app.baselineSamples / 30,
                    backgroundColor: const Color(0xFFE2E8F0),
                    color: const Color(0xFF2E75B6)),
                  const SizedBox(height: 6),
                  Text(
                    isEs
                      ? 'Aprendiendo tu ritmo personal... (${app.baselineSamples}/30)'
                      : 'Learning your personal rhythm... (${app.baselineSamples}/30)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))]),
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                TrendArrow(trendKey: trendKey),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEs ? 'Dirección de tu salud' : 'Your health direction',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(app.t(_trendMsgKey(trendKey)),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 16),

            QuickLogBar(eventLog: app.eventLog, onEventAdded: () => setState(() {})),
            const SizedBox(height: 16),

            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: () => _showHowIFeel(context, app),
                icon: const Text('📝', style: TextStyle(fontSize: 20)),
                label: Text(isEs ? '¿Cómo me siento hoy?' : 'How do I feel today?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showHowIFeel(BuildContext context, AppStateProvider app) {
    final isEs = app.language.name == 'es';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isEs ? '¿Cómo te sientes ahora mismo?' : 'How do you feel right now?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: Color(0xFF1F4E79))),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _feelBtn(context, app, isEs ? '😊 Muy bien' : '😊 Very good', 0.0),
            _feelBtn(context, app, isEs ? '🙂 Bien' : '🙂 Good', 0.05),
            _feelBtn(context, app, isEs ? '😐 Regular' : '😐 Okay', 0.10),
            _feelBtn(context, app, isEs ? '😟 Cansado' : '😟 Tired', 0.15),
            _feelBtn(context, app, isEs ? '🤒 Mal' : '🤒 Bad', 0.20),
          ]),
        ]),
      ),
    );
  }

  Widget _feelBtn(BuildContext context, AppStateProvider app, String label, double p) {
    return ElevatedButton(
      onPressed: () {
        app.setMockPerturbation(p);
        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF1F5F9), foregroundColor: const Color(0xFF1E293B),
        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(label, style: const TextStyle(fontSize: 15)),
    );
  }
}
