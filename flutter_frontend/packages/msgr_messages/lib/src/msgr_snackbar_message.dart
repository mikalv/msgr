import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Describes the semantic intent of a snackbar notification.
enum MsgrSnackbarIntent {
  /// Communicates that an operation completed successfully.
  success,

  /// Indicates that something failed and requires user attention.
  error,

  /// Highlights information that might need confirmation or awareness.
  warning,

  /// Shares neutral context, updates or guidance.
  info,

  /// Presents contextual help or onboarding style hints.
  help,
}

/// Immutable model that represents a snackbar notification to be rendered.
@immutable
class MsgrSnackbarMessage extends Equatable {
  /// Creates a snackbar description.
  const MsgrSnackbarMessage({
    required this.id,
    required this.title,
    this.body,
    this.intent = MsgrSnackbarIntent.info,
    Duration? duration,
    this.actionLabel,
    Map<String, dynamic>? metadata,
  })  : duration = duration ?? const Duration(seconds: 4),
        metadata = metadata == null
            ? const {}
            : Map.unmodifiable(Map.of(metadata));

  /// Unique identifier for the snackbar, useful when tracking dismissals.
  final String id;

  /// Primary heading rendered with emphasis.
  final String title;

  /// Optional supporting body copy shown under the title.
  final String? body;

  /// Semantic intent that influences colours and icons in the UI.
  final MsgrSnackbarIntent intent;

  /// Duration the snackbar should stay visible.
  final Duration duration;

  /// Optional label rendered for an action button.
  final String? actionLabel;

  /// Free-form metadata that consumers can leverage for callbacks.
  final Map<String, dynamic> metadata;

  /// Whether the snackbar exposes an action to the user.
  bool get hasAction => (actionLabel ?? '').isNotEmpty;

  /// Creates a modified copy of this snackbar message.
  MsgrSnackbarMessage copyWith({
    String? id,
    String? title,
    String? body,
    MsgrSnackbarIntent? intent,
    Duration? duration,
    String? actionLabel,
    Map<String, dynamic>? metadata,
  }) {
    return MsgrSnackbarMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      intent: intent ?? this.intent,
      duration: duration ?? this.duration,
      actionLabel: actionLabel ?? this.actionLabel,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Serialises this snackbar into a JSON friendly map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'intent': intent.name,
      'durationMilliseconds': duration.inMilliseconds,
      'actionLabel': actionLabel,
      'metadata': metadata,
    };
  }

  /// Recreates a snackbar from its serialised representation.
  factory MsgrSnackbarMessage.fromMap(Map<String, dynamic> map) {
    return MsgrSnackbarMessage(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String?,
      intent: _intentFrom(map['intent']),
      duration: Duration(
        milliseconds: (map['durationMilliseconds'] as num?)?.toInt() ??
            (map['duration_ms'] as num?)?.toInt() ??
            const Duration(seconds: 4).inMilliseconds,
      ),
      actionLabel: map['actionLabel'] as String? ?? map['action_label'] as String?,
      metadata: _readMetadata(map['metadata']),
    );
  }

  static MsgrSnackbarIntent _intentFrom(dynamic value) {
    if (value is MsgrSnackbarIntent) {
      return value;
    }
    final name = value?.toString().toLowerCase();
    switch (name) {
      case 'success':
        return MsgrSnackbarIntent.success;
      case 'error':
        return MsgrSnackbarIntent.error;
      case 'warning':
        return MsgrSnackbarIntent.warning;
      case 'help':
        return MsgrSnackbarIntent.help;
      default:
        return MsgrSnackbarIntent.info;
    }
  }

  static Map<String, dynamic> _readMetadata(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map.unmodifiable(Map.of(value));
    }
    return const {};
  }

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        intent,
        duration,
        actionLabel,
        metadata,
      ];
}
