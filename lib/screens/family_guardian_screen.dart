// ============================================================
// BIOSENSE — Family Guardian Screen (👨‍👩‍👧‍👦 Familia)
// Token QR temporal de 60s — seguridad nivel banco
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state_provider.dart';
import '../core/guardian_manager.dart';

class FamilyGuardianScreen extends StatefulWidget {
  const FamilyGuardianScreen({super.key});
  @override
  State<FamilyGuardianScreen> createState() => _FamilyGuardianScreenState();
}

class _FamilyGuardianScreenState extends State<FamilyGuardianScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final GuardianManager _guardian = GuardianManager();
  GuardianToken? _currentToken;
  Timer? _refreshTimer;
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
      _currentToken = _guardian.generateTemporalToken();
      _secondsLeft  = 60;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _generateToken(); // Auto-renueva
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppStateProvider>();
    final isEs = app.language.name == 'es';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEs ? 'Red de Ángeles Guardianes' : 'Guardian Network'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF1F4E79),
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: const Color(0xFF1F4E79),
          tabs: [
            Tab(text: isEs ? 'Mi código QR' : 'My QR Code'),
            Tab(text: isEs ? 'Mis familiares' : 'My Family'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildMyQr(isEs),
        _buildFamiliars(isEs),
      ]),
    );
  }

  Widget _buildMyQr(bool isEs) {
    final token   = _currentToken;
    final payload = token != null ? _guardian.generateQrPayload() : '';
    final expired = token != null && !token.isValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Text('🛡️', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          isEs ? 'Comparte este código con tu Ángel Guardián'
               : 'Share this code with your Guardian Angel',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
            color: Color(0xFF1F4E79))),
        const SizedBox(height: 8),
        Text(
          isEs ? 'Solo verán tu semáforo (🟢/🟡/🟠/🔴). Nunca datos médicos.'
               : 'They will only see your status (🟢/🟡/🟠/🔴). Never medical data.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),

        // QR con countdown
        Stack(alignment: Alignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
                blurRadius: 12)]),
            child: expired
              ? const SizedBox(width: 200, height: 200,
                  child: Center(child: Text('🔄', style: TextStyle(fontSize: 60))))
              : QrImageView(data: payload, version: QrVersions.auto,
                  size: 200, backgroundColor: Colors.white),
          ),
          if (!expired)
            Positioned(bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _secondsLeft > 20
                    ? const Color(0xFF22C55E)
                    : _secondsLeft > 10
                      ? const Color(0xFFF97316)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('${_secondsLeft}s',
                  style: const TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.bold)),
              )),
        ]),
        const SizedBox(height: 16),

        // Botón refrescar
        OutlinedButton.icon(
          onPressed: _generateToken,
          icon: const Icon(Icons.refresh),
          label: Text(isEs ? 'Generar nuevo código' : 'Generate new code'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1F4E79),
            side: const BorderSide(color: Color(0xFF1F4E79))),
        ),
        const SizedBox(height: 20),

        // Caja de privacidad
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.4))),
          child: Column(children: [
            const Text('🔒', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              isEs
                ? 'El código expira en 60 segundos. Si alguien te fotografía el QR, no podrá usarlo después. Privacidad total.'
                : 'The code expires in 60 seconds. If someone photographs it, they cannot use it later. Total privacy.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFamiliars(bool isEs) {
    // Mock data — en producción viene de Firestore / Guardian Service
    final familiars = [
      _FamiliarMock(isEs ? 'Mamá (Doña Mary)' : 'Mom (Doña Mary)',
        isEs ? 'Cambios tempranos — hace 2 horas' : 'Early changes — 2 hours ago',
        'orange', const Color(0xFFF97316), phone: ''),
      _FamiliarMock(isEs ? 'Hijo (Danny)' : 'Son (Danny)',
        isEs ? 'Todo bien' : 'All good',
        'green', const Color(0xFF22C55E), phone: ''),
    ];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(isEs ? '🔗 Vincular familiar (escanear QR)'
                             : '🔗 Link family member (scan QR)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      Expanded(
        child: familiars.isEmpty
          ? Center(child: Text(
              isEs ? 'Aún no tienes familiares vinculados.\nEscanea su QR para empezar.'
                   : 'No family members linked yet.\nScan their QR to start.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF64748B))))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: familiars.length,
              itemBuilder: (_, i) => _familiarCard(familiars[i], isEs)),
      ),
    ]);
  }

  Widget _familiarCard(_FamiliarMock f, bool isEs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)]),
      child: Row(children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(color: f.color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: f.color.withOpacity(0.4),
              blurRadius: 8, spreadRadius: 2)])),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold,
            fontSize: 16, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Text(f.status, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ])),
        IconButton(
          icon: const Icon(Icons.phone, color: Color(0xFF22C55E), size: 28),
          onPressed: () {},
          tooltip: isEs ? 'Llamar' : 'Call'),
      ]),
    );
  }
}

class _FamiliarMock {
  final String name, status, statusKey, phone;
  final Color color;
  const _FamiliarMock(this.name, this.status, this.statusKey, this.color, {this.phone = ''});
}
