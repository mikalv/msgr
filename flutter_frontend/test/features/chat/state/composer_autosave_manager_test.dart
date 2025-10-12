import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/state/chat_cache_repository.dart';
import 'package:messngr/features/chat/state/composer_autosave_manager.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';

void main() {
  group('ComposerDraftAutosaveManager', () {
    test('flushes the latest draft per thread', () {
      fakeAsync((async) {
        final cache = InMemoryChatCacheStore();
        final controller = ChatComposerController();
        final manager = ComposerDraftAutosaveManager(
          cache: cache,
          controller: controller,
          debounceDuration: const Duration(milliseconds: 100),
          backgroundSyncInterval: const Duration(seconds: 5),
        );

        controller.setText('første');
        manager.scheduleSave(
          threadId: 'alpha',
          snapshot: controller.snapshot(),
        );

        controller.setText('andre');
        manager.scheduleSave(
          threadId: 'alpha',
          snapshot: controller.snapshot(),
        );

        controller.setText('beta-tekst');
        manager.scheduleSave(
          threadId: 'beta',
          snapshot: controller.snapshot(),
        );

        async.elapse(const Duration(milliseconds: 120));
        async.flushMicrotasks();

        final alpha = async.run(() async => cache.readDraft('alpha'));
        final beta = async.run(() async => cache.readDraft('beta'));

        expect(alpha?.text, equals('andre'));
        expect(beta?.text, equals('beta-tekst'));
        expect(controller.value.autosaveStatus,
            equals(ComposerAutosaveStatus.saved));
        manager.dispose();
      });
    });

    test('marks failure when cache write throws', () {
      fakeAsync((async) {
        final cache = _ThrowingCacheStore();
        final controller = ChatComposerController();
        final manager = ComposerDraftAutosaveManager(
          cache: cache,
          controller: controller,
          debounceDuration: const Duration(milliseconds: 50),
          backgroundSyncInterval: const Duration(seconds: 5),
        );

        controller.setText('tekst');
        manager.scheduleSave(
          threadId: 'alpha',
          snapshot: controller.snapshot(),
        );

        async.elapse(const Duration(milliseconds: 60));
        async.flushMicrotasks();

        expect(controller.value.autosaveStatus,
            equals(ComposerAutosaveStatus.failed));
        manager.dispose();
      });
    });
  });
}

class _ThrowingCacheStore extends InMemoryChatCacheStore {
  @override
  Future<void> saveDraft(String threadId, ChatDraftSnapshot snapshot) {
    throw Exception('unable to persist');
  }
}
