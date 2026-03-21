import 'package:flutter_test/flutter_test.dart';

import 'package:core/providers/settings_provider.dart';

void main() {
  group('UserSettings', () {
    test('default values', () {
      final settings = UserSettings();
      expect(settings.notifyDesktop, true);
      expect(settings.notifyMobile, true);
      expect(settings.notifyAbout, 'everything');
      expect(settings.notifyThreadReplies, true);
      expect(settings.notifySounds, true);
      expect(settings.dndEnabled, false);
      expect(settings.dndStart, isNull);
      expect(settings.dndEnd, isNull);
      expect(settings.showOnlineStatus, true);
      expect(settings.showReadReceipts, true);
      expect(settings.showTypingIndicators, true);
      expect(settings.locale, 'en');
      expect(settings.dateFormat, 'auto');
      expect(settings.time24h, true);
      expect(settings.statusText, isNull);
      expect(settings.statusEmoji, isNull);
      expect(settings.theme, 'dark');
      expect(settings.fontSize, 14.0);
      expect(settings.compactMode, false);
    });

    test('copyWith overrides specified fields', () {
      final settings = UserSettings();
      final updated = settings.copyWith(
        notifyDesktop: false,
        theme: 'light',
        fontSize: 16.0,
        dndEnabled: true,
        dndStart: '22:00',
        dndEnd: '08:00',
      );
      expect(updated.notifyDesktop, false);
      expect(updated.theme, 'light');
      expect(updated.fontSize, 16.0);
      expect(updated.dndEnabled, true);
      expect(updated.dndStart, '22:00');
      expect(updated.dndEnd, '08:00');
      // Unchanged
      expect(updated.notifyMobile, true);
      expect(updated.locale, 'en');
    });
  });

  group('UserSettings.applyServerData', () {
    test('parses server response fields', () {
      final settings = UserSettings();
      settings.applyServerData({
        'notify_desktop': false,
        'notify_mobile': false,
        'notify_about': 'mentions',
        'notify_thread_replies': false,
        'notify_sounds': false,
        'dnd_enabled': true,
        'dnd_start': '23:00',
        'dnd_end': '07:00',
        'show_online_status': false,
        'show_read_receipts': false,
        'show_typing_indicators': false,
        'locale': 'nb',
        'date_format': 'DD/MM/YYYY',
        'time_24h': false,
        'status_text': 'In a meeting',
        'status_emoji': ':calendar:',
      });

      expect(settings.notifyDesktop, false);
      expect(settings.notifyMobile, false);
      expect(settings.notifyAbout, 'mentions');
      expect(settings.notifyThreadReplies, false);
      expect(settings.notifySounds, false);
      expect(settings.dndEnabled, true);
      expect(settings.dndStart, '23:00');
      expect(settings.dndEnd, '07:00');
      expect(settings.showOnlineStatus, false);
      expect(settings.showReadReceipts, false);
      expect(settings.showTypingIndicators, false);
      expect(settings.locale, 'nb');
      expect(settings.dateFormat, 'DD/MM/YYYY');
      expect(settings.time24h, false);
      expect(settings.statusText, 'In a meeting');
      expect(settings.statusEmoji, ':calendar:');
    });

    test('ignores unknown keys', () {
      final settings = UserSettings();
      settings.applyServerData({
        'unknown_field': 'value',
        'another_unknown': 42,
      });
      // No exception; defaults unchanged
      expect(settings.notifyDesktop, true);
      expect(settings.locale, 'en');
    });

    test('partial update preserves untouched fields', () {
      final settings = UserSettings();
      settings.applyServerData({
        'locale': 'nb',
      });
      expect(settings.locale, 'nb');
      expect(settings.notifyDesktop, true); // unchanged
      expect(settings.theme, 'dark'); // local-only, unchanged
    });
  });

  group('UserSettings.toServerMap', () {
    test('serializes synced fields', () {
      final settings = UserSettings(
        notifyDesktop: false,
        locale: 'nb',
        statusText: 'Away',
        statusEmoji: ':palm_tree:',
      );

      final json = settings.toServerMap();
      expect(json['notify_desktop'], false);
      expect(json['locale'], 'nb');
      expect(json['status_text'], 'Away');
      expect(json['status_emoji'], ':palm_tree:');
      expect(json['notify_mobile'], true);
      expect(json['time_24h'], true);
    });

    test('does not include local-only settings in sync JSON', () {
      final settings = UserSettings(
        theme: 'light',
        fontSize: 18.0,
        compactMode: true,
      );

      final json = settings.toServerMap();
      expect(json.containsKey('theme'), false);
      expect(json.containsKey('fontSize'), false);
      expect(json.containsKey('font_size'), false);
      expect(json.containsKey('compactMode'), false);
      expect(json.containsKey('compact_mode'), false);
    });

    test('round-trips through applyServerData', () {
      final original = UserSettings(
        notifyDesktop: false,
        notifyAbout: 'dms_only',
        dndEnabled: true,
        dndStart: '22:00',
        dndEnd: '06:00',
        locale: 'nb',
        time24h: false,
      );

      final json = original.toServerMap();
      final restored = UserSettings();
      restored.applyServerData(json);

      expect(restored.notifyDesktop, false);
      expect(restored.notifyAbout, 'dms_only');
      expect(restored.dndEnabled, true);
      expect(restored.dndStart, '22:00');
      expect(restored.dndEnd, '06:00');
      expect(restored.locale, 'nb');
      expect(restored.time24h, false);
    });
  });
}
