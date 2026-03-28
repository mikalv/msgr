import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/call_provider.dart';

/// Fullscreen screen shown while calling someone (waiting for answer).
class OutgoingCallScreen extends ConsumerWidget {
  const OutgoingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final name = call.remoteDisplayName ?? 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Material(
      color: const Color(0xF0111111),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.blueGrey.withAlpha(60),
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),

            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),

            const _CallingDots(),

            const Spacer(flex: 3),

            // Cancel button
            GestureDetector(
              onTap: () => ref.read(callProvider.notifier).hangUp(),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child:
                    const Icon(Icons.call_end, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Cancel',
                style: TextStyle(color: Colors.white70, fontSize: 13)),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _CallingDots extends StatefulWidget {
  const _CallingDots();
  @override
  State<_CallingDots> createState() => _CallingDotsState();
}

class _CallingDotsState extends State<_CallingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final dots = '.' * (1 + (_ctrl.value * 3).floor());
        return Text('Calling$dots',
            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 16));
      },
    );
  }
}
