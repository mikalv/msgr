import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// TypingIndicators — who is typing in each channel
// ---------------------------------------------------------------------------

/// Maps channel ID to a list of profile display names that are currently
/// typing in that channel.
class TypingIndicatorsNotifier extends StateNotifier<Map<String, List<String>>> {
  TypingIndicatorsNotifier() : super({});

  final Map<String, Timer> _expiryTimers = {};

  /// Record that a profile started typing in a channel.
  /// Automatically expires after [duration] (default 5 seconds).
  void setTyping(
    String channelId,
    String profileName, {
    Duration duration = const Duration(seconds: 5),
  }) {
    final current = List<String>.from(state[channelId] ?? []);
    if (!current.contains(profileName)) {
      current.add(profileName);
    }
    state = {...state, channelId: current};

    // Auto-expire
    final timerKey = '$channelId:$profileName';
    _expiryTimers[timerKey]?.cancel();
    _expiryTimers[timerKey] = Timer(duration, () {
      stopTyping(channelId, profileName);
    });
  }

  /// Record that a profile stopped typing.
  void stopTyping(String channelId, String profileName) {
    final current = List<String>.from(state[channelId] ?? []);
    current.remove(profileName);
    if (current.isEmpty) {
      final updated = Map<String, List<String>>.from(state);
      updated.remove(channelId);
      state = updated;
    } else {
      state = {...state, channelId: current};
    }

    final timerKey = '$channelId:$profileName';
    _expiryTimers[timerKey]?.cancel();
    _expiryTimers.remove(timerKey);
  }

  /// Clear all typing for a channel (e.g., when switching channels).
  void clearChannel(String channelId) {
    final updated = Map<String, List<String>>.from(state);
    updated.remove(channelId);
    state = updated;

    _expiryTimers.removeWhere((key, timer) {
      if (key.startsWith('$channelId:')) {
        timer.cancel();
        return true;
      }
      return false;
    });
  }

  void clear() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    state = {};
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

final typingIndicatorsProvider =
    StateNotifierProvider<TypingIndicatorsNotifier, Map<String, List<String>>>((ref) {
  return TypingIndicatorsNotifier();
});

/// Who is typing in a specific channel (list of display names).
final channelTypingProvider = Provider.family<List<String>, String>((ref, channelId) {
  final typing = ref.watch(typingIndicatorsProvider);
  return typing[channelId] ?? [];
});
