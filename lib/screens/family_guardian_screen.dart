// ============================================================
// BIOSENSE OS — Trusted Care Network v2.0
// Red de Acompañamiento Seguro — Sin emojis decorativos
// ALTEA-GARAY HTS | USPTO Provisional #63/914,860
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/app_state_provider.dart';
import '../core/guardian_manager.dart';
import '../design/biosense_theme.dart';

class FamilyGuardianScreen extends StatefulWidget {
  const FamilyGuardianScreen({super.key});
  @override
  State<FamilyGuardianScreen> createState() => _FamilyGuardianScreenState();
}

class _FamilyGuardianScreenState extends State<FamilyGuardianScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final GuardianManager _guardian = GuardianManager();
  Timer? _countdownTimer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _generateToken();
  }

  void _generateToken() {
    setState(() {
      _secondsLeft  = 60;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) { t.cancel(); _generateToken(); }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';

    return Scaffold(
      backgroundColor: BioSenseColor.bgPrimary,
      appBar: AppBar(
        title: Text(isEs
          ? 'Red de Acompañamiento Seguro'
          : 'Trusted Care Network'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: BioSenseColor.primary,
          unselectedLabelColor: BioSenseColor.textMuted,
          indicatorColor: BioSenseColor.primary,
          indicatorWeight: 2,
          labelStyle: BioSenseText.label.copyWith(
            color: BioSenseColor.primary, 
            letterSpacing: 0.5
          ),
          tabs: [
            Tab(text: isEs ? 'MI CÓDIGO QR' : 'MY QR CODE'),
            Tab(text: isEs ? 'RED ACTIVA' : 'ACTIVE NETWORK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs, 
        children: [
          _buildMyQr(isEs),
          _buildNetwork(isEs),
        ]
      ),
    );
  }

  Widget _buildMyQr(bool isEs) {
    final payload = _guardian.generateQrPayload();
    final Color timerColor = _secondsLeft > 30
        ? BioSenseColor.stable
        : _secondsLeft > 10
          ? BioSenseColor.warning
          : BioSenseColor.alert;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(BioSenseSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BioSenseTheme.clinicalCard(
            animate: false,
            padding: const EdgeInsets.all(BioSenseSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                      color: BioSenseColor.primary, 
                      size: 20
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEs ? 'CÓDIGO DE ACCESO TEMPORAL' : 'TEMPORARY ACCESS CODE',
                      style: BioSenseText.label.copyWith(
                        color: BioSenseColor.primary
                      )
                    ),
                  ]
                ),
                const SizedBox(height: BioSenseSpacing.sm),
                Text(
                  isEs
                    ? 'Comparta este código únicamente con personas de su confianza. Solo verán su estado general (Estable / Vigilancia / Alerta). Nunca datos médicos detallados.'
                    : 'Share this code only with trusted individuals. They will only see your general status (Stable / Watch / Alert). Never detailed medical data.',
                  style: BioSenseText.body
                ),
              ]
            )
          ),
          const SizedBox(height: BioSenseSpacing.xl),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(BioSenseRadius.lg),
              border: Border.all(color: BioSenseColor.border),
              boxShadow: BioSenseShadow.card
            ),
            child: Column(
              children: [
                QrImageView(
                  data: payload,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: BioSenseColor.primary
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: BioSenseColor.textPrimary
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(Icons.timer_outlined, color: timerColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      isEs
                        ? 'Código válido por $_secondsLeft segundos'
                        : 'Code valid for $_secondsLeft seconds',
                      style: BioSenseText.caption.copyWith(color: timerColor)
                    ),
                  ]
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(BioSenseRadius.full),
                  child: LinearProgressIndicator(
                    value: _secondsLeft / 60,
                    backgroundColor: BioSenseColor.border,
                    valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                    minHeight: 3
                  )
                ),
              ]
            )
          ),
          const SizedBox(height: BioSenseSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generateToken,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: Text(isEs ? 'Generar nuevo código' : 'Generate new code'),
            )
          ),
          const SizedBox(height: BioSenseSpacing.xl),

          BioSenseTheme.clinicalCard(
            animate: false,
            color: BioSenseColor.stable.withOpacity(0.04),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                  color: BioSenseColor.stable, 
                  size: 20
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEs
                      ? 'Este código expira automáticamente en 60 segundos. Una fotografía del código QR no puede ser reutilizada después de su expiración. Privacidad de grado financiero.'
                      : 'This code expires automatically in 60 seconds. A photograph of the QR code cannot be reused after expiration. Financial-grade privacy.',
                    style: BioSenseText.caption.copyWith(
                      color: BioSenseColor.stable
                    )
                  )
                ),
              ]
            )
          ),
          const SizedBox(height: BioSenseSpacing.lg),
          BioSenseTheme.institutionalFooter(),
        ]
      )
    );
  }

  Widget _buildNetwork(bool isEs) {
    final familiars = [
      _FamiliarData(
        isEs ? 'Contacto 1' : 'Contact 1',
        isEs ? 'Sin desviaciones predictivas detectadas' : 'No predictive deviations detected',
        'stable', 
        BioSenseColor.stable
      ),
      _FamiliarData(
        isEs ? 'Contacto 2' : 'Contact 2',
        isEs ? 'Variación preventiva detectada — hace 2 horas' : 'Preventive variation detected — 2 hours ago',
        'fatigue', 
        BioSenseColor.warning
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(BioSenseSpacing.lg),
          child: SizedBox(
            width: double.infinity, 
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner_outlined, size: 18),
              label: Text(isEs
                ? 'Vincular nuevo contacto (QR)'
                : 'Link new contact (QR)'
              ),
            )
          )
        ),
        const Divider(height: 1),
        Expanded(
          child: familiars.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline,
                      size: 48, 
                      color: BioSenseColor.textMuted
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEs
                        ? 'Sin contactos vinculados.\nComparta su código QR para iniciar.'
                        : 'No contacts linked.\nShare your QR code to start.',
                      textAlign: TextAlign.center,
                      style: BioSenseText.body
                    ),
                  ]
                )
              )
            : ListView.separated(
                padding: const EdgeInsets.all(BioSenseSpacing.xl),
                itemCount: familiars.length,
                separatorBuilder: (_, __) =>
                  const SizedBox(height: BioSenseSpacing.md),
                itemBuilder: (_, i) => BioSenseTheme.clinicalCard(
                  animate: false,
                  padding: const EdgeInsets.all(BioSenseSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 10, 
                        height: 10,
                        decoration: BoxDecoration(
                          color: familiars[i].color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: familiars[i].color.withOpacity(0.4),
                            blurRadius: 6, 
                            spreadRadius: 1
                          )]
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(familiars[i].name, style: BioSenseText.subtitle),
                            const SizedBox(height: 2),
                            Text(familiars[i].status, style: BioSenseText.caption),
                          ]
                        )
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_outlined,
                          color: BioSenseColor.stable, 
                          size: 24
                        ),
                        onPressed: () {},
                        tooltip: isEs ? 'Llamar' : 'Call'
                      ),
                    ]
                  )
                )
              )
        ),
        BioSenseTheme.institutionalFooter(),
      ]
    );
  }
}

class _FamiliarData {
  final String name, status, statusKey;
  final Color color;
  const _FamiliarData(this.name, this.status, this.statusKey, this.color);
}
