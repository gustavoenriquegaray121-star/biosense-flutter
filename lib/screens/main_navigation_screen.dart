// ============================================================
// BIOSENSE OS — Main Navigation v2.0
// Iconografía lineal — Sin emojis — Estilo clínico profesional
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../design/biosense_theme.dart';
import 'home_screen.dart';
import 'my_health_screen.dart';
import 'history_screen.dart';
import 'clinical_summary_screen.dart';
import 'family_guardian_screen.dart';
import 'tips_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    MyHealthScreen(),
    HistoryScreen(),
    ClinicalSummaryScreen(),
    FamilyGuardianScreen(),
    TipsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isEs = context.watch<AppStateProvider>().language.name == 'es';

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BioSenseColor.surface,
          border: Border(top: BorderSide(
            color: BioSenseColor.border, width: 1))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: BioSenseColor.surface,
          indicatorColor: BioSenseColor.primary.withOpacity(0.10),
          height: 62,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _dest(Icons.monitor_heart_outlined,
              isEs ? 'Inicio' : 'Home'),
            _dest(Icons.biotech_outlined,
              isEs ? 'Mi Salud' : 'Health'),
            _dest(Icons.timeline_outlined,
              isEs ? 'Historial' : 'History'),
            _dest(Icons.medical_services_outlined,
              isEs ? 'Médico' : 'Clinical'),
            _dest(Icons.people_outline,
              isEs ? 'Red' : 'Network'),
            _dest(Icons.recommend_outlined,
              isEs ? 'Consejos' : 'Tips'),
            _dest(Icons.tune_outlined,
              isEs ? 'Config.' : 'Config.'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(IconData icon, String label) {
    return NavigationDestination(
      icon: Icon(icon, size: 22),
      selectedIcon: Icon(icon, size: 22, color: BioSenseColor.primary),
      label: label,
    );
  }
}
