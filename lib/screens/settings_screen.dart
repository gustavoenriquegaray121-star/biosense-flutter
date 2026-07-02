// ============================================================
// BIOSENSE — Settings Screen (⚙️ Configuración)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state_provider.dart';
import '../core/localization_manager.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _mockMode  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _mockMode = prefs.getBool('mock_mode') ?? true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setBool('mock_mode', _mockMode);
    if (mounted) {
      context.read<AppStateProvider>().setUserName(_nameCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Guardado'),
          duration: Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEs ? 'Configuración' : 'Settings'),
        actions: [
          TextButton(onPressed: _save,
            child: Text(isEs ? 'Guardar' : 'Save',
              style: const TextStyle(color: Color(0xFF2E75B6),
                fontWeight: FontWeight.bold, fontSize: 16))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Nombre
          _sectionTitle(isEs ? '¿Cómo te llamas?' : 'What is your name?'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: isEs ? 'Tu nombre' : 'Your name',
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E75B6), width: 2))),
          ),
          const SizedBox(height: 24),

          // Idioma
          _sectionTitle(isEs ? 'Idioma / Language' : 'Language / Idioma'),
          const SizedBox(height: 8),
          _langToggle(app, isEs),
          const SizedBox(height: 24),

          // Voz
          _sectionTitle(isEs ? 'Voz de Altea' : 'Altea Voice'),
          const SizedBox(height: 8),
          _card(child: SwitchListTile(
            value: app.voiceEnabled,
            onChanged: (v) => app.setVoiceEnabled(v),
            title: Text(isEs ? 'Activar avisos por voz' : 'Enable voice alerts',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(isEs
              ? 'Altea te habla cuando algo cambia'
              : 'Altea speaks when something changes',
              style: const TextStyle(fontSize: 12)),
            activeColor: const Color(0xFF2E75B6),
          )),
          const SizedBox(height: 24),

          // Perfil
          _sectionTitle(isEs ? '¿Quién eres?' : 'Who are you?'),
          const SizedBox(height: 10),
          _profileGrid(app, isEs),
          const SizedBox(height: 24),

          // Conexión
          _sectionTitle(isEs ? 'Pulsera BioSense' : 'BioSense Band'),
          const SizedBox(height: 8),
          _card(child: SwitchListTile(
            value: _mockMode,
            onChanged: (v) {
              setState(() => _mockMode = v);
              if (v) {
                app.connectMockMode();
              } else {
                app.connectHardware();
              }
            },
            title: Text(isEs ? 'Modo simulación' : 'Simulation mode',
              style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_mockMode
              ? (isEs ? 'Sin pulsera física — modo demostración'
                      : 'No physical band — demo mode')
              : (isEs ? 'Buscando pulsera BioSense por Bluetooth...'
                      : 'Searching for BioSense band via Bluetooth...'),
              style: const TextStyle(fontSize: 12)),
            activeColor: const Color(0xFF2E75B6),
          )),
          const SizedBox(height: 24),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4))),
            child: Text(
              isEs
                ? '⚠️ BioSense es un sistema de alerta predictiva. No diagnostica enfermedades. La interpretación clínica corresponde al médico.'
                : '⚠️ BioSense is a predictive alert system. It does not diagnose diseases. Clinical interpretation belongs to the physician.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
          ),
          const SizedBox(height: 12),
          Center(child: Text('BioSense v1.0 | ALTEA-GARAY HTS | USPTO #63/914,860',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
      color: Color(0xFF1F4E79)));

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0))),
    child: child);

  Widget _langToggle(AppStateProvider app, bool isEs) {
    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => app.toggleLanguage(AppLanguage.es),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isEs ? const Color(0xFF1F4E79) : Colors.white,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🇲🇽', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('Español', style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isEs ? Colors.white : const Color(0xFF64748B))),
          ]),
        ),
      )),
      Expanded(child: GestureDetector(
        onTap: () => app.toggleLanguage(AppLanguage.en),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: !isEs ? const Color(0xFF1F4E79) : Colors.white,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
            border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('🇺🇸', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text('English', style: TextStyle(
              fontWeight: FontWeight.bold,
              color: !isEs ? Colors.white : const Color(0xFF64748B))),
          ]),
        ),
      )),
    ]);
  }

  Widget _profileGrid(AppStateProvider app, bool isEs) {
    final options = [
      _PO(UserProfile.nino,        '👶', isEs ? 'Niño'      : 'Child'),
      _PO(UserProfile.adulto,      '🧑', isEs ? 'Adulto'    : 'Adult'),
      _PO(UserProfile.adultoMayor, '👴', isEs ? 'Mayor'     : 'Senior'),
      _PO(UserProfile.deportista,  '🏃', isEs ? 'Deportista': 'Athlete'),
      _PO(UserProfile.cardiaco,    '🫀', isEs ? 'Corazón'   : 'Cardiac'),
      _PO(UserProfile.diabetes,    '🩸', isEs ? 'Diabetes'  : 'Diabetes'),
      _PO(UserProfile.hipertension,'💊', isEs ? 'Presión'   : 'Hypert.'),
      _PO(UserProfile.embarazo,    '🤰', isEs ? 'Embarazo'  : 'Pregnancy'),
      _PO(UserProfile.respiratorio,'🫁', isEs ? 'Respirat.' : 'Respirat.'),
    ];
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, childAspectRatio: 1.1,
      crossAxisSpacing: 8, mainAxisSpacing: 8,
      children: options.map((o) {
        final sel = app.currentProfile == o.profile;
        return GestureDetector(
          onTap: () => app.changeProfile(o.profile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF1F4E79).withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? const Color(0xFF1F4E79) : const Color(0xFFE2E8F0),
                width: sel ? 2 : 1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(o.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(o.label, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sel ? const Color(0xFF1F4E79) : const Color(0xFF374151))),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _PO {
  final UserProfile profile; final String emoji, label;
  const _PO(this.profile, this.emoji, this.label);
}
