// ============================================================
// BIOSENSE OS — Onboarding Fisiológico v1.0
// Calibración inicial del motor PHSE
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_state_provider.dart';
import '../models/user_profile.dart';
import '../design/biosense_theme.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;

  // Paso 1 — Identidad
  final _nameCtrl = TextEditingController();
  UserProfile _selectedProfile = UserProfile.adulto;

  // Paso 2 — Condiciones médicas
  final Set<String> _conditions = {'none'};

  // Paso 3 — Nivel de actividad
  String _activityLevel = 'moderate';

  // Paso 4 — Contacto emergencia
  final _contactNameCtrl  = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();

  // Animación fade entre páginas
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _fadeCtrl.reset();
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic);
      setState(() => _currentPage++);
      _fadeCtrl.forward();
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    final app = context.read<AppStateProvider>();
    final prefs = await SharedPreferences.getInstance();

    // Guardar todo
    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('activity_level', _activityLevel);
    await prefs.setStringList('conditions', _conditions.toList());
    await prefs.setString('emergency_contact_name',
      _contactNameCtrl.text.trim());
    await prefs.setString('emergency_contact_phone',
      _contactPhoneCtrl.text.trim());

    // Aplicar al provider
    app.setUserName(_nameCtrl.text.trim());
    app.changeProfile(_selectedProfile);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = context.watch<AppStateProvider>().language.name == 'es';

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(children: [

          // ── Barra de progreso superior
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'PHSE ',
                    style: TextStyle(fontFamily: 'Inter',
                      fontSize: 18, fontWeight: FontWeight.w300,
                      color: Colors.white60)),
                  TextSpan(text: 'Altea Garay',
                    style: TextStyle(fontFamily: 'Inter',
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: Color(0xFF10AC84))),
                ])),
                Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(fontFamily: 'Inter',
                    fontSize: 12, color: Colors.white38)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(BioSenseRadius.full),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalPages,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF10AC84)),
                  minHeight: 3)),
            ]),
          ),

          // ── Páginas
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Page1Identity(
                  nameCtrl: _nameCtrl,
                  selected: _selectedProfile,
                  onProfile: (p) => setState(() => _selectedProfile = p),
                  isEs: isEs),
                _Page2Conditions(
                  selected: _conditions,
                  onToggle: (c) => setState(() {
                    if (c == 'none') {
                      _conditions.clear();
                      _conditions.add('none');
                    } else {
                      _conditions.remove('none');
                      if (_conditions.contains(c)) _conditions.remove(c);
                      else _conditions.add(c);
                      if (_conditions.isEmpty) _conditions.add('none');
                    }
                  }),
                  isEs: isEs),
                _Page3Activity(
                  selected: _activityLevel,
                  onSelect: (a) => setState(() => _activityLevel = a),
                  isEs: isEs),
                _Page4Emergency(
                  nameCtrl: _contactNameCtrl,
                  phoneCtrl: _contactPhoneCtrl,
                  isEs: isEs),
              ],
            ),
          ),

          // ── Botón siguiente
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10AC84),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(BioSenseRadius.md))),
                child: Text(
                  _currentPage < _totalPages - 1
                    ? (isEs ? 'Continuar' : 'Continue')
                    : (isEs
                        ? 'Listo. Comencemos a monitorear.'
                        : 'Ready. Let\'s start monitoring.'),
                  style: const TextStyle(fontFamily: 'Inter',
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// PÁGINA 1 — Identidad y Perfil Fisiológico
// ============================================================
class _Page1Identity extends StatelessWidget {
  final TextEditingController nameCtrl;
  final UserProfile selected;
  final ValueChanged<UserProfile> onProfile;
  final bool isEs;

  const _Page1Identity({required this.nameCtrl, required this.selected,
    required this.onProfile, required this.isEs});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(
        isEs
          ? 'Configuraremos tu perfil\nen menos de 1 minuto.'
          : 'We\'ll set up your profile\nin under 1 minute.',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 26,
          fontWeight: FontWeight.w300, color: Colors.white,
          height: 1.3, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(
        isEs
          ? 'Esta información calibra el motor predictivo PHSE.'
          : 'This information calibrates the PHSE predictive engine.',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: Colors.white38)),
      const SizedBox(height: 32),

      // Campo nombre
      _DarkLabel(isEs ? '¿CÓMO TE LLAMAS?' : 'WHAT IS YOUR NAME?'),
      const SizedBox(height: 8),
      _DarkInput(controller: nameCtrl,
        hint: isEs ? 'Tu nombre' : 'Your name',
        icon: Icons.person_outline),
      const SizedBox(height: 28),

      // Perfil fisiológico
      _DarkLabel(
        isEs ? 'PERFIL FISIOLÓGICO' : 'PHYSIOLOGICAL PROFILE'),
      const SizedBox(height: 4),
      Text(
        isEs
          ? 'Define los umbrales adaptativos del motor PHSE'
          : 'Defines adaptive thresholds for the PHSE engine',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
          color: Colors.white30)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8,
        children: [
          _ProfileChip(UserProfile.nino,
            isEs ? 'Infantil' : 'Pediatric',
            Icons.child_care_outlined, selected, onProfile),
          _ProfileChip(UserProfile.adulto,
            isEs ? 'Adulto' : 'Adult',
            Icons.person_outlined, selected, onProfile),
          _ProfileChip(UserProfile.adultoMayor,
            isEs ? 'Adulto Mayor' : 'Senior',
            Icons.elderly_outlined, selected, onProfile),
          _ProfileChip(UserProfile.embarazo,
            isEs ? 'Embarazo' : 'Pregnancy',
            Icons.pregnant_woman_outlined, selected, onProfile),
          _ProfileChip(UserProfile.deportista,
            isEs ? 'Deportista' : 'Athletic',
            Icons.fitness_center_outlined, selected, onProfile),
          _ProfileChip(UserProfile.cardiaco,
            isEs ? 'Cardíaco' : 'Cardiac',
            Icons.favorite_border_outlined, selected, onProfile),
        ]),
    ]),
  );
}

// ============================================================
// PÁGINA 2 — Condiciones Médicas
// ============================================================
class _Page2Conditions extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool isEs;

  const _Page2Conditions({required this.selected,
    required this.onToggle, required this.isEs});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(
        isEs
          ? '¿Tienes alguna condición\nmédica preexistente?'
          : 'Do you have any\npre-existing condition?',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 26,
          fontWeight: FontWeight.w300, color: Colors.white,
          height: 1.3, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(
        isEs
          ? 'El motor PHSE ajusta los umbrales según tu condición.'
          : 'The PHSE engine adjusts thresholds to your condition.',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: Colors.white38)),
      const SizedBox(height: 32),

      ...[
        ('none',        isEs ? 'Ninguna' : 'None',
          Icons.check_circle_outline),
        ('diabetes',    isEs ? 'Diabetes' : 'Diabetes',
          Icons.water_drop_outlined),
        ('hipertension',isEs ? 'Hipertensión' : 'Hypertension',
          Icons.monitor_heart_outlined),
        ('cardiaco',    isEs ? 'Cardiopatía' : 'Heart disease',
          Icons.favorite_border_outlined),
        ('epoc',        isEs ? 'EPOC / Asma' : 'COPD / Asthma',
          Icons.air_outlined),
        ('renal',       isEs ? 'Enfermedad Renal' : 'Renal disease',
          Icons.biotech_outlined),
        ('otra',        isEs ? 'Otra' : 'Other',
          Icons.add_circle_outline),
      ].map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ConditionTile(
          key: ValueKey(e.$1),
          id: e.$1, label: e.$2, icon: e.$3,
          selected: selected.contains(e.$1),
          onTap: () => onToggle(e.$1)))),
    ]),
  );
}

// ============================================================
// PÁGINA 3 — Nivel de Actividad
// ============================================================
class _Page3Activity extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool isEs;

  const _Page3Activity({required this.selected,
    required this.onSelect, required this.isEs});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(
        isEs
          ? '¿Cuál es tu nivel de\nactividad física habitual?'
          : 'What is your usual\nphysical activity level?',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 26,
          fontWeight: FontWeight.w300, color: Colors.white,
          height: 1.3, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(
        isEs
          ? 'Ajusta la línea base metabólica y la respuesta galvánica.'
          : 'Adjusts metabolic baseline and galvanic response.',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: Colors.white38)),
      const SizedBox(height: 32),

      ...[
        ('sedentary',     isEs ? 'Sedentario' : 'Sedentary',
          isEs ? 'Actividad mínima, trabajo de escritorio'
               : 'Minimal activity, desk work',
          Icons.chair_outlined),
        ('moderate',      isEs ? 'Moderado' : 'Moderate',
          isEs ? 'Ejercicio ligero 2-3 veces por semana'
               : 'Light exercise 2-3 times per week',
          Icons.directions_walk_outlined),
        ('athletic',      isEs ? 'Deportivo' : 'Athletic',
          isEs ? 'Entrenamiento regular 4-5 veces por semana'
               : 'Regular training 4-5 times per week',
          Icons.directions_run_outlined),
        ('high_performance', isEs ? 'Alto Rendimiento' : 'High Performance',
          isEs ? 'Atleta profesional o entrenamiento diario intenso'
               : 'Professional athlete or intense daily training',
          Icons.sports_outlined),
      ].map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ActivityTile(
          id: e.$1, label: e.$2, desc: e.$3, icon: e.$4,
          selected: selected == e.$1,
          onTap: () => onSelect(e.$1)))),
    ]),
  );
}

// ============================================================
// PÁGINA 4 — Red de Emergencia
// ============================================================
class _Page4Emergency extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl;
  final bool isEs;

  const _Page4Emergency({required this.nameCtrl,
    required this.phoneCtrl, required this.isEs});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Text(
        isEs
          ? 'Red de Acompañamiento\nSeguro'
          : 'Trusted Care\nNetwork',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 26,
          fontWeight: FontWeight.w300, color: Colors.white,
          height: 1.3, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(
        isEs
          ? 'Este contacto recibirá alertas si usas el botón de auxilio.'
          : 'This contact will receive alerts when you use the help button.',
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12,
          color: Colors.white38)),
      const SizedBox(height: 32),

      _DarkLabel(isEs ? 'NOMBRE DEL CONTACTO' : 'CONTACT NAME'),
      const SizedBox(height: 8),
      _DarkInput(controller: nameCtrl,
        hint: isEs ? 'Ej. María García' : 'e.g. John Smith',
        icon: Icons.person_outline),
      const SizedBox(height: 20),

      _DarkLabel(isEs ? 'TELÉFONO' : 'PHONE NUMBER'),
      const SizedBox(height: 8),
      _DarkInput(controller: phoneCtrl,
        hint: isEs ? '+52 81 0000 0000' : '+1 555 000 0000',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone),
      const SizedBox(height: 32),

      // Permisos
      _DarkLabel(isEs ? 'PERMISOS REQUERIDOS' : 'REQUIRED PERMISSIONS'),
      const SizedBox(height: 12),
      _PermissionRow(
        icon: Icons.bluetooth_outlined,
        label: isEs ? 'Bluetooth' : 'Bluetooth',
        desc: isEs ? 'Enlace con la pulsera BioSense' : 'Link with BioSense band',
        color: const Color(0xFF4FC3F7),
        permission: Permission.bluetoothConnect),
      const SizedBox(height: 8),
      _PermissionRow(
        icon: Icons.notifications_outlined,
        label: isEs ? 'Notificaciones' : 'Notifications',
        desc: isEs ? 'Alertas predictivas del motor PHSE' : 'PHSE engine predictive alerts',
        color: const Color(0xFF10AC84),
        permission: Permission.notification),
      const SizedBox(height: 8),
      _PermissionRow(
        icon: Icons.location_on_outlined,
        label: isEs ? 'Ubicación' : 'Location',
        desc: isEs ? 'Coordenadas en alertas de emergencia' : 'Coordinates in emergency alerts',
        color: const Color(0xFFF39C12),
        permission: Permission.locationWhenInUse),

      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF10AC84).withOpacity(0.08),
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          border: Border.all(
            color: const Color(0xFF10AC84).withOpacity(0.25))),
        child: Row(children: [
          const Icon(Icons.shield_outlined,
            color: Color(0xFF10AC84), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            isEs
              ? 'Todos tus datos se procesan localmente. BioSense no comparte información con terceros.'
              : 'All data is processed locally. BioSense does not share information with third parties.',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11,
              color: Color(0xFF10AC84), height: 1.4))),
        ])),
    ]),
  );
}

// ============================================================
// WIDGETS AUXILIARES
// ============================================================

class _DarkLabel extends StatelessWidget {
  final String text;
  const _DarkLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontFamily: 'Inter', fontSize: 10,
      fontWeight: FontWeight.w800, color: Colors.white38,
      letterSpacing: 1.2));
}

class _DarkInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;

  const _DarkInput({required this.controller, required this.hint,
    required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1A2640),
      borderRadius: BorderRadius.circular(BioSenseRadius.md),
      border: Border.all(color: Colors.white24)),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      textInputAction: TextInputAction.next,
      keyboardAppearance: Brightness.dark,
      cursorColor: const Color(0xFF10AC84),
      style: const TextStyle(
        fontFamily: 'Inter', color: Colors.white,
        fontSize: 15, fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Colors.white30, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A2640),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          borderSide: const BorderSide(
            color: Color(0xFF10AC84), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16)),
    ));
}

class _ProfileChip extends StatelessWidget {
  final UserProfile profile;
  final String label;
  final IconData icon;
  final UserProfile selected;
  final ValueChanged<UserProfile> onSelect;

  const _ProfileChip(this.profile, this.label, this.icon,
    this.selected, this.onSelect);

  @override
  Widget build(BuildContext context) {
    final isSelected = profile == selected;
    return GestureDetector(
      onTap: () => onSelect(profile),
      child: AnimatedContainer(
        duration: BioSenseMotion.normal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
            ? const Color(0xFF10AC84).withOpacity(0.15)
            : const Color(0xFF1A2640),
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          border: Border.all(
            color: isSelected
              ? const Color(0xFF10AC84)
              : Colors.white12,
            width: isSelected ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
            color: isSelected
              ? const Color(0xFF10AC84)
              : Colors.white38,
            size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontFamily: 'Inter', fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? const Color(0xFF10AC84) : Colors.white60)),
        ])));
  }
}

class _ConditionTile extends StatelessWidget {
  final String id, label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionTile({
    super.key, required this.id, required this.label,
    required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: BioSenseMotion.normal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: selected
          ? const Color(0xFF10AC84).withOpacity(0.10)
          : const Color(0xFF1A2640),
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        border: Border.all(
          color: selected ? const Color(0xFF10AC84) : Colors.white12,
          width: selected ? 1.5 : 1)),
      child: Row(children: [
        Icon(icon,
          color: selected
            ? const Color(0xFF10AC84) : Colors.white38,
          size: 20),
        const SizedBox(width: 14),
        Text(label, style: TextStyle(
          fontFamily: 'Inter', fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? const Color(0xFF10AC84) : Colors.white70)),
        const Spacer(),
        AnimatedContainer(
          duration: BioSenseMotion.normal,
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: selected
              ? const Color(0xFF10AC84)
              : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                ? const Color(0xFF10AC84) : Colors.white24,
              width: 1.5)),
          child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 12)
            : null),
      ])));
}

class _ActivityTile extends StatelessWidget {
  final String id, label, desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityTile({required this.id, required this.label,
    required this.desc, required this.icon,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: BioSenseMotion.normal,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
          ? const Color(0xFF10AC84).withOpacity(0.10)
          : const Color(0xFF1A2640),
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        border: Border.all(
          color: selected ? const Color(0xFF10AC84) : Colors.white12,
          width: selected ? 1.5 : 1)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: selected
              ? const Color(0xFF10AC84).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(BioSenseRadius.sm)),
          child: Icon(icon,
            color: selected
              ? const Color(0xFF10AC84) : Colors.white38,
            size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(label, style: TextStyle(
            fontFamily: 'Inter', fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF10AC84) : Colors.white.withOpacity(0.80))),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(
            fontFamily: 'Inter', fontSize: 11, color: Colors.white38)),
        ])),
        if (selected)
          const Icon(Icons.check_circle,
            color: Color(0xFF10AC84), size: 20),
      ])));
}

class _PermissionRow extends StatefulWidget {
  final IconData icon;
  final String label, desc;
  final Color color;
  final Permission permission;

  const _PermissionRow({required this.icon, required this.label,
    required this.desc, required this.color, required this.permission});

  @override
  State<_PermissionRow> createState() => _PermissionRowState();
}

class _PermissionRowState extends State<_PermissionRow> {
  PermissionStatus _status = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final s = await widget.permission.status;
    if (mounted) setState(() => _status = s);
  }

  Future<void> _requestPermission() async {
    final s = await widget.permission.request();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status.isGranted;
    final color = granted ? const Color(0xFF10AC84) : widget.color;

    return GestureDetector(
      onTap: granted ? null : _requestPermission,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(BioSenseRadius.md),
          border: Border.all(color: color.withOpacity(0.35))),
        child: Row(children: [
          Icon(widget.icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(widget.label, style: TextStyle(
              fontFamily: 'Inter', fontSize: 13,
              fontWeight: FontWeight.w600, color: color)),
            Text(widget.desc, style: const TextStyle(
              fontFamily: 'Inter', fontSize: 11, color: Colors.white38)),
          ])),
          granted
            ? const Icon(Icons.check_circle_outline,
                color: Color(0xFF10AC84), size: 20)
            : Icon(Icons.chevron_right_outlined,
                color: color.withOpacity(0.5), size: 18),
        ]),
      ),
    );
  }
}
