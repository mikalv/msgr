import 'package:messngr/features/chat/media/chat_media_attachment.dart';

class ComposerSubmission {
  const ComposerSubmission({
    required this.text,
    required this.attachments,
  });

  final String text;
  final List<ChatMediaAttachment> attachments;

  bool get hasText => text.trim().isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
}
