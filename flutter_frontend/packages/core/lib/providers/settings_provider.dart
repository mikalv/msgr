import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'msgr_client_provider.dart';
import 'auth_state_provider.dart';

// ---------------------------------------------------------------------------
// UserSettings model
// ---------------------------------------------------------------------------

class UserSettings {
  // Synced to server
  bool notifyDesktop;
  bool notifyMobile;
  String notifyAbout; // 'everything', 'mentions', 'dms_only', 'nothing'
  bool notifyThreadReplies;
  bool notifySounds;
  bool dndEnabled;
  String? dndStart; // "22:00"
  String? dndEnd; // "08:00"
  bool showOnlineStatus;
  bool showReadReceipts;
  bool showTypingIndicators;
  String locale;
  String dateFormat;
  bool time24h;
  String? statusText;
  String? statusEmoji;

  // Local-only settings (not synced)
  String theme; // 'dark', 'light', 'system'
  double fontSize;
  bool compactMode;

  UserSettings({
    this.notifyDesktop = true,
    this.notifyMobile = true,
    this.notifyAbout = 'everything',
    this.notifyThreadReplies = true,
    this.notifySounds = true,
    this.dndEnabled = false,
    this.dndStart,
    this.dndEnd,
    this.showOnlineStatus = true,
    this.showReadReceipts = true,
    this.showTypingIndicators = true,
    this.locale = 'en',
    this.dateFormat = 'auto',
    this.time24h = true,
    this.statusText,
    this.statusEmoji,
    this.theme = 'dark',
    this.fontSize = 14.0,
    this.compactMode = false,
  });

  UserSettings copyWith({
    bool? notifyDesktop,
    bool? notifyMobile,
    String? notifyAbout,
    bool? notifyThreadReplies,
    bool? notifySounds,
    bool? dndEnabled,
    String? dndStart,
    String? dndEnd,
    bool? showOnlineStatus,
    bool? showReadReceipts,
    bool? showTypingIndicators,
    String? locale,
    String? dateFormat,
    bool? time24h,
    String? statusText,
    String? statusEmoji,
    String? theme,
    double? fontSize,
    bool? compactMode,
  }) {
    return UserSettings(
      notifyDesktop: notifyDesktop ?? this.notifyDesktop,
      notifyMobile: notifyMobile ?? this.notifyMobile,
      notifyAbout: notifyAbout ?? this.notifyAbout,
      notifyThreadReplies: notifyThreadReplies ?? this.notifyThreadReplies,
      notifySounds: notifySounds ?? this.notifySounds,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showReadReceipts: showReadReceipts ?? this.showReadReceipts,
      showTypingIndicators: showTypingIndicators ?? this.showTypingIndicators,
      locale: locale ?? this.locale,
      dateFormat: dateFormat ?? this.dateFormat,
      time24h: time24h ?? this.time24h,
      statusText: statusText ?? this.statusText,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      theme: theme ?? this.theme,
      fontSize: fontSize ?? this.fontSize,
      compactMode: compactMode ?? this.compactMode,
    );
  }

  /// Synced fields as a server-compatible map.
  Map<String, dynamic> toServerMap() {
    return {
      'notify_desktop': notifyDesktop,
      'notify_mobile': notifyMobile,
      'notify_about': notifyAbout,
      'notify_thread_replies': notifyThreadReplies,
      'notify_sounds': notifySounds,
      'dnd_enabled': dndEnabled,
      'dnd_start': dndStart,
      'dnd_end': dndEnd,
      'show_online_status': showOnlineStatus,
      'show_read_receipts': showReadReceipts,
      'show_typing_indicators': showTypingIndicators,
      'locale': locale,
      'date_format': dateFormat,
      'time_24h': time24h,
      'status_text': statusText,
      'status_emoji': statusEmoji,
    };
  }

  /// Merge server response into this settings object.
  void applyServerData(Map<String, dynamic> data) {
    if (data.containsKey('notify_desktop')) {
      notifyDesktop = data['notify_desktop'] as bool? ?? notifyDesktop;
    }
    if (data.containsKey('notify_mobile')) {
      notifyMobile = data['notify_mobile'] as bool? ?? notifyMobile;
    }
    if (data.containsKey('notify_about')) {
      notifyAbout = data['notify_about'] as String? ?? notifyAbout;
    }
    if (data.containsKey('notify_thread_replies')) {
      notifyThreadReplies =
          data['notify_thread_replies'] as bool? ?? notifyThreadReplies;
    }
    if (data.containsKey('notify_sounds')) {
      notifySounds = data['notify_sounds'] as bool? ?? notifySounds;
    }
    if (data.containsKey('dnd_enabled')) {
      dndEnabled = data['dnd_enabled'] as bool? ?? dndEnabled;
    }
    if (data.containsKey('dnd_start')) {
      dndStart = data['dnd_start'] as String?;
    }
    if (data.containsKey('dnd_end')) {
      dndEnd = data['dnd_end'] as String?;
    }
    if (data.containsKey('show_online_status')) {
      showOnlineStatus =
          data['show_online_status'] as bool? ?? showOnlineStatus;
    }
    if (data.containsKey('show_read_receipts')) {
      showReadReceipts =
          data['show_read_receipts'] as bool? ?? showReadReceipts;
    }
    if (data.containsKey('show_typing_indicators')) {
      showTypingIndicators =
          data['show_typing_indicators'] as bool? ?? showTypingIndicators;
    }
    if (data.containsKey('locale')) {
      locale = data['locale'] as String? ?? locale;
    }
    if (data.containsKey('date_format')) {
      dateFormat = data['date_format'] as String? ?? dateFormat;
    }
    if (data.containsKey('time_24h')) {
      time24h = data['time_24h'] as bool? ?? time24h;
    }
    if (data.containsKey('status_text')) {
      statusText = data['status_text'] as String?;
    }
    if (data.containsKey('status_emoji')) {
      statusEmoji = data['status_emoji'] as String?;
    }
  }
}

// ---------------------------------------------------------------------------
// SettingsNotifier
// ---------------------------------------------------------------------------

class SettingsNotifier extends StateNotifier<UserSettings> {
  SettingsNotifier(this._ref) : super(UserSettings()) {
    _loadLocalSettings();
    _loadFromServer();
  }

  final Ref _ref;
  Timer? _debounce;

  // SharedPreferences keys for local-only settings
  static const _keyTheme = 'settings_theme';
  static const _keyFontSize = 'settings_font_size';
  static const _keyCompactMode = 'settings_compact_mode';

  /// Load local-only settings from SharedPreferences.
  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_keyTheme) ?? 'dark';
      final fontSize = prefs.getDouble(_keyFontSize) ?? 14.0;
      final compactMode = prefs.getBool(_keyCompactMode) ?? false;

      state = state.copyWith(
        theme: theme,
        fontSize: fontSize,
        compactMode: compactMode,
      );
    } catch (_) {}
  }

  /// Persist local-only settings to SharedPreferences.
  Future<void> _persistLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTheme, state.theme);
      await prefs.setDouble(_keyFontSize, state.fontSize);
      await prefs.setBool(_keyCompactMode, state.compactMode);
    } catch (_) {}
  }

  /// Fetch settings from the server.
  Future<void> _loadFromServer() async {
    try {
      final api = _ref.read(msgrApiProvider);
      final data = await api.getSettings();
      state.applyServerData(data);
      // Re-emit state so listeners pick up changes
      state = state.copyWith();
    } catch (_) {
      // Server unavailable or not logged in — keep defaults
    }
  }

  /// Push current synced settings to the server (debounced).
  void _syncToServer() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final api = _ref.read(msgrApiProvider);
        await api.updateSettings(state.toServerMap());
      } catch (_) {
        // Silently fail — settings are still cached locally
      }
    });
  }

  /// Update one or more settings fields and sync.
  void update(UserSettings Function(UserSettings) updater) {
    state = updater(state);
    _syncToServer();
  }

  /// Update a local-only setting (theme, fontSize, compactMode).
  void updateLocal(UserSettings Function(UserSettings) updater) {
    state = updater(state);
    _persistLocalSettings();
  }

  /// Reload settings from the server (e.g. after login).
  Future<void> reload() async {
    await _loadLocalSettings();
    await _loadFromServer();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier(ref);
});

/// Convenience: resolved ThemeMode from settings.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final theme = ref.watch(settingsProvider).theme;
  switch (theme) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});

/// Whether desktop notifications are enabled.
final desktopNotificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).notifyDesktop;
});

/// Whether typing indicators should be sent.
final sendTypingIndicatorsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).showTypingIndicators;
});
