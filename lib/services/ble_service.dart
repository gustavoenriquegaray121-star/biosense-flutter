// ============================================================
// PHSE Altea Garay — ble_service.dart v2.2 FINAL
// Un solo reensamblador (BleFragmentReassembler en decoder.dart)
// Sin _reassembler duplicado
// ============================================================

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:phse_altea_garay/core/biosense_decoder.dart';

enum BleConnectionState { disconnected, scanning, connecting, connected }

class BleService {
  static const String _deviceName = 'BioSense-Band';
  static const String _serviceUuid =
      'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';
  static const String _charUuid =
      'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';
  static const String _epochUuid =
      'C206F56F-3B8E-4D9B-AF4F-B2C3D4E5F6A';

  final _stateCtrl  = StreamController<BleConnectionState>.broadcast();
  final _packetCtrl = StreamController<BioSensePacket>.broadcast();

  Stream<BleConnectionState> get stateStream  => _stateCtrl.stream;
  Stream<BioSensePacket>     get packetStream  => _packetCtrl.stream;

  BleConnectionState _state = BleConnectionState.disconnected;
  BluetoothDevice?   _device;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  // Un solo reensamblador — definido en biosense_decoder.dart
  final _reassembler = BleFragmentReassembler();

  BleConnectionState get state => _state;

  void _setState(BleConnectionState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  // ── Conexión ───────────────────────────────────────────
  Future<void> connect() async {
    if (_state != BleConnectionState.disconnected) return;
    _setState(BleConnectionState.scanning);
    _reassembler.reset();

    await FlutterBluePlus.startScan(
      withNames: [_deviceName],
      timeout: const Duration(seconds: 15),
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (results.isEmpty) return;
      await FlutterBluePlus.stopScan();
      _device = results.first.device;
      _setState(BleConnectionState.connecting);
      await _connectDevice(_device!);
    });
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      _setState(BleConnectionState.connected);

      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _setState(BleConnectionState.disconnected);
          _reassembler.reset();
        }
      });

      await _setupNotifications(device);
    } catch (_) {
      _setState(BleConnectionState.disconnected);
    }
  }

  Future<void> _setupNotifications(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final svc in services) {
      if (svc.uuid.toString().toUpperCase() !=
          _serviceUuid.toUpperCase()) continue;

      for (final char in svc.characteristics) {
        final uuid = char.uuid.toString().toUpperCase();

        // Notificaciones de datos
        if (uuid == _charUuid.toUpperCase()) {
          await char.setNotifyValue(true);
          _notifySub = char.onValueReceived.listen(_onFragment);
        }

        // Sincronizar epoch con el ESP32-C3
        if (uuid == _epochUuid.toUpperCase()) {
          final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final bytes = Uint8List(4)
            ..[0] = epoch & 0xFF
            ..[1] = (epoch >> 8) & 0xFF
            ..[2] = (epoch >> 16) & 0xFF
            ..[3] = (epoch >> 24) & 0xFF;
          await char.write(bytes, withoutResponse: false);
        }
      }
    }
  }

  // ── Receptor de fragmentos ─────────────────────────────
  void _onFragment(List<int> raw) {
    final complete = _reassembler.feed(raw);
    if (complete == null) return;
    final packet = BioSenseDecoder.decode(complete);
    if (packet != null) _packetCtrl.add(packet);
  }

  // ── Desconexión ────────────────────────────────────────
  Future<void> disconnect() async {
    await _scanSub?.cancel();
    await _connSub?.cancel();
    await _notifySub?.cancel();
    await _device?.disconnect();
    _reassembler.reset();
    _setState(BleConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateCtrl.close();
    _packetCtrl.close();
  }
}

