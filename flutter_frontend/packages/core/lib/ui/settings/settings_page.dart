import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/settings_provider.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';
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
  teamAdmin('Team Admin', Icons.admin_panel_settings_outlined),
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
      case _Category.teamAdmin:
        return const _TeamAdminSection();
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
// Team Admin section
// ---------------------------------------------------------------------------

class _TeamAdminSection extends ConsumerStatefulWidget {
  const _TeamAdminSection();

  @override
  ConsumerState<_TeamAdminSection> createState() => _TeamAdminSectionState();
}

class _TeamAdminSectionState extends ConsumerState<_TeamAdminSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _invites = [];
  bool _loadingMembers = false;
  bool _loadingInvites = false;
  String? _myRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;
    final client = ref.read(msgrApiProvider);
    final accountId = ref.read(simpleAuthProvider).accountId;

    setState(() { _loadingMembers = true; _loadingInvites = true; });

    try {
      final members = await client.getTeamMembers(team.slug);
      final me = members.where((m) => m['account_id']?.toString() == accountId).firstOrNull;
      setState(() {
        _members = members;
        _myRole = me?['role']?.toString() ?? 'member';
        _loadingMembers = false;
      });
    } catch (_) {
      setState(() => _loadingMembers = false);
    }

    try {
      final invites = await client.getInviteLinks(team.slug);
      setState(() { _invites = invites; _loadingInvites = false; });
    } catch (_) {
      setState(() => _loadingInvites = false);
    }
  }

  bool get _isAdmin => _myRole == 'owner' || _myRole == 'admin';
  bool get _isOwner => _myRole == 'owner';

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(selectedTeamProvider);
    if (team == null) {
      return const Center(child: Text('No team selected', style: TextStyle(color: Colors.white54)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Team: ${team.name}'),
        if (_myRole != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isOwner ? const Color(0xFFF59E0B).withAlpha(40) : const Color(0xFF6366F1).withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _myRole!.toUpperCase(),
                    style: TextStyle(
                      color: _isOwner ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: ref.watch(themeProvider).colors.accent,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Members'),
            Tab(text: 'Invites'),
            Tab(text: 'Apps'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(team),
              _buildMembersTab(),
              _buildInvitesTab(),
              _AppMarketplaceTab(teamSlug: team.slug),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(dynamic team) {
    final nameController = TextEditingController(text: team.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SubSectionTitle('TEAM NAME'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                enabled: _isAdmin,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final client = ref.read(msgrApiProvider);
                  await client.updateTeam(team.slug, name: nameController.text.trim());
                  ref.read(teamListProvider.notifier).refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Team name updated'), duration: Duration(seconds: 2)),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: ref.watch(themeProvider).colors.accent),
                child: const Text('Save'),
              ),
            ],
          ],
        ),
        const _SubSectionTitle('TEAM SLUG'),
        Text(team.slug, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 14, fontFamily: 'monospace')),
        const SizedBox(height: 4),
        Text('${_members.length} members', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12)),
      ],
    );
  }

  Widget _buildMembersTab() {
    if (_loadingMembers) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        final name = m['display_name']?.toString() ?? 'Unknown';
        final role = m['role']?.toString() ?? 'member';
        final accountId = m['account_id']?.toString() ?? '';
        final myAccountId = ref.read(simpleAuthProvider).accountId;
        final isSelf = accountId == myAccountId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: role == 'owner'
                ? const Color(0xFFF59E0B)
                : role == 'admin'
                    ? const Color(0xFF6366F1)
                    : Colors.blueGrey,
            radius: 16,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(role, style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11)),
          trailing: _isOwner && !isSelf && role != 'owner'
              ? PopupMenuButton<String>(
                  color: const Color(0xFF2A2A2A),
                  onSelected: (action) => _onMemberAction(action, m),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: role == 'admin' ? 'demote' : 'promote',
                      child: Text(
                        role == 'admin' ? 'Demote to member' : 'Promote to admin',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove from team', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                  ],
                )
              : isSelf
                  ? const Text('You', style: TextStyle(color: Colors.white38, fontSize: 11))
                  : null,
        );
      },
    );
  }

  Future<void> _onMemberAction(String action, Map<String, dynamic> member) async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;
    final client = ref.read(msgrApiProvider);
    final accountId = member['account_id']?.toString() ?? '';

    try {
      if (action == 'promote') {
        await client.changeTeamMemberRole(team.slug, accountId, 'admin');
      } else if (action == 'demote') {
        await client.changeTeamMemberRole(team.slug, accountId, 'member');
      } else if (action == 'remove') {
        await client.removeTeamMember(team.slug, accountId);
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Widget _buildInvitesTab() {
    if (_loadingInvites) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              onPressed: _createInvite,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New invite link'),
              style: ElevatedButton.styleFrom(backgroundColor: ref.watch(themeProvider).colors.accent),
            ),
          ),
        Expanded(
          child: _invites.isEmpty
              ? Center(child: Text('No active invite links', style: TextStyle(color: Colors.white.withAlpha(100))))
              : ListView.builder(
                  itemCount: _invites.length,
                  itemBuilder: (context, index) {
                    final inv = _invites[index];
                    final code = inv['code']?.toString() ?? '';
                    final url = inv['url']?.toString() ?? '';
                    final usedCount = inv['used_count'] ?? 0;
                    final expiresAt = inv['expires_at']?.toString() ?? '';

                    return ListTile(
                      leading: const Icon(Icons.link, color: Colors.white54, size: 18),
                      title: Text(code, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
                      subtitle: Text('Used: $usedCount  Expires: ${expiresAt.split('T').first}',
                          style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: url.isNotEmpty ? url : 'https://dev.msgr.no/invite/$code'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                          if (_isAdmin)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              onPressed: () => _revokeInvite(inv['id']?.toString() ?? ''),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _createInvite() async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;
    final client = ref.read(msgrApiProvider);
    try {
      await client.createInviteLink(team.slug);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  Future<void> _revokeInvite(String inviteId) async {
    final team = ref.read(selectedTeamProvider);
    if (team == null) return;
    final client = ref.read(msgrApiProvider);
    try {
      await client.revokeInvite(team.slug, inviteId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// App Marketplace tab (inside Team Admin)
// ---------------------------------------------------------------------------

class _AppMarketplaceTab extends ConsumerStatefulWidget {
  const _AppMarketplaceTab({required this.teamSlug});
  final String teamSlug;

  @override
  ConsumerState<_AppMarketplaceTab> createState() => _AppMarketplaceTabState();
}

class _AppMarketplaceTabState extends ConsumerState<_AppMarketplaceTab> {
  bool _showInstalled = false;
  String? _categoryFilter;
  String _searchQuery = '';
  List<Map<String, dynamic>> _directoryApps = [];
  List<Map<String, dynamic>> _installedApps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final client = ref.read(msgrApiProvider);
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        client.getAppDirectory(category: _categoryFilter, query: _searchQuery.isEmpty ? null : _searchQuery),
        client.getInstalledApps(widget.teamSlug),
      ]);
      if (mounted) {
        setState(() {
          _directoryApps = results[0] as List<Map<String, dynamic>>;
          final rawInstalled = results[1] as List<Map<String, dynamic>>;
          _installedApps = rawInstalled;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> get _installedSlugs {
    return _installedApps
        .map((i) => (i['app'] as Map?)?['slug']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeProvider).colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle: Browse / Installed
        Row(
          children: [
            ChoiceChip(
              label: const Text('Browse'),
              selected: !_showInstalled,
              selectedColor: accent,
              backgroundColor: Colors.white.withAlpha(15),
              labelStyle: TextStyle(color: !_showInstalled ? Colors.white : Colors.white70, fontSize: 12),
              side: BorderSide.none,
              onSelected: (_) => setState(() => _showInstalled = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('Installed (${_installedApps.length})'),
              selected: _showInstalled,
              selectedColor: accent,
              backgroundColor: Colors.white.withAlpha(15),
              labelStyle: TextStyle(color: _showInstalled ? Colors.white : Colors.white70, fontSize: 12),
              side: BorderSide.none,
              onSelected: (_) => setState(() => _showInstalled = true),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_showInstalled)
          _buildInstalledView()
        else
          _buildBrowseView(),
      ],
    );
  }

  Widget _buildBrowseView() {
    return Expanded(
      child: Column(
        children: [
          // Search
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search apps...',
              hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
            onChanged: (v) {
              _searchQuery = v;
              _loadData();
            },
          ),
          const SizedBox(height: 8),

          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in [null, 'developer-tools', 'productivity', 'communication', 'calendar'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(cat == null ? 'All' : _categoryLabel(cat), style: const TextStyle(fontSize: 11)),
                      selected: _categoryFilter == cat,
                      selectedColor: ref.watch(themeProvider).colors.accent.withAlpha(60),
                      backgroundColor: Colors.white.withAlpha(10),
                      labelStyle: TextStyle(color: _categoryFilter == cat ? Colors.white : Colors.white54),
                      side: BorderSide.none,
                      onSelected: (_) {
                        setState(() => _categoryFilter = cat);
                        _loadData();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // App grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _directoryApps.isEmpty
                    ? Center(child: Text('No apps found', style: TextStyle(color: Colors.white.withAlpha(100))))
                    : ListView.builder(
                        itemCount: _directoryApps.length,
                        itemBuilder: (context, index) {
                          final app = _directoryApps[index];
                          final slug = app['slug']?.toString() ?? '';
                          final isInstalled = _installedSlugs.contains(slug);
                          return _AppListTile(
                            app: app,
                            isInstalled: isInstalled,
                            onTap: () => _showAppDetailDialog(app, isInstalled),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledView() {
    if (_installedApps.isEmpty) {
      return Expanded(
        child: Center(child: Text('No apps installed', style: TextStyle(color: Colors.white.withAlpha(100)))),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _installedApps.length,
        itemBuilder: (context, index) {
          final inst = _installedApps[index];
          final app = inst['app'] as Map<String, dynamic>? ?? {};
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: ref.watch(themeProvider).colors.accent.withAlpha(40),
              radius: 18,
              child: Text(
                (app['name']?.toString() ?? '?')[0].toUpperCase(),
                style: TextStyle(color: ref.watch(themeProvider).colors.accent, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(app['name']?.toString() ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(
              inst['status']?.toString() ?? 'active',
              style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11),
            ),
            trailing: PopupMenuButton<String>(
              color: const Color(0xFF2A2A2A),
              onSelected: (action) => _onInstalledAction(action, inst),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'config', child: Text('Edit config', style: TextStyle(color: Colors.white, fontSize: 13))),
                const PopupMenuItem(value: 'uninstall', child: Text('Uninstall', style: TextStyle(color: Colors.redAccent, fontSize: 13))),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onInstalledAction(String action, Map<String, dynamic> inst) async {
    final app = inst['app'] as Map<String, dynamic>? ?? {};
    final appSlug = app['slug']?.toString() ?? '';

    if (action == 'uninstall') {
      final client = ref.read(msgrApiProvider);
      await client.uninstallApp(widget.teamSlug, appSlug);
      _loadData();
    }
  }

  Future<void> _showAppDetailDialog(Map<String, dynamic> app, bool isInstalled) async {
    final slug = app['slug']?.toString() ?? '';
    final name = app['name']?.toString() ?? 'App';
    final description = app['description']?.toString() ?? '';
    final scopes = (app['required_scopes'] as List?)?.cast<String>() ?? [];
    final configSchema = app['config_schema'] as Map<String, dynamic>? ?? {};
    final config = <String, dynamic>{};
    final channels = ref.read(channelListProvider).channels;
    final selectedChannels = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(description, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13)),
                    ),

                  // Scopes
                  if (scopes.isNotEmpty) ...[
                    Text('Permissions', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    for (final scope in scopes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(
                              scope.contains('write') ? Icons.edit_outlined : Icons.visibility_outlined,
                              size: 14,
                              color: scope.contains('write') ? Colors.orange.shade300 : Colors.green.shade300,
                            ),
                            const SizedBox(width: 6),
                            Text(scope, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // Config form
                  if (configSchema.isNotEmpty) ...[
                    Text('Configuration', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final entry in configSchema.entries)
                      _buildConfigField(entry.key, entry.value as Map<String, dynamic>, config, (k, v) {
                        setDialogState(() => config[k] = v);
                      }),
                  ],

                  // Channel binding
                  const SizedBox(height: 12),
                  Text('Channels', style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final ch in channels)
                        FilterChip(
                          label: Text('# ${ch.name}', style: const TextStyle(fontSize: 11)),
                          selected: selectedChannels.contains(ch.id),
                          selectedColor: ref.watch(themeProvider).colors.accent.withAlpha(60),
                          backgroundColor: Colors.white.withAlpha(10),
                          labelStyle: TextStyle(color: selectedChannels.contains(ch.id) ? Colors.white : Colors.white54),
                          side: BorderSide.none,
                          onSelected: (sel) {
                            setDialogState(() {
                              if (sel) selectedChannels.add(ch.id);
                              else selectedChannels.remove(ch.id);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            if (!isInstalled)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: ref.watch(themeProvider).colors.accent),
                child: const Text('Install'),
              ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final client = ref.read(msgrApiProvider);
      try {
        await client.installApp(widget.teamSlug, slug, config: config, channelIds: selectedChannels.toList());
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name installed!'), duration: const Duration(seconds: 2)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Install failed: $e'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    }
  }

  Widget _buildConfigField(String key, Map<String, dynamic> field, Map<String, dynamic> values, void Function(String, dynamic) onChanged) {
    final type = field['type']?.toString() ?? 'string';
    final label = field['label']?.toString() ?? key;
    final placeholder = field['placeholder']?.toString();

    switch (type) {
      case 'boolean':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
              Switch(
                value: values[key] == true,
                activeColor: ref.watch(themeProvider).colors.accent,
                onChanged: (v) => onChanged(key, v),
              ),
            ],
          ),
        );
      case 'select':
        final options = (field['options'] as List?)?.cast<String>() ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButtonFormField<String>(
            value: values[key] as String? ?? field['default'] as String?,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              isDense: true,
            ),
            dropdownColor: const Color(0xFF2A2A3E),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => onChanged(key, v),
          ),
        );
      default: // string, secret, url
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            obscureText: type == 'secret',
            keyboardType: type == 'url' ? TextInputType.url : TextInputType.text,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.white.withAlpha(120)),
              hintText: placeholder,
              hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
              filled: true,
              fillColor: Colors.white.withAlpha(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => onChanged(key, v),
          ),
        );
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'developer-tools': return 'Developer Tools';
      case 'productivity': return 'Productivity';
      case 'communication': return 'Communication';
      case 'calendar': return 'Calendar';
      default: return cat;
    }
  }
}

class _AppListTile extends StatelessWidget {
  const _AppListTile({required this.app, required this.isInstalled, required this.onTap});
  final Map<String, dynamic> app;
  final bool isInstalled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = app['name']?.toString() ?? 'Unknown';
    final desc = app['description']?.toString() ?? '';
    final count = app['install_count'] ?? 0;
    final featured = app['featured'] == true;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Colors.white.withAlpha(15),
        radius: 20,
        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      title: Row(
        children: [
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          if (featured) ...[
            const SizedBox(width: 6),
            Icon(Icons.star, size: 14, color: Colors.amber.shade400),
          ],
          if (isInstalled) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: Colors.green.withAlpha(40), borderRadius: BorderRadius.circular(4)),
              child: const Text('Installed', style: TextStyle(color: Colors.green, fontSize: 10)),
            ),
          ],
        ],
      ),
      subtitle: Text(desc, style: TextStyle(color: Colors.white.withAlpha(80), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text('$count installs', style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 10)),
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
