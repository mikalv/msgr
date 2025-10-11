import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'msgr_bubble_style.dart';
import 'msgr_message.dart';
import 'msgr_theme.dart';

/// Registry of available chat themes that can be applied to messages.
@immutable
class MsgrThemePalette extends Equatable {
  /// Creates a palette with the provided [themes] and optional [fallback].
  MsgrThemePalette({
    MsgrMessageTheme? fallback,
    Iterable<MsgrMessageTheme> themes = const [],
  })  : fallback = fallback ?? MsgrMessageTheme.defaultTheme,
        _themes = Map.unmodifiable({
          for (final theme in themes) theme.id: theme,
          (fallback ?? MsgrMessageTheme.defaultTheme).id:
              fallback ?? MsgrMessageTheme.defaultTheme,
        });

  /// Theme returned when an unknown identifier is requested.
  final MsgrMessageTheme fallback;

  final Map<String, MsgrMessageTheme> _themes;

  /// All available theme entries.
  List<MsgrMessageTheme> get themes =>
      _themes.values.toList(growable: false);

  /// Resolves a [MsgrMessageTheme] by [id], using [fallback] when missing.
  MsgrMessageTheme resolve([String? id]) {
    if (id == null || id.isEmpty) {
      return fallback;
    }
    return _themes[id] ?? fallback;
  }

  /// Returns a new palette containing the provided [theme].
  MsgrThemePalette register(MsgrMessageTheme theme) {
    return MsgrThemePalette(
      fallback: fallback,
      themes: [..._themes.values, theme],
    );
  }

  /// Combines the entries from this palette with [other].
  MsgrThemePalette merge(MsgrThemePalette other) {
    return MsgrThemePalette(
      fallback: other.fallback,
      themes: [..._themes.values, ...other._themes.values],
    );
  }

  /// Applies a resolved theme to the given [message].
  MsgrMessage apply(MsgrMessage message, {String? themeId}) {
    final resolved = resolve(themeId ?? message.theme.id);
    return message.themed(resolved);
  }

  /// Provides a curated palette inspired by high-end chat applications.
  static MsgrThemePalette standard() {
    const aurora = MsgrMessageTheme(
      id: 'aurora',
      name: 'Aurora Borealis',
      primaryColor: '#38BDF8',
      backgroundColor: '#0F172A',
      isDark: true,
      incomingBubble: MsgrBubbleStyle(
        backgroundColor: '#1E293B',
        textColor: '#E2E8F0',
        borderColor: '#38BDF8',
        borderWidth: 1,
        cornerRadius: 20,
        linkColor: '#38BDF8',
      ),
      outgoingBubble: MsgrBubbleStyle(
        backgroundColor: '#38BDF8',
        textColor: '#0F172A',
        cornerRadius: 20,
        linkColor: '#0EA5E9',
      ),
      systemBubble: MsgrBubbleStyle(
        backgroundColor: '#0F172A',
        textColor: '#E0F2FE',
        borderColor: '#38BDF8',
        borderWidth: 1,
        cornerRadius: 14,
      ),
      timestampTextColor: '#94A3B8',
      reactionBackgroundColor: '#1E293B',
      avatarBorderColor: '#38BDF8',
      avatarBackgroundColor: '#0F172A',
    );

    const sunrise = MsgrMessageTheme(
      id: 'sunrise',
      name: 'Sunrise Meadow',
      primaryColor: '#F97316',
      backgroundColor: '#FFFBEB',
      incomingBubble: MsgrBubbleStyle(
        backgroundColor: '#FEF3C7',
        textColor: '#92400E',
        borderColor: '#FDBA74',
        borderWidth: 1,
        cornerRadius: 16,
        linkColor: '#F97316',
      ),
      outgoingBubble: MsgrBubbleStyle(
        backgroundColor: '#F97316',
        textColor: '#FFF7ED',
        cornerRadius: 16,
        linkColor: '#FED7AA',
      ),
      systemBubble: MsgrBubbleStyle(
        backgroundColor: '#FFEDD5',
        textColor: '#78350F',
        cornerRadius: 12,
      ),
      timestampTextColor: '#F59E0B',
      reactionBackgroundColor: '#FED7AA',
      avatarBackgroundColor: '#FFEDD5',
      avatarBorderColor: '#F97316',
    );

    const midnight = MsgrMessageTheme(
      id: 'midnight',
      name: 'Midnight Neon',
      primaryColor: '#6366F1',
      backgroundColor: '#0F172A',
      isDark: true,
      incomingBubble: MsgrBubbleStyle(
        backgroundColor: '#1E1B4B',
        textColor: '#E0E7FF',
        borderColor: '#6366F1',
        borderWidth: 1,
        cornerRadius: 22,
        linkColor: '#A5B4FC',
      ),
      outgoingBubble: MsgrBubbleStyle(
        backgroundColor: '#6366F1',
        textColor: '#E0E7FF',
        cornerRadius: 22,
        linkColor: '#C7D2FE',
      ),
      systemBubble: MsgrBubbleStyle(
        backgroundColor: '#312E81',
        textColor: '#C7D2FE',
        cornerRadius: 14,
      ),
      fontFamily: 'SpaceGrotesk',
      timestampTextColor: '#818CF8',
      reactionBackgroundColor: '#1E1B4B',
      avatarBackgroundColor: '#312E81',
      avatarBorderColor: '#6366F1',
    );

    return MsgrThemePalette(
      fallback: MsgrMessageTheme.defaultTheme,
      themes: const [
        MsgrMessageTheme.defaultTheme,
        aurora,
        sunrise,
        midnight,
      ],
    );
  }

  @override
  List<Object?> get props => [
        fallback,
        ..._themes.entries.map((entry) => MapEntry(entry.key, entry.value)),
      ];
}
