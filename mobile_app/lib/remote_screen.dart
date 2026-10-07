import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'connection.dart';
import 'protocol.dart';

/// The clicker itself: a huge "next" area, a "previous" button and
/// a row of slideshow controls. Swiping the big area also works.
class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key, required this.connection});

  final RemoteConnection connection;

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  bool _userClosed = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    widget.connection.closed.then((_) {
      if (!mounted || _userClosed) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mất kết nối với máy tính')));
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _send(RemoteCommand command) async {
    HapticFeedback.mediumImpact();
    try {
      await widget.connection.send(command);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gửi lệnh lỗi: $e')));
    }
  }

  void _disconnect() {
    _userClosed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final connection = widget.connection;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(connection.transport == Transport.wifi ? Icons.wifi : Icons.bluetooth,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(connection.name, overflow: TextOverflow.ellipsis)),
                  TextButton.icon(onPressed: _disconnect, icon: const Icon(Icons.close), label: const Text('Ngắt')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -200) _send(RemoteCommand.next);
                    if (v > 200) _send(RemoteCommand.prev);
                  },
                  child: _BigButton(
                    color: scheme.primary,
                    foreground: scheme.onPrimary,
                    icon: Icons.arrow_forward_rounded,
                    label: 'TIẾP',
                    onTap: () => _send(RemoteCommand.next),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _BigButton(
                  color: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                  icon: Icons.arrow_back_rounded,
                  label: 'LÙI',
                  onTap: () => _send(RemoteCommand.prev),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SmallButton(icon: Icons.play_arrow, label: 'Từ đầu', onTap: () => _send(RemoteCommand.start)),
                  _SmallButton(icon: Icons.slideshow, label: 'Slide này', onTap: () => _send(RemoteCommand.resume)),
                  _SmallButton(icon: Icons.square, label: 'Màn đen', onTap: () => _send(RemoteCommand.black)),
                  _SmallButton(icon: Icons.stop, label: 'Kết thúc', onTap: () => _send(RemoteCommand.end)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: foreground),
              Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
