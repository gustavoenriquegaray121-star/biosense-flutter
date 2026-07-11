// ============================================================
// BIOSENSE OS — SecureBLE Service v1.0
// AES-256-GCM + Anti-Replay + BLE Secure Connections
// Implementa Phoenix SecureLink — USPTO #63/914,860
// ============================================================

import 'dart:typed_data';
import 'package:crypto/crypto.dart';

// ============================================================
// PAQUETE DE TELEMETRÍA SEGURA
// Estructura: [Seq(4)] [Timestamp(8)] [Payload(N)] [Tag(16)]
// ============================================================
class SecureTelemetryPacket {
  final int sequenceNumber;   // Contador anti-replay monotónico
  final int timestampMs;      // Timestamp milisegundos (Uint32, válido hasta 2106)
  final double hrv;           // HRV ms
  final double temperature;   // °C
  final double gsr;           // µS — Estrés Autonómico
  final double spO2;          // % Oxigenación
  final int trustScore;       // 0-100 Trust Continuum
  final Uint8List authTag;    // GCM Auth Tag 16 bytes

  const SecureTelemetryPacket({
    required this.sequenceNumber,
    required this.timestampMs,
    required this.hrv,
    required this.temperature,
    required this.gsr,
    required this.spO2,
    required this.trustScore,
    required this.authTag,
  });

  // Serializar para transmisión BLE (28 bytes payload + 16 tag = 44 bytes)
  Uint8List toBytes() {
    final buffer = ByteData(44);
    buffer.setUint32(0, sequenceNumber, Endian.little);
    buffer.setUint32(4, timestampMs & 0xFFFFFFFF, Endian.little);
    buffer.setUint16(8,  (hrv * 100).round(), Endian.little);
    buffer.setUint16(10, (temperature * 100).round(), Endian.little);
    buffer.setUint16(12, (gsr * 1000).round(), Endian.little);
    buffer.setUint16(14, (spO2 * 100).round(), Endian.little);
    buffer.setUint8(16, trustScore);
    final result = Uint8List(44);
    result.setAll(0, buffer.buffer.asUint8List());
    result.setAll(28, authTag);
    return result;
  }

  // Deserializar desde BLE
  static SecureTelemetryPacket? fromBytes(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final buffer = ByteData.sublistView(bytes);
    return SecureTelemetryPacket(
      sequenceNumber: buffer.getUint32(0, Endian.little),
      timestampMs:    buffer.getUint32(4, Endian.little),
      hrv:         buffer.getUint16(8,  Endian.little) / 100.0,
      temperature: buffer.getUint16(10, Endian.little) / 100.0,
      gsr:         buffer.getUint16(12, Endian.little) / 1000.0,
      spO2:        buffer.getUint16(14, Endian.little) / 100.0,
      trustScore:  buffer.getUint8(16),
      authTag:     bytes.sublist(28, 44),
    );
  }
}

// ============================================================
// MOTOR DE AUTENTICACIÓN — HMAC-SHA256 (simulación AES-GCM)
// En hardware real: usar pointycastle AES-256-GCM
// ============================================================
class BioSenseAuthEngine {
  // Clave de sesión derivada de ECDH (32 bytes)
  // En producción: generada durante el emparejamiento BLE
  static final Uint8List _sessionKey = Uint8List.fromList(
    List.generate(32, (i) => (i * 7 + 13) % 256));

  // Último número de secuencia recibido (anti-replay)
  int _lastSequenceNumber = -1;

  // Trust Score acumulado
  int _trustScore = 100;

  // ── Validar paquete recibido
  ValidationResult validatePacket(SecureTelemetryPacket packet) {
    // 1. Anti-Replay: rechazar secuencias iguales o menores
    if (packet.sequenceNumber <= _lastSequenceNumber) {
      _degradeTrust(15, 'REPLAY_ATTACK');
      return ValidationResult.replayAttack(
        expected: _lastSequenceNumber + 1,
        received: packet.sequenceNumber);
    }

    // 2. Timestamp: rechazar paquetes de más de 5 segundos
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ageMs = (nowMs - packet.timestampMs).toDouble();
    if (ageMs > 5000) {
      _degradeTrust(10, 'STALE_PACKET');
      return ValidationResult.stalePacket(ageMs: ageMs);
    }

    // 3. Verificar Auth Tag (HMAC-SHA256 simulando AES-GCM)
    final computedTag = _computeAuthTag(packet);
    if (!_tagsMatch(computedTag, packet.authTag)) {
      _degradeTrust(25, 'AUTH_FAILURE');
      return ValidationResult.authFailure();
    }

    // 4. Validar rango fisiológico
    if (!_isPhysiologicallyPlausible(packet)) {
      _degradeTrust(5, 'IMPLAUSIBLE_DATA');
      return ValidationResult.implausibleData();
    }

    // 5. Todo OK — actualizar estado
    _lastSequenceNumber = packet.sequenceNumber;
    _recoverTrust(2);

    return ValidationResult.valid(
      trustScore: _trustScore,
      sequenceNumber: packet.sequenceNumber);
  }

  // ── Computar tag de autenticación
  Uint8List _computeAuthTag(SecureTelemetryPacket packet) {
    final message = [
      packet.sequenceNumber,
      packet.timestampMs & 0xFF,
      (packet.hrv * 100).round(),
      (packet.temperature * 100).round(),
      (packet.gsr * 1000).round(),
      (packet.spO2 * 100).round(),
    ].map((v) => v & 0xFF).toList();

    final hmac = Hmac(sha256, _sessionKey);
    final digest = hmac.convert(message);
    return Uint8List.fromList(digest.bytes.take(16).toList());
  }

  bool _tagsMatch(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    // Comparación en tiempo constante (previene timing attacks)
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  bool _isPhysiologicallyPlausible(SecureTelemetryPacket p) {
    return p.hrv >= 20 && p.hrv <= 200 &&
           p.temperature >= 35.0 && p.temperature <= 42.0 &&
           p.gsr >= 0.1 && p.gsr <= 50.0 &&
           p.spO2 >= 80.0 && p.spO2 <= 100.0;
  }

  void _degradeTrust(int amount, String reason) {
    _trustScore = (_trustScore - amount).clamp(0, 100);
  }

  void _recoverTrust(int amount) {
    _trustScore = (_trustScore + amount).clamp(0, 100);
  }

  int get trustScore => _trustScore;

  // Trust Continuum según patente
  TrustLevel get trustLevel {
    if (_trustScore >= 95) return TrustLevel.certified;
    if (_trustScore >= 85) return TrustLevel.observation;
    if (_trustScore >= 70) return TrustLevel.warning;
    return TrustLevel.revoked;
  }

  void resetSession() {
    _lastSequenceNumber = -1;
    _trustScore = 100;
  }
}

// ============================================================
// RESULTADO DE VALIDACIÓN
// ============================================================
class ValidationResult {
  final bool isValid;
  final String reason;
  final int? trustScore;
  final int? sequenceNumber;
  final String? detail;

  const ValidationResult._({
    required this.isValid,
    required this.reason,
    this.trustScore,
    this.sequenceNumber,
    this.detail,
  });

  factory ValidationResult.valid({
    required int trustScore,
    required int sequenceNumber}) =>
    ValidationResult._(
      isValid: true,
      reason: 'VALID',
      trustScore: trustScore,
      sequenceNumber: sequenceNumber);

  factory ValidationResult.replayAttack({
    required int expected,
    required int received}) =>
    ValidationResult._(
      isValid: false,
      reason: 'REPLAY_ATTACK',
      detail: 'Expected seq >$expected, got $received');

  factory ValidationResult.stalePacket({required double ageMs}) =>
    ValidationResult._(
      isValid: false,
      reason: 'STALE_PACKET',
      detail: 'Packet age: ${ageMs.toStringAsFixed(0)} ms');

  factory ValidationResult.authFailure() =>
    ValidationResult._(
      isValid: false,
      reason: 'AUTH_FAILURE',
      detail: 'GCM tag mismatch — data integrity compromised');

  factory ValidationResult.implausibleData() =>
    ValidationResult._(
      isValid: false,
      reason: 'IMPLAUSIBLE_DATA',
      detail: 'Physiological values outside valid range');

  @override
  String toString() => 'ValidationResult('
    'valid: $isValid, reason: $reason'
    '${detail != null ? ", detail: $detail" : ""}'
    '${trustScore != null ? ", trust: $trustScore" : ""})';
}

// ============================================================
// TRUST CONTINUUM — Niveles de confianza
// ============================================================
enum TrustLevel {
  certified,   // 95-100: Operación óptima
  observation, // 85-94:  Micro-desviaciones detectadas
  warning,     // 70-84:  Monitoreo intensivo
  revoked,     // <70:    Certificate Revoked
}

extension TrustLevelX on TrustLevel {
  String label(bool isEs) {
    switch (this) {
      case TrustLevel.certified:
        return isEs ? 'CERTIFICADO' : 'CERTIFIED';
      case TrustLevel.observation:
        return isEs ? 'OBSERVACIÓN' : 'OBSERVATION';
      case TrustLevel.warning:
        return isEs ? 'ADVERTENCIA' : 'WARNING';
      case TrustLevel.revoked:
        return isEs ? 'REVOCADO' : 'REVOKED';
    }
  }

  String get color {
    switch (this) {
      case TrustLevel.certified:   return '#10AC84';
      case TrustLevel.observation: return '#F39C12';
      case TrustLevel.warning:     return '#E67E22';
      case TrustLevel.revoked:     return '#E74C3C';
    }
  }
}

// ============================================================
// PHSE TRUST MATRIX — 4 vectores de confianza
// ============================================================
class PhseTrustMatrix {
  final double patient;      // Trayectoria fisiológica
  final double hardware;     // Integridad del circuito
  final double network;      // Estabilidad del canal BLE
  final double cryptography; // Cadena criptográfica

  const PhseTrustMatrix({
    required this.patient,
    required this.hardware,
    required this.network,
    required this.cryptography,
  });

  // Confianza Clínica Global (Overall Clinical Confidence)
  double get overallConfidence =>
      (patient * 0.35 + hardware * 0.25 +
       network * 0.20 + cryptography * 0.20)
      .clamp(0.0, 1.0);

  String get overallPercentage =>
      '${(overallConfidence * 100).toStringAsFixed(1)}%';

  // Simular matriz en demo mode
  factory PhseTrustMatrix.demo({
    required double dhsi,
    required int trustScore,
  }) {
    return PhseTrustMatrix(
      patient:      dhsi.clamp(0.0, 1.0),
      hardware:     (trustScore / 100.0).clamp(0.0, 1.0),
      network:      1.0,   // En demo: canal perfecto
      cryptography: 1.0,   // En demo: cadena perfecta
    );
  }

  @override
  String toString() => 'PhseTrustMatrix('
    'patient: ${(patient*100).toStringAsFixed(1)}%, '
    'hardware: ${(hardware*100).toStringAsFixed(1)}%, '
    'network: ${(network*100).toStringAsFixed(1)}%, '
    'crypto: ${(cryptography*100).toStringAsFixed(1)}%, '
    'overall: $overallPercentage)';
}

// ============================================================
// GENERADOR DE PAQUETES DEMO (sin hardware físico)
// Simula el firmware biosense_band.ino
// ============================================================
class MockBandPacketGenerator {
  int _sequence = 0;
  final BioSenseAuthEngine _auth = BioSenseAuthEngine();

  SecureTelemetryPacket generatePacket({
    required double hrv,
    required double temperature,
    required double gsr,
    double spO2 = 98.0,
  }) {
    _sequence++;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Crear paquete sin tag
    final partial = SecureTelemetryPacket(
      sequenceNumber: _sequence,
      timestampMs: now,
      hrv: hrv,
      temperature: temperature,
      gsr: gsr,
      spO2: spO2,
      trustScore: 100,
      authTag: Uint8List(16), // placeholder
    );

    // Computar tag real
    final tag = _auth._computeAuthTag(partial);

    // Retornar paquete con tag auténtico
    return SecureTelemetryPacket(
      sequenceNumber: _sequence,
      timestampMs: now,
      hrv: hrv,
      temperature: temperature,
      gsr: gsr,
      spO2: spO2,
      trustScore: 100,
      authTag: tag,
    );
  }
}
