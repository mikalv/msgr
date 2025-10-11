import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/models/base.dart';
import 'package:meta/meta.dart';

mixin AttachmentType {
  /// Backend specified types.
  static const image = 'image';
  static const file = 'file';
  static const giphy = 'giphy';
  static const video = 'video';
  static const audio = 'audio';
  static const voiceRecording = 'voiceRecording';

  /// Application custom types.
  static const urlPreview = 'url_preview';
}

@immutable
class Attachment extends BaseModel {
  final String? _type;
  final String mediaUrl;
  final MMessage message;

  Attachment({
    String? id,
    String? type,
    required this.mediaUrl,
    required this.message,
  }) : _type = type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attachment &&
        other.id == id &&
        other._type == _type &&
        other.mediaUrl == mediaUrl &&
        other.message == message;
  }

  @override
  int get hashCode =>
      id.hashCode ^ _type.hashCode ^ mediaUrl.hashCode ^ message.hashCode;

  @override
  String toString() {
    return 'Attachment{id: $id, type: $_type, mediaUrl: $mediaUrl, messageID: ${message.id}}';
  }
}
