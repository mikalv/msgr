import 'package:flutter/material.dart';
import 'package:msgr_messages/msgr_messages.dart';

/// Describes the look and feel for a specific participant in the chat.
class ChatProfileThemeData {
  const ChatProfileThemeData({
    required this.profileId,
    required this.accentColor,
    required this.bubbleGradient,
    required this.textStyle,
    required this.presenceColor,
  });

  final String profileId;
  final Color accentColor;
  final Gradient bubbleGradient;
  final TextStyle textStyle;
  final Color presenceColor;

  ChatProfileThemeData merge(ChatProfileThemeData other) {
    return ChatProfileThemeData(
      profileId: other.profileId.isNotEmpty ? other.profileId : profileId,
      accentColor: other.accentColor,
      bubbleGradient: other.bubbleGradient,
      textStyle: other.textStyle,
      presenceColor: other.presenceColor,
    );
  }

  static ChatProfileThemeData resolve(
    String profileId, {
    required ThemeData theme,
    MsgrMessageTheme? messageTheme,
  }) {
    final baseBubble = messageTheme?.bubbleColor != null
        ? Color(messageTheme!.bubbleColor!)
        : theme.colorScheme.primaryContainer;
    final baseAccent = messageTheme?.highlightColor != null
        ? Color(messageTheme!.highlightColor!)
        : theme.colorScheme.primary;

    final textColor = messageTheme?.textColor != null
        ? Color(messageTheme!.textColor!)
        : theme.colorScheme.onPrimaryContainer;

    final gradient = LinearGradient(
      colors: [
        baseBubble.withOpacity(0.92),
        baseBubble.withOpacity(0.82),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return ChatProfileThemeData(
      profileId: profileId,
      accentColor: baseAccent,
      bubbleGradient: gradient,
      textStyle: theme.textTheme.bodyMedium!.copyWith(
        color: textColor,
        height: 1.35,
      ),
      presenceColor: messageTheme?.presenceColor != null
          ? Color(messageTheme!.presenceColor!)
          : baseAccent,
    );
  }
}

/// Provides the profile theme registry to descendant widgets.
class ChatProfileTheme extends InheritedWidget {
  const ChatProfileTheme({
    super.key,
    required super.child,
    required this.themes,
    required this.fallback,
  });

  final Map<String, ChatProfileThemeData> themes;
  final ChatProfileThemeData fallback;

  static ChatProfileThemeData of(BuildContext context, String profileId) {
    final scope = context.dependOnInheritedWidgetOfExactType<ChatProfileTheme>();
    if (scope == null) {
      throw FlutterError(
        'ChatProfileTheme.of() called with a context that does not contain a ChatProfileTheme.',
      );
    }
    return scope.themes[profileId] ?? scope.fallback;
  }

  @override
  bool updateShouldNotify(ChatProfileTheme oldWidget) {
    if (fallback != oldWidget.fallback) {
      return true;
    }
    if (themes.length != oldWidget.themes.length) {
      return true;
    }
    for (final entry in themes.entries) {
      final other = oldWidget.themes[entry.key];
      if (other == null || other != entry.value) {
        return true;
      }
    }
    return false;
  }
}
