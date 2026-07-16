// ============================================================
// PHSE Altea Garay — Packet Decoder v5.7.1
// CRC32 IEEE 802.3 — offset 40 (estándar oro)
// Diseño: Gustavo Enrique Garay | ALTEA-GARAY HTS
// USPTO Provisional #63/914,860
// ============================================================

import 'dart:typed_data';

class BioSensePacket {
  final int    sequenceNumber;
  final int    epochTime;
  final double hrv;           // ms RMSSD
  final double temperature;   // °C
  final double gsr;           // µS conductancia
  final double spo2;          // % saturación
  final int    fitnessWinner; // Canal ganador Darwin (0-4)
  final double glucose;       // mg/dL estimado no invasivo
  final double motion;        // g magnitud movimiento MPU6050
  final List<int> fitnessScores; // [C1,C2,C3,C4,C5] Darwin scores

  const BioSensePacket({
    required this.sequenceNumber,
    required this.epochTime,
    required this.hrv,
    required this.temperature,
    required this.gsr,
    required this.spo2,
    required this.fitnessWinner,
    required this.glucose,
    required this.motion,
    required this.fitnessScores,
  });

  // Estado clínico de glucosa
  String get glucoseStatus {
    if (glucose < 70)  return 'hypo';
    if (glucose < 100) return 'normal';
    if (glucose < 126) return 'pre';
    if (glucose < 180) return 'high';
    return 'hyper';
  }

  String glucoseStatusLabel(bool isEs) {
    switch (glucoseStatus) {
      case 'hypo':   return isEs ? 'Hipoglucemia' : 'Hypoglycemia';
      case 'normal': return isEs ? 'Normal' : 'Normal';
      case 'pre':    return isEs ? 'Prediabetes' : 'Prediabetes';
      case 'high':   return isEs ? 'Elevada' : 'Elevated';
      default:       return isEs ? 'Hiperglucemia' : 'Hyperglycemia';
    }
  }

  // Canal ganador Darwin
  String get winnerChannel {
    const names = ['IR/HRV', 'Verde', 'NIR/Glucosa', 'Temperatura', 'Movimiento'];
    return 'C${fitnessWinner + 1} · ${names[fitnessWinner.clamp(0, 4)]}';
  }

  // Fitness promedio del sistema
  double get avgFitness {
    if (fitnessScores.isEmpty) return 0;
    return fitnessScores.reduce((a, b) => a + b) / fitnessScores.length;
  }
}

class BioSenseDecoder {
  static const int PACKET_SIZE = 44;
  static const int CRC_OFFSET  = 40;

  // CRC32 IEEE 802.3 — idéntico al firmware ESP32
  static int _calculateCRC32(Uint8List data, int len) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < len; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        crc = (crc >> 1) ^ ((crc & 1) != 0 ? 0xEDB88320 : 0);
      }
    }
    return ~crc & 0xFFFFFFFF;
  }

  static BioSensePacket? decode(Uint8List data) {
    if (data.length != PACKET_SIZE) return null;

    final bd = ByteData.view(
      data.buffer, data.offsetInBytes, data.length);

    // Validar CRC32
    final receivedCrc = bd.getUint32(CRC_OFFSET, Endian.little);
    final computedCrc = _calculateCRC32(
      data.sublist(0, CRC_OFFSET), CRC_OFFSET);

    if (receivedCrc != computedCrc) {
      final seq = bd.getUint32(0, Endian.little);
      // ignore: avoid_print
      print('[PHSE] CRC32 FAIL — paquete $seq descartado');
      return null;
    }

    return BioSensePacket(
      sequenceNumber: bd.getUint32(0,  Endian.little),
      epochTime:      bd.getUint32(4,  Endian.little),
      hrv:            bd.getUint16(8,  Endian.little) / 100.0,
      temperature:    bd.getUint16(10, Endian.little) / 100.0,
      gsr:            bd.getUint16(12, Endian.little) / 1000.0,
      spo2:           bd.getUint16(14, Endian.little) / 100.0,
      fitnessWinner:  data[16],
      glucose:        bd.getUint16(17, Endian.little) / 10.0,
      motion:         bd.getUint16(19, Endian.little) / 1000.0,
      fitnessScores:  List<int>.from(data.sublist(21, 26)),
    );
  }
}
