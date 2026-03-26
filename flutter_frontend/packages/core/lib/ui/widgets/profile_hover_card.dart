import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/ui/shell/profile_card.dart';

/// Wraps a child widget to show a profile card on hover (desktop) or tap (mobile).
///
/// On desktop: hover for 400ms triggers card as a positioned overlay.
/// On mobile/fallback: tap opens the full profile card dialog.
class ProfileHoverCard extends ConsumerStatefulWidget {
  const ProfileHoverCard({
    super.key,
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
    this.role,
    required this.child,
  });

  final String profileId;
  final String displayName;
  final String? avatarUrl;
  final String? role;
  final Widget child;

  @override
  ConsumerState<ProfileHoverCard> createState() => _ProfileHoverCardState();
}

class _ProfileHoverCardState extends ConsumerState<ProfileHoverCard> {
  Timer? _hoverTimer;
  OverlayEntry? _overlay;

  void _onHoverEnter(PointerEvent event) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 400), () {
      _showOverlay(event.position);
    });
  }

  void _onHoverExit(PointerEvent _) {
    _hoverTimer?.cancel();
    _hideOverlay();
  }

  void _showOverlay(Offset position) {
    _hideOverlay();
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Position card near the hover point, clamped to screen
    double left = position.dx + 8;
    double top = position.dy + 8;
    const cardWidth = 280.0;
    const cardHeight = 200.0;

    if (left + cardWidth > screenSize.width) left = position.dx - cardWidth - 8;
    if (top + cardHeight > screenSize.height) top = position.dy - cardHeight - 8;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: MouseRegion(
          onExit: (_) => _hideOverlay(),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1E1E2E),
            child: _MiniProfileCard(
              profileId: widget.profileId,
              displayName: widget.displayName,
              avatarUrl: widget.avatarUrl,
              role: widget.role,
              onSendMessage: () {
                _hideOverlay();
                _openFullCard();
              },
              onViewProfile: () {
                _hideOverlay();
                _openFullCard();
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _openFullCard() {
    final auth = ref.read(simpleAuthProvider);
    showProfileCardById(
      context,
      ref,
      profileId: widget.profileId,
    );
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      child: GestureDetector(
        onTap: _openFullCard,
        child: widget.child,
      ),
    );
  }
}

/// Lightweight mini profile card shown on hover overlay.
class _MiniProfileCard extends StatelessWidget {
  const _MiniProfileCard({
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
    this.role,
    this.onSendMessage,
    this.onViewProfile,
  });

  final String profileId;
  final String displayName;
  final String? avatarUrl;
  final String? role;
  final VoidCallback? onSendMessage;
  final VoidCallback? onViewProfile;

  @override
  Widget build(BuildContext context) {
    final color = _colorForName(displayName);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withAlpha(60),
                child: Text(initial, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    if (role != null && role!.isNotEmpty)
                      Text(role!, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text('Message', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: onSendMessage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outline, size: 14),
                  label: const Text('Profile', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: onViewProfile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _nameColors = <Color>[
    Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFFFB74D),
    Color(0xFFBA68C8), Color(0xFFE57373), Color(0xFF4DD0E1),
  ];

  static Color _colorForName(String name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return _nameColors[hash.abs() % _nameColors.length];
  }
}
