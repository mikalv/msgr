import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/call_provider.dart';

/// Fullscreen overlay shown when receiving an incoming call.
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);

    return Material(
      color: const Color(0xF0111111),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            _PulsingAvatar(name: call.remoteDisplayName ?? '?'),
            const SizedBox(height: 24),
            Text(
              call.remoteDisplayName ?? 'Unknown',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              call.isVideo ? 'Video Call' : 'Voice Call',
              style:
                  TextStyle(color: Colors.white.withAlpha(150), fontSize: 16),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallActionButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  label: 'Decline',
                  onTap: () => ref.read(callProvider.notifier).rejectCall(),
                ),
                _CallActionButton(
                  icon: call.isVideo ? Icons.videocam : Icons.call,
                  color: Colors.green,
                  label: 'Accept',
                  onTap: () => ref.read(callProvider.notifier).acceptCall(),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _PulsingAvatar extends StatefulWidget {
  const _PulsingAvatar({required this.name});
  final String name;
  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(
        scale: 1.0 + 0.1 * math.sin(_ctrl.value * 2 * math.pi),
        child: child,
      ),
      child: CircleAvatar(
        radius: 56,
        backgroundColor: Colors.green.withAlpha(60),
        child: Text(initial,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
