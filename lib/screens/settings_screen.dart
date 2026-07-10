// ============================================================
// BIOSENSE OS — Settings Screen v2.0
// Configuración del Sistema — Sin emojis decorativos
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state_provider.dart';
import '../core/localization_manager.dart';
import '../models/user_profile.dart';
import '../design/biosense_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _mockMode  = true;
  String? _photoPath;
  final _picker = ImagePicker();

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
      _photoPath = prefs.getString('user_photo');
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setBool('mock_mode', _mockMode);
    if (_photoPath != null) await prefs.setString('user_photo', _photoPath!);
    if (mounted) {
      context.read<AppStateProvider>().setUserName(_nameCtrl.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          context.read<AppStateProvider>().language.name == 'es'
            ? 'Configuración guardada correctamente'
            : 'Settings saved successfully'),
        backgroundColor: BioSenseColor.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.sm))));
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (picked != null) {
      setState(() => _photoPath = picked.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_photo', picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      appBar: AppBar(
        title: Text(isEs ? 'Configuración del Sistema' : 'System Configuration'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(isEs ? 'Guardar' : 'Save',
              style: TextStyle(
                color: BioSenseColor.primary,
                fontWeight: FontWeight.w700))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BioSenseSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── IDENTIFICACIÓN DEL PACIENTE
            _SectionHeader(
              isEs ? 'IDENTIFICACIÓN DEL PACIENTE' : 'PATIENT IDENTIFICATION'),
            // ── FOTO DE PERFIL
            BioSenseTheme.clinicalCard(
              animate: false,
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Row(children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: BioSenseColor.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BioSenseColor.border, width: 1.5),
                      image: _photoPath != null
                        ? DecorationImage(
                            image: FileImage(File(_photoPath!)),
                            fit: BoxFit.cover)
                        : null),
                    child: _photoPath == null
                      ? const Icon(Icons.person_outline,
                          color: BioSenseColor.primary, size: 28)
                      : null),
                ),
                const SizedBox(width: BioSenseSpacing.lg),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    isEs ? 'Fotografía de perfil' : 'Profile photo',
                    style: BioSenseText.subtitle),
                  const SizedBox(height: 4),
                  Text(
                    isEs
                      ? 'Toca para seleccionar desde galería'
                      : 'Tap to select from gallery',
                    style: BioSenseText.caption),
                ])),
              ]),
            ),
            const SizedBox(height: BioSenseSpacing.md),

                        Container(
              decoration: BoxDecoration(
                color: BioSenseColor.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(BioSenseRadius.md),
                border: Border.all(color: BioSenseColor.primary.withOpacity(0.20))),
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(isEs ? 'Nombre del paciente' : 'Patient name',
                  style: BioSenseText.caption.copyWith(
                    color: BioSenseColor.primary, fontWeight: FontWeight.w700)),
                const SizedBox(height: BioSenseSpacing.sm),
                TextField(
                  controller: _nameCtrl,
                  style: BioSenseText.body,
                  decoration: InputDecoration(
                    hintText: isEs
                      ? 'Ingrese su nombre'
                      : 'Enter your name',
                    hintStyle: BioSenseText.body.copyWith(
                      color: BioSenseColor.textHint),
                    prefixIcon: const Icon(Icons.person_outline,
                      color: BioSenseColor.primary, size: 20))),
              ]),
            ),
            const SizedBox(height: BioSenseSpacing.xxl),

            // ── IDIOMA DEL SISTEMA
            _SectionHeader(
              isEs ? 'IDIOMA DEL SISTEMA' : 'SYSTEM LANGUAGE'),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => app.toggleLanguage(AppLanguage.es),
                child: AnimatedContainer(
                  duration: BioSenseMotion.normal,
                  curve: BioSenseMotion.flow,
                  padding: const EdgeInsets.all(BioSenseSpacing.lg),
                  decoration: BoxDecoration(
                    color: isEs
                      ? BioSenseColor.primary
                      : BioSenseColor.surface,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(BioSenseRadius.md)),
                    border: Border.all(color: BioSenseColor.border)),
                  child: Column(children: [
                    Text('ES', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: isEs ? Colors.white : BioSenseColor.textMuted)),
                    Text('Español', style: TextStyle(
                      fontSize: 11,
                      color: isEs ? Colors.white70 : BioSenseColor.textMuted)),
                  ]),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => app.toggleLanguage(AppLanguage.en),
                child: AnimatedContainer(
                  duration: BioSenseMotion.normal,
                  curve: BioSenseMotion.flow,
                  padding: const EdgeInsets.all(BioSenseSpacing.lg),
                  decoration: BoxDecoration(
                    color: !isEs
                      ? BioSenseColor.primary
                      : BioSenseColor.surface,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(BioSenseRadius.md)),
                    border: Border.all(color: BioSenseColor.border)),
                  child: Column(children: [
                    Text('EN', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: !isEs ? Colors.white : BioSenseColor.textMuted)),
                    Text('English', style: TextStyle(
                      fontSize: 11,
                      color: !isEs ? Colors.white70 : BioSenseColor.textMuted)),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: BioSenseSpacing.xxl),

            // ── ALERTAS DE VOZ
            _SectionHeader(
              isEs ? 'ALERTAS DE VOZ — ALTEA' : 'VOICE ALERTS — ALTEA'),
            Container(
              decoration: BoxDecoration(
                color: BioSenseColor.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(BioSenseRadius.md),
                border: Border.all(color: BioSenseColor.accent.withOpacity(0.25))),
              child: SwitchListTile(
                value: app.voiceEnabled,
                onChanged: (v) => app.setVoiceEnabled(v),
                activeColor: BioSenseColor.accent,
                title: Text(
                  isEs ? 'Activar alertas por voz' : 'Enable voice alerts',
                  style: BioSenseText.subtitle.copyWith(color: BioSenseColor.accent)),
                subtitle: Text(
                  isEs
                    ? 'El sistema ALTEA emite avisos auditivos al detectar cambios de estado'
                    : 'The ALTEA system emits audio alerts when detecting status changes',
                  style: BioSenseText.caption),
                secondary: Icon(Icons.record_voice_over_outlined,
                  color: BioSenseColor.accent),
              ),
            ),
            const SizedBox(height: BioSenseSpacing.xxl),

            // ── PERFIL FISIOLÓGICO
            _SectionHeader(
              isEs ? 'PERFIL FISIOLÓGICO' : 'PHYSIOLOGICAL PROFILE'),
            Text(
              isEs
                ? 'El perfil calibra los umbrales del motor PHSE. El algoritmo central no cambia.'
                : 'The profile calibrates PHSE engine thresholds. The core algorithm does not change.',
              style: BioSenseText.caption),
            const SizedBox(height: BioSenseSpacing.md),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              crossAxisSpacing: BioSenseSpacing.sm,
              mainAxisSpacing: BioSenseSpacing.sm,
              children: _profiles(isEs).map((p) {
                final sel = app.currentProfile == p.profile;
                return GestureDetector(
                  onTap: () => app.changeProfile(p.profile),
                  child: AnimatedContainer(
                    duration: BioSenseMotion.normal,
                    decoration: BoxDecoration(
                      color: sel
                        ? BioSenseColor.primary
                        : BioSenseColor.surface,
                      borderRadius: BorderRadius.circular(BioSenseRadius.md),
                      border: Border.all(
                        color: sel
                          ? BioSenseColor.primary
                          : BioSenseColor.border,
                        width: sel ? 1.5 : 1)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(p.icon,
                        color: sel ? Colors.white : BioSenseColor.primary,
                        size: 20),
                      const SizedBox(height: 4),
                      Text(p.label, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : BioSenseColor.textPrimary),
                        textAlign: TextAlign.center),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: BioSenseSpacing.xxl),

            // ── CONEXIÓN BLE
            _SectionHeader(
              isEs ? 'CONEXIÓN CON PULSERA BIOSENSE' : 'BIOSENSE BAND CONNECTION'),
            Container(
              decoration: BoxDecoration(
                color: BioSenseColor.warning.withOpacity(0.06),
                borderRadius: BorderRadius.circular(BioSenseRadius.md),
                border: Border.all(color: BioSenseColor.warning.withOpacity(0.30))),
              child: SwitchListTile(
                value: _mockMode,
                onChanged: (v) {
                  setState(() => _mockMode = v);
                  if (v) app.connectMockMode();
                  else app.connectHardware();
                },
                activeColor: BioSenseColor.warning,
                title: Text(
                  isEs ? 'Modo demostración' : 'Demo mode',
                  style: BioSenseText.subtitle.copyWith(
                    color: BioSenseColor.warning)),
                subtitle: Text(
                  _mockMode
                    ? (isEs
                        ? 'Sin pulsera física — modo demostración activo'
                        : 'No physical band — demo mode active')
                    : (isEs
                        ? 'Buscando pulsera BioSense por Bluetooth...'
                        : 'Searching for BioSense band via Bluetooth...'),
                  style: BioSenseText.caption),
                secondary: Icon(Icons.bluetooth_outlined,
                  color: BioSenseColor.warning),
              ),
            ),
            const SizedBox(height: BioSenseSpacing.xxl),

            // ── AVISO LEGAL
            Container(
              padding: const EdgeInsets.all(BioSenseSpacing.lg),
              decoration: BoxDecoration(
                color: BioSenseColor.surface,
                borderRadius: BorderRadius.circular(BioSenseRadius.md),
                border: Border.all(color: BioSenseColor.border)),
              child: Text(
                isEs
                  ? 'BioSense es un sistema de alerta predictiva de grado clínico. No emite diagnósticos médicos. La interpretación clínica y el diagnóstico permanecen bajo la responsabilidad exclusiva del profesional de la salud habilitado.'
                  : 'BioSense is a clinical-grade predictive alert system. It does not issue medical diagnoses. Clinical interpretation and diagnosis remain under the exclusive responsibility of the licensed healthcare professional.',
                style: BioSenseText.caption.copyWith(height: 1.6)),
            ),
            const SizedBox(height: BioSenseSpacing.xxl),
            BioSenseTheme.institutionalFooter(),
          ],
        ),
      ),
    );
  }

  List<_ProfileOption> _profiles(bool isEs) => [
    _ProfileOption(UserProfile.nino,        Icons.child_care_outlined,
      isEs ? 'Infantil' : 'Pediatric'),
    _ProfileOption(UserProfile.adulto,      Icons.person_outlined,
      isEs ? 'Adulto' : 'Adult'),
    _ProfileOption(UserProfile.adultoMayor, Icons.elderly_outlined,
      isEs ? 'Mayor' : 'Senior'),
    _ProfileOption(UserProfile.deportista,  Icons.fitness_center_outlined,
      isEs ? 'Deportista' : 'Athletic'),
    _ProfileOption(UserProfile.cardiaco,    Icons.favorite_border_outlined,
      isEs ? 'Cardíaco' : 'Cardiac'),
    _ProfileOption(UserProfile.diabetes,    Icons.water_drop_outlined,
      isEs ? 'Diabetes' : 'Diabetes'),
    _ProfileOption(UserProfile.hipertension,Icons.monitor_heart_outlined,
      isEs ? 'Hipert.' : 'Hypert.'),
    _ProfileOption(UserProfile.embarazo,    Icons.pregnant_woman_outlined,
      isEs ? 'Embarazo' : 'Pregnancy'),
    _ProfileOption(UserProfile.respiratorio,Icons.air_outlined,
      isEs ? 'Resp.' : 'Respir.'),
  ];
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BioSenseSpacing.md),
    child: Text(text, style: BioSenseText.label.copyWith(
      color: BioSenseColor.primary)));
}

class _ProfileOption {
  final UserProfile profile;
  final IconData icon;
  final String label;
  const _ProfileOption(this.profile, this.icon, this.label);
}
