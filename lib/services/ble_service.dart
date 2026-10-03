// ============================================================
// PHSE Altea Garay — BLE Service v2.2
//
// Protocolo v9
// Paquete: 44 bytes
//
// Fragmento:
//   bytes 0-3 : sequenceNumber LE uint32
//   byte  4   : fragment index
//   byte  5   : total fragments
//   bytes 6+  : payload máximo 14 bytes
//
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'biosense_decoder.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

class BleService {
  static const String deviceName =
      'BioSense-Band';

  static const String serviceUuid =
      'A17EA550-1A1D-4C8D-8A9E-D18A3B5C2F4E';

  static const String charUuid =
      'B105E45E-2A7D-4C8A-9F3E-A1B2C3D4E5F6';

  static const String epochUuid =
      'C206F56F-3B8E-4D9B-AF4F-B2C3D4E5F6A';

  // ── Streams ─────────────────────────────────────────────

  final _stateCtrl =
      StreamController<BleConnectionState>.broadcast();

  final _packetCtrl =
      StreamController<BioSensePacket>.broadcast();

  Stream<BleConnectionState>
      get stateStream =>
          _stateCtrl.stream;

  Stream<BioSensePacket>
      get packetStream =>
          _packetCtrl.stream;

  // ── Estado ──────────────────────────────────────────────

  BleConnectionState _state =
      BleConnectionState.disconnected;

  BluetoothDevice? _device;

  StreamSubscription?
      _scanSub;

  StreamSubscription?
      _connSub;

  StreamSubscription?
      _notifySub;

  // ── Reensamblador único ─────────────────────────────────

  final BleFragmentReassembler
      _reassembler =
      BleFragmentReassembler();

  BleConnectionState get state =>
      _state;

  // ========================================================
  // Estado
  // ========================================================

  void _setState(
      BleConnectionState state) {
    if (_state == state) {
      return;
    }

    _state = state;
    _stateCtrl.add(state);
  }

  // ========================================================
  // Conexión
  // ========================================================

  Future<void> connect() async {
    if (_state !=
        BleConnectionState.disconnected) {
      return;
    }

    _reassembler.reset();

    _setState(
      BleConnectionState.scanning,
    );

    try {
      await FlutterBluePlus.startScan(
        withNames: [deviceName],
        timeout:
            const Duration(seconds: 15),
      );

      await _scanSub?.cancel();

      _scanSub =
          FlutterBluePlus.scanResults.listen(
        (results) async {
          if (results.isEmpty) {
            return;
          }

          // Tomamos el primer dispositivo
          // cuyo nombre coincida.
          ScanResult? target;

          for (final result in results) {
            if (result.device.platformName ==
                deviceName) {
              target = result;
              break;
            }

            if (result.advertisementData
                    .advName ==
                deviceName) {
              target = result;
              break;
            }
          }

          if (target == null) {
            return;
          }

          await _scanSub?.cancel();
          _scanSub = null;

          await FlutterBluePlus.stopScan();

          _device = target.device;

          _setState(
            BleConnectionState.connecting,
          );

          await _connectDevice(
            target.device,
          );
        },
      );
    } catch (_) {
      await FlutterBluePlus.stopScan();

      _setState(
        BleConnectionState.disconnected,
      );
    }
  }

  // ========================================================
  // Conectar dispositivo
  // ========================================================

  Future<void> _connectDevice(
      BluetoothDevice device) async {
    try {
      await device.connect(
        autoConnect: false,
      );

      _setState(
        BleConnectionState.connected,
      );

      await _connSub?.cancel();

      _connSub =
          device.connectionState.listen(
        (state) {
          if (state ==
              BluetoothConnectionState
                  .disconnected) {
            _reassembler.reset();

            _setState(
              BleConnectionState
                  .disconnected,
            );
          }
        },
      );

      await _setupNotifications(
        device,
      );
    } catch (_) {
      _reassembler.reset();

      _setState(
        BleConnectionState.disconnected,
      );
    }
  }

  // ========================================================
  // Descubrir servicios y características
  // ========================================================

  Future<void> _setupNotifications(
      BluetoothDevice device) async {
    final services =
        await device.discoverServices();

    for (final service in services) {
      if (service.uuid
              .toString()
              .toUpperCase() !=
          serviceUuid.toUpperCase()) {
        continue;
      }

      for (final characteristic
          in service.characteristics) {
        final uuid = characteristic.uuid
            .toString()
            .toUpperCase();

        // ── Datos BioSense ────────────────────────────────

        if (uuid ==
            charUuid.toUpperCase()) {
          await characteristic
              .setNotifyValue(true);

          await _notifySub?.cancel();

          _notifySub =
              characteristic
                  .onValueReceived
                  .listen(
            _onFragment,
          );
        }

        // ── Sincronización epoch ──────────────────────────

        if (uuid ==
            epochUuid.toUpperCase()) {
          final epoch =
              DateTime.now()
                      .millisecondsSinceEpoch ~/
                  1000;

          final bytes =
              Uint8List(4);

          final bd =
              ByteData.sublistView(
            bytes,
          );

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
  }

  // ========================================================
  // Recepción BLE
  // ========================================================

  void _onFragment(
      List<int> raw) {
    // ── Paquete completo ──────────────────────────────────
    //
    // Permite que el firmware envíe directamente
    // los 44 bytes cuando el MTU lo permita.

    if (raw.length == 44) {
      _tryDecode(
        Uint8List.fromList(raw),
      );

      return;
    }

    // ── Fragmento ─────────────────────────────────────────

    final assembled =
        _reassembler.feed(raw);

    if (assembled == null) {
      return;
    }

    _tryDecode(
      Uint8List.fromList(
        assembled,
      ),
    );
  }

  // ========================================================
  // Decoder
  // ========================================================

  void _tryDecode(
      Uint8List data) {
    final packet =
        BioSenseDecoder.decode(data);

    if (packet == null) {
      return;
    }

    _packetCtrl.add(packet);
  }

  // ========================================================
  // Desconexión
  // ========================================================

  Future<void> disconnect() async {
    await FlutterBluePlus.stopScan();

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

    _setState(
      BleConnectionState.disconnected,
    );
  }

  // ========================================================
  // Dispose
  // ========================================================

  Future<void> dispose() async {
    await disconnect();

    await _stateCtrl.close();
    await _packetCtrl.close();
  }
}
