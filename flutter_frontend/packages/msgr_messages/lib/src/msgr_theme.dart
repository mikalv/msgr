import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

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
  });

  /// Identifier for the theme.
  final String id;

  /// Human friendly name of the theme.
  final String name;

  /// Primary accent colour rendered for the message.
  final String primaryColor;

  /// Background colour used in the chat bubble.
  final String backgroundColor;

  /// Whether the theme is optimised for dark mode.
  final bool isDark;

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
  }) {
    return MsgrMessageTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      isDark: isDark ?? this.isDark,
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
    };
  }

  /// Recreates a theme from a JSON compatible map.
  factory MsgrMessageTheme.fromMap(Map<String, dynamic> map) {
    return MsgrMessageTheme(
      id: map['id'] as String? ?? 'default',
      name: map['name'] as String? ?? 'Default',
      primaryColor: map['primaryColor'] as String? ?? '#2563EB',
      backgroundColor: map['backgroundColor'] as String? ?? '#F8FAFC',
      isDark: map['isDark'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name, primaryColor, backgroundColor, isDark];
}
