part of 'package:core/features/chat/widgets/chat_composer.dart';

enum ComposerSendState { idle, sending, queuedOffline, failed }

enum ComposerAutosaveStatus { idle, dirty, saving, saved, failed }

class ChatComposerValue {
  const ChatComposerValue({
    required this.text,
    required this.attachments,
    required this.voiceNote,
    required this.mentions,
    this.error,
    this.command,
    this.sendState = ComposerSendState.idle,
    this.autosaveStatus = ComposerAutosaveStatus.idle,
    this.lastAutosave,
  });

  static const _unset = Object();

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final List<ComposerMention> mentions;
  final String? error;
  final SlashCommand? command;
  final ComposerSendState sendState;
  final ComposerAutosaveStatus autosaveStatus;
  final DateTime? lastAutosave;

  factory ChatComposerValue.empty() => const ChatComposerValue(
        text: '',
        attachments: [],
        voiceNote: null,
        mentions: [],
        error: null,
        command: null,
        sendState: ComposerSendState.idle,
        autosaveStatus: ComposerAutosaveStatus.idle,
        lastAutosave: null,
      );

  ChatComposerValue copyWith({
    String? text,
    List<ComposerAttachment>? attachments,
    ComposerVoiceNote? voiceNote,
    bool clearVoiceNote = false,
    Object? error = _unset,
    SlashCommand? command,
    bool clearCommand = false,
    List<ComposerMention>? mentions,
    bool clearMentions = false,
    ComposerSendState? sendState,
    ComposerAutosaveStatus? autosaveStatus,
    DateTime? lastAutosave,
    bool clearLastAutosave = false,
  }) {
    final resolvedError = error == _unset ? this.error : error as String?;
    final resolvedCommand = clearCommand ? null : (command ?? this.command);
    final resolvedMentions =
        clearMentions ? <ComposerMention>[] : (mentions ?? this.mentions);
    final resolvedLastAutosave =
        clearLastAutosave ? null : (lastAutosave ?? this.lastAutosave);
    return ChatComposerValue(
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      voiceNote: clearVoiceNote ? null : (voiceNote ?? this.voiceNote),
      mentions: resolvedMentions,
      error: resolvedError,
      command: resolvedCommand,
      sendState: sendState ?? this.sendState,
      autosaveStatus: autosaveStatus ?? this.autosaveStatus,
      lastAutosave: resolvedLastAutosave,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatComposerValue &&
        other.text == text &&
        listEquals(other.attachments, attachments) &&
        other.voiceNote == voiceNote &&
        listEquals(other.mentions, mentions) &&
        other.error == error &&
        other.command == command &&
        other.sendState == sendState &&
        other.autosaveStatus == autosaveStatus &&
        other.lastAutosave == lastAutosave;
  }

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAll(attachments),
        voiceNote,
        Object.hashAll(mentions),
        error,
        command,
        sendState,
        autosaveStatus,
        lastAutosave?.millisecondsSinceEpoch,
      );
}

class ChatComposerResult {
  const ChatComposerResult({
    required this.text,
    this.attachments = const [],
    this.voiceNote,
    this.command,
    this.mentions = const [],
    this.richContent,
  });

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final SlashCommand? command;
  final List<ComposerMention> mentions;
  /// Rich content map for location/contact shares (bypasses text content).
  final Map<String, dynamic>? richContent;

  bool get hasCommand => command != null;
  bool get hasMentions => mentions.isNotEmpty;
  bool get hasRichContent => richContent != null;
}

class ComposerAttachment {
  ComposerAttachment({
    required this.id,
    required this.name,
    required this.size,
    this.bytes,
    this.path,
    this.mimeType,
  });

  factory ComposerAttachment.fromPlatformFile(PlatformFile file) {
    final id = file.identifier ??
        '${file.name}-${DateTime.now().microsecondsSinceEpoch}';
    final bytes = file.bytes;
    final mimeType = lookupMimeType(file.name, headerBytes: bytes);
    if (bytes == null) {
      return ComposerAttachment(
        id: id,
        name: file.name,
        size: file.size,
        path: file.path,
        mimeType: mimeType,
      );
    }
    return ComposerAttachment(
      id: id,
      name: file.name,
      size: file.size,
      bytes: bytes,
      path: file.path,
      mimeType: mimeType,
    );
  }

  static Future<ComposerAttachment?> fromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(file.name, headerBytes: bytes);
      final id = '${file.name}-${DateTime.now().microsecondsSinceEpoch}';
      return ComposerAttachment(
        id: id,
        name: file.name,
        size: bytes.length,
        bytes: bytes,
        path: file.path,
        mimeType: mimeType,
      );
    } catch (_) {
      return null;
    }
  }

  final String id;
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;
  final String? mimeType;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;

  String get humanSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ComposerAttachment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class ComposerVoiceNote {
  const ComposerVoiceNote({required this.duration, required this.bytes});

  final Duration duration;
  final Uint8List bytes;

  String get formattedDuration =>
      '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
}

class SlashCommand {
  const SlashCommand(this.name, this.description);

  final String name;
  final String description;

  /// Default commands are now loaded from the server API via [slashCommandsProvider].
  /// This static list serves as a fallback while commands are loading.
  static const defaults = <SlashCommand>[];
}

class ComposerMention {
  const ComposerMention({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return handle.isNotEmpty ? handle.substring(0, 1).toUpperCase() : '?';
    }
    final buffer = StringBuffer();
    for (final part in parts.take(2)) {
      buffer.write(part.substring(0, 1).toUpperCase());
    }
    return buffer.toString();
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return displayName.toLowerCase().contains(lower) ||
        handle.toLowerCase().contains(lower);
  }

  /// Default mentions available before team profiles are loaded.
  /// Includes special mentions (@channel, @here).
  static const defaults = <ComposerMention>[
    ComposerMention(id: '__channel__', displayName: 'channel', handle: 'channel'),
    ComposerMention(id: '__here__', displayName: 'here', handle: 'here'),
  ];
}
