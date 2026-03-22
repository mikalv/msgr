part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _groupingThreshold = Duration(minutes: 5);

/// Deterministic color palette for sender names.
const _nameColors = <Color>[
  Color(0xFF4FC3F7), // light blue
  Color(0xFF81C784), // green
  Color(0xFFFFB74D), // orange
  Color(0xFFBA68C8), // purple
  Color(0xFFE57373), // red
  Color(0xFF4DD0E1), // cyan
  Color(0xFFFFF176), // yellow
  Color(0xFFA1887F), // brown
  Color(0xFF90A4AE), // blue grey
  Color(0xFFF06292), // pink
];

Color _colorForName(String name) {
  var hash = 0;
  for (var i = 0; i < name.length; i++) {
    hash = name.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return _nameColors[hash.abs() % _nameColors.length];
}

// ---------------------------------------------------------------------------
// URL regex for auto-linking plain text
// ---------------------------------------------------------------------------

final _urlRegex = RegExp(
  r'https?://[^\s<>\)\]]+',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Timestamp / date helpers (Norwegian)
// ---------------------------------------------------------------------------

const _monthsNb = [
  'jan', 'feb', 'mar', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'des',
];

String _formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  if (msgDay == today) return time;
  if (msgDay == today.subtract(const Duration(days: 1))) return 'I g\u00e5r $time';
  return '${dt.day}. ${_monthsNb[dt.month - 1]} $time';
}

String _formatDateSeparator(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(dt.year, dt.month, dt.day);

  if (msgDay == today) return 'I dag';
  if (msgDay == today.subtract(const Duration(days: 1))) return 'I g\u00e5r';
  return '${dt.day}. ${_monthsNb[dt.month - 1]} ${dt.year}';
}

bool _isDifferentDay(DateTime a, DateTime b) {
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

// ---------------------------------------------------------------------------
// Grouping helper
// ---------------------------------------------------------------------------

/// Whether [msg] starts a new visual group compared to [prev].
bool _startsNewGroup(SlackMessage msg, SlackMessage? prev) {
  if (prev == null) return true;
  if (msg.senderProfileId != prev.senderProfileId) return true;
  if (msg.insertedAt.difference(prev.insertedAt).abs() > _groupingThreshold) {
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Shared context menu item builder
// ---------------------------------------------------------------------------

PopupMenuEntry<String> _buildContextMenuItem(
  String value,
  IconData icon,
  String label, {
  bool isDestructive = false,
}) {
  return PopupMenuItem<String>(
    value: value,
    height: 36,
    child: Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDestructive ? Colors.redAccent : Colors.white70,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}
