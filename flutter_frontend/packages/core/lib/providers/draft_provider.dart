import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'team_list_provider.dart';

// ---------------------------------------------------------------------------
// ChannelDrafts — draft text per channel, persisted to SharedPreferences
// ---------------------------------------------------------------------------

class ChannelDraftsNotifier extends StateNotifier<Map<String, String>> {
  ChannelDraftsNotifier({required String teamSlug})
      : _teamSlug = teamSlug,
        super({}) {
    _loadFromPrefs();
  }

  final String _teamSlug;

  /// Debounce timers per channel to avoid hammering SharedPreferences.
  final Map<String, Timer> _debounceTimers = {};
  static const _debounceDuration = Duration(milliseconds: 500);

  String get _prefsKey => 'drafts_$_teamSlug';

  /// Load all persisted drafts for this team from SharedPreferences.
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null && mounted) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        state = map.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {
      // Silently ignore — drafts are best-effort.
    }
  }

  /// Persist all drafts to SharedPreferences.
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, jsonEncode(state));
      }
    } catch (_) {
      // Best-effort persistence.
    }
  }

  /// Update the draft for a channel.
  ///
  /// Immediately updates in-memory state and debounces the prefs write
  /// by 500 ms to avoid excessive I/O while the user is typing.
  void updateDraft(String channelId, String text) {
    if (text.isEmpty) {
      clearDraft(channelId);
      return;
    }
    final updated = Map<String, String>.from(state);
    updated[channelId] = text;
    state = updated;
    _debounceSave();
  }

  /// Clear the draft for a channel (e.g., after sending a message).
  void clearDraft(String channelId) {
    _debounceTimers[channelId]?.cancel();
    _debounceTimers.remove(channelId);

    final updated = Map<String, String>.from(state);
    updated.remove(channelId);
    state = updated;
    _saveToPrefs(); // immediate save on clear
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
    _saveToPrefs();
  }

  @override
  void dispose() {
    // Flush any pending debounced save before disposing.
    if (_debounceTimers.containsKey('__save__')) {
      _debounceTimers['__save__']?.cancel();
      _saveToPrefs();
    }
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }

  void _debounceSave() {
    _debounceTimers['__save__']?.cancel();
    _debounceTimers['__save__'] = Timer(_debounceDuration, _saveToPrefs);
  }

  /// Flush any pending debounced save immediately. Exposed for tests.
  @visibleForTesting
  Future<void> flushSave() async {
    _debounceTimers['__save__']?.cancel();
    _debounceTimers.remove('__save__');
    await _saveToPrefs();
  }
}

final channelDraftsProvider =
    StateNotifierProvider<ChannelDraftsNotifier, Map<String, String>>((ref) {
  final team = ref.watch(selectedTeamProvider);
  final teamSlug = team?.slug ?? 'default';

  return ChannelDraftsNotifier(teamSlug: teamSlug);
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
