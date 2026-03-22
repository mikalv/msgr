import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'package:core/ui/theme/msgr_theme.dart';

/// Reusable avatar widget with three-tier image resolution:
/// 1. Custom [avatarUrl] (uploaded to MinIO) — highest priority
/// 2. Gravatar from [email] (MD5 hash lookup)
/// 3. Letter-circle fallback with deterministic color from [profileId]
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.profileId,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.size = 36,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  /// Used for deterministic color selection in the letter fallback.
  final String profileId;

  /// First letter is used for the fallback circle.
  final String displayName;

  /// Custom uploaded avatar URL (highest priority).
  final String? avatarUrl;

  /// Email for Gravatar lookup (second priority).
  final String? email;

  /// Diameter of the avatar circle in logical pixels.
  final double size;

  /// Whether to show the online indicator dot.
  final bool showOnlineIndicator;

  /// Whether the user is currently online.
  final bool isOnline;

  static const _palette = [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFFE57373),
    Color(0xFF4DD0E1),
    Color(0xFFFFF176),
    Color(0xFFA1887F),
    Color(0xFF90A4AE),
    Color(0xFFF06292),
  ];

  Color _colorFromId(String id) {
    final hash = id.hashCode.abs();
    return _palette[hash % _palette.length];
  }

  String? _gravatarUrl() {
    final e = email;
    if (e == null || e.isEmpty) return null;
    final normalized = e.trim().toLowerCase();
    final hash = md5.convert(utf8.encode(normalized)).toString();
    final pixelSize = (size * 2).toInt();
    return 'https://gravatar.com/avatar/$hash?d=404&s=$pixelSize';
  }

  Widget _letterFallback() {
    final letter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFromId(profileId),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }

  Widget _networkAvatar(String url, {Widget? fallback}) {
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      imageBuilder: (_, imageProvider) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (_, __) => _letterFallback(),
      errorWidget: (_, __, ___) => fallback ?? _letterFallback(),
    );
  }

  Widget _buildAvatar() {
    // Tier 1: custom avatar URL
    final custom = avatarUrl;
    if (custom != null && custom.isNotEmpty) {
      return _networkAvatar(custom);
    }

    // Tier 2: Gravatar from email
    final gravatar = _gravatarUrl();
    if (gravatar != null) {
      return _networkAvatar(gravatar, fallback: _letterFallback());
    }

    // Tier 3: letter-circle fallback
    return _letterFallback();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();

    if (!showOnlineIndicator || !isOnline) {
      return SizedBox(width: size, height: size, child: avatar);
    }

    final theme = MsgrTheme.of(context);
    final dotSize = size * 0.3;
    const borderWidth = 2.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -(borderWidth / 2),
            bottom: -(borderWidth / 2),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: theme.onlineDot,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.sidebarBg,
                  width: borderWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
