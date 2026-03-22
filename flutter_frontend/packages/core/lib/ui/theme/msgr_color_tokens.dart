import 'dart:ui';

class MsgrColorTokens {
  const MsgrColorTokens({
    required this.sidebarBg,
    required this.sidebarItemActive,
    required this.sidebarItemHover,
    required this.sidebarText,
    required this.sidebarTextBright,
    required this.contentBg,
    required this.contentBorder,
    required this.messageHover,
    required this.messageAuthorName,
    required this.messageText,
    required this.messageTimestamp,
    required this.headerBg,
    required this.headerBorder,
    required this.accent,
    required this.unreadBadge,
    required this.onlineDot,
    required this.teamRailBg,
  });

  final Color sidebarBg;
  final Color sidebarItemActive;
  final Color sidebarItemHover;
  final Color sidebarText;
  final Color sidebarTextBright;
  final Color contentBg;
  final Color contentBorder;
  final Color messageHover;
  final Color messageAuthorName;
  final Color messageText;
  final Color messageTimestamp;
  final Color headerBg;
  final Color headerBorder;
  final Color accent;
  final Color unreadBadge;
  final Color onlineDot;
  final Color teamRailBg;

  static const dark = MsgrColorTokens(
    sidebarBg: Color(0xFF1A1D21),
    sidebarItemActive: Color(0xFF1164A3),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFD1D2D3),
    sidebarTextBright: Color(0xFFFFFFFF),
    contentBg: Color(0xFF222529),
    contentBorder: Color(0xFF2E3035),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFF4FC3F7),
    messageText: Color(0xFFE8E8E8),
    messageTimestamp: Color(0x59FFFFFF),
    headerBg: Color(0xFF222529),
    headerBorder: Color(0xFF2E3035),
    accent: Color(0xFF1164A3),
    unreadBadge: Color(0xFFE01E5A),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF0F0F10),
  );
}
