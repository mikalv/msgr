import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:core/providers/call_provider.dart';

/// Active call screen with video/voice display and controls.
class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersInitialized = true);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callProvider);
    final name = call.remoteDisplayName ?? 'Unknown';

    // Assign streams to renderers
    if (_renderersInitialized) {
      if (call.localStream != null) _localRenderer.srcObject = call.localStream;
      if (call.remoteStream != null)
        _remoteRenderer.srcObject = call.remoteStream;
    }

    return Material(
      color: const Color(0xFF111111),
      child: SafeArea(
        child: Stack(
          children: [
            // Remote video (fullscreen) or voice avatar
            if (call.isVideo && call.remoteStream != null)
              Positioned.fill(
                child: RTCVideoView(_remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.blueGrey.withAlpha(60),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_formatDuration(call.duration),
                        style: TextStyle(
                            color: Colors.white.withAlpha(150), fontSize: 14)),
                  ],
                ),
              ),

            // Top bar: name + duration (for video mode)
            if (call.isVideo)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(_formatDuration(call.duration),
                        style: TextStyle(
                            color: Colors.white.withAlpha(180), fontSize: 14)),
                  ],
                ),
              ),

            // Local video PiP (draggable, bottom-right)
            if (call.isVideo && call.localStream != null)
              Positioned(
                right: 16,
                bottom: 100,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(_localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                ),
              ),

            // Bottom toolbar
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: call.isMicMuted ? Icons.mic_off : Icons.mic,
                    active: !call.isMicMuted,
                    onTap: () => ref.read(callProvider.notifier).toggleMic(),
                  ),
                  if (call.isVideo)
                    _ControlButton(
                      icon: call.isCameraMuted
                          ? Icons.videocam_off
                          : Icons.videocam,
                      active: !call.isCameraMuted,
                      onTap: () =>
                          ref.read(callProvider.notifier).toggleCamera(),
                    ),
                  if (call.isVideo)
                    _ControlButton(
                      icon: Icons.flip_camera_ios,
                      active: true,
                      onTap: () => ref.read(callProvider.notifier).flipCamera(),
                    ),
                  // Hang up
                  GestureDetector(
                    onTap: () => ref.read(callProvider.notifier).hangUp(),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton(
      {required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color:
              active ? Colors.white.withAlpha(30) : Colors.white.withAlpha(80),
          shape: BoxShape.circle,
        ),
        child:
            Icon(icon, color: active ? Colors.white : Colors.white54, size: 24),
      ),
    );
  }
}
