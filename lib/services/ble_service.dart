// ============================================================
// BIOSENSE OS — BLE Service v2.1 (Fixed)
// Sincronizado con firmware biosense_band.ino y API FlutterBluePlus
// ============================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/secure_ble_service.dart';

const String kServiceUUID        = 'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';
const String kCharacteristicUUID = 'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';
const String kDeviceName         = 'BioSense-Band';
const int    kMtuRequested       = 64;
const int    kPacketSize         = 44;

// Cambiado a Status para coincidir con tu AppStateProvider
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  mtuNegotiating,
  ready,
  signalLost,
  error,
}

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BleConnectionStatus _state = BleConnectionStatus.disconnected;
  BluetoothDevice? _device;
  int _negotiatedMtu = 23;

  final BioSenseAuthEngine _authEngine = BioSenseAuthEngine();
  final List<int> _fragmentBuffer = [];

  // Streams públicos
  final StreamController<BleConnectionStatus> _stateCtrl =
      StreamController<BleConnectionStatus>.broadcast();
  final StreamController<SecureTelemetryPacket> _packetCtrl =
      StreamController<SecureTelemetryPacket>.broadcast();
  final StreamController<ValidationResult> _validationCtrl =
      StreamController<ValidationResult>.broadcast();

  // Stream adicional que pide health_repository.dart
  final StreamController<List<int>> _rawMetricsCtrl = 
      StreamController<List<int>>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _stateCtrl.stream; // Renombrado a statusStream
  Stream<SecureTelemetryPacket> get packetStream => _packetCtrl.stream;
  Stream<ValidationResult> get validationStream => _validationCtrl.stream;
  Stream<List<int>> get rawMetricsStream => _rawMetricsCtrl.stream; // Getter agregado

  BleConnectionStatus get state => _state;
  int get negotiatedMtu => _negotiatedMtu;
  int get trustScore => _authEngine.trustScore;
  TrustLevel get trustLevel => _authEngine.trustLevel;

  Future<void> startScan() async {
    _setState(BleConnectionStatus.scanning);
    try {
      // Corrección API: Removido 'withNames' no soportado en startScan directo
      await FlutterBluePlus.startScan(
        withServices: [Guid(kServiceUUID)],
        timeout: const Duration(seconds: 10),
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // Corrección API: Usar r.advertisementData.advName en versiones nuevas
          final advName = r.advertisementData.advName;
          if (advName == kDeviceName || r.device.advName == kDeviceName) {
            FlutterBluePlus.stopScan();
            _connect(r.device);
            break;
          }
        }
      });
    } catch (e) {
      _setState(BleConnectionStatus.error);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    _setState(BleConnectionStatus.connecting);
    _device = device;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _setState(BleConnectionStatus.connected);

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setState(BleConnectionStatus.signalLost);
          _fragmentBuffer.clear();
          _authEngine.resetSession();
        }
      });

      await _negotiateMtu(device);
      await _discoverServices(device);

    } catch (e) {
      _setState(BleConnectionStatus.error);
    }
  }

  Future<void> _negotiateMtu(BluetoothDevice device) async {
    _setState(BleConnectionStatus.mtuNegotiating);
    try {
      _negotiatedMtu = await device.requestMtu(kMtuRequested);
    } catch (e) {
      _negotiatedMtu = 23;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == Guid(kServiceUUID)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(kCharacteristicUUID)) {
            await char.setNotifyValue(true);
            char.onValueReceived.listen((rawBytes) {
              _rawMetricsCtrl.add(rawBytes); // Alimentar repositorio analítico
              _handleRawBytes(rawBytes);
            });
            _setState(BleConnectionStatus.ready);
            return;
          }
        }
      }
    }
    _setState(BleConnectionStatus.error);
  }

  void _handleRawBytes(List<int> rawBytes) {
    if (_negotiatedMtu < kPacketSize) {
      _fragmentBuffer.addAll(rawBytes);
      if (_fragmentBuffer.length >= kPacketSize) {
        final completePacket = Uint8List.fromList(_fragmentBuffer.take(kPacketSize).toList());
        _fragmentBuffer.removeRange(0, kPacketSize);
        _parseCompletePacket(completePacket);
      }
    } else {
      _parseCompletePacket(Uint8List.fromList(rawBytes));
    }
  }

  void _parseCompletePacket(Uint8List bytes) {
    if (bytes.length < kPacketSize) return;
    final packet = SecureTelemetryPacket.fromBytes(bytes);
    if (packet == null) return;

    final result = _authEngine.validatePacket(packet);
    _validationCtrl.add(result);

    if (result.isValid) {
      _packetCtrl.add(packet);
    }
  }

  // Métodos puente requeridos por AppStateProvider y HealthRepository
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _fragmentBuffer.clear();
    _authEngine.resetSession();
    _setState(BleConnectionStatus.disconnected);
  }

  Future<void> disconnectDevice() async => await disconnect();
  void startMockMode() { /* No-op: el hardware real toma precedencia */ }
  void setMockPerturbation(double value) { /* No-op en modo productivo */ }

  void _setState(BleConnectionStatus s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    _stateCtrl.close();
    _packetCtrl.close();
    _validationCtrl.close();
    _rawMetricsCtrl.close();
  }
}
