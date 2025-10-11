import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'msgr_bubble_style.dart';

/// Describes a visual theme for rendering chat messages.
@immutable
class MsgrMessageTheme extends Equatable {
  /// Creates a message theme definition.
  const MsgrMessageTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.backgroundColor,
    this.isDark = false,
    MsgrBubbleStyle? incomingBubble,
    MsgrBubbleStyle? outgoingBubble,
    MsgrBubbleStyle? systemBubble,
    this.fontFamily,
    this.timestampTextColor,
    this.reactionBackgroundColor,
    this.avatarBackgroundColor,
    this.avatarBorderColor,
    this.bubbleSpacing = 8,
    this.showAvatars = true,
  })  : incomingBubble = incomingBubble ?? MsgrBubbleStyle.defaultIncoming,
        outgoingBubble = outgoingBubble ?? MsgrBubbleStyle.defaultOutgoing,
        systemBubble = systemBubble ??
            incomingBubble ??
            MsgrBubbleStyle.defaultSystem;

  /// Identifier for the theme.
  final String id;

  /// Human friendly name of the theme.
  final String name;

  /// Primary accent colour rendered for the message.
  final String primaryColor;

  /// Background colour used behind the chat conversation.
  final String backgroundColor;

  /// Whether the theme is optimised for dark mode.
  final bool isDark;

  /// Styling applied to incoming message bubbles.
  final MsgrBubbleStyle incomingBubble;

  /// Styling applied to outgoing message bubbles.
  final MsgrBubbleStyle outgoingBubble;

  /// Styling applied to system or status bubbles.
  final MsgrBubbleStyle systemBubble;

  /// Optional font family applied to message text.
  final String? fontFamily;

  /// Colour used to render timestamps.
  final String? timestampTextColor;

  /// Background colour used behind reactions and quick actions.
  final String? reactionBackgroundColor;

  /// Background colour applied to avatars.
  final String? avatarBackgroundColor;

  /// Border colour applied to avatars.
  final String? avatarBorderColor;

  /// Vertical spacing between consecutive bubbles in the timeline.
  final double bubbleSpacing;

  /// Whether avatars should be displayed alongside messages.
  final bool showAvatars;

  /// Default theme applied when no other preference is supplied.
  static const MsgrMessageTheme defaultTheme = MsgrMessageTheme(
    id: 'default',
    name: 'Default',
    primaryColor: '#2563EB',
    backgroundColor: '#F8FAFC',
  );

  /// Creates a copy with selectively overridden fields.
  MsgrMessageTheme copyWith({
    String? id,
    String? name,
    String? primaryColor,
    String? backgroundColor,
    bool? isDark,
    MsgrBubbleStyle? incomingBubble,
    MsgrBubbleStyle? outgoingBubble,
    MsgrBubbleStyle? systemBubble,
    String? fontFamily,
    String? timestampTextColor,
    String? reactionBackgroundColor,
    String? avatarBackgroundColor,
    String? avatarBorderColor,
    double? bubbleSpacing,
    bool? showAvatars,
  }) {
    return MsgrMessageTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isDark: isDark ?? this.isDark,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      systemBubble: systemBubble ?? this.systemBubble,
      fontFamily: fontFamily ?? this.fontFamily,
      timestampTextColor: timestampTextColor ?? this.timestampTextColor,
      reactionBackgroundColor:
          reactionBackgroundColor ?? this.reactionBackgroundColor,
      avatarBackgroundColor: avatarBackgroundColor ?? this.avatarBackgroundColor,
      avatarBorderColor: avatarBorderColor ?? this.avatarBorderColor,
      bubbleSpacing: bubbleSpacing ?? this.bubbleSpacing,
      showAvatars: showAvatars ?? this.showAvatars,
    );
  }

  /// Serialises the theme into a JSON compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'primaryColor': primaryColor,
      'backgroundColor': backgroundColor,
      'isDark': isDark,
      'incomingBubble': incomingBubble.toMap(),
      'outgoingBubble': outgoingBubble.toMap(),
      'systemBubble': systemBubble.toMap(),
      'fontFamily': fontFamily,
      'timestampTextColor': timestampTextColor,
      'reactionBackgroundColor': reactionBackgroundColor,
      'avatarBackgroundColor': avatarBackgroundColor,
      'avatarBorderColor': avatarBorderColor,
      'bubbleSpacing': bubbleSpacing,
      'showAvatars': showAvatars,
    };
  }

  /// Recreates a theme from a JSON compatible map.
  factory MsgrMessageTheme.fromMap(Map<String, dynamic> map) {
    final incoming = map['incomingBubble'];
    final outgoing = map['outgoingBubble'];
    final system = map['systemBubble'];
    return MsgrMessageTheme(
      id: map['id'] as String? ?? 'default',
      name: map['name'] as String? ?? 'Default',
      primaryColor: map['primaryColor'] as String? ?? '#2563EB',
      backgroundColor: map['backgroundColor'] as String? ?? '#F8FAFC',
      isDark: map['isDark'] as bool? ?? false,
      incomingBubble: incoming is Map<String, dynamic>
          ? MsgrBubbleStyle.fromMap(incoming)
          : null,
      outgoingBubble: outgoing is Map<String, dynamic>
          ? MsgrBubbleStyle.fromMap(outgoing)
          : null,
      systemBubble: system is Map<String, dynamic>
          ? MsgrBubbleStyle.fromMap(system)
          : null,
      fontFamily: map['fontFamily'] as String?,
      timestampTextColor: map['timestampTextColor'] as String?,
      reactionBackgroundColor: map['reactionBackgroundColor'] as String?,
      avatarBackgroundColor: map['avatarBackgroundColor'] as String?,
      avatarBorderColor: map['avatarBorderColor'] as String?,
      bubbleSpacing: (map['bubbleSpacing'] as num?)?.toDouble() ?? 8,
      showAvatars: map['showAvatars'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        primaryColor,
        backgroundColor,
        isDark,
        incomingBubble,
        outgoingBubble,
        systemBubble,
        fontFamily,
        timestampTextColor,
        reactionBackgroundColor,
        avatarBackgroundColor,
        avatarBorderColor,
        bubbleSpacing,
        showAvatars,
      ];
}
