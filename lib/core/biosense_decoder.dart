// ============================================================
// PHSE Altea Garay — biosense_decoder.dart v2.2 FINAL
// Protocolo v9 (0x09) — 44 bytes, CRC32 en bytes 40-43
// ============================================================

import 'dart:typed_data';

// ── Paquete decodificado ───────────────────────────────────
class BioSensePacket {
  final int    protocolVersion;    // byte 0  = 0x09
  final int    sensorFlags;        // byte 1
  final int    sequenceNumber;     // bytes 2-5 LE
  final int    epochTime;          // bytes 6-9 LE
  final double hrv;                // bytes 10-11 / 100.0
  final double temperature;        // bytes 12-13 / 100.0
  // bytes 14-15: reservados
  final double spo2;               // bytes 16-17 / 100.0
  final int    fitnessWinnerScore; // byte 18 — puntuación del canal ganador
  final double glucose;            // bytes 19-20 entero mg/dL (experimental)
  final double motion;             // bytes 21-22 / 1000.0
  final List<int> fitnessScores;   // bytes 23-27 (C0..C4)
  final int    fitnessWinner;      // byte 28 — índice 0-4 del canal ganador
  final double battery;            // bytes 29-30 / 1000.0
  final int    heartRateAvg;       // byte 31 — beatAvg
  final int    heartRateInstant;   // byte 32 — BPM instantáneo
  final bool   batteryLow;         // byte 33
  final int    alertLevel;         // byte 34: 0=verde 1=amarillo 2=rojo
  // bytes 35-39: reservados
  // bytes 40-43: CRC32 LE

  const BioSensePacket({
    required this.protocolVersion,
    required this.sensorFlags,
    required this.sequenceNumber,
    required this.epochTime,
    required this.hrv,
    required this.temperature,
    required this.spo2,
    required this.fitnessWinnerScore,
    required this.glucose,
    required this.motion,
    required this.fitnessScores,
    required this.fitnessWinner,
    required this.battery,
    required this.heartRateAvg,
    required this.heartRateInstant,
    required this.batteryLow,
    required this.alertLevel,
  });

  // ── Flags ──────────────────────────────────────────────
  bool get maxValid            => (sensorFlags & 0x01) != 0;
  bool get mlxValid            => (sensorFlags & 0x02) != 0;
  bool get mpuValid            => (sensorFlags & 0x04) != 0;
  bool get batteryValid        => (sensorFlags & 0x08) != 0;
  bool get hrvValid            => (sensorFlags & 0x10) != 0;
  bool get oxyValid            => (sensorFlags & 0x20) != 0;
  bool get glucoseExperimental => (sensorFlags & 0x40) != 0;
  bool get motionValid         => (sensorFlags & 0x80) != 0;

  // ── Helpers ────────────────────────────────────────────
  String get alertName {
    switch (alertLevel) {
      case 1:  return 'warning';
      case 2:  return 'critical';
      default: return 'stable';
    }
  }

  String get winnerChannel {
    const names = ['IR/HRV', 'Verde', 'NIR/Glucosa', 'Temperatura', 'Movimiento'];
    final idx = fitnessWinner.clamp(0, 4) as int;
    return 'C${idx + 1} · ${names[idx]}';
  }

  double get avgFitness {
    if (fitnessScores.isEmpty) return 0;
    return fitnessScores.reduce((a, b) => a + b) / fitnessScores.length;
  }
}

// ── Reensamblador de fragmentos BLE v9 ────────────────────
// Formato de cada fragmento enviado por el firmware:
//   bytes 0-3 : sequenceNumber (LE uint32)
//   byte  4   : índice del fragmento (0-based)
//   byte  5   : total de fragmentos para este paquete
//   bytes 6.. : payload (máximo FRAG_PAYLOAD=14 bytes)
//
// Para un paquete de 44 bytes con payload 14:
//   ceil(44/14) = 4 fragmentos esperados
class BleFragmentReassembler {
  static const int _packetSize   = 44;
  static const int _maxPayload   = 14;
  static const int _expectedFrgs = 4; // ceil(44/14)

  // seq → { index → payload }
  final Map<int, Map<int, List<int>>> _bufs  = {};
  final Map<int, int>                 _totals = {};

  /// Alimentar un fragmento BLE crudo.
  /// Devuelve los 44 bytes reconstruidos si el paquete está completo,
  /// o null si aún faltan fragmentos.
  Uint8List? feed(List<int> raw) {
    // Paquete completo sin fragmentar (MTU grande)
    if (raw.length == _packetSize) {
      return Uint8List.fromList(raw);
    }

    // Mínimo: 6 bytes de encabezado + 1 byte de payload
    if (raw.length < 7) return null;

    final seq     = raw[0] | (raw[1] << 8) | (raw[2] << 16) | (raw[3] << 24);
    final index   = raw[4];
    final total   = raw[5];
    final payload = raw.sublist(6);

    // Validaciones de coherencia del protocolo
    if (total == 0 || total > _expectedFrgs) return null;
    if (index >= total) return null;
    if (payload.isEmpty || payload.length > _maxPayload) return null;

    // Inicializar buffer para esta secuencia
    if (!_bufs.containsKey(seq)) {
      _bufs[seq]   = {};
      _totals[seq] = total;
      // Evitar acumulación: conservar solo los últimos 4 paquetes en vuelo
      if (_bufs.length > 4) {
        final oldest = _bufs.keys.reduce((a, b) => a < b ? a : b);
        _bufs.remove(oldest);
        _totals.remove(oldest);
      }
    }

    // Rechazar si el total cambia para la misma secuencia
    if (_totals[seq] != total) return null;

    // Guardar fragmento (ignorar duplicados)
    _bufs[seq]![index] = payload;

    // Verificar que tenemos todos los fragmentos
    final buf = _bufs[seq]!;
    if (buf.length < total) return null;
    for (int i = 0; i < total; i++) {
      if (!buf.containsKey(i)) return null;
    }

    // Reconstruir ordenado por índice
    final assembled = <int>[];
    for (int i = 0; i < total; i++) {
      assembled.addAll(buf[i]!);
    }

    _bufs.remove(seq);
    _totals.remove(seq);

    // Rechazar si el resultado no es exactamente 44 bytes
    if (assembled.length < _packetSize) return null;
    return Uint8List.fromList(assembled.sublist(0, _packetSize));
  }

  void reset() {
    _bufs.clear();
    _totals.clear();
  }
}

// ── Decoder principal ──────────────────────────────────────
class BioSenseDecoder {
  static const int _packetSize = 44;
  static const int _crcOffset  = 40;
  static const int _protoV9    = 0x09;

  static int _crc32(Uint8List data, int len) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < len; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xEDB88320 : 0);
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }

  /// Decodifica 44 bytes reconstruidos.
  /// Devuelve null si la versión o CRC no coinciden.
  static BioSensePacket? decode(Uint8List data) {
    if (data.length != _packetSize) return null;

    final bd = ByteData.sublistView(data);

    if (data[0] != _protoV9) return null;

    final receivedCrc = bd.getUint32(_crcOffset, Endian.little);
    if (receivedCrc != _crc32(data, _crcOffset)) return null;

    return BioSensePacket(
      protocolVersion:    data[0],
      sensorFlags:        data[1],
      sequenceNumber:     bd.getUint32(2,  Endian.little),
      epochTime:          bd.getUint32(6,  Endian.little),
      hrv:                bd.getUint16(10, Endian.little) / 100.0,
      temperature:        bd.getUint16(12, Endian.little) / 100.0,
      spo2:               bd.getUint16(16, Endian.little) / 100.0,
      fitnessWinnerScore: data[18],
      glucose:            bd.getUint16(19, Endian.little).toDouble(),
      motion:             bd.getUint16(21, Endian.little) / 1000.0,
      fitnessScores:      List<int>.unmodifiable(data.sublist(23, 28)),
      fitnessWinner:      data[28],
      battery:            bd.getUint16(29, Endian.little) / 1000.0,
      heartRateAvg:       data[31],
      heartRateInstant:   data[32],
      batteryLow:         data[33] != 0,
      alertLevel:         data[34],
    );
  }
}

