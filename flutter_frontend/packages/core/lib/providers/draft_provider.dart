import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/draft_dao.dart';

import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelDrafts — draft text per channel, persisted to local SQLite DB
// ---------------------------------------------------------------------------

class ChannelDraftsNotifier extends StateNotifier<Map<String, String>> {
  ChannelDraftsNotifier({
    DraftDao? dao,
    required String teamSlug,
  })  : _dao = dao,
        _teamSlug = teamSlug,
        super({}) {
    if (_dao != null) _loadFromStorage();
  }

  final DraftDao? _dao;
  final String _teamSlug;

  /// Debounce timers per channel to avoid hammering the DB.
  final Map<String, Timer> _debounceTimers = {};
  static const _debounceDuration = Duration(milliseconds: 500);

  /// Load all persisted drafts for this team from the local DB.
  Future<void> _loadFromStorage() async {
    try {
      final drafts = await _dao!.getAllDrafts(_teamSlug);
      if (drafts.isNotEmpty && mounted) {
        state = {...state, ...drafts};
      }
    } catch (_) {
      // Silently ignore — drafts are best-effort.
    }
  }

  /// Update the draft for a channel.
  ///
  /// Immediately updates in-memory state and debounces the DB write
  /// by 500 ms to avoid excessive I/O while the user is typing.
  void updateDraft(String channelId, String text) {
    if (text.isEmpty) {
      clearDraft(channelId);
      return;
    }
    final updated = Map<String, String>.from(state);
    updated[channelId] = text;
    state = updated;
    _debouncePersist(channelId, text);
  }

  /// Clear the draft for a channel (e.g., after sending a message).
  void clearDraft(String channelId) {
    _debounceTimers[channelId]?.cancel();
    _debounceTimers.remove(channelId);

    final updated = Map<String, String>.from(state);
    updated.remove(channelId);
    state = updated;
    _removeDraft(channelId);
  }

  /// Get the draft for a specific channel.
  String? getDraft(String channelId) => state[channelId];

  /// Whether a channel has a non-empty draft.
  bool hasDraft(String channelId) {
    final draft = state[channelId];
    return draft != null && draft.isNotEmpty;
  }

  void clear() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    state = {};
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }

  void _debouncePersist(String channelId, String text) {
    _debounceTimers[channelId]?.cancel();
    _debounceTimers[channelId] = Timer(_debounceDuration, () {
      _persistDraft(channelId, text);
    });
  }

  Future<void> _persistDraft(String channelId, String text) async {
    try {
      await _dao?.saveDraft(channelId, _teamSlug, text);
    } catch (_) {
      // Best-effort persistence. Draft is still in memory.
    }
  }

  Future<void> _removeDraft(String channelId) async {
    try {
      await _dao?.deleteDraft(channelId, _teamSlug);
    } catch (_) {
      // Best-effort.
    }
  }
}

final channelDraftsProvider =
    StateNotifierProvider<ChannelDraftsNotifier, Map<String, String>>((ref) {
  final team = ref.watch(selectedTeamProvider);
  final teamSlug = team?.slug ?? 'default';

  // Try to use libmsgr database for persistent drafts, fall back to in-memory
  DraftDao? dao;
  try {
    final db = LibMsgr().databaseService.instance;
    dao = DraftDao(db);
  } catch (_) {
    // LibMsgr not bootstrapped yet — drafts will be in-memory only
  }

  return ChannelDraftsNotifier(dao: dao, teamSlug: teamSlug);
});

/// Draft text for a specific channel (null if no draft).
final channelDraftProvider = Provider.family<String?, String>((ref, channelId) {
  final drafts = ref.watch(channelDraftsProvider);
  return drafts[channelId];
});

/// Whether a channel has a draft (for sidebar indicator).
final channelHasDraftProvider = Provider.family<bool, String>((ref, channelId) {
  final draft = ref.watch(channelDraftProvider(channelId));
  return draft != null && draft.isNotEmpty;
});
