import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'connection.dart';
import 'protocol.dart';
import 'remote_screen.dart';

/// A computer found on the network or over Bluetooth, ready to connect with one tap.
class _Target {
  const _Target(this.id, this.name, this.transport, this.connect);

  final String id;
  final String name;
  final Transport transport;
  final Future<RemoteConnection> Function() connect;
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _targets = <String, _Target>{};
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _bonjourSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  String? _connectingId;
  bool _bluetoothOff = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  void _startDiscovery() {
    _startBonjour();
    _startBle();
  }

  Future<void> _stopDiscovery() async {
    await _bonjourSub?.cancel();
    await _scanSub?.cancel();
    _bonjourSub = _scanSub = null;
    await _discovery?.stop();
    _discovery = null;
    await FlutterBluePlus.stopScan();
  }

  Future<void> _restartDiscovery() async {
    await _stopDiscovery();
    if (!mounted) return;
    setState(_targets.clear);
    _startDiscovery();
  }

  Future<void> _startBonjour() async {
    final discovery = BonsoirDiscovery(type: kBonjourType);
    _discovery = discovery;
    await discovery.initialize();
    _bonjourSub = discovery.eventStream!.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          event.service.resolve(discovery.serviceResolver);
        case BonsoirDiscoveryServiceResolvedEvent():
          final service = event.service;
          // Prefer IPv4: link-local IPv6 needs a scope id that Socket.connect may not get.
          final host = service.hostAddresses.firstWhere((a) => !a.contains(':'),
              orElse: () => service.hostAddress ?? service.hostname ?? '');
          if (host.isEmpty) return;
          _put(_Target('wifi:${service.name}', service.name, Transport.wifi,
              () => WifiConnection.connect(host, port: service.port, name: service.name)));
        case BonsoirDiscoveryServiceLostEvent():
          _remove('wifi:${event.service.name}');
        default:
          break;
      }
    });
    await discovery.start();
  }

  Future<void> _startBle() async {
    if (!await FlutterBluePlus.isSupported) return;
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : 'VirtualPen';
        _put(_Target('ble:${r.device.remoteId}', name, Transport.bluetooth,
            () => BleConnection.connect(r.device, name: name)));
      }
    });
    try {
      // iOS reports "unknown" for a moment after launch, so wait briefly for "on".
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 3));
      if (mounted) setState(() => _bluetoothOff = false);
      await FlutterBluePlus.startScan(withServices: [Guid(kBleServiceUuid)], timeout: const Duration(seconds: 20));
    } on TimeoutException {
      if (mounted) setState(() => _bluetoothOff = true);
    }
  }

  void _put(_Target target) {
    if (mounted) setState(() => _targets[target.id] = target);
  }

  void _remove(String id) {
    if (mounted) setState(() => _targets.remove(id));
  }

  Future<void> _connect(_Target target) async {
    if (_connectingId != null) return;
    setState(() => _connectingId = target.id);
    // Scanning while connecting slows BLE connects down, especially on Android.
    await FlutterBluePlus.stopScan();
    try {
      final connection = await target.connect();
      await _stopDiscovery();
      if (!mounted) return;
      setState(() => _connectingId = null);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RemoteScreen(connection: connection)));
      await connection.close();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không kết nối được ${target.name}: $e')));
      }
    }
    if (!mounted) return;
    setState(() => _connectingId = null);
    _restartDiscovery();
  }

  Future<void> _connectManually() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập IP của máy tính'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '192.168.1.10', helperText: 'Xem IP trong cửa sổ VirtualPen Receiver'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Kết nối')),
        ],
      ),
    );
    final text = input?.trim() ?? '';
    if (text.isEmpty) return;
    // Accept both "host" and "host:port".
    final parts = text.split(':');
    final host = parts.first;
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? kTcpPort : kTcpPort;
    await _connect(_Target('manual:$text', host, Transport.wifi, () => WifiConnection.connect(host, port: port)));
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets.values.toList()..sort((a, b) => a.transport.index.compareTo(b.transport.index));
    return Scaffold(
      appBar: AppBar(
        title: const Text('VirtualPen Remote'),
        actions: [IconButton(onPressed: _restartDiscovery, icon: const Icon(Icons.refresh), tooltip: 'Tìm lại')],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Chạy VirtualPen Receiver trên máy tính (Mac/Windows/Linux), rồi chọn máy bên dưới.\n'
                'Cùng mạng WiFi, hoặc bật Bluetooth trên cả hai máy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            if (_bluetoothOff)
              const ListTile(
                dense: true,
                leading: Icon(Icons.bluetooth_disabled, color: Colors.orangeAccent),
                title: Text('Bluetooth đang tắt — chỉ tìm qua WiFi'),
              ),
            Expanded(
              child: targets.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang tìm máy tính…'),
                      ]),
                    )
                  : ListView(
                      children: [
                        for (final t in targets)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: Icon(t.transport == Transport.wifi ? Icons.wifi : Icons.bluetooth, size: 32),
                              title: Text(t.name),
                              subtitle: Text(t.transport == Transport.wifi ? 'WiFi' : 'Bluetooth'),
                              trailing: _connectingId == t.id
                                  ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.chevron_right),
                              onTap: () => _connect(t),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: _connectingId == null ? _connectManually : null,
                icon: const Icon(Icons.keyboard),
                label: const Text('Nhập IP thủ công'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
