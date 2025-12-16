import 'dart:collection';

import 'package:flutter/foundation.dart';

class TypingParticipant {
  TypingParticipant({
    required this.profileId,
    required this.profileName,
    this.threadId,
    this.expiresAt,
  });

  final String profileId;
  final String profileName;
  final String? threadId;
  final DateTime? expiresAt;
}

class TypingParticipantsNotifier extends ChangeNotifier {
  final Map<String, Map<String, TypingParticipant>> _typing = {};

  UnmodifiableMapView<String, List<TypingParticipant>> get activeByThread {
    final mapped = <String, List<TypingParticipant>>{};
    for (final entry in _typing.entries) {
      mapped[entry.key] = entry.value.values.toList(growable: false);
    }
    return UnmodifiableMapView(mapped);
  }

  void setTyping({
    required String profileId,
    required String profileName,
    String? threadId,
    DateTime? expiresAt,
  }) {
    final key = threadId ?? 'root';
    final participants = _typing.putIfAbsent(key, () => {});
    participants[profileId] = TypingParticipant(
      profileId: profileId,
      profileName: profileName,
      threadId: threadId,
      expiresAt: expiresAt,
    );
    notifyListeners();
  }

  void stopTyping({required String profileId, String? threadId}) {
    final key = threadId ?? 'root';
    final participants = _typing[key];
    if (participants == null) {
      return;
    }
    final removed = participants.remove(profileId);
    if (removed != null) {
      if (participants.isEmpty) {
        _typing.remove(key);
      }
      notifyListeners();
    }
  }

  void pruneExpired(DateTime now) {
    bool changed = false;
    final keys = List<String>.from(_typing.keys);
    for (final key in keys) {
      final participants = _typing[key];
      if (participants == null) continue;
      final expired = participants.values.where((participant) {
        final expiresAt = participant.expiresAt;
        return expiresAt != null && expiresAt.isBefore(now);
      }).toList();
      if (expired.isEmpty) continue;
      for (final participant in expired) {
        participants.remove(participant.profileId);
      }
      if (participants.isEmpty) {
        _typing.remove(key);
      }
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clear() {
    if (_typing.isEmpty) return;
    _typing.clear();
    notifyListeners();
  }
}
