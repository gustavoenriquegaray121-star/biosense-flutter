// ============================================================
// BIOSENSE OS — BLE Service v2.0
// UUIDs sincronizados con firmware biosense_band.ino
// MTU negociada: 64 bytes
// Parseo correcto de bytes raw → SecureTelemetryPacket
// ============================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/secure_ble_service.dart';

// ============================================================
// UUIDs — IDÉNTICOS al firmware biosense_band.ino
// ============================================================
const String kServiceUUID        = 'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';
const String kCharacteristicUUID = 'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';
const String kDeviceName         = 'BioSense-Band';
const int    kMtuRequested       = 64;  // MTU mínima para 44 bytes de paquete
const int    kPacketSize         = 44;  // Tamaño exacto del SecureTelemetryPacket

// ============================================================
// ESTADO DE CONEXIÓN
// ============================================================
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  mtuNegotiating,
  ready,          // Conectado + MTU OK + características encontradas
  signalLost,
  error,
}

// ============================================================
// BLE SERVICE
// ============================================================
class BleService {
  // Instancia singleton
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Estado
  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  int _negotiatedMtu = 23; // MTU default BLE

  // Motor de autenticación SecureLink
  final BioSenseAuthEngine _authEngine = BioSenseAuthEngine();

  // Buffer de fragmentación (para paquetes fragmentados)
  final List<int> _fragmentBuffer = [];
  int _lastFragmentSeq = -1;

  // Streams públicos
  final StreamController<BleConnectionState> _stateCtrl =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<SecureTelemetryPacket> _packetCtrl =
      StreamController<SecureTelemetryPacket>.broadcast();
  final StreamController<ValidationResult> _validationCtrl =
      StreamController<ValidationResult>.broadcast();

  Stream<BleConnectionState> get stateStream => _stateCtrl.stream;
  Stream<SecureTelemetryPacket> get packetStream => _packetCtrl.stream;
  Stream<ValidationResult> get validationStream => _validationCtrl.stream;

  BleConnectionState get state => _state;
  int get negotiatedMtu => _negotiatedMtu;
  int get trustScore => _authEngine.trustScore;
  TrustLevel get trustLevel => _authEngine.trustLevel;

  // ── Iniciar escaneo
  Future<void> startScan() async {
    _setState(BleConnectionState.scanning);

    try {
      await FlutterBluePlus.startScan(
        withNames: [kDeviceName],
        withServices: [Guid(kServiceUUID)],
        timeout: const Duration(seconds: 10));

      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName == kDeviceName ||
              r.advertisementData.serviceUuids.contains(Guid(kServiceUUID))) {
            FlutterBluePlus.stopScan();
            _connect(r.device);
            break;
          }
        }
      });
    } catch (e) {
      _setState(BleConnectionState.error);
    }
  }

  // ── Conectar al dispositivo
  Future<void> _connect(BluetoothDevice device) async {
    _setState(BleConnectionState.connecting);
    _device = device;

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _setState(BleConnectionState.connected);

      // Escuchar desconexión
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setState(BleConnectionState.signalLost);
          _fragmentBuffer.clear();
          _authEngine.resetSession();
        }
      });

      // Negociar MTU — CRÍTICO para paquetes de 44 bytes
      await _negotiateMtu(device);

      // Descubrir servicios y característica
      await _discoverServices(device);

    } catch (e) {
      _setState(BleConnectionState.error);
    }
  }

  // ── Negociar MTU mayor al default de 23 bytes
  Future<void> _negotiateMtu(BluetoothDevice device) async {
    _setState(BleConnectionState.mtuNegotiating);
    try {
      _negotiatedMtu = await device.requestMtu(kMtuRequested);
      if (_negotiatedMtu < kPacketSize) {
        // MTU insuficiente — activar modo fragmentación
        _fragmentBuffer.clear();
      }
    } catch (e) {
      // Algunos dispositivos no soportan cambio de MTU
      // Activar fragmentación automáticamente
      _negotiatedMtu = 23;
    }
  }

  // ── Descubrir servicios
  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == Guid(kServiceUUID)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(kCharacteristicUUID)) {
            _characteristic = char;
            await _subscribeToNotifications(char);
            _setState(BleConnectionState.ready);
            return;
          }
        }
      }
    }

    // No se encontró la característica
    _setState(BleConnectionState.error);
  }

  // ── Suscribirse a notificaciones BLE
  Future<void> _subscribeToNotifications(
      BluetoothCharacteristic char) async {
    await char.setNotifyValue(true);

    char.onValueReceived.listen((rawBytes) {
      _handleRawBytes(rawBytes);
    });
  }

  // ── Parsear bytes raw → SecureTelemetryPacket
  // ESTE ES EL PUNTO CRÍTICO — convierte uint8[] del ESP32 a objeto Dart
  void _handleRawBytes(List<int> rawBytes) {
    // Si MTU < 44 bytes, necesitamos reassembly
    if (_negotiatedMtu < kPacketSize) {
      _handleFragmented(rawBytes);
    } else {
      _parseCompletePacket(Uint8List.fromList(rawBytes));
    }
  }

  // ── Manejar fragmentación cuando MTU < 44 bytes
  void _handleFragmented(List<int> fragment) {
    _fragmentBuffer.addAll(fragment);

    // Cuando acumulamos 44 bytes, tenemos el paquete completo
    if (_fragmentBuffer.length >= kPacketSize) {
      final completePacket =
          Uint8List.fromList(_fragmentBuffer.take(kPacketSize).toList());
      _fragmentBuffer.removeRange(0, kPacketSize);
      _parseCompletePacket(completePacket);
    }
  }

  // ── Parsear paquete completo de 44 bytes
  void _parseCompletePacket(Uint8List bytes) {
    if (bytes.length < kPacketSize) return;

    // Deserializar bytes → SecureTelemetryPacket
    final packet = SecureTelemetryPacket.fromBytes(bytes);
    if (packet == null) return;

    // Validar con BioSenseAuthEngine (anti-replay + auth tag)
    final result = _authEngine.validatePacket(packet);
    _validationCtrl.add(result);

    if (result.isValid) {
      // Solo emitir si el paquete es auténtico
      _packetCtrl.add(packet);
    }
  }

  // ── Desconectar
  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _characteristic = null;
    _fragmentBuffer.clear();
    _authEngine.resetSession();
    _setState(BleConnectionState.disconnected);
  }

  void _setState(BleConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  void dispose() {
    _stateCtrl.close();
    _packetCtrl.close();
    _validationCtrl.close();
  }
}
