import 'dart:ui' show Brightness;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:core/ui/theme/msgr_color_tokens.dart';

/// Available color themes.
enum MsgrThemeName { neutral, teal, indigo, rose, amber, emerald }

/// Light/dark/system mode.
enum MsgrBrightness { light, dark, system }

class ThemeState {
  const ThemeState({
    this.theme = MsgrThemeName.teal,
    this.brightness = MsgrBrightness.dark,
  });

  final MsgrThemeName theme;
  final MsgrBrightness brightness;

  bool get isEffectivelyDark {
    if (brightness == MsgrBrightness.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return brightness == MsgrBrightness.dark;
  }

  MsgrColorTokens get colors {
    final dark = isEffectivelyDark;
    switch (theme) {
      case MsgrThemeName.neutral:
        return dark ? MsgrColorTokens.neutralDark : MsgrColorTokens.neutralLight;
      case MsgrThemeName.teal:
        return dark ? MsgrColorTokens.tealDark : MsgrColorTokens.tealLight;
      case MsgrThemeName.indigo:
        return dark ? MsgrColorTokens.indigoDark : MsgrColorTokens.indigoLight;
      case MsgrThemeName.rose:
        return dark ? MsgrColorTokens.roseDark : MsgrColorTokens.roseLight;
      case MsgrThemeName.amber:
        return dark ? MsgrColorTokens.amberDark : MsgrColorTokens.amberLight;
      case MsgrThemeName.emerald:
        return dark ? MsgrColorTokens.emeraldDark : MsgrColorTokens.emeraldLight;
    }
  }

  ThemeState copyWith({MsgrThemeName? theme, MsgrBrightness? brightness}) {
    return ThemeState(
      theme: theme ?? this.theme,
      brightness: brightness ?? this.brightness,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _load();
  }

  static const _themeKey = 'msgr_theme';
  static const _brightnessKey = 'msgr_brightness';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    final brightnessName = prefs.getString(_brightnessKey);

    state = ThemeState(
      theme: MsgrThemeName.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => MsgrThemeName.teal,
      ),
      brightness: MsgrBrightness.values.firstWhere(
        (b) => b.name == brightnessName,
        orElse: () => MsgrBrightness.dark,
      ),
    );
  }

  Future<void> setTheme(MsgrThemeName theme) async {
    state = state.copyWith(theme: theme);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_themeKey, theme.name);
  }

  Future<void> setBrightness(MsgrBrightness brightness) async {
    state = state.copyWith(brightness: brightness);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_brightnessKey, brightness.name);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
