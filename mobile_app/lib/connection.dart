import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'protocol.dart';

enum Transport { wifi, bluetooth }

/// A live link to the desktop receiver (macOS/Windows/Linux), over either WiFi or Bluetooth LE.
abstract class RemoteConnection {
  String get name;
  Transport get transport;

  /// Completes when the link drops (receiver closed, out of range, ...).
  Future<void> get closed;

  Future<void> send(RemoteCommand command);
  Future<void> close();
}

class WifiConnection implements RemoteConnection {
  WifiConnection._(this._socket, this.name) {
    _socket.listen((_) {}, onDone: _markClosed, onError: (_) => _markClosed(), cancelOnError: true);
  }

  static Future<WifiConnection> connect(String host, {int port = kTcpPort, String? name}) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    socket.setOption(SocketOption.tcpNoDelay, true);
    return WifiConnection._(socket, name ?? host);
  }

  final Socket _socket;
  final _closed = Completer<void>();

  @override
  final String name;

  @override
  Transport get transport => Transport.wifi;

  @override
  Future<void> get closed => _closed.future;

  // No flush: rapid taps would otherwise collide with an in-flight flush.
  // Write failures surface through the socket's onError → [closed].
  @override
  Future<void> send(RemoteCommand command) async => _socket.write('${command.wire}\n');

  @override
  Future<void> close() async {
    _socket.destroy();
    _markClosed();
  }

  void _markClosed() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

class BleConnection implements RemoteConnection {
  BleConnection._(this._device, this._command, this.name) {
    _stateSub = _device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) _markClosed();
    });
  }

  static Future<BleConnection> connect(BluetoothDevice device, {String? name}) async {
    await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 10), mtu: null);
    try {
      final services = await device.discoverServices();
      final service = services.firstWhere((s) => s.uuid == Guid(kBleServiceUuid));
      final command = service.characteristics.firstWhere((c) => c.uuid == Guid(kBleCommandUuid));
      return BleConnection._(device, command, name ?? device.platformName);
    } on StateError {
      await device.disconnect();
      throw const SocketException('Thiết bị không chạy VirtualPen Receiver');
    }
  }

  final BluetoothDevice _device;
  final BluetoothCharacteristic _command;
  late final StreamSubscription<BluetoothConnectionState> _stateSub;
  final _closed = Completer<void>();

  @override
  final String name;

  @override
  Transport get transport => Transport.bluetooth;

  @override
  Future<void> get closed => _closed.future;

  @override
  Future<void> send(RemoteCommand command) => _command.write(utf8.encode(command.wire));

  @override
  Future<void> close() async {
    await _device.disconnect();
    _markClosed();
  }

  void _markClosed() {
    if (_closed.isCompleted) return;
    _stateSub.cancel();
    _closed.complete();
  }
}
