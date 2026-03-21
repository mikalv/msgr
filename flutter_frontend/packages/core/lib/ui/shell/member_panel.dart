import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/models.dart';
import 'package:core/providers/team_list_provider.dart';

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

  return items.map((p) {
    return SlackProfile(
      id: p['id']?.toString() ?? '',
      displayName: p['display_name']?.toString() ?? p['name']?.toString() ?? '',
      avatarUrl: p['avatar_url'] as String?,
      email: p['email'] as String?,
      role: p['role'] as String?,
    );
  }).toList();
});

/// A 240px wide panel showing team members on the right side of the chat area.
class MemberPanel extends ConsumerWidget {
  const MemberPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Medlemmer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Member list
          Expanded(
            child: membersAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Kunne ikke laste medlemmer',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Text(
                      'Ingen medlemmer',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberTile(profile: member);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.profile});

  final SlackProfile profile;

  void _showMemberContextMenu(BuildContext context, Offset globalPosition) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        _memberMenuItem('profile', Icons.person_outline, 'Vis profil'),
        _memberMenuItem('dm', Icons.chat_bubble_outline, 'Send DM'),
        const PopupMenuDivider(),
        _memberMenuItem('mention', Icons.alternate_email, 'Nevn i melding'),
        _memberMenuItem('copy', Icons.copy, 'Kopier brukernavn'),
      ],
    );

    if (result == null || !context.mounted) return;

    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: profile.displayName));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Brukernavn kopiert'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kommer snart'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  static PopupMenuItem<String> _memberMenuItem(
    String value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showMemberContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showMemberContextMenu(context, details.globalPosition),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Avatar with presence dot
          Stack(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueGrey.shade600,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              // Online presence dot (grey by default since we don't have real presence yet)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2A2A2A),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Name and role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.role != null && profile.role!.isNotEmpty)
                  Text(
                    profile.role!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
