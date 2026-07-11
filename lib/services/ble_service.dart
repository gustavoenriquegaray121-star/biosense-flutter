// ============================================================
// BIOSENSE OS — BLE Service v2.0
// UUIDs sincronizados con firmware biosense_band.ino
// MTU negociada: 64 bytes
// Mantiene interfaz compatible con HealthRepository y AppStateProvider
// ============================================================

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/secure_ble_service.dart';

// ============================================================
// UUIDs — IDÉNTICOS al firmware biosense_band.ino
// ============================================================
const String kServiceUUID        = 'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';
const String kCharacteristicUUID = 'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';
const String kDeviceName         = 'BioSense-Band';
const int    kMtuRequested       = 64;
const int    kPacketSize         = 44;

// ============================================================
// ESTADO DE CONEXIÓN — compatible con AppStateProvider
// ============================================================
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

// ============================================================
// BLE SERVICE — interfaz compatible con HealthRepository
// ============================================================
class BleService {
  // Estado y conexión
  BleConnectionStatus _status = BleConnectionStatus.disconnected;
  BluetoothDevice? _device;
  int _negotiatedMtu = 23;

  // Motor de autenticación SecureLink
  final BioSenseAuthEngine _authEngine = BioSenseAuthEngine();
  final MockBandPacketGenerator _generator = MockBandPacketGenerator();

  // Buffer para fragmentación
  final List<int> _fragmentBuffer = [];

  // Mock mode
  bool _mockMode = false;
  double _mockPerturbation = 0.0;
  Timer? _mockTimer;
  final Random _rng = Random();

  // Streams públicos
  final _statusCtrl =
      StreamController<BleConnectionStatus>.broadcast();
  final _rawMetricsCtrl =
      StreamController<Map<String, double>>.broadcast();
  final _validationCtrl =
      StreamController<ValidationResult>.broadcast();

  // ── Streams expuestos
  Stream<BleConnectionStatus> get statusStream  => _statusCtrl.stream;
  Stream<Map<String, double>> get rawMetricsStream => _rawMetricsCtrl.stream;
  Stream<ValidationResult>    get validationStream => _validationCtrl.stream;

  BleConnectionStatus get status => _status;
  int  get trustScore  => _authEngine.trustScore;
  TrustLevel get trustLevel => _authEngine.trustLevel;

  // ── Mock mode (sin hardware físico)
  void startMockMode({double perturbation = 0.0}) {
    _mockMode = true;
    _mockPerturbation = perturbation;
    _mockTimer?.cancel();
    _setState(BleConnectionStatus.ready);

    _mockTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final noise = (_rng.nextDouble() - 0.5) * 0.04;
      _rawMetricsCtrl.add({
        'hrv':  1.0 + noise - _mockPerturbation,
        'temp': 1.0 + noise * 0.5 + _mockPerturbation * 0.3,
        'resp': 1.0 + noise * 0.3 + _mockPerturbation * 0.2,
        'gsr':  1.0 + noise * 0.8 + _mockPerturbation * 0.5,
      });
    });
  }

  void setMockPerturbation(double p) {
    _mockPerturbation = p;
    if (!_mockMode) startMockMode(perturbation: p);
  }

  // ── Escaneo BLE real
  Future<void> startScan() async {
    if (_mockMode) { startMockMode(); return; }
    _setState(BleConnectionStatus.scanning);

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(kServiceUUID)],
        timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final uuids = r.advertisementData.serviceUuids
              .map((g) => g.toString().toUpperCase()).toList();
          if (uuids.contains(kServiceUUID.toUpperCase())) {
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

      // Negociar MTU
      _setState(BleConnectionStatus.mtuNegotiating);
      try {
        _negotiatedMtu = await device.requestMtu(kMtuRequested);
      } catch (_) {
        _negotiatedMtu = 23; // fallback con fragmentación
      }

      // Descubrir servicios
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid == Guid(kServiceUUID)) {
          for (final char in service.characteristics) {
            if (char.uuid == Guid(kCharacteristicUUID)) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen(_handleRawBytes);
              _setState(BleConnectionStatus.ready);
              return;
            }
          }
        }
      }
      _setState(BleConnectionStatus.error);
    } catch (e) {
      _setState(BleConnectionStatus.error);
    }
  }

  // ── Parseo de bytes raw del ESP32
  void _handleRawBytes(List<int> rawBytes) {
    if (_negotiatedMtu < kPacketSize) {
      // Fragmentación: acumular hasta 44 bytes
      _fragmentBuffer.addAll(rawBytes);
      if (_fragmentBuffer.length >= kPacketSize) {
        final complete = Uint8List.fromList(
            _fragmentBuffer.take(kPacketSize).toList());
        _fragmentBuffer.removeRange(0, kPacketSize);
        _parsePacket(complete);
      }
    } else {
      _parsePacket(Uint8List.fromList(rawBytes));
    }
  }

  void _parsePacket(Uint8List bytes) {
    if (bytes.length < kPacketSize) return;
    final packet = SecureTelemetryPacket.fromBytes(bytes);
    if (packet == null) return;

    final result = _authEngine.validatePacket(packet);
    _validationCtrl.add(result);

    if (result.isValid) {
      // Normalizar métricas para el motor DHSI
      _rawMetricsCtrl.add({
        'hrv':  _normalize(packet.hrv,  20, 100),
        'temp': _normalize(packet.temperature, 35.5, 38.5),
        'resp': _normalize(packet.spO2, 95, 100),
        'gsr':  _normalize(packet.gsr,  0.1, 10.0),
      });
    }
  }

  // Normalizar valor a rango 0.7-1.3 para el motor DHSI
  double _normalize(double val, double min, double max) {
    final normalized = (val - min) / (max - min);
    return 0.7 + normalized * 0.6;
  }

  // ── Desconectar
  Future<void> disconnectDevice() async {
    _mockTimer?.cancel();
    _mockMode = false;
    await _device?.disconnect();
    _device = null;
    _fragmentBuffer.clear();
    _authEngine.resetSession();
    _setState(BleConnectionStatus.disconnected);
  }

  void _setState(BleConnectionStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    _mockTimer?.cancel();
    _statusCtrl.close();
    _rawMetricsCtrl.close();
    _validationCtrl.close();
  }
}
