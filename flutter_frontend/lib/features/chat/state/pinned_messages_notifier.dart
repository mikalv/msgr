import 'dart:collection';

import 'package:flutter/foundation.dart';

class PinnedMessageInfo {
  const PinnedMessageInfo({
    required this.messageId,
    required this.pinnedById,
    required this.pinnedAt,
    this.metadata = const {},
  });

  final String messageId;
  final String pinnedById;
  final DateTime pinnedAt;
  final Map<String, dynamic> metadata;
}

class PinnedMessagesNotifier extends ChangeNotifier {
  final Map<String, PinnedMessageInfo> _pinned = {};

  UnmodifiableListView<PinnedMessageInfo> get pinnedMessages {
    final list = _pinned.values.toList()
      ..sort((a, b) => b.pinnedAt.compareTo(a.pinnedAt));
    return UnmodifiableListView(list);
  }

  bool isPinned(String messageId) => _pinned.containsKey(messageId);

  void pin(PinnedMessageInfo info) {
    _pinned[info.messageId] = info;
    notifyListeners();
  }

  void unpin(String messageId) {
    if (_pinned.remove(messageId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_pinned.isEmpty) return;
    _pinned.clear();
    notifyListeners();
  }
}
