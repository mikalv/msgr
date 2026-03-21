import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

/// Special mentions that are always available regardless of team members.
const _specialMentions = <ComposerMention>[
  ComposerMention(
    id: '__channel__',
    displayName: 'channel',
    handle: 'channel',
  ),
  ComposerMention(
    id: '__here__',
    displayName: 'here',
    handle: 'here',
  ),
];

/// Provides team members as mention candidates for the composer.
/// Updates when the selected team changes.
/// Includes special mentions (@channel, @here) at the top.
final mentionCandidatesProvider =
    FutureProvider<List<ComposerMention>>((ref) async {
  final team = ref.watch(selectedTeamProvider);
  if (team == null) return _specialMentions;

  final api = ref.read(msgrApiProvider);
  final profiles = await api.getProfiles(team.slug);
  final memberMentions = profiles
      .map((p) => ComposerMention(
            id: p['id']?.toString() ?? '',
            displayName: p['display_name']?.toString() ?? 'Ukjent',
            handle: (p['display_name']?.toString() ?? 'ukjent')
                .toLowerCase()
                .replaceAll(RegExp(r'\s+'), '.'),
            avatarUrl: p['avatar_url']?.toString(),
          ))
      .where((m) => m.id.isNotEmpty)
      .toList();

  return [..._specialMentions, ...memberMentions];
});
