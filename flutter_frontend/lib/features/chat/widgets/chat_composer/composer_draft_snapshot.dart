part of 'package:messngr/features/chat/widgets/chat_composer.dart';

class ChatDraftSnapshot {
  ChatDraftSnapshot({
    required this.text,
    required this.attachments,
    required this.updatedAt,
    this.voiceNote,
  });

  factory ChatDraftSnapshot.fromComposerValue(ChatComposerValue value) {
    return ChatDraftSnapshot(
      text: value.text,
      attachments: value.attachments
          .map(DraftAttachmentSnapshot.fromAttachment)
          .toList(growable: false),
      voiceNote: value.voiceNote == null
          ? null
          : DraftVoiceNoteSnapshot.fromVoiceNote(value.voiceNote!),
      updatedAt: DateTime.now(),
    );
  }

  factory ChatDraftSnapshot.fromJson(Map<String, dynamic> json) {
    final updatedRaw = json['updatedAt'];
    return ChatDraftSnapshot(
      text: json['text'] as String? ?? '',
      attachments: [
        for (final entry in json['attachments'] as List<dynamic>? ?? const [])
          if (entry is Map<String, dynamic>)
            DraftAttachmentSnapshot.fromJson(entry)
      ],
      voiceNote: json['voiceNote'] is Map<String, dynamic>
          ? DraftVoiceNoteSnapshot.fromJson(
              json['voiceNote'] as Map<String, dynamic>,
            )
          : null,
      updatedAt: updatedRaw is String
          ? DateTime.tryParse(updatedRaw) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String text;
  final List<DraftAttachmentSnapshot> attachments;
  final DraftVoiceNoteSnapshot? voiceNote;
  final DateTime updatedAt;

  bool get isEmpty =>
      text.trim().isEmpty && attachments.isEmpty && voiceNote == null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'attachments': [
        for (final attachment in attachments) attachment.toJson(),
      ],
      if (voiceNote != null) 'voiceNote': voiceNote!.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ChatComposerValue applyTo(ChatComposerValue base) {
    return base.copyWith(
      text: text,
      attachments: [
        for (final attachment in attachments) attachment.toAttachment(),
      ],
      voiceNote: voiceNote?.toVoiceNote(),
      clearMentions: true,
      autosaveStatus: ComposerAutosaveStatus.saved,
      lastAutosave: updatedAt,
      sendState: ComposerSendState.idle,
      clearCommand: true,
      error: null,
    );
  }
}

class DraftAttachmentSnapshot {
  DraftAttachmentSnapshot({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    this.path,
    this.bytes,
  });

  factory DraftAttachmentSnapshot.fromAttachment(ComposerAttachment attachment) {
    return DraftAttachmentSnapshot(
      id: attachment.id,
      name: attachment.name,
      size: attachment.size,
      mimeType: attachment.mimeType,
      path: attachment.path,
      bytes: attachment.bytes,
    );
  }

  factory DraftAttachmentSnapshot.fromJson(Map<String, dynamic> json) {
    final encoded = json['bytes'];
    Uint8List? decodedBytes;
    if (encoded is String && encoded.isNotEmpty) {
      decodedBytes = Uint8List.fromList(base64Decode(encoded));
    }
    return DraftAttachmentSnapshot(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ukjent-fil',
      size: json['size'] as int? ?? decodedBytes?.length ?? 0,
      mimeType: json['mimeType'] as String?,
      path: json['path'] as String?,
      bytes: decodedBytes,
    );
  }

  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final String? path;
  final Uint8List? bytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'size': size,
      if (mimeType != null) 'mimeType': mimeType,
      if (path != null) 'path': path,
      if (bytes != null && bytes!.isNotEmpty)
        'bytes': base64Encode(bytes!),
    };
  }

  ComposerAttachment toAttachment() {
    return ComposerAttachment(
      id: id,
      name: name,
      size: size,
      mimeType: mimeType,
      path: path,
      bytes: bytes,
    );
  }
}

class DraftVoiceNoteSnapshot {
  DraftVoiceNoteSnapshot({
    required this.duration,
    required this.bytes,
  });

  factory DraftVoiceNoteSnapshot.fromVoiceNote(ComposerVoiceNote note) {
    return DraftVoiceNoteSnapshot(
      duration: note.duration,
      bytes: note.bytes,
    );
  }

  factory DraftVoiceNoteSnapshot.fromJson(Map<String, dynamic> json) {
    final encoded = json['bytes'];
    final data = encoded is String && encoded.isNotEmpty
        ? Uint8List.fromList(base64Decode(encoded))
        : Uint8List(0);
    return DraftVoiceNoteSnapshot(
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      bytes: data,
    );
  }

  final Duration duration;
  final Uint8List bytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'durationMs': duration.inMilliseconds,
      'bytes': base64Encode(bytes),
    };
  }

  ComposerVoiceNote toVoiceNote() {
    return ComposerVoiceNote(duration: duration, bytes: bytes);
  }
}
