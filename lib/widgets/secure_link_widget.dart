// ============================================================
// BIOSENSE OS — Phoenix SecureLink Widget v1.0
// Visualización en tiempo real de la cadena criptográfica
// Patent: USPTO #63/914,860 — Phoenix SecureLink
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/secure_ble_service.dart';
import '../design/biosense_theme.dart';

// ============================================================
// WIDGET PRINCIPAL — SecureLink Status Card
// ============================================================
class SecureLinkCard extends StatefulWidget {
  final bool isEs;
  final bool isCrit;

  const SecureLinkCard({
    super.key,
    required this.isEs,
    required this.isCrit,
  });

  @override
  State<SecureLinkCard> createState() => _SecureLinkCardState();
}

class _SecureLinkCardState extends State<SecureLinkCard>
    with SingleTickerProviderStateMixin {

  // Motor de autenticación
  final BioSenseAuthEngine _authEngine = BioSenseAuthEngine();
  final MockBandPacketGenerator _generator = MockBandPacketGenerator();

  // Estado visible
  int _trustScore = 100;
  TrustLevel _trustLevel = TrustLevel.certified;
  String _lastPacketStatus = 'AUTHENTICATED';
  String _lastEvent = '';
  int _packetsValidated = 0;
  int _packetsRejected = 0;
  bool _chainVerified = true;
  DateTime _lastPacketTime = DateTime.now();

  // Animación del indicador
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _pulseCtrl,
          curve: Curves.easeInOut));

    // Simular paquetes cada 200ms (50Hz como el firmware)
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: 800), (_) => _processPacket());
  }

  void _processPacket() {
    if (!mounted) return;

    // Generar paquete autenticado del mock
    final packet = _generator.generatePacket(
      hrv: 45.0 + (_packetsValidated % 10) * 0.5,
      temperature: 36.6 + (_packetsValidated % 5) * 0.01,
      gsr: 1.2 + (_packetsValidated % 8) * 0.05,
      spO2: 98.0,
    );

    // Validar
    final result = _authEngine.validatePacket(packet);

    setState(() {
      _trustScore = _authEngine.trustScore;
      _trustLevel = _authEngine.trustLevel;
      _lastPacketTime = DateTime.now();

      if (result.isValid) {
        _packetsValidated++;
        _lastPacketStatus = 'AUTHENTICATED';
        _lastEvent = '';
        _chainVerified = true;
      } else {
        _packetsRejected++;
        _lastPacketStatus = result.reason;
        _lastEvent = result.detail ?? '';
        _chainVerified = false;
        // Restaurar después de mostrar el error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() {
            _chainVerified = true;
            _lastPacketStatus = 'AUTHENTICATED';
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _trustColor {
    switch (_trustLevel) {
      case TrustLevel.certified:   return BioSenseColor.stable;
      case TrustLevel.observation: return BioSenseColor.warning;
      case TrustLevel.warning:     return const Color(0xFFE67E22);
      case TrustLevel.revoked:     return BioSenseColor.alert;
    }
  }

  String _trustLevelLabel(bool isEs) => _trustLevel.label(isEs);

  String _packetStatusLabel(String status, bool isEs) {
    switch (status) {
      case 'AUTHENTICATED':
        return isEs ? 'Autenticado' : 'Authenticated';
      case 'REPLAY_ATTACK':
        return isEs ? 'Replay detectado' : 'Replay detected';
      case 'AUTH_FAILURE':
        return isEs ? 'Fallo de autenticación' : 'Auth failure';
      case 'STALE_PACKET':
        return isEs ? 'Paquete expirado' : 'Stale packet';
      case 'IMPLAUSIBLE_DATA':
        return isEs ? 'Datos implausibles' : 'Implausible data';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEs = widget.isEs;
    final isCrit = widget.isCrit || _trustLevel == TrustLevel.revoked;

    return AnimatedContainer(
      duration: BioSenseMotion.slow,
      decoration: BoxDecoration(
        color: isCrit
          ? BioSenseColor.criticalCard
          : _trustColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(BioSenseRadius.md),
        border: Border.all(
          color: _trustColor.withOpacity(isCrit ? 0.6 : 0.25),
          width: isCrit ? 1.5 : 1.0),
        boxShadow: [BoxShadow(
          color: _trustColor.withOpacity(0.10),
          blurRadius: 16, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(BioSenseSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [

        // ── HEADER
        Row(children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _pulseAnim.value,
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: _trustColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: _trustColor.withOpacity(0.5),
                    blurRadius: 8, spreadRadius: 2)])))),
          const SizedBox(width: 8),
          Text(
            'PHOENIX SECURELINK',
            style: BioSenseText.label.copyWith(
              color: _trustColor, letterSpacing: 1.2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _trustColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(BioSenseRadius.full),
              border: Border.all(
                color: _trustColor.withOpacity(0.4))),
            child: Text(
              _trustLevelLabel(isEs),
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 9,
                fontWeight: FontWeight.w800,
                color: _trustColor,
                letterSpacing: 0.8))),
        ]),
        const SizedBox(height: BioSenseSpacing.lg),

        // ── TRUST SCORE grande
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$_trustScore',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 48,
              fontWeight: FontWeight.w200,
              color: _trustColor, letterSpacing: -2,
              fontFeatures: const [FontFeature.tabularFigures()])),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text('%',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 18,
                color: _trustColor.withOpacity(0.6)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              isEs ? 'Trust Score' : 'Trust Score',
              style: BioSenseText.caption),
            Text(
              isEs ? 'Trust Continuum PHSE' : 'PHSE Trust Continuum',
              style: BioSenseText.caption.copyWith(
                color: BioSenseColor.textHint)),
          ])),
        ]),
        const SizedBox(height: BioSenseSpacing.sm),

        // Barra Trust Score
        BioSenseTheme.gradientBar(
          value: _trustScore / 100.0,
          color: _trustColor, height: 4),
        const SizedBox(height: BioSenseSpacing.lg),

        // ── 4 MÉTRICAS DE LA CADENA
        Row(children: [
          _ChainMetric(
            icon: Icons.shield_outlined,
            label: isEs ? 'Cadena' : 'Chain',
            value: _chainVerified
              ? (isEs ? 'Verificada' : 'Verified')
              : (isEs ? 'Alerta' : 'Alert'),
            color: _chainVerified
              ? BioSenseColor.stable : BioSenseColor.alert),
          _ChainMetric(
            icon: Icons.lock_outline,
            label: isEs ? 'Último paquete' : 'Last packet',
            value: _packetStatusLabel(_lastPacketStatus, isEs),
            color: _lastPacketStatus == 'AUTHENTICATED'
              ? BioSenseColor.stable : BioSenseColor.alert),
          _ChainMetric(
            icon: Icons.verified_outlined,
            label: isEs ? 'Validados' : 'Validated',
            value: '$_packetsValidated',
            color: BioSenseColor.stable),
          _ChainMetric(
            icon: Icons.block_outlined,
            label: isEs ? 'Rechazados' : 'Rejected',
            value: '$_packetsRejected',
            color: _packetsRejected > 0
              ? BioSenseColor.warning : BioSenseColor.textMuted),
        ]),
        const SizedBox(height: BioSenseSpacing.md),

        // ── PHSE TRUST MATRIX
        _TrustMatrixRow(isEs: isEs),
        const SizedBox(height: BioSenseSpacing.md),

        // ── EVENTO activo (si hay error)
        if (_lastEvent.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(BioSenseSpacing.sm),
            decoration: BoxDecoration(
              color: BioSenseColor.alert.withOpacity(0.08),
              borderRadius: BorderRadius.circular(BioSenseRadius.sm),
              border: Border.all(
                color: BioSenseColor.alert.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined,
                color: BioSenseColor.alert, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text(_lastEvent,
                style: BioSenseText.caption.copyWith(
                  color: BioSenseColor.alert))),
            ])),
          const SizedBox(height: BioSenseSpacing.sm),
        ],

        // ── FOOTER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Text(
            'AES-256-GCM  ·  Anti-Replay  ·  BLE Secure',
            style: BioSenseText.institutional),
          Text(
            '${_lastPacketTime.hour.toString().padLeft(2,'0')}:'
            '${_lastPacketTime.minute.toString().padLeft(2,'0')}:'
            '${_lastPacketTime.second.toString().padLeft(2,'0')}',
            style: BioSenseText.institutional),
        ]),
      ]),
    );
  }
}

// ── Métrica individual de la cadena
class _ChainMetric extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _ChainMetric({
    required this.icon, required this.label,
    required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(height: 3),
    Text(value,
      style: TextStyle(
        fontFamily: 'Inter', fontSize: 11,
        fontWeight: FontWeight.w700, color: color),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis),
    Text(label,
      style: BioSenseText.caption.copyWith(fontSize: 9),
      textAlign: TextAlign.center),
  ]));
}

// ── PHSE Trust Matrix visual
class _TrustMatrixRow extends StatelessWidget {
  final bool isEs;
  const _TrustMatrixRow({required this.isEs});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BioSenseSpacing.sm),
    decoration: BoxDecoration(
      color: BioSenseColor.primary.withOpacity(0.05),
      borderRadius: BorderRadius.circular(BioSenseRadius.sm),
      border: Border.all(
        color: BioSenseColor.primary.withOpacity(0.12))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Text(
        isEs ? 'PHSE TRUST MATRIX' : 'PHSE TRUST MATRIX',
        style: BioSenseText.label.copyWith(
          color: BioSenseColor.primary, fontSize: 9)),
      const SizedBox(height: 8),
      Row(children: [
        _MatrixVector(
          label: isEs ? 'Paciente' : 'Patient',
          value: 0.98, color: BioSenseColor.stable),
        const SizedBox(width: 6),
        _MatrixVector(
          label: isEs ? 'Hardware' : 'Hardware',
          value: 0.95, color: BioSenseColor.stable),
        const SizedBox(width: 6),
        _MatrixVector(
          label: isEs ? 'Red' : 'Network',
          value: 1.0, color: BioSenseColor.stable),
        const SizedBox(width: 6),
        _MatrixVector(
          label: isEs ? 'Cripto' : 'Crypto',
          value: 1.0, color: BioSenseColor.stable),
      ]),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        Text(
          isEs
            ? 'Confianza Clínica Global'
            : 'Overall Clinical Confidence',
          style: BioSenseText.caption.copyWith(fontSize: 9)),
        Text('99.2%',
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 11,
            fontWeight: FontWeight.w800,
            color: BioSenseColor.stable)),
      ]),
    ]));
}

class _MatrixVector extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MatrixVector({
    required this.label, required this.value,
    required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(BioSenseRadius.full),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: color.withOpacity(0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 4)),
    const SizedBox(height: 3),
    Text('${(value*100).round()}%',
      style: TextStyle(
        fontFamily: 'Inter', fontSize: 9,
        fontWeight: FontWeight.w700, color: color),
      textAlign: TextAlign.center),
    Text(label,
      style: BioSenseText.caption.copyWith(fontSize: 8),
      textAlign: TextAlign.center),
  ]));
}
