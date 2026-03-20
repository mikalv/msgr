import 'package:flutter/material.dart';

import 'channel_list_item.dart';
import 'dm_list_item.dart';
import 'shell_models.dart';
import 'shell_theme.dart';

/// Channel sidebar (240 px wide) showing the active team name, a search field,
/// collapsible channel and DM sections, and "create" buttons.
class ChannelSidebar extends StatefulWidget {
  const ChannelSidebar({
    super.key,
    required this.teamName,
    required this.channels,
    required this.dmContacts,
    this.selectedChannelId,
    this.selectedDmId,
    this.onChannelSelected,
    this.onDmSelected,
    this.onCreateChannel,
  });

  final String teamName;
  final List<MockChannel> channels;
  final List<MockDmContact> dmContacts;
  final String? selectedChannelId;
  final String? selectedDmId;
  final ValueChanged<MockChannel>? onChannelSelected;
  final ValueChanged<MockDmContact>? onDmSelected;
  final VoidCallback? onCreateChannel;

  @override
  State<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends State<ChannelSidebar> {
  bool _channelsExpanded = true;
  bool _dmsExpanded = true;
  final _searchController = TextEditingController();

  List<MockChannel> get _sortedChannels {
    final sorted = List<MockChannel>.from(widget.channels);
    sorted.sort((a, b) {
      // Unread first
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      // Then by last activity
      final aTime = a.lastActivityAt ?? DateTime(2000);
      final bTime = b.lastActivityAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<MockDmContact> get _sortedDms {
    final sorted = List<MockDmContact>.from(widget.dmContacts);
    sorted.sort((a, b) {
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;
      final aTime = a.lastActivityAt ?? DateTime(2000);
      final bTime = b.lastActivityAt ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ShellTheme.sidebarWidth,
      color: ShellTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team name header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.teamName,
                    style: const TextStyle(
                      color: ShellTheme.sidebarTextBright,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: ShellTheme.sidebarText, size: 18),
                  onPressed: () {},
                  tooltip: 'Innstillinger',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: ShellTheme.sidebarText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Sok...',
                  hintStyle: TextStyle(color: ShellTheme.sidebarText.withAlpha(128)),
                  prefixIcon: const Icon(Icons.search, color: ShellTheme.sidebarText, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  filled: true,
                  fillColor: ShellTheme.sidebarHoverItem,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                // Channels section
                _SectionHeader(
                  title: 'Kanaler',
                  isExpanded: _channelsExpanded,
                  onToggle: () =>
                      setState(() => _channelsExpanded = !_channelsExpanded),
                ),
                if (_channelsExpanded) ...[
                  for (final channel in _sortedChannels)
                    ChannelListItem(
                      channel: channel,
                      isSelected: channel.id == widget.selectedChannelId,
                      onTap: () => widget.onChannelSelected?.call(channel),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: TextButton.icon(
                      onPressed: () => widget.onCreateChannel?.call(),
                      icon: const Icon(Icons.add, size: 14, color: ShellTheme.sidebarText),
                      label: const Text(
                        'Opprett kanal',
                        style: TextStyle(color: ShellTheme.sidebarText, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                // DMs section
                _SectionHeader(
                  title: 'Direktemeldinger',
                  isExpanded: _dmsExpanded,
                  onToggle: () =>
                      setState(() => _dmsExpanded = !_dmsExpanded),
                ),
                if (_dmsExpanded) ...[
                  for (final dm in _sortedDms)
                    DmListItem(
                      contact: dm,
                      isSelected: dm.id == widget.selectedDmId,
                      onTap: () => widget.onDmSelected?.call(dm),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add, size: 14, color: ShellTheme.sidebarText),
                      label: const Text(
                        'Ny melding',
                        style: TextStyle(color: ShellTheme.sidebarText, fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 28),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onToggle,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: ShellTheme.sidebarText,
              size: 16,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ShellTheme.sidebarText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
