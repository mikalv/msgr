import 'package:flutter/material.dart';
import 'package:msgr_messages/msgr_messages.dart';

/// Styled snackbar inspired by high-end messengers with intent aware visuals.
class MsgrSnackBar extends SnackBar {
  MsgrSnackBar({
    super.key,
    required MsgrSnackbarMessage message,
    MsgrSnackBarThemeData? theme,
    VoidCallback? onAction,
  }) : this._(
          message: message,
          theme: MsgrSnackBarThemeData.standard().merge(theme),
          onAction: onAction,
        );

  MsgrSnackBar._({
    required MsgrSnackbarMessage message,
    required MsgrSnackBarThemeData theme,
    VoidCallback? onAction,
  }) : super(
          elevation: 0,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          behavior: SnackBarBehavior.floating,
          margin: theme.margin,
          duration: message.duration,
          content: _MsgrSnackBarContent(
            message: message,
            theme: theme,
            onAction: onAction,
          ),
        );

  /// Shows the snackbar using the [ScaffoldMessenger] of the given [context].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context,
    MsgrSnackbarMessage message, {
    MsgrSnackBarThemeData? theme,
    VoidCallback? onAction,
  }) {
    return ScaffoldMessenger.of(context).showSnackBar(
      MsgrSnackBar(
        message: message,
        theme: theme,
        onAction: onAction,
      ),
    );
  }
}

class _MsgrSnackBarContent extends StatelessWidget {
  const _MsgrSnackBarContent({
    required this.message,
    required this.theme,
    this.onAction,
  });

  final MsgrSnackbarMessage message;
  final MsgrSnackBarThemeData theme;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final intentTheme = theme.resolveIntent(message.intent);
    final titleStyle = theme.titleStyle ??
        Theme.of(context).textTheme.titleMedium?.copyWith(
              color: intentTheme.foregroundColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(
          color: intentTheme.foregroundColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        );
    final bodyStyle = theme.descriptionStyle ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: intentTheme.foregroundColor.withOpacity(0.9),
            ) ??
        TextStyle(
          color: intentTheme.foregroundColor.withOpacity(0.9),
          fontSize: 13,
        );
    final actionStyle = theme.actionStyle ??
        Theme.of(context).textTheme.labelLarge?.copyWith(
              color: intentTheme.actionForegroundColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(
          color: intentTheme.actionForegroundColor,
          fontWeight: FontWeight.w600,
        );

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: theme.borderRadius,
        boxShadow: theme.shadows,
      ),
      child: ClipRRect(
        borderRadius: theme.borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: intentTheme.backgroundGradient,
                  borderRadius: theme.borderRadius,
                ),
              ),
            ),
            Padding(
              padding: theme.padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: intentTheme.iconBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      intentTheme.icon,
                      color: intentTheme.foregroundColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.title,
                          style: titleStyle,
                        ),
                        if (message.body != null && message.body!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              message.body!,
                              style: bodyStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (message.hasAction)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: intentTheme.actionForegroundColor,
                        ),
                        child: Text(
                          message.actionLabel!,
                          style: actionStyle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme configuration for [MsgrSnackBar].
class MsgrSnackBarThemeData {
  MsgrSnackBarThemeData({
    required this.margin,
    required this.padding,
    required this.borderRadius,
    required List<BoxShadow> shadows,
    this.titleStyle,
    this.descriptionStyle,
    this.actionStyle,
    required this.surfaceColor,
    required Map<MsgrSnackbarIntent, MsgrSnackBarIntentTheme> intents,
  })  : shadows = List.unmodifiable(shadows),
        intents = Map.unmodifiable(intents);

  /// Distance between the snackbar and the screen edges.
  final EdgeInsets margin;

  /// Internal padding surrounding the content.
  final EdgeInsets padding;

  /// Border radius applied to the snackbar container.
  final BorderRadius borderRadius;

  /// Shadow definition for the snackbar.
  final List<BoxShadow> shadows;

  /// Optional override for the title text style.
  final TextStyle? titleStyle;

  /// Optional override for the body text style.
  final TextStyle? descriptionStyle;

  /// Optional override for the action button text style.
  final TextStyle? actionStyle;

  /// Base colour rendered beneath the gradient.
  final Color surfaceColor;

  /// Mapping between intent and the colours/icons used.
  final Map<MsgrSnackbarIntent, MsgrSnackBarIntentTheme> intents;

  /// Creates the opinionated default theme used by the snackbars.
  factory MsgrSnackBarThemeData.standard() {
    return MsgrSnackBarThemeData(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      shadows: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 16),
        ),
      ],
      surfaceColor: const Color(0xFF111827),
      intents: const {
        MsgrSnackbarIntent.success: MsgrSnackBarIntentTheme(
          icon: Icons.check_circle_rounded,
          foregroundColor: Colors.white,
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFF166534),
              Color(0xFF22C55E),
              Color(0x00111827),
            ],
          ),
        ),
        MsgrSnackbarIntent.error: MsgrSnackBarIntentTheme(
          icon: Icons.error_rounded,
          foregroundColor: Colors.white,
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFF7F1D1D),
              Color(0xFFEF4444),
              Color(0x00111827),
            ],
          ),
        ),
        MsgrSnackbarIntent.warning: MsgrSnackBarIntentTheme(
          icon: Icons.warning_rounded,
          foregroundColor: Colors.white,
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFFB45309),
              Color(0xFFF97316),
              Color(0x00111827),
            ],
          ),
        ),
        MsgrSnackbarIntent.info: MsgrSnackBarIntentTheme(
          icon: Icons.info_rounded,
          foregroundColor: Colors.white,
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFF1D4ED8),
              Color(0xFF3B82F6),
              Color(0x00111827),
            ],
          ),
        ),
        MsgrSnackbarIntent.help: MsgrSnackBarIntentTheme(
          icon: Icons.help_rounded,
          foregroundColor: Colors.white,
          backgroundGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.55, 1.0],
            colors: [
              Color(0xFF6D28D9),
              Color(0xFFA855F7),
              Color(0x00111827),
            ],
          ),
        ),
      },
    );
  }

  /// Returns a copy with selectively overridden properties.
  MsgrSnackBarThemeData copyWith({
    EdgeInsets? margin,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
    List<BoxShadow>? shadows,
    TextStyle? titleStyle,
    TextStyle? descriptionStyle,
    TextStyle? actionStyle,
    Color? surfaceColor,
    Map<MsgrSnackbarIntent, MsgrSnackBarIntentTheme>? intentThemes,
  }) {
    return MsgrSnackBarThemeData(
      margin: margin ?? this.margin,
      padding: padding ?? this.padding,
      borderRadius: borderRadius ?? this.borderRadius,
      shadows: shadows == null ? this.shadows : List.unmodifiable(shadows),
      titleStyle: titleStyle ?? this.titleStyle,
      descriptionStyle: descriptionStyle ?? this.descriptionStyle,
      actionStyle: actionStyle ?? this.actionStyle,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      intents: intentThemes == null
          ? intents
          : Map.unmodifiable({
              ...intents,
              ...intentThemes,
            }),
    );
  }

  /// Combines this theme with [other], letting [other] override the values.
  MsgrSnackBarThemeData merge(MsgrSnackBarThemeData? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      margin: other.margin,
      padding: other.padding,
      borderRadius: other.borderRadius,
      shadows: other.shadows,
      titleStyle: other.titleStyle,
      descriptionStyle: other.descriptionStyle,
      actionStyle: other.actionStyle,
      surfaceColor: other.surfaceColor,
      intentThemes: other.intents,
    );
  }

  /// Resolves the theme for the provided [intent].
  MsgrSnackBarIntentTheme resolveIntent(MsgrSnackbarIntent intent) {
    return intents[intent] ?? intents[MsgrSnackbarIntent.info]!;
  }
}

/// Theme fragment describing iconography and colours for a snackbar intent.
class MsgrSnackBarIntentTheme {
  const MsgrSnackBarIntentTheme({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundGradient,
    this.iconBackgroundColor = const Color(0x33FFFFFF),
    Color? actionForegroundColor,
  }) : actionForegroundColor = actionForegroundColor ?? foregroundColor;

  /// Icon rendered inside the intent badge.
  final IconData icon;

  /// Primary colour used for text and icons.
  final Color foregroundColor;

  /// Gradient drawn behind the snackbar content.
  final Gradient backgroundGradient;

  /// Background colour used for the circular icon container.
  final Color iconBackgroundColor;

  /// Colour used for the action label.
  final Color actionForegroundColor;

  /// Creates a modified copy of this intent theme.
  MsgrSnackBarIntentTheme copyWith({
    IconData? icon,
    Color? foregroundColor,
    Gradient? backgroundGradient,
    Color? iconBackgroundColor,
    Color? actionForegroundColor,
  }) {
    return MsgrSnackBarIntentTheme(
      icon: icon ?? this.icon,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      actionForegroundColor:
          actionForegroundColor ?? this.actionForegroundColor,
    );
  }
}

/// Convenience helpers for showing the snackbar from a [ScaffoldMessenger].
extension MsgrSnackBarMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMsgrSnackBar(
    MsgrSnackbarMessage message, {
    MsgrSnackBarThemeData? theme,
    VoidCallback? onAction,
  }) {
    return showSnackBar(
      MsgrSnackBar(
        message: message,
        theme: theme,
        onAction: onAction,
      ),
    );
  }
}

/// Convenience extension on [BuildContext] for the snackbar helper.
extension MsgrSnackBarContext on BuildContext {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMsgrSnackBar(
    MsgrSnackbarMessage message, {
    MsgrSnackBarThemeData? theme,
    VoidCallback? onAction,
  }) {
    return ScaffoldMessenger.of(this).showMsgrSnackBar(
      message,
      theme: theme,
      onAction: onAction,
    );
  }
}
