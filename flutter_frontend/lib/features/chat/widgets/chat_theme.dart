import 'package:flutter/material.dart';

/// Visual constants for the chat experience so every widget can stay in sync
/// when we iterate on the look and feel.
class ChatTheme {
  const ChatTheme._();

  static Gradient backgroundGradient(ThemeData theme) {
    final scheme = theme.colorScheme;
    return LinearGradient(
      colors: [
        scheme.primary.withOpacity(0.10),
        scheme.surfaceVariant.withOpacity(0.25),
        scheme.surface,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }

  static BoxDecoration panelDecoration(ThemeData theme) {
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    return BoxDecoration(
      color: Color.alphaBlend(
        scheme.surfaceTint.withOpacity(brightness == Brightness.dark ? 0.12 : 0.18),
        scheme.surface.withOpacity(brightness == Brightness.dark ? 0.82 : 0.94),
      ),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(
        color: scheme.outlineVariant.withOpacity(0.45),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(brightness == Brightness.dark ? 0.35 : 0.16),
          blurRadius: 40,
          spreadRadius: -12,
          offset: const Offset(0, 32),
        ),
      ],
    );
  }

  static BoxDecoration timelineDecoration(ThemeData theme) {
    final scheme = theme.colorScheme;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        colors: [
          scheme.surfaceVariant.withOpacity(0.45),
          scheme.surface.withOpacity(0.88),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: scheme.outlineVariant.withOpacity(0.28),
      ),
    );
  }

  static BoxDecoration composerDecoration(ThemeData theme) {
    final scheme = theme.colorScheme;
    return BoxDecoration(
      color: scheme.surface.withOpacity(0.98),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: scheme.outlineVariant.withOpacity(0.35)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 32,
          offset: Offset(0, 22),
        ),
      ],
    );
  }

  static Gradient selfBubbleGradient(ThemeData theme) {
    final scheme = theme.colorScheme;
    return LinearGradient(
      colors: [
        scheme.primary,
        scheme.primaryContainer,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static Color otherBubbleColor(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Color.alphaBlend(
      scheme.surfaceTint.withOpacity(0.14),
      scheme.surfaceVariant.withOpacity(0.92),
    );
  }

  static TextStyle headerTitleStyle(ThemeData theme) =>
      theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700) ??
      const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);

  static TextStyle headerSubtitleStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ) ??
      const TextStyle(fontSize: 14);
}
