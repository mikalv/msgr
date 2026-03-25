import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/channel_list_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';
import 'package:core/ui/shell/profile_card.dart';

/// Provider that fetches team member profiles from GET /api/teams/:slug/profiles.
final teamMembersProvider =
    FutureProvider.autoDispose<List<SlackProfile>>((ref) async {
  final team = ref.watch(selectedTeamProvider);
  if (team == null) return [];

  final client = ref.read(msgrApiProvider);
  final raw = await client.getRaw('/api/teams/${team.slug}/profiles');

  List<Map<String, dynamic>> items;
  if (raw is List) {
    items = raw.cast<Map<String, dynamic>>();
  } else if (raw is Map<String, dynamic>) {
    final data = raw['data'];
    if (data is List) {
      items = data.cast<Map<String, dynamic>>();
    } else {
      items = [];
    }
  } else {
    items = [];
  }

  return items.map((p) => SlackProfile.fromJson(p)).toList();
});

/// A 240px wide panel showing channel members on the right side of the chat area.
///
/// Shows channel-specific members with add/remove functionality.
class MemberPanel extends ConsumerStatefulWidget {
  const MemberPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<MemberPanel> createState() => _MemberPanelState();
}

class _MemberPanelState extends ConsumerState<MemberPanel> {
  List<Map<String, dynamic>>? _channelMembers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadMembers() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    setState(() => _loading = true);
    try {
      final client = ref.read(msgrApiProvider);
      final members = await client.getChannelMembers(team.slug, channel.id);
      if (mounted) setState(() {
        _channelMembers = members;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    // Load all team members to pick from
    final client = ref.read(msgrApiProvider);
    final allProfiles = await client.getProfiles(team.slug);

    // Filter out already-in-channel members
    final currentIds = (_channelMembers ?? [])
        .map((m) => m['profile_id'] as String?)
        .whereType<String>()
        .toSet();

    final available = allProfiles
        .where((p) => !currentIds.contains(p['id']?.toString()))
        .toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All team members are already in this channel')),
        );
      }
      return;
    }

    if (!mounted) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _AddMemberDialog(available: available),
    );

    if (selected != null && selected.isNotEmpty) {
      await client.addChannelMembers(team.slug, channel.id, selected);
      _loadMembers(); // Refresh
    }
  }

  Future<void> _removeMember(String profileId, String displayName) async {
    final team = ref.read(selectedTeamProvider);
    final channel = ref.read(selectedChannelProvider);
    if (team == null || channel == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Remove member', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove $displayName from #${channel.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final client = ref.read(msgrApiProvider);
      await client.removeChannelMember(team.slug, channel.id, profileId);
      _loadMembers(); // Refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(selectedChannelProvider);
    final auth = ref.read(simpleAuthProvider);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Members${_channelMembers != null ? ' (${_channelMembers!.length})' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Add member button
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Add member',
                  onPressed: _addMember,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Member list
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _channelMembers == null || _channelMembers!.isEmpty
                    ? Center(
                        child: Text(
                          'No members',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _channelMembers!.length,
                        itemBuilder: (context, index) {
                          final m = _channelMembers![index];
                          final profileId = m['profile_id'] as String? ?? '';
                          final displayName = m['display_name'] as String? ?? '';
                          final role = m['role'] as String? ?? 'member';
                          final avatarUrl = m['avatar_url'] as String?;
                          final isMe = profileId == auth.profileId;

                          return _ChannelMemberTile(
                            profileId: profileId,
                            displayName: displayName,
                            role: role,
                            avatarUrl: avatarUrl,
                            isMe: isMe,
                            onRemove: isMe ? null : () => _removeMember(profileId, displayName),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChannelMemberTile extends StatelessWidget {
  const _ChannelMemberTile({
    required this.profileId,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    this.isMe = false,
    this.onRemove,
  });

  final String profileId;
  final String displayName;
  final String role;
  final String? avatarUrl;
  final bool isMe;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blueGrey.shade600,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName + (isMe ? ' (you)' : ''),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (role == 'admin') ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.close, size: 14, color: Colors.white.withValues(alpha: 0.3)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Remove',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Dialog for selecting team members to add to a channel.
class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.available});
  final List<Map<String, dynamic>> available;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final Set<String> _selected = {};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.available.where((p) {
      if (_search.isEmpty) return true;
      final name = (p['display_name'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase());
    }).toList();

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A3E),
      title: const Text('Add members', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 320,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final p = filtered[i];
                  final id = p['id']?.toString() ?? '';
                  final name = p['display_name']?.toString() ?? '';
                  final isSelected = _selected.contains(id);

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blueGrey.shade600,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                        : const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
                    onTap: () => setState(() {
                      isSelected ? _selected.remove(id) : _selected.add(id);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A5A)),
          child: Text('Add (${_selected.length})'),
        ),
      ],
    );
  }
}
