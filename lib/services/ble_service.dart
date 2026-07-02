// ============================================================
// BIOSENSE — BLE Service
// Comunicación con la pulsera ESP32-C3 SuperMini
// Lee paquete binario TelemetryPacket de 16 bytes:
//   [4B hrv float][4B temp float][4B resp float][4B gsr float]
// ============================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String kServiceUuid = 'A17EA550-61A6-4A1B-A045-8B6F9A27F3EA';
const String kCharUuid    = 'B105E45E-5061-4A1B-A045-8B6F9A27F3EA';
const String kDeviceName  = 'BioSense_Band_v1';

enum BleConnectionStatus { disconnected, scanning, connecting, connected, error }

class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _scanSub;
  StreamSubscription? _dataSub;

  final _rawMetricsController = StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get rawMetricsStream => _rawMetricsController.stream;

  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get status => _status;

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  // ── Buscar y conectar con la pulsera
  Future<void> startScan() async {
    if (_status == BleConnectionStatus.scanning ||
        _status == BleConnectionStatus.connected) return;
    _setStatus(BleConnectionStatus.scanning);

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withNames: [kDeviceName],
      );
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.platformName == kDeviceName) {
            await FlutterBluePlus.stopScan();
            await _connect(r.device);
            break;
          }
        }
      });
    } catch (_) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _setStatus(BleConnectionStatus.connecting);
    _device = device;
    try {
      await device.connect(autoConnect: false);
      _setStatus(BleConnectionStatus.connected);

      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.toString().toUpperCase() == kServiceUuid.toUpperCase()) {
          for (final c in s.characteristics) {
            if (c.uuid.toString().toUpperCase() == kCharUuid.toUpperCase()) {
              _characteristic = c;
              await c.setNotifyValue(true);
              _dataSub = c.onValueReceived.listen(_onData);
            }
          }
        }
      }

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setStatus(BleConnectionStatus.disconnected);
        }
      });
    } catch (_) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  // ── Parsear el TelemetryPacket de 16 bytes del firmware
  void _onData(List<int> bytes) {
    if (bytes.length < 16) return;
    final buffer = Uint8List.fromList(bytes).buffer;
    final view = ByteData.view(buffer);

    final hrv  = view.getFloat32(0,  Endian.little);
    final temp = view.getFloat32(4,  Endian.little);
    final resp = view.getFloat32(8,  Endian.little);
    final gsr  = view.getFloat32(12, Endian.little);

    // Normalizar a escala 1.0 = basal (el firmware envía valores crudos)
    _rawMetricsController.add({
      'hrv':  _normalizeHrv(hrv),
      'temp': temp / 36.5,        // 36.5°C = basal humano
      'resp': resp / 16.0,        // 16 rpm = basal humano
      'gsr':  gsr / 100.0,        // normalización relativa
    });
  }

  double _normalizeHrv(double rrIntervalMs) {
    // RR interval típico en reposo: ~800ms. HRV alta = buena variabilidad.
    if (rrIntervalMs <= 0) return 1.0;
    return (rrIntervalMs / 800.0).clamp(0.5, 1.5);
  }

  // ── Modo simulación (desarrollo sin hardware)
  Timer? _mockTimer;
  int _mockCycle = 0;
  double _mockPerturbation = 0.0;

  void startMockMode({double perturbation = 0.0}) {
    _mockPerturbation = perturbation;
    _setStatus(BleConnectionStatus.connected);
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _mockCycle++;
      final noise = ((_mockCycle * 7919) % 100 / 100.0 - 0.5) * 0.04;
      _rawMetricsController.add({
        'hrv':  1.0 + _mockPerturbation * -0.16 + noise,
        'temp': 1.0 + _mockPerturbation *  0.15 + noise,
        'resp': 1.0 + _mockPerturbation *  0.08 + noise,
        'gsr':  1.0 + _mockPerturbation *  0.11 + noise,
      });
    });
  }

  void setMockPerturbation(double p) => _mockPerturbation = p;

  void stopMockMode() {
    _mockTimer?.cancel();
    _setStatus(BleConnectionStatus.disconnected);
  }

  Future<void> disconnectDevice() async {
    _mockTimer?.cancel();
    await _scanSub?.cancel();
    await _dataSub?.cancel();
    await _device?.disconnect();
    _setStatus(BleConnectionStatus.disconnected);
  }

  void dispose() {
    _rawMetricsController.close();
    _statusController.close();
    disconnectDevice();
  }
}
