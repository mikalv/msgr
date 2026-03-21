import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:core/providers/draft_provider.dart';

void main() {
  group('ChannelDraftsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty', () {
      final notifier = _TestableDraftNotifier();
      expect(notifier.debugState, isEmpty);
    });

    test('updateDraft stores draft text by channel id', () {
      final notifier = _TestableDraftNotifier();
      notifier.updateDraft('ch-1', 'Hello draft');
      expect(notifier.debugState['ch-1'], 'Hello draft');
    });

    test('updateDraft with empty text calls clearDraft', () {
      final notifier = _TestableDraftNotifier();
      notifier.updateDraft('ch-1', 'Some text');
      expect(notifier.debugState['ch-1'], 'Some text');

      notifier.updateDraft('ch-1', '');
      expect(notifier.debugState.containsKey('ch-1'), false);
    });

    test('clearDraft removes draft for channel', () {
      final notifier = _TestableDraftNotifier();
      notifier.setStateDirectly({'ch-1': 'Draft text', 'ch-2': 'Other'});
      notifier.clearDraft('ch-1');
      expect(notifier.debugState.containsKey('ch-1'), false);
      expect(notifier.debugState['ch-2'], 'Other');
    });

    test('hasDraft returns true for non-empty draft', () {
      final notifier = _TestableDraftNotifier();
      notifier.setStateDirectly({'ch-1': 'Draft'});
      expect(notifier.hasDraft('ch-1'), true);
    });

    test('hasDraft returns false for missing channel', () {
      final notifier = _TestableDraftNotifier();
      expect(notifier.hasDraft('ch-1'), false);
    });

    test('hasDraft returns false for empty string', () {
      final notifier = _TestableDraftNotifier();
      notifier.setStateDirectly({'ch-1': ''});
      expect(notifier.hasDraft('ch-1'), false);
    });

    test('getDraft returns null for missing channel', () {
      final notifier = _TestableDraftNotifier();
      expect(notifier.getDraft('ch-1'), isNull);
    });

    test('getDraft returns stored text', () {
      final notifier = _TestableDraftNotifier();
      notifier.setStateDirectly({'ch-1': 'My draft'});
      expect(notifier.getDraft('ch-1'), 'My draft');
    });

    test('clear removes all drafts', () {
      final notifier = _TestableDraftNotifier();
      notifier.setStateDirectly({'ch-1': 'A', 'ch-2': 'B'});
      notifier.clear();
      expect(notifier.debugState, isEmpty);
    });

    test('multiple channels have independent drafts', () {
      final notifier = _TestableDraftNotifier();
      notifier.updateDraft('ch-1', 'Draft one');
      notifier.updateDraft('ch-2', 'Draft two');
      expect(notifier.debugState['ch-1'], 'Draft one');
      expect(notifier.debugState['ch-2'], 'Draft two');

      notifier.clearDraft('ch-1');
      expect(notifier.debugState.containsKey('ch-1'), false);
      expect(notifier.debugState['ch-2'], 'Draft two');
    });

    test('drafts persist to SharedPreferences and survive recreation', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier1 = _TestableDraftNotifier(teamSlug: 'team-a');
      notifier1.updateDraft('ch-1', 'Persistent draft');
      await notifier1.flushSave();
      notifier1.dispose();

      // Verify it was written to SharedPreferences.
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('drafts_team-a');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['ch-1'], 'Persistent draft');

      // Recreate notifier for the same team — it should load the draft.
      final notifier2 = _TestableDraftNotifier(teamSlug: 'team-a');
      // Wait for async _loadFromPrefs to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifier2.debugState['ch-1'], 'Persistent draft');
      notifier2.dispose();
    });

    test('drafts are scoped to team slug', () async {
      SharedPreferences.setMockInitialValues({});

      final notifierA = _TestableDraftNotifier(teamSlug: 'team-a');
      notifierA.updateDraft('ch-1', 'Team A draft');
      await notifierA.flushSave();
      notifierA.dispose();

      final notifierB = _TestableDraftNotifier(teamSlug: 'team-b');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(notifierB.debugState['ch-1'], isNull);
      notifierB.dispose();
    });

    test('clearDraft immediately persists removal', () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = _TestableDraftNotifier(teamSlug: 'team-x');
      notifier.updateDraft('ch-1', 'Will be cleared');
      await notifier.flushSave();

      notifier.clearDraft('ch-1');
      // clearDraft saves immediately (no debounce).
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('drafts_team-x');
      // Either null (removed) or empty map.
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded.containsKey('ch-1'), false);
      }
      notifier.dispose();
    });
  });
}

/// Testable subclass that exposes internal state.
class _TestableDraftNotifier extends ChannelDraftsNotifier {
  _TestableDraftNotifier({String teamSlug = 'test-team'})
      : super(teamSlug: teamSlug);

  Map<String, String> get debugState => state;

  /// Directly set internal state for testing clearDraft/hasDraft/getDraft.
  void setStateDirectly(Map<String, String> newState) {
    state = newState;
  }
}
