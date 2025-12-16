import 'package:flutter/foundation.dart';

class MessageEditingNotifier extends ChangeNotifier {
  String? _editingMessageId;
  String? _originalBody;
  final Set<String> _deletedMessageIds = <String>{};

  String? get editingMessageId => _editingMessageId;
  String? get originalBody => _originalBody;
  bool isDeleted(String messageId) => _deletedMessageIds.contains(messageId);

  void startEditing(String messageId, {String? body}) {
    _editingMessageId = messageId;
    _originalBody = body;
    notifyListeners();
  }

  void cancelEditing() {
    if (_editingMessageId == null && _originalBody == null) return;
    _editingMessageId = null;
    _originalBody = null;
    notifyListeners();
  }

  void markDeleted(String messageId) {
    if (_deletedMessageIds.add(messageId)) {
      notifyListeners();
    }
  }

  void restore(String messageId) {
    if (_deletedMessageIds.remove(messageId)) {
      notifyListeners();
    }
  }

  void clear() {
    _editingMessageId = null;
    _originalBody = null;
    _deletedMessageIds.clear();
    notifyListeners();
  }
}
