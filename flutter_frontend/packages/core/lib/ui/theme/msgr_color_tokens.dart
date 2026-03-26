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
    required this.accentHover,
    required this.unreadBadge,
    required this.onlineDot,
    required this.teamRailBg,
    required this.inputBg,
    required this.inputBorder,
    required this.dialogBg,
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
  final Color accentHover;
  final Color unreadBadge;
  final Color onlineDot;
  final Color teamRailBg;
  final Color inputBg;
  final Color inputBorder;
  final Color dialogBg;

  bool get isDark => contentBg.computeLuminance() < 0.3;

  // ── Neutral ────────────────────────────────────────────────
  static const neutralDark = MsgrColorTokens(
    sidebarBg: Color(0xFF1E2022),
    sidebarItemActive: Color(0xFF6B7280),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFA1A1A1),
    sidebarTextBright: Color(0xFFE5E5E5),
    contentBg: Color(0xFF141618),
    contentBorder: Color(0xFF2A2D30),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFFE5E5E5),
    messageText: Color(0xFFE5E5E5),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF1E2022),
    headerBorder: Color(0xFF2A2D30),
    accent: Color(0xFF6B7280),
    accentHover: Color(0xFF4B5563),
    unreadBadge: Color(0xFF9CA3AF),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF111314),
    inputBg: Color(0xFF2A2D30),
    inputBorder: Color(0xFF2A2D30),
    dialogBg: Color(0xFF1E2022),
  );

  static const neutralLight = MsgrColorTokens(
    sidebarBg: Color(0xFFFFFFFF),
    sidebarItemActive: Color(0xFF6B7280),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFF4B5563),
    sidebarTextBright: Color(0xFF1A1A1A),
    contentBg: Color(0xFFF4F6F8),
    contentBorder: Color(0xFFE5E7EB),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFF1A1A1A),
    messageText: Color(0xFF1A1A1A),
    messageTimestamp: Color(0xFF9CA3AF),
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFE5E7EB),
    accent: Color(0xFF6B7280),
    accentHover: Color(0xFF4B5563),
    unreadBadge: Color(0xFF6B7280),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFFE5E7EB),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFE5E7EB),
    dialogBg: Color(0xFFFFFFFF),
  );

  // ── Teal (default) ─────────────────────────────────────────
  static const tealDark = MsgrColorTokens(
    sidebarBg: Color(0xFF171717),
    sidebarItemActive: Color(0xFF20B2AA),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFA1A1A1),
    sidebarTextBright: Color(0xFFE5E5E5),
    contentBg: Color(0xFF0F0F0F),
    contentBorder: Color(0xFF262626),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFF5CD5CE),
    messageText: Color(0xFFE5E5E5),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF171717),
    headerBorder: Color(0xFF262626),
    accent: Color(0xFF20B2AA),
    accentHover: Color(0xFF1A9089),
    unreadBadge: Color(0xFF20B2AA),
    onlineDot: Color(0xFF20B2AA),
    teamRailBg: Color(0xFF0A0A0A),
    inputBg: Color(0xFF262626),
    inputBorder: Color(0xFF262626),
    dialogBg: Color(0xFF171717),
  );

  static const tealLight = MsgrColorTokens(
    sidebarBg: Color(0xFFF8FAFA),
    sidebarItemActive: Color(0xFF20B2AA),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFF4B5563),
    sidebarTextBright: Color(0xFF1A1A1A),
    contentBg: Color(0xFFFFFFFF),
    contentBorder: Color(0xFFE5E7EB),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFF1A9089),
    messageText: Color(0xFF1A1A1A),
    messageTimestamp: Color(0xFF9CA3AF),
    headerBg: Color(0xFFF8FAFA),
    headerBorder: Color(0xFFE5E7EB),
    accent: Color(0xFF20B2AA),
    accentHover: Color(0xFF1A9089),
    unreadBadge: Color(0xFF20B2AA),
    onlineDot: Color(0xFF20B2AA),
    teamRailBg: Color(0xFFE6F3F2),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFE5E7EB),
    dialogBg: Color(0xFFFFFFFF),
  );

  // ── Indigo ─────────────────────────────────────────────────
  static const indigoDark = MsgrColorTokens(
    sidebarBg: Color(0xFF1E1B4B),
    sidebarItemActive: Color(0xFF6366F1),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFA5B4FC),
    sidebarTextBright: Color(0xFFE0E7FF),
    contentBg: Color(0xFF0C0A1D),
    contentBorder: Color(0xFF312E81),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFFA5B4FC),
    messageText: Color(0xFFE0E7FF),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF1E1B4B),
    headerBorder: Color(0xFF312E81),
    accent: Color(0xFF6366F1),
    accentHover: Color(0xFF4F46E5),
    unreadBadge: Color(0xFF6366F1),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF080620),
    inputBg: Color(0xFF312E81),
    inputBorder: Color(0xFF312E81),
    dialogBg: Color(0xFF1E1B4B),
  );

  static const indigoLight = MsgrColorTokens(
    sidebarBg: Color(0xFFFFFFFF),
    sidebarItemActive: Color(0xFF6366F1),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFF4338CA),
    sidebarTextBright: Color(0xFF1E1B4B),
    contentBg: Color(0xFFFAFAFA),
    contentBorder: Color(0xFFE0E7FF),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFF4338CA),
    messageText: Color(0xFF1E1B4B),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFE0E7FF),
    accent: Color(0xFF6366F1),
    accentHover: Color(0xFF4F46E5),
    unreadBadge: Color(0xFF6366F1),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFFE0E7FF),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFE0E7FF),
    dialogBg: Color(0xFFFFFFFF),
  );

  // ── Rose ───────────────────────────────────────────────────
  static const roseDark = MsgrColorTokens(
    sidebarBg: Color(0xFF1C1011),
    sidebarItemActive: Color(0xFFF43F5E),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFFDA4AF),
    sidebarTextBright: Color(0xFFFFE4E6),
    contentBg: Color(0xFF0F0506),
    contentBorder: Color(0xFF2D1619),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFFFDA4AF),
    messageText: Color(0xFFFFE4E6),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF1C1011),
    headerBorder: Color(0xFF2D1619),
    accent: Color(0xFFF43F5E),
    accentHover: Color(0xFFE11D48),
    unreadBadge: Color(0xFFF43F5E),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF0A0304),
    inputBg: Color(0xFF2D1619),
    inputBorder: Color(0xFF2D1619),
    dialogBg: Color(0xFF1C1011),
  );

  static const roseLight = MsgrColorTokens(
    sidebarBg: Color(0xFFFFFFFF),
    sidebarItemActive: Color(0xFFF43F5E),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFFBE123C),
    sidebarTextBright: Color(0xFF1A1A1A),
    contentBg: Color(0xFFFFF1F2),
    contentBorder: Color(0xFFFECDD3),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFFBE123C),
    messageText: Color(0xFF1A1A1A),
    messageTimestamp: Color(0xFF9CA3AF),
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFFECDD3),
    accent: Color(0xFFF43F5E),
    accentHover: Color(0xFFE11D48),
    unreadBadge: Color(0xFFF43F5E),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFFFFE4E6),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFFECDD3),
    dialogBg: Color(0xFFFFFFFF),
  );

  // ── Amber ──────────────────────────────────────────────────
  static const amberDark = MsgrColorTokens(
    sidebarBg: Color(0xFF1C1408),
    sidebarItemActive: Color(0xFFF59E0B),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFFFCD34D),
    sidebarTextBright: Color(0xFFFEF3C7),
    contentBg: Color(0xFF0F0A00),
    contentBorder: Color(0xFF2D2210),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFFFCD34D),
    messageText: Color(0xFFFEF3C7),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF1C1408),
    headerBorder: Color(0xFF2D2210),
    accent: Color(0xFFF59E0B),
    accentHover: Color(0xFFD97706),
    unreadBadge: Color(0xFFF59E0B),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFF0A0700),
    inputBg: Color(0xFF2D2210),
    inputBorder: Color(0xFF2D2210),
    dialogBg: Color(0xFF1C1408),
  );

  static const amberLight = MsgrColorTokens(
    sidebarBg: Color(0xFFFFFFFF),
    sidebarItemActive: Color(0xFFF59E0B),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFFB45309),
    sidebarTextBright: Color(0xFF1A1A1A),
    contentBg: Color(0xFFFFFBEB),
    contentBorder: Color(0xFFFDE68A),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFFB45309),
    messageText: Color(0xFF1A1A1A),
    messageTimestamp: Color(0xFF9CA3AF),
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFFDE68A),
    accent: Color(0xFFF59E0B),
    accentHover: Color(0xFFD97706),
    unreadBadge: Color(0xFFF59E0B),
    onlineDot: Color(0xFF2BAC76),
    teamRailBg: Color(0xFFFEF3C7),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFFDE68A),
    dialogBg: Color(0xFFFFFFFF),
  );

  // ── Emerald ────────────────────────────────────────────────
  static const emeraldDark = MsgrColorTokens(
    sidebarBg: Color(0xFF052E1C),
    sidebarItemActive: Color(0xFF10B981),
    sidebarItemHover: Color(0x0FFFFFFF),
    sidebarText: Color(0xFF6EE7B7),
    sidebarTextBright: Color(0xFFD1FAE5),
    contentBg: Color(0xFF021F13),
    contentBorder: Color(0xFF064E3B),
    messageHover: Color(0x0AFFFFFF),
    messageAuthorName: Color(0xFF6EE7B7),
    messageText: Color(0xFFD1FAE5),
    messageTimestamp: Color(0xFF6B7280),
    headerBg: Color(0xFF052E1C),
    headerBorder: Color(0xFF064E3B),
    accent: Color(0xFF10B981),
    accentHover: Color(0xFF059669),
    unreadBadge: Color(0xFF10B981),
    onlineDot: Color(0xFF10B981),
    teamRailBg: Color(0xFF011A0E),
    inputBg: Color(0xFF064E3B),
    inputBorder: Color(0xFF064E3B),
    dialogBg: Color(0xFF052E1C),
  );

  static const emeraldLight = MsgrColorTokens(
    sidebarBg: Color(0xFFFFFFFF),
    sidebarItemActive: Color(0xFF10B981),
    sidebarItemHover: Color(0x08000000),
    sidebarText: Color(0xFF047857),
    sidebarTextBright: Color(0xFF1A1A1A),
    contentBg: Color(0xFFECFDF5),
    contentBorder: Color(0xFFA7F3D0),
    messageHover: Color(0x06000000),
    messageAuthorName: Color(0xFF047857),
    messageText: Color(0xFF1A1A1A),
    messageTimestamp: Color(0xFF9CA3AF),
    headerBg: Color(0xFFFFFFFF),
    headerBorder: Color(0xFFA7F3D0),
    accent: Color(0xFF10B981),
    accentHover: Color(0xFF059669),
    unreadBadge: Color(0xFF10B981),
    onlineDot: Color(0xFF10B981),
    teamRailBg: Color(0xFFD1FAE5),
    inputBg: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFA7F3D0),
    dialogBg: Color(0xFFFFFFFF),
  );

  /// Legacy alias — kept for backward compatibility.
  static const dark = tealDark;
}
