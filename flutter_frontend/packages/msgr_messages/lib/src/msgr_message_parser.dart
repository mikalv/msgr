import 'msgr_code_message.dart';
import 'msgr_markdown_message.dart';
import 'msgr_message.dart';
import 'msgr_location_message.dart';
import 'msgr_system_message.dart';
import 'msgr_text_message.dart';
import 'msgr_image_message.dart';
import 'msgr_video_message.dart';
import 'msgr_audio_message.dart';
import 'msgr_file_message.dart';

/// Creates strongly typed message instances from dynamic map payloads.
MsgrMessage msgrMessageFromMap(Map<String, dynamic> map) {
  final type = map['type'];
  if (type is! String) {
    throw const FormatException('Message type is missing.');
  }
  final kind = MsgrMessageKind.values.firstWhere(
    (value) => value.name == type,
    orElse: () => throw FormatException('Unsupported message type: $type'),
  );
  switch (kind) {
    case MsgrMessageKind.text:
      return MsgrTextMessage.fromMap(map);
    case MsgrMessageKind.markdown:
      return MsgrMarkdownMessage.fromMap(map);
    case MsgrMessageKind.code:
      return MsgrCodeMessage.fromMap(map);
    case MsgrMessageKind.system:
      return MsgrSystemMessage.fromMap(map);
    case MsgrMessageKind.image:
    case MsgrMessageKind.thumbnail:
      return MsgrImageMessage.fromMap(map);
    case MsgrMessageKind.video:
      return MsgrVideoMessage.fromMap(map);
    case MsgrMessageKind.audio:
    case MsgrMessageKind.voice:
      return MsgrAudioMessage.fromMap(map);
    case MsgrMessageKind.file:
      return MsgrFileMessage.fromMap(map);
    case MsgrMessageKind.location:
      return MsgrLocationMessage.fromMap(map);
  }
}
