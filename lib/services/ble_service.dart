// ============================================================
// BIOSENSE — BLE Service v1.14 compatible
// flutter_blue_plus: 1.14.0
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
  StreamSubscription? _scanSub;
  StreamSubscription? _dataSub;

  final _rawMetricsController =
      StreamController<Map<String, double>>.broadcast();
  Stream<Map<String, double>> get rawMetricsStream =>
      _rawMetricsController.stream;

  final _statusController =
      StreamController<BleConnectionStatus>.broadcast();
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BleConnectionStatus get status => _status;

  void _setStatus(BleConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  Future<void> startScan() async {
    if (_status == BleConnectionStatus.scanning ||
        _status == BleConnectionStatus.connected) return;
    _setStatus(BleConnectionStatus.scanning);
    try {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.localName == kDeviceName) {
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
              await c.setNotifyValue(true);
              _dataSub = c.value.listen(_onData);
            }
          }
        }
      }
      device.state.listen((state) {
        if (state == BluetoothDeviceState.disconnected) {
          _setStatus(BleConnectionStatus.disconnected);
        }
      });
    } catch (_) {
      _setStatus(BleConnectionStatus.error);
    }
  }

  void _onData(List<int> bytes) {
    if (bytes.length < 16) return;
    final buffer = Uint8List.fromList(bytes).buffer;
    final view = ByteData.view(buffer);
    final hrv  = view.getFloat32(0,  Endian.little);
    final temp = view.getFloat32(4,  Endian.little);
    final resp = view.getFloat32(8,  Endian.little);
    final gsr  = view.getFloat32(12, Endian.little);
    _rawMetricsController.add({
      'hrv':  (hrv / 800.0).clamp(0.5, 1.5),
      'temp': temp / 36.5,
      'resp': resp / 16.0,
      'gsr':  (gsr / 100.0).clamp(0.0, 2.0),
    });
  }

  // ── Modo simulación
  Timer? _mockTimer;
  int    _mockCycle = 0;
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
