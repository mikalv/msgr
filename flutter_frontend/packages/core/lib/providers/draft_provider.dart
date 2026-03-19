import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// ChannelDrafts — draft text per channel, persisted to local DB
// ---------------------------------------------------------------------------

class ChannelDraftsNotifier extends StateNotifier<Map<String, String>> {
  ChannelDraftsNotifier() : super({}) {
    _loadFromStorage();
  }

  /// Load persisted drafts from local storage.
  Future<void> _loadFromStorage() async {
    // TODO: Load from local DB (Hive/Sembast/libmsgr storage).
    // Drafts are permanent until the user sends or deletes them.
  }

  /// Update the draft for a channel.
  void updateDraft(String channelId, String text) {
    if (text.isEmpty) {
      clearDraft(channelId);
      return;
    }
    state = {...state, channelId: text};
    _persistDraft(channelId, text);
  }

  /// Clear the draft for a channel (e.g., after sending a message).
  void clearDraft(String channelId) {
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

  void clear() => state = {};

  Future<void> _persistDraft(String channelId, String text) async {
    // TODO: Save to local DB.
    // Drafts survive app restart. Never auto-deleted.
  }

  Future<void> _removeDraft(String channelId) async {
    // TODO: Remove from local DB.
  }
}

final channelDraftsProvider =
    StateNotifierProvider<ChannelDraftsNotifier, Map<String, String>>((ref) {
  return ChannelDraftsNotifier();
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
