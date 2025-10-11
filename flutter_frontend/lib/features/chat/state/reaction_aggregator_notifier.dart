import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';

class ReactionAggregatorNotifier extends ChangeNotifier {
  final Map<String, List<ReactionAggregate>> _aggregates = {};

  UnmodifiableListView<ReactionAggregate> aggregatesFor(String messageId) {
    return UnmodifiableListView(_aggregates[messageId] ?? const []);
  }

  void apply(String messageId, List<ReactionAggregate> aggregates) {
    _aggregates[messageId] = List<ReactionAggregate>.from(aggregates);
    notifyListeners();
  }

  void clearFor(String messageId) {
    if (_aggregates.remove(messageId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_aggregates.isEmpty) return;
    _aggregates.clear();
    notifyListeners();
  }
}
