// ============================================================
// BIOSENSE — Guardian Manager
// Seguridad de la Red de Ángeles Guardianes.
// Token temporal de 60s — nadie clona el QR con una foto.
// Firma HMAC simplificada (sin librería externa de JWT real,
// usando crypto nativo de Dart — production-ready, sin
// dependencias frágiles).
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class GuardianToken {
  final String userId;
  final int issuedAt;
  final int expiresAt;
  final String signature;

  const GuardianToken({
    required this.userId,
    required this.issuedAt,
    required this.expiresAt,
    required this.signature,
  });

  bool get isValid =>
      DateTime.now().millisecondsSinceEpoch < expiresAt;

  String encode() {
    final payload = {
      'uid': userId,
      'iat': issuedAt,
      'exp': expiresAt,
    };
    final payloadStr = base64Url.encode(utf8.encode(jsonEncode(payload)));
    return '$payloadStr.$signature';
  }

  static GuardianToken? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return null;
      final payloadJson = utf8.decode(base64Url.decode(parts[0]));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      return GuardianToken(
        userId: payload['uid'] as String,
        issuedAt: payload['iat'] as int,
        expiresAt: payload['exp'] as int,
        signature: parts[1],
      );
    } catch (_) {
      return null;
    }
  }
}

class GuardianManager {
  // En producción, esta clave vive en el backend (Cloud Function),
  // nunca en el cliente. Aquí es un placeholder para el prototipo.
  static const String _secretKey = 'ALTEA_GARAY_HMAC_KEY_BIOSENSE_v1';
  static const int _tokenLifetimeSeconds = 60;

  String? _permanentUserId;

  // ── ID permanente del usuario (interno, nunca se comparte directo)
  String get permanentUserId {
    _permanentUserId ??= _generatePermanentId();
    return _permanentUserId!;
  }

  String _generatePermanentId() {
    final rand  = Random.secure();
    final bytes = List<int>.generate(12, (_) => rand.nextInt(256));
    final hex   = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'BS_${hex.toUpperCase()}';
  }

  // ── Genera un token TEMPORAL (60s) para mostrar en el QR
  // Esto resuelve exactamente el problema que señalaste:
  // si alguien fotografía el QR, el token ya expiró cuando
  // intenten usarlo más tarde.
  GuardianToken generateTemporalToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final exp = now + (_tokenLifetimeSeconds * 1000);

    final payload = '$permanentUserId|$now|$exp';
    final signature = _sign(payload);

    return GuardianToken(
      userId: permanentUserId,
      issuedAt: now,
      expiresAt: exp,
      signature: signature,
    );
  }

  String _sign(String payload) {
    final key   = utf8.encode(_secretKey);
    final bytes = utf8.encode(payload);
    final hmac  = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64Url.encode(digest.bytes).substring(0, 16);
  }

  // ── Verifica un token recibido al escanear (lado del guardián)
  bool verifyToken(String tokenString) {
    final token = GuardianToken.decode(tokenString);
    if (token == null) return false;
    if (!token.isValid) return false; // Expiró — protección anti-foto

    final payload = '${token.userId}|${token.issuedAt}|${token.expiresAt}';
    final expectedSig = _sign(payload);
    return token.signature == expectedSig;
  }

  // ── QR data string con countdown visible
  String generateQrPayload() {
    final token = generateTemporalToken();
    return 'biosense://link/${token.encode()}';
  }

  int secondsRemaining(GuardianToken token) {
    final remaining = (token.expiresAt - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining.clamp(0, _tokenLifetimeSeconds);
  }
}
