// ============================================================
// BIOSENSE OS — Main Entry Point v2.0
// ALTEA-GARAY HTS | USPTO Provisional #63/914,860
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/dhsi_engine.dart';
import 'core/profile_manager.dart';
import 'core/voice_manager.dart';
import 'core/localization_manager.dart';
import 'core/event_log.dart';
import 'services/ble_service.dart';
import 'repositories/health_repository.dart';
import 'providers/app_state_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design/biosense_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final eventLog = EventLog();
  await eventLog.load();

  runApp(BioSenseApp(eventLog: eventLog));
}

class BioSenseApp extends StatelessWidget {
  final EventLog eventLog;
  const BioSenseApp({super.key, required this.eventLog});

  @override
  Widget build(BuildContext context) {
    final profileManager  = ProfileManager();
    final dhsiEngine      = DHSIEngine(profileManager: profileManager);
    final bleService      = BleService();
    final healthRepository = HealthRepository(
      dhsiEngine: dhsiEngine,
      bleService: bleService,
      eventLog: eventLog,
    );
    final voiceManager  = VoiceManager();
    final localization  = LocalizationManager();

    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(
        healthRepository: healthRepository,
        voiceManager: voiceManager,
        localization: localization,
      ),
      child: MaterialApp(
        title: 'BioSense',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        theme: BioSenseTheme.theme,
        home: const SplashScreen(),
      ),
    );
  }
}

// ── Splash Screen elegante
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  double _progress = 0.0;
  String _status = 'Initializing PHSE engine...';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _update(0.20, 'Initializing PHSE engine...');
    await Future.delayed(const Duration(milliseconds: 400));
    _update(0.45, 'Verifying sensor channels...');
    await Future.delayed(const Duration(milliseconds: 400));
    _update(0.70, 'Loading physiological profiles...');
    await Future.delayed(const Duration(milliseconds: 400));
    _update(0.90, 'Calibrating Kalman filter...');
    await Future.delayed(const Duration(milliseconds: 400));
    _update(1.0, 'System ready.');
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Provider.of<AppStateProvider>(context, listen: false).connectMockMode();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _update(double p, String s) {
    if (mounted) setState(() { _progress = p; _status = s; });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Isotipo — hexágono con línea ECG
                CustomPaint(
                  size: const Size(52, 52),
                  painter: _IsotypePainter()),
                const SizedBox(height: 24),

                // Logotipo
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'Bio',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300,
                      color: Colors.white70, letterSpacing: -1)),
                  TextSpan(text: 'Sense',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                      color: Color(0xFF10AC84), letterSpacing: -1)),
                ])),
                const SizedBox(height: 6),
                const Text('Predictive Vital Monitoring System',
                  style: TextStyle(fontSize: 12, color: Colors.white38,
                    letterSpacing: 0.5)),
                const Text('ALTEA-GARAY HTS  ·  USPTO #63/914,860',
                  style: TextStyle(fontSize: 10, color: Colors.white24,
                    letterSpacing: 0.3)),

                const Spacer(),

                // Barra de progreso
                Text(_status,
                  style: const TextStyle(fontSize: 11,
                    color: Color(0xFF10AC84), letterSpacing: 0.5)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF10AC84)),
                    minHeight: 2)),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Isotipo: hexágono abierto con línea ECG
class _IsotypePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hexágono
    final hexPaint = Paint()
      ..color = const Color(0xFF10AC84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final hex = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..lineTo(w * 0.5, 0);
    canvas.drawPath(hex, hexPaint);

    // Línea ECG
    final ecgPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ecgPath = Path()
      ..moveTo(w * 0.10, h * 0.50)
      ..lineTo(w * 0.28, h * 0.50)
      ..lineTo(w * 0.35, h * 0.28)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.50, h * 0.50)
      ..lineTo(w * 0.90, h * 0.50);
    canvas.drawPath(ecgPath, ecgPaint);
  }

  @override
  bool shouldRepaint(_IsotypePainter _) => false;
}
