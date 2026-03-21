import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:core/features/chat/widgets/chat_composer.dart';
import 'package:core/providers/auth_state_provider.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/providers/team_list_provider.dart';

/// Special mentions always available.
const _specialMentions = <ComposerMention>[
  ComposerMention(id: '__channel__', displayName: 'channel', handle: 'channel'),
  ComposerMention(id: '__here__', displayName: 'here', handle: 'here'),
];

/// Holds the loaded mention candidates.
class MentionState {
  const MentionState({this.mentions = const [], this.loaded = false});
  final List<ComposerMention> mentions;
  final bool loaded;
}

class MentionNotifier extends StateNotifier<MentionState> {
  MentionNotifier() : super(const MentionState());

  Future<void> load(String teamSlug, dynamic api, {String? myAccountId}) async {
    if (state.loaded) return;
    try {
      final profiles = await api.getProfiles(teamSlug) as List<Map<String, dynamic>>;
      final members = profiles
          .where((p) => p['account_id']?.toString() != myAccountId)
          .map((p) => ComposerMention(
                id: p['id']?.toString() ?? '',
                displayName: p['display_name']?.toString() ?? 'Unknown',
                handle: (p['display_name']?.toString() ?? 'unknown')
                    .toLowerCase()
                    .replaceAll(RegExp(r'\s+'), '.'),
                avatarUrl: p['avatar_url']?.toString(),
              ))
          .where((m) => m.id.isNotEmpty)
          .toList();
      state = MentionState(
        mentions: [..._specialMentions, ...members],
        loaded: true,
      );
    } catch (e) {
      state = MentionState(mentions: List.from(_specialMentions), loaded: true);
    }
  }

  void reset() {
    state = const MentionState();
  }
}

final mentionNotifierProvider =
    StateNotifierProvider<MentionNotifier, MentionState>((ref) {
  final notifier = MentionNotifier();

  final team = ref.watch(selectedTeamProvider);
  final auth = ref.watch(simpleAuthProvider);

  // Reset when team changes
  if (team != null && auth.isLoggedIn && auth.accessToken != null) {
    final api = ref.read(msgrApiProvider);
    // Load asynchronously
    Future.microtask(() => notifier.load(team.slug, api, myAccountId: auth.accountId));
  }

  return notifier;
});

/// Convenience: just the mention list.
final mentionCandidatesProvider = Provider<List<ComposerMention>>((ref) {
  final state = ref.watch(mentionNotifierProvider);
  // TEMP DEBUG: always add a test mention to verify the pipeline works
  final result = state.mentions.isNotEmpty
      ? state.mentions
      : <ComposerMention>[
          ..._specialMentions,
          const ComposerMention(id: 'test', displayName: 'TestUser', handle: 'testuser'),
        ];
  return result;
});
