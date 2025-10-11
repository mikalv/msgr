import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Visual styling applied to an individual chat bubble.
@immutable
class MsgrBubbleStyle extends Equatable {
  /// Creates a bubble style description.
  const MsgrBubbleStyle({
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.borderWidth = 0,
    this.cornerRadius = 18,
    this.linkColor,
  });

  /// Background fill colour of the bubble.
  final String backgroundColor;

  /// Default text colour rendered inside the bubble.
  final String textColor;

  /// Optional border colour used for outlines.
  final String? borderColor;

  /// Width of the optional border in logical pixels.
  final double borderWidth;

  /// Rounded corner radius applied to the bubble.
  final double cornerRadius;

  /// Colour applied to interactive links rendered inside the bubble.
  final String? linkColor;

  /// Baseline bubble style for incoming messages.
  static const MsgrBubbleStyle defaultIncoming = MsgrBubbleStyle(
    backgroundColor: '#FFFFFF',
    textColor: '#0F172A',
    borderColor: '#E2E8F0',
    borderWidth: 1,
    cornerRadius: 18,
    linkColor: '#2563EB',
  );

  /// Baseline bubble style for outgoing messages.
  static const MsgrBubbleStyle defaultOutgoing = MsgrBubbleStyle(
    backgroundColor: '#2563EB',
    textColor: '#FFFFFF',
    cornerRadius: 18,
    linkColor: '#BFDBFE',
  );

  /// Baseline bubble style for system messages.
  static const MsgrBubbleStyle defaultSystem = MsgrBubbleStyle(
    backgroundColor: '#F1F5F9',
    textColor: '#475569',
    cornerRadius: 12,
  );

  /// Creates a copy with selectively overridden fields.
  MsgrBubbleStyle copyWith({
    String? backgroundColor,
    String? textColor,
    String? borderColor,
    double? borderWidth,
    double? cornerRadius,
    String? linkColor,
  }) {
    return MsgrBubbleStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      linkColor: linkColor ?? this.linkColor,
    );
  }

  /// Serialises the bubble style into a JSON friendly map.
  Map<String, dynamic> toMap() {
    return {
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
      'cornerRadius': cornerRadius,
      'linkColor': linkColor,
    };
  }

  /// Recreates a bubble style from a JSON compatible map.
  factory MsgrBubbleStyle.fromMap(Map<String, dynamic> map) {
    return MsgrBubbleStyle(
      backgroundColor: map['backgroundColor'] as String? ?? '#FFFFFF',
      textColor: map['textColor'] as String? ?? '#0F172A',
      borderColor: map['borderColor'] as String?,
      borderWidth: (map['borderWidth'] as num?)?.toDouble() ?? 0,
      cornerRadius: (map['cornerRadius'] as num?)?.toDouble() ?? 18,
      linkColor: map['linkColor'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        backgroundColor,
        textColor,
        borderColor,
        borderWidth,
        cornerRadius,
        linkColor,
      ];
}
