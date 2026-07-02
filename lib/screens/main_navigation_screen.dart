// ============================================================
// BIOSENSE — Main Navigation
// 🏠 Inicio | ❤️ Mi Salud | 📊 Historial | 👨‍⚕️ Médico
// 👨‍👩‍👧‍👦 Familia | 💡 Consejos | ⚙️ Configuración
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final isEs = context.watch<AppStateProvider>().language.name == 'es';

    final screens = [
      const HomeScreen(),
      const MyHealthScreen(),
      const HistoryScreen(),
      const ClinicalSummaryScreen(),
      const FamilyGuardianScreen(),
      const TipsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF1F4E79).withOpacity(0.12),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Text('🏠', style: TextStyle(fontSize: 20)),
              label: isEs ? 'Inicio' : 'Home'),
            NavigationDestination(
              icon: const Text('❤️', style: TextStyle(fontSize: 20)),
              label: isEs ? 'Mi Salud' : 'My Health'),
            NavigationDestination(
              icon: const Text('📊', style: TextStyle(fontSize: 20)),
              label: isEs ? 'Historial' : 'History'),
            NavigationDestination(
              icon: const Text('👨‍⚕️', style: TextStyle(fontSize: 20)),
              label: isEs ? 'Médico' : 'Doctor'),
            NavigationDestination(
              icon: const Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 18)),
              label: isEs ? 'Familia' : 'Family'),
            NavigationDestination(
              icon: const Text('💡', style: TextStyle(fontSize: 20)),
              label: isEs ? 'Consejos' : 'Tips'),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined, size: 20),
              label: isEs ? 'Ajustes' : 'Settings'),
          ],
        ),
      ),
    );
  }
}
