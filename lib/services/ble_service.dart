// ============================================================
// PHSE Altea Garay — BLE Service v3.0
//
// Compatible con flutter_blue_plus 1.14.0
// Protocolo BioSense v9 — 44 bytes
//
// Capas:
//   BLE -> fragment reassembler -> decoder -> rawMetricsStream
//
// IMPORTANTE:
//   No modifica el protocolo v9.
// ============================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/biosense_decoder.dart';

// ============================================================
// Estado de conexión
// ============================================================

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
}

// Compatibilidad con cualquier código antiguo que pudiera
// referirse al nombre anterior.
typedef BleConnectionState = BleConnectionStatus;

// ============================================================
// Servicio BLE
// ============================================================

class BleService {
  static const String deviceName = 'BioSense-Band';

  static const String serviceUuid =
      'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';

  static const String charUuid =
      'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';

  static const String epochUuid =
      'C206F56F-3B8E-4D9B-AF4F-B2C3D4E5F6A';

  // ==========================================================
  // Streams públicos
  // ==========================================================

  final StreamController<BleConnectionStatus> _statusCtrl =
      StreamController<BleConnectionStatus>.broadcast();

  final StreamController<BioSensePacket> _packetCtrl =
      StreamController<BioSensePacket>.broadcast();

  final StreamController<Map<String, double>> _rawMetricsCtrl =
      StreamController<Map<String, double>>.broadcast();

  Stream<BleConnectionStatus> get statusStream => _statusCtrl.stream;

  Stream<BioSensePacket> get packetStream => _packetCtrl.stream;

  Stream<Map<String, double>> get rawMetricsStream =>
      _rawMetricsCtrl.stream;

  // ==========================================================
  // Estado
  // ==========================================================

  BleConnectionStatus _status =
      BleConnectionStatus.disconnected;

  BluetoothDevice? _device;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  final BleFragmentReassembler _reassembler =
      BleFragmentReassembler();

  // ==========================================================
  // Mock
  // ==========================================================

  Timer? _mockTimer;
  double _mockPerturbation = 0.0;
  int _mockSequence = 0;

  // ==========================================================
  // Getters
  // ==========================================================

  BleConnectionStatus get status => _status;

  // Compatibilidad con código antiguo.
  BleConnectionStatus get state => _status;

  // ==========================================================
  // Estado interno
  // ==========================================================

  void _setStatus(BleConnectionStatus status) {
    if (_status == status) {
      return;
    }

    _status = status;
    _statusCtrl.add(status);
  }

  // ==========================================================
  // API esperada por HealthRepository
  // ==========================================================

  Future<void> startScan() async {
    await connect();
  }

  Future<void> disconnectDevice() async {
    await disconnect();
  }

  // ==========================================================
  // Conexión BLE
  // ==========================================================

  Future<void> connect() async {
    // Si venimos del modo demostracion, el estado es "connected" por el
    // mock. Hay que apagar el mock primero o el escaneo nunca arranca.
    if (_mockTimer != null) {
      await _stopMockTimer();
      _status = BleConnectionStatus.disconnected;
    }

    if (_status != BleConnectionStatus.disconnected) {
      return;
    }

    _reassembler.reset();

    _setStatus(BleConnectionStatus.scanning);

    try {
      await _scanSub?.cancel();
      _scanSub = null;

      // flutter_blue_plus 1.14.0 NO tiene withNames.
      // Escaneamos y filtramos manualmente por localName.
      _scanSub = FlutterBluePlus.scanResults.listen(
        (results) {
          _findAndConnect(results);
        },
        onError: (_) {
          _handleConnectionFailure();
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // Si el escaneo termino y no se encontro la pulsera, el estado
      // seguia en "scanning" para siempre. Lo regresamos a desconectado.
      if (_status == BleConnectionStatus.scanning) {
        await _handleConnectionFailure();
      }
    } catch (_) {
      await _handleConnectionFailure();
    }
  }

  Future<void> _findAndConnect(
    List<ScanResult> results,
  ) async {
    if (_status != BleConnectionStatus.scanning) {
      return;
    }

    ScanResult? target;

    for (final result in results) {
      final deviceNameFromPlatform =
          result.device.localName.trim();

      final deviceNameFromAdvertisement =
          result.advertisementData.localName.trim();

      if (deviceNameFromPlatform == deviceName ||
          deviceNameFromAdvertisement == deviceName) {
        target = result;
        break;
      }
    }

    if (target == null) {
      return;
    }

    await _scanSub?.cancel();
    _scanSub = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    _device = target.device;

    _setStatus(BleConnectionStatus.connecting);

    await _connectDevice(target.device);
  }

  Future<void> _connectDevice(
    BluetoothDevice device,
  ) async {
    try {
      await device.connect(
        autoConnect: false,
      );

      await _connSub?.cancel();

      _connSub = device.connectionState.listen(
        (state) {
          if (state ==
              BluetoothConnectionState.disconnected) {
            _reassembler.reset();

            _setStatus(
              BleConnectionStatus.disconnected,
            );
          }
        },
      );

      await _setupNotifications(device);

      _setStatus(BleConnectionStatus.connected);
    } catch (_) {
      _reassembler.reset();

      _setStatus(
        BleConnectionStatus.disconnected,
      );
    }
  }

  // ==========================================================
  // Servicios / características
  // ==========================================================

  Future<void> _setupNotifications(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();

    bool dataCharacteristicFound = false;

    for (final service in services) {
      final serviceId =
          service.uuid.toString().toUpperCase();

      if (serviceId != serviceUuid.toUpperCase()) {
        continue;
      }

      for (final characteristic
          in service.characteristics) {
        final uuid =
            characteristic.uuid.toString().toUpperCase();

        // ----------------------------------------------------
        // Característica de datos BioSense
        // ----------------------------------------------------

        if (uuid == charUuid.toUpperCase()) {
          await characteristic.setNotifyValue(true);

          await _notifySub?.cancel();

          _notifySub =
              characteristic.onValueReceived.listen(
            _onFragment,
          );

          dataCharacteristicFound = true;
        }

        // ----------------------------------------------------
        // Sincronización de epoch
        // ----------------------------------------------------

        if (uuid == epochUuid.toUpperCase()) {
          final epoch =
              DateTime.now()
                      .millisecondsSinceEpoch ~/
                  1000;

          final bytes = Uint8List(4);

          final bd = ByteData.sublistView(bytes);

          bd.setUint32(
            0,
            epoch,
            Endian.little,
          );

          await characteristic.write(
            bytes,
            withoutResponse: false,
          );
        }
      }
    }

    if (!dataCharacteristicFound) {
      throw StateError(
        'BioSense data characteristic not found',
      );
    }
  }

  // ==========================================================
  // Recepción BLE
  // ==========================================================

  void _onFragment(List<int> raw) {
    if (raw.length == 44) {
      _tryDecode(
        Uint8List.fromList(raw),
      );
      return;
    }

    final assembled = _reassembler.feed(raw);

    if (assembled == null) {
      return;
    }

    _tryDecode(assembled);
  }

  // ==========================================================
  // Decoder
  // ==========================================================

  void _tryDecode(Uint8List data) {
    final packet = BioSenseDecoder.decode(data);

    if (packet == null) {
      return;
    }

    _packetCtrl.add(packet);

    _emitRawMetrics(packet);
  }

  // ==========================================================
  // Adaptador BioSensePacket -> HealthRepository
  // ==========================================================
  //
  // El protocolo v9 contiene HRV y temperatura, pero NO tiene
  // campos explícitos llamados "resp" y "gsr".
  //
  // Por eso NO vamos a inventar una correspondencia fisiológica.
  //
  // Para evitar contaminar el motor DHSI con datos falsos,
  // usamos los valores disponibles del paquete solamente para
  // los canales que realmente existen y mantenemos resp/gsr
  // en 1.0 hasta que el contrato del protocolo defina esos
  // canales.
  //
  // Esto permite compilar y mantener la arquitectura limpia.
  // ==========================================================

  void _emitRawMetrics(BioSensePacket packet) {
    _rawMetricsCtrl.add({
      'hrv': packet.hrv,
      'temp': packet.temperature,
      'resp': 1.0,
      'gsr': 1.0,
    });
  }

  // ==========================================================
  // MOCK MODE
  // ==========================================================

  Future<void> startMockMode({
    double perturbation = 0.0,
  }) async {
    _mockPerturbation = perturbation;

    await _stopMockTimer();

    _reassembler.reset();

    _setStatus(BleConnectionStatus.connected);

    _mockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        _emitMockMetrics();
      },
    );

    _emitMockMetrics();
  }

  void setMockPerturbation(double perturbation) {
    _mockPerturbation = perturbation;
  }

  void _emitMockMetrics() {
    final p = _mockPerturbation;

    // Variación pequeña para evitar una señal completamente
    // estática durante el modo de prueba.
    final wave =
        math.sin(_mockSequence * 0.15) * 0.01;

    _mockSequence++;

    _rawMetricsCtrl.add({
      'hrv': 1.0 + p + wave,
      'temp': 1.0 + (p * 0.5) + wave,
      'resp': 1.0 + p + wave,
      'gsr': 1.0 + p + wave,
    });
  }

  Future<void> _stopMockTimer() async {
    _mockTimer?.cancel();
    _mockTimer = null;
  }

  // ==========================================================
  // Error de conexión
  // ==========================================================

  Future<void> _handleConnectionFailure() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSub?.cancel();
    _scanSub = null;

    _reassembler.reset();

    _setStatus(
      BleConnectionStatus.disconnected,
    );
  }

  // ==========================================================
  // Desconexión
  // ==========================================================

  Future<void> disconnect() async {
    await _stopMockTimer();

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSub?.cancel();
    _scanSub = null;

    await _notifySub?.cancel();
    _notifySub = null;

    await _connSub?.cancel();
    _connSub = null;

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;

    _reassembler.reset();

    _setStatus(
      BleConnectionStatus.disconnected,
    );
  }

  // ==========================================================
  // Dispose
  // ==========================================================

  Future<void> dispose() async {
    await disconnect();

    await _statusCtrl.close();
    await _packetCtrl.close();
    await _rawMetricsCtrl.close();
  }
}
