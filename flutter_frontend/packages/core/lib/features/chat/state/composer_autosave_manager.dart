import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

class ComposerDraftAutosaveManager {
  ComposerDraftAutosaveManager({
    required ChatCacheStore cache,
    required ChatComposerController controller,
    Duration debounceDuration = const Duration(milliseconds: 600),
    Duration backgroundSyncInterval = const Duration(seconds: 20),
    void Function(ChatDraftSnapshot snapshot)? onSaved,
  })  : _cache = cache,
        _controller = controller,
        _debounceDuration = debounceDuration,
        _onSaved = onSaved {
    _backgroundTimer = Timer.periodic(backgroundSyncInterval, (_) {
      flush();
    });
  }

  final ChatCacheStore _cache;
  final ChatComposerController _controller;
  final Duration _debounceDuration;
  final void Function(ChatDraftSnapshot snapshot)? _onSaved;

  final Map<String, ChatDraftSnapshot> _pending = <String, ChatDraftSnapshot>{};

  Timer? _debounceTimer;
  Timer? _backgroundTimer;
  bool _isSaving = false;
  bool _hasPendingFlush = false;

  void scheduleSave({
    required String threadId,
    required ChatDraftSnapshot snapshot,
  }) {
    _pending[threadId] = snapshot;
    _hasPendingFlush = true;
    _controller.markAutosaveInProgress();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, flush);
  }

  Future<void> flush() async {
    if (!_hasPendingFlush || _isSaving) {
      return;
    }
    _isSaving = true;

    final pending = Map<String, ChatDraftSnapshot>.from(_pending);
    _pending.clear();

    try {
      for (final entry in pending.entries) {
        await _cache.saveDraft(entry.key, entry.value);
        _onSaved?.call(entry.value);
      }
      _hasPendingFlush = _pending.isNotEmpty;
      _controller.markAutosaveSuccess(
        pending.values.isNotEmpty
            ? pending.values.last.updatedAt
            : DateTime.now(),
      );
    } catch (error, stack) {
      debugPrint('composer autosave failed: $error\n$stack');
      _controller.markAutosaveFailure();
      _pending.addAll(pending);
      _hasPendingFlush = true;
    } finally {
      _isSaving = false;
      if (_hasPendingFlush && _pending.isNotEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(_debounceDuration, flush);
      }
    }
  }

  Future<void> flushNow() async {
    _debounceTimer?.cancel();
    _hasPendingFlush = _pending.isNotEmpty;
    await flush();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _backgroundTimer?.cancel();
  }
}
