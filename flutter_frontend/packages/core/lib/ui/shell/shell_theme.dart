import 'dart:ui';

/// Dark sidebar theme constants inspired by Slack/Discord.
///
/// All colours are intentionally hardcoded here so the shell renders
/// consistently regardless of the host app's ThemeData.
class ShellTheme {
  ShellTheme._();

  static const sidebarBg = Color(0xFF1A1D21);
  static const sidebarText = Color(0xFFD1D2D3);
  static const sidebarTextBright = Color(0xFFFFFFFF);
  static const sidebarActiveItem = Color(0xFF1164A3);
  static const sidebarHoverItem = Color(0xFF27242C);
  static const accentColor = Color(0xFF02AC88);
  static const unreadBadge = Color(0xFFE01E5A);
  static const onlineDot = Color(0xFF2BAC76);
  static const teamRailBg = Color(0xFF0F0F10);
  static const teamRailWidth = 56.0;
  static const sidebarWidth = 240.0;
}
