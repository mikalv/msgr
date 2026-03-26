import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/settings_provider.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/theme_provider.dart';

// ---------------------------------------------------------------------------
// Top-level settings page — fullscreen modal dialog
// ---------------------------------------------------------------------------

/// Opens the settings page as a fullscreen dialog.
void openSettingsPage(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 820,
          height: 600,
          child: _SettingsLayout(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category definitions
// ---------------------------------------------------------------------------

enum _Category {
  profile('Profile', Icons.person_outline),
  notifications('Notifications', Icons.notifications_outlined),
  appearance('Appearance', Icons.palette_outlined),
  language('Language & Region', Icons.language),
  privacy('Privacy', Icons.lock_outline),
  connectedAccounts('Connected Accounts', Icons.link),
  devices('Devices', Icons.devices);

  const _Category(this.label, this.icon);
  final String label;
  final IconData icon;
}

// ---------------------------------------------------------------------------
// Two-panel layout: sidebar + content
// ---------------------------------------------------------------------------

class _SettingsLayout extends StatefulWidget {
  const _SettingsLayout();

  @override
  State<_SettingsLayout> createState() => _SettingsLayoutState();
}

class _SettingsLayoutState extends State<_SettingsLayout> {
  _Category _selected = _Category.profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left sidebar
        Container(
          width: 200,
          color: const Color(0xFF161819),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 8),
              for (final cat in _Category.values)
                _CategoryTile(
                  category: cat,
                  isSelected: cat == _selected,
                  onTap: () => setState(() => _selected = cat),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'v0.1.0',
                  style: TextStyle(
                    color: Colors.white.withAlpha(80),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Divider
        Container(width: 1, color: Colors.white10),

        // Right content
        Expanded(
          child: Column(
            children: [
              // Close button row
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selected) {
      case _Category.profile:
        return const _ProfileSection();
      case _Category.notifications:
        return const _NotificationsSection();
      case _Category.appearance:
        return const _AppearanceSection();
      case _Category.language:
        return const _LanguageSection();
      case _Category.privacy:
        return const _PrivacySection();
      case _Category.connectedAccounts:
        return const _ConnectedAccountsSection();
      case _Category.devices:
        return const _DevicesSection();
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _Category category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white.withAlpha(15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withAlpha(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                category.icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.white54,
              ),
              const SizedBox(width: 10),
              Text(
                category.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable setting widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SubSectionTitle extends StatelessWidget {
  const _SubSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    this.description,
    required this.trailing,
  });

  final String label;
  final String? description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile section
// ---------------------------------------------------------------------------

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(simpleAuthProvider);
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Profile'),

        // Avatar placeholder
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF02AC88),
                child: Text(
                  (auth.displayName ?? auth.email ?? '?')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                auth.displayName ?? 'No name set',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (auth.email != null)
                Text(
                  auth.email!,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),

        const _SubSectionTitle('STATUS'),
        _SettingRow(
          label: 'Status message',
          description: settings.statusText ?? 'Not set',
          trailing: SizedBox(
            width: 180,
            child: TextField(
              controller: TextEditingController(text: settings.statusText ?? ''),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'What are you up to?',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
              onSubmitted: (value) {
                ref.read(settingsProvider.notifier).update(
                      (s) => s.copyWith(statusText: value.isEmpty ? null : value),
                    );
              },
            ),
          ),
        ),
        _SettingRow(
          label: 'Status emoji',
          trailing: SizedBox(
            width: 80,
            child: TextField(
              controller:
                  TextEditingController(text: settings.statusEmoji ?? ''),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '--',
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
              onSubmitted: (value) {
                ref.read(settingsProvider.notifier).update(
                      (s) =>
                          s.copyWith(statusEmoji: value.isEmpty ? null : value),
                    );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications section
// ---------------------------------------------------------------------------

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Notifications'),

        _SettingRow(
          label: 'Desktop notifications',
          description: 'Show system notifications for new messages',
          trailing: Switch(
            value: settings.notifyDesktop,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(notifyDesktop: v)),
          ),
        ),
        _SettingRow(
          label: 'Mobile notifications',
          description: 'Push notifications to your mobile devices',
          trailing: Switch(
            value: settings.notifyMobile,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(notifyMobile: v)),
          ),
        ),
        _SettingRow(
          label: 'Notify about',
          description: 'Choose which messages trigger notifications',
          trailing: DropdownButton<String>(
            value: settings.notifyAbout,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'everything', child: Text('Everything')),
              DropdownMenuItem(value: 'mentions', child: Text('Mentions only')),
              DropdownMenuItem(value: 'dms_only', child: Text('DMs only')),
              DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
            ],
            onChanged: (v) {
              if (v != null) {
                notifier.update((s) => s.copyWith(notifyAbout: v));
              }
            },
          ),
        ),
        _SettingRow(
          label: 'Thread replies',
          description: 'Notify when someone replies to a thread you follow',
          trailing: Switch(
            value: settings.notifyThreadReplies,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(notifyThreadReplies: v)),
          ),
        ),
        _SettingRow(
          label: 'Notification sounds',
          description: 'Play a sound for incoming messages',
          trailing: Switch(
            value: settings.notifySounds,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(notifySounds: v)),
          ),
        ),

        const _SubSectionTitle('DO NOT DISTURB'),
        _SettingRow(
          label: 'Enable Do Not Disturb',
          description: 'Mute all notifications during scheduled hours',
          trailing: Switch(
            value: settings.dndEnabled,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) =>
                notifier.update((s) => s.copyWith(dndEnabled: v)),
          ),
        ),
        if (settings.dndEnabled) ...[
          _SettingRow(
            label: 'Start time',
            trailing: _TimePicker(
              value: settings.dndStart ?? '22:00',
              onChanged: (v) =>
                  notifier.update((s) => s.copyWith(dndStart: v)),
            ),
          ),
          _SettingRow(
            label: 'End time',
            trailing: _TimePicker(
              value: settings.dndEnd ?? '08:00',
              onChanged: (v) =>
                  notifier.update((s) => s.copyWith(dndEnd: v)),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFF02AC88),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          onChanged('$hh:$mm');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Appearance section (local only)
// ---------------------------------------------------------------------------

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  static const _themeSwatches = <MsgrThemeName, (String, Color)>{
    MsgrThemeName.neutral: ('Neutral', Color(0xFF6B7280)),
    MsgrThemeName.teal: ('Teal', Color(0xFF20B2AA)),
    MsgrThemeName.indigo: ('Indigo', Color(0xFF6366F1)),
    MsgrThemeName.rose: ('Rose', Color(0xFFF43F5E)),
    MsgrThemeName.amber: ('Amber', Color(0xFFF59E0B)),
    MsgrThemeName.emerald: ('Emerald', Color(0xFF10B981)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Appearance'),

        // ── Brightness mode ──
        const _SubSectionTitle('MODE'),
        Row(
          children: [
            for (final mode in MsgrBrightness.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    mode == MsgrBrightness.light ? 'Light'
                    : mode == MsgrBrightness.dark ? 'Dark'
                    : 'System',
                  ),
                  selected: themeState.brightness == mode,
                  selectedColor: themeState.colors.accent,
                  backgroundColor: Colors.white.withAlpha(15),
                  labelStyle: TextStyle(
                    color: themeState.brightness == mode
                        ? Colors.white
                        : Colors.white70,
                    fontSize: 13,
                  ),
                  side: BorderSide.none,
                  onSelected: (_) => themeNotifier.setBrightness(mode),
                ),
              ),
          ],
        ),

        // ── Color theme grid ──
        const _SubSectionTitle('THEME'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in _themeSwatches.entries)
              _ThemeSwatch(
                name: entry.value.$1,
                color: entry.value.$2,
                isSelected: themeState.theme == entry.key,
                onTap: () => themeNotifier.setTheme(entry.key),
              ),
          ],
        ),

        const SizedBox(height: 16),
        _SettingRow(
          label: 'Font size',
          description: '${settings.fontSize.round()} px',
          trailing: SizedBox(
            width: 160,
            child: Slider(
              value: settings.fontSize,
              min: 10,
              max: 22,
              divisions: 12,
              activeColor: themeState.colors.accent,
              onChanged: (v) {
                settingsNotifier.updateLocal((s) => s.copyWith(fontSize: v));
              },
            ),
          ),
        ),
        _SettingRow(
          label: 'Compact mode',
          description: 'Reduce spacing between messages',
          trailing: Switch(
            value: settings.compactMode,
            activeColor: themeState.colors.accent,
            onChanged: (v) {
              settingsNotifier.updateLocal((s) => s.copyWith(compactMode: v));
            },
          ),
        ),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.name,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white.withAlpha(20),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language section
// ---------------------------------------------------------------------------

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Language & Region'),

        _SettingRow(
          label: 'Language',
          description: 'Choose the app display language',
          trailing: DropdownButton<String>(
            value: settings.locale,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'nb', child: Text('Norsk')),
            ],
            onChanged: (v) {
              if (v != null) {
                notifier.update((s) => s.copyWith(locale: v));
              }
            },
          ),
        ),
        _SettingRow(
          label: 'Date format',
          description: 'How dates are displayed',
          trailing: DropdownButton<String>(
            value: settings.dateFormat,
            dropdownColor: const Color(0xFF2A2A2A),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('Auto (system)')),
              DropdownMenuItem(value: 'dd/mm/yyyy', child: Text('DD/MM/YYYY')),
              DropdownMenuItem(value: 'mm/dd/yyyy', child: Text('MM/DD/YYYY')),
              DropdownMenuItem(value: 'yyyy-mm-dd', child: Text('YYYY-MM-DD')),
            ],
            onChanged: (v) {
              if (v != null) {
                notifier.update((s) => s.copyWith(dateFormat: v));
              }
            },
          ),
        ),
        _SettingRow(
          label: '24-hour clock',
          description: 'Use 24-hour time format instead of AM/PM',
          trailing: Switch(
            value: settings.time24h,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) {
              notifier.update((s) => s.copyWith(time24h: v));
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Privacy section
// ---------------------------------------------------------------------------

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Privacy'),

        _SettingRow(
          label: 'Show online status',
          description: 'Let others see when you are online',
          trailing: Switch(
            value: settings.showOnlineStatus,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) {
              notifier.update((s) => s.copyWith(showOnlineStatus: v));
            },
          ),
        ),
        _SettingRow(
          label: 'Read receipts',
          description: 'Let others know when you have read their messages',
          trailing: Switch(
            value: settings.showReadReceipts,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) {
              notifier.update((s) => s.copyWith(showReadReceipts: v));
            },
          ),
        ),
        _SettingRow(
          label: 'Typing indicators',
          description:
              'Show when you are typing and see when others are typing',
          trailing: Switch(
            value: settings.showTypingIndicators,
            activeColor: const Color(0xFF02AC88),
            onChanged: (v) {
              notifier.update((s) => s.copyWith(showTypingIndicators: v));
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Connected Accounts section (placeholder)
// ---------------------------------------------------------------------------

class _ConnectedAccountsSection extends StatelessWidget {
  const _ConnectedAccountsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Connected Accounts'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(Icons.link_off, color: Colors.white.withAlpha(100), size: 40),
              const SizedBox(height: 12),
              Text(
                'No connected accounts yet',
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect services like GitHub for richer integrations.',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Devices section (placeholder)
// ---------------------------------------------------------------------------

class _DevicesSection extends StatelessWidget {
  const _DevicesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Devices'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.computer, color: Color(0xFF02AC88), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Active now',
                      style: TextStyle(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF02AC88).withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Current',
                  style: TextStyle(
                    color: Color(0xFF02AC88),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Other sessions will appear here once multi-device support is active.',
          style: TextStyle(
            color: Colors.white.withAlpha(100),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
