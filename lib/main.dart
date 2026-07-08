// ============================================================
// BIOSENSE — Main Entry Point
// Early Homeostasis Deviation Alert
// ALTEA-GARAY HTS | USPTO Provisional #63/914,860
//
// Arquitectura:
//   Flutter → AppStateProvider → HealthRepository → DHSIEngine
//                                                       │
//                                  ┌────────────────────┼────────────────────┐
//                                  ▼                    ▼                    ▼
//                            KalmanFilter         DHSICalculator       TrendDetector
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
import 'design/biosense_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Inicializar EventLog (carga eventos previos de SharedPreferences)
  final eventLog = EventLog();
  await eventLog.load();

  runApp(BioSenseApp(eventLog: eventLog));
}

class BioSenseApp extends StatelessWidget {
  final EventLog eventLog;
  const BioSenseApp({super.key, required this.eventLog});

  @override
  Widget build(BuildContext context) {
    // ── Composición de dependencias (Dependency Injection manual) ──
    final profileManager = ProfileManager();
    final dhsiEngine      = DHSIEngine(profileManager: profileManager);
    final bleService      = BleService();
    final healthRepository = HealthRepository(
      dhsiEngine: dhsiEngine,
      bleService: bleService,
      eventLog: eventLog,
    );
    final voiceManager   = VoiceManager();
    final localization    = LocalizationManager();

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
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              color: Color(0xFF1F4E79), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

// ── Pantalla de bienvenida ────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        // Arranca el motor en modo simulación por defecto
        Provider.of<AppStateProvider>(context, listen: false).connectMockMode();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainNavigationScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F4E79),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 30, spreadRadius: 4)],
                ),
                child: const Center(child: Text('🫀', style: TextStyle(fontSize: 52))),
              ),
              const SizedBox(height: 24),
              const Text('BioSense',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Tu cuerpo habla antes que los síntomas.',
                style: TextStyle(fontSize: 14, color: Color(0xFF93C5FD),
                  fontStyle: FontStyle.italic)),
              const SizedBox(height: 48),
              const SizedBox(width: 28, height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3B82F6))),
              const SizedBox(height: 16),
              const Text('Iniciando motor predictivo…',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 60),
              const Text('Powered by Phoenix-UCC v7.3',
                style: TextStyle(fontSize: 10, color: Color(0xFF334155), letterSpacing: 0.5)),
              const Text('ALTEA-GARAY HTS | USPTO #63/914,860',
                style: TextStyle(fontSize: 9, color: Color(0xFF1E293B))),
            ]),
          ),
        ),
      ),
    );
  }
}
