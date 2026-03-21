import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';

/// A Spotlight/Alfred-style quick switcher overlay activated by Cmd+K.
///
/// Shows channels, DMs, and teams filtered by a search query with keyboard
/// navigation (up/down arrows, Enter to select, Escape to close).
class QuickSwitcher extends ConsumerStatefulWidget {
  const QuickSwitcher({super.key});

  @override
  ConsumerState<QuickSwitcher> createState() => _QuickSwitcherState();
}

class _QuickSwitcherState extends ConsumerState<QuickSwitcher> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
        _selectedIndex = 0;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<_SwitcherItem> _buildResults() {
    final channels = ref.read(channelListProvider).channels;
    final teams = ref.read(teamListProvider).teams;

    final items = <_SwitcherItem>[];

    // Add teams
    for (final team in teams) {
      items.add(_SwitcherItem(
        id: team.id,
        title: team.name,
        subtitle: team.slug,
        icon: Icons.business,
        kind: _SwitcherKind.team,
        data: team,
      ));
    }

    // Add channels
    for (final ch in channels) {
      final isChannel = ch.kind == ChannelKind.channel;
      items.add(_SwitcherItem(
        id: ch.id,
        title: ch.name,
        subtitle: ch.topic ?? (isChannel ? 'Kanal' : 'Direktemelding'),
        icon: isChannel ? Icons.tag : Icons.chat_bubble_outline,
        kind: isChannel ? _SwitcherKind.channel : _SwitcherKind.dm,
        data: ch,
      ));
    }

    if (_query.isEmpty) return items;

    // Fuzzy match: split query into chars and check if they appear in order
    final lowerQuery = _query.toLowerCase();
    return items.where((item) {
      final target = item.title.toLowerCase();
      // Simple substring match first
      if (target.contains(lowerQuery)) return true;
      // Fuzzy: all query chars appear in order
      var qi = 0;
      for (var i = 0; i < target.length && qi < lowerQuery.length; i++) {
        if (target[i] == lowerQuery[qi]) qi++;
      }
      return qi == lowerQuery.length;
    }).toList()
      ..sort((a, b) {
        // Prioritize prefix matches
        final aStarts =
            a.title.toLowerCase().startsWith(lowerQuery) ? 0 : 1;
        final bStarts =
            b.title.toLowerCase().startsWith(lowerQuery) ? 0 : 1;
        if (aStarts != bStarts) return aStarts.compareTo(bStarts);
        // Then exact contains
        final aContains =
            a.title.toLowerCase().contains(lowerQuery) ? 0 : 1;
        final bContains =
            b.title.toLowerCase().contains(lowerQuery) ? 0 : 1;
        return aContains.compareTo(bContains);
      });
  }

  void _handleSelect(_SwitcherItem item) {
    switch (item.kind) {
      case _SwitcherKind.team:
        final team = item.data as SlackTeam;
        ref.read(selectedTeamProvider.notifier).select(team);
        break;
      case _SwitcherKind.channel:
      case _SwitcherKind.dm:
        final channel = item.data as SlackChannel;
        ref.read(selectedChannelProvider.notifier).select(channel);
        break;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final results = _buildResults();
    // Clamp selected index
    if (_selectedIndex >= results.length) {
      _selectedIndex = results.isEmpty ? 0 : results.length - 1;
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            if (_selectedIndex < results.length - 1) _selectedIndex++;
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (_selectedIndex > 0) _selectedIndex--;
          });
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (results.isNotEmpty && _selectedIndex < results.length) {
            _handleSelect(results[_selectedIndex]);
          }
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 440),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ga til kanal, DM, eller team...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (results.isNotEmpty &&
                          _selectedIndex < results.length) {
                        _handleSelect(results[_selectedIndex]);
                      }
                    },
                  ),
                ),

                // Divider
                Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.08),
                ),

                // Results
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _query.isEmpty
                          ? 'Ingen elementer tilgjengelig'
                          : 'Ingen treff for "$_query"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final isSelected = index == _selectedIndex;
                        return _SwitcherResultTile(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => _handleSelect(item),
                          onHover: () {
                            setState(() => _selectedIndex = index);
                          },
                        );
                      },
                    ),
                  ),

                // Footer hint
                Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.08),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _KeyHint(label: '\u2191\u2193'),
                      const SizedBox(width: 4),
                      Text(
                        'naviger',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const _KeyHint(label: '\u23CE'),
                      const SizedBox(width: 4),
                      Text(
                        'velg',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const _KeyHint(label: 'esc'),
                      const SizedBox(width: 4),
                      Text(
                        'lukk',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal models
// ---------------------------------------------------------------------------

enum _SwitcherKind { channel, dm, team }

class _SwitcherItem {
  const _SwitcherItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
    required this.data,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final _SwitcherKind kind;
  final Object data;
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SwitcherResultTile extends StatelessWidget {
  const _SwitcherResultTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  final _SwitcherItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF02ac88).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFF02ac88)
                    : Colors.white.withOpacity(0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle.isNotEmpty)
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Kind badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  switch (item.kind) {
                    _SwitcherKind.channel => 'kanal',
                    _SwitcherKind.dm => 'DM',
                    _SwitcherKind.team => 'team',
                  },
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Show the quick switcher as a modal dialog.
void showQuickSwitcher(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const QuickSwitcher(),
  );
}
