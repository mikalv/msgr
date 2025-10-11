import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/features/chat/media/chat_media_attachment.dart';
import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/models/composer_submission.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/chat_socket.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:msgr_messages/msgr_messages.dart';

class StubChatApi implements ChatApi {
  StubChatApi();

  final List<ChatMessage> messages = [];
  final List<MediaUploadRequest> uploadRequests = [];
  MediaUploadInstructions? lastInstructions;

  final ChatThread thread = const ChatThread(
    id: 'conversation-1',
    participantNames: ['Demo', 'Buddy'],
    kind: ChatThreadKind.direct,
    topic: null,
  );

  int _accountCounter = 0;
  int _messageCounter = 0;
  int _uploadCounter = 0;

  @override
  Future<AccountIdentity> createAccount(String displayName, {String? email}) async {
    _accountCounter += 1;
    return AccountIdentity(
      accountId: 'account-$_accountCounter',
      profileId: 'profile-$_accountCounter',
    );
  }

  @override
  Future<ChatThread> ensureDirectConversation({
    required AccountIdentity current,
    required String targetProfileId,
  }) async {
    return thread;
  }

  @override
  Future<ChatThread> createGroupConversation({
    required AccountIdentity current,
    required String topic,
    required List<String> participantIds,
    ChatStructureType structureType = ChatStructureType.friends,
  }) async {
    return thread;
  }

  @override
  Future<ChatThread> createChannelConversation({
    required AccountIdentity current,
    required String topic,
    List<String> participantIds = const [],
    ChatStructureType structureType = ChatStructureType.project,
    ChatVisibility visibility = ChatVisibility.team,
  }) async {
    return thread;
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required AccountIdentity current,
    required String conversationId,
    int limit = 50,
  }) async {
    return messages;
  }

  @override
  Future<MediaUploadInstructions> createMediaUpload({
    required AccountIdentity current,
    required String conversationId,
    required MediaUploadRequest request,
  }) async {
    _uploadCounter += 1;
    uploadRequests.add(request);
    final now = DateTime.now();
    final instructions = MediaUploadInstructions(
      id: 'upload-$_uploadCounter',
      bucket: 'bucket',
      objectKey: 'object-$_uploadCounter',
      uploadMethod: 'PUT',
      uploadUrl: Uri.parse('https://example.com/upload/$_uploadCounter'),
      uploadHeaders: {'content-type': request.contentType},
      uploadExpiresAt: now.add(const Duration(minutes: 5)),
      downloadMethod: 'GET',
      downloadUrl: Uri.parse('https://example.com/download/$_uploadCounter'),
      downloadExpiresAt: now.add(const Duration(minutes: 10)),
      publicUrl: Uri.parse('https://example.com/public/$_uploadCounter'),
      retentionUntil: now.add(const Duration(days: 7)),
    );
    lastInstructions = instructions;
    return instructions;
  }

  @override
  Future<ChatMessage> sendStructuredMessage({
    required AccountIdentity current,
    required String conversationId,
    String? body,
    String? kind,
    Map<String, dynamic>? media,
    Map<String, dynamic>? payload,
  }) async {
    _messageCounter += 1;
    final now = DateTime.now().toIso8601String();
    final payloadMap = <String, dynamic>{};
    if (media != null) {
      payloadMap['media'] = media;
    }
    if (payload != null) {
      payloadMap.addAll(payload);
    }

    final json = <String, dynamic>{
      'id': 'msg-$_messageCounter',
      'type': kind ?? (body != null ? 'text' : 'system'),
      'status': 'sent',
      'sent_at': now,
      'inserted_at': now,
      'profile': {
        'id': current.profileId,
        'name': 'Deg',
        'mode': 'private',
      },
      if (body != null) 'body': body,
      if (payloadMap.isNotEmpty) 'payload': payloadMap,
    };

    final message = ChatMessage.fromJson(json);
    messages.add(message);
    return message;
  }
}

class StubRealtime implements ChatRealtime {
  final StreamController<ChatMessage> _controller =
      StreamController<ChatMessage>.broadcast();

  bool wasConnected = false;
  bool _isConnected = false;
  AccountIdentity? identity;
  String? conversationId;
  final List<String> sentBodies = [];

  @override
  Stream<ChatMessage> get messages => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect({
    required AccountIdentity identity,
    required String conversationId,
  }) async {
    this.identity = identity;
    this.conversationId = conversationId;
    wasConnected = true;
    _isConnected = true;
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  Future<ChatMessage> send(String body) async {
    sentBodies.add(body);

    final message = ChatMessage.text(
      id: 'ws-${sentBodies.length}',
      body: body,
      profileId: identity?.profileId ?? 'profile-self',
      profileName: 'Deg',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(message);
    }

    return message;
  }

  void emit(ChatMessage message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }
}

class StubChatMediaUploader extends ChatMediaUploader {
  StubChatMediaUploader({required this.api}) : super(api: api);

  final StubChatApi api;
  final List<ChatMediaAttachment> uploads = [];

  @override
  Future<ChatMessage> uploadAndSend({
    required AccountIdentity current,
    required String conversationId,
    required ChatMediaAttachment attachment,
    String? caption,
  }) async {
    uploads.add(attachment);

    final kind = _mapKind(attachment.type);
    await api.createMediaUpload(
      current: current,
      conversationId: conversationId,
      request: MediaUploadRequest(
        kind: kind,
        contentType: attachment.mimeType,
        byteSize: attachment.byteSize,
        fileName: attachment.fileName,
      ),
    );

    final media = <String, dynamic>{
      'url': 'https://example.com/${attachment.id}',
      'contentType': attachment.mimeType,
      'byteSize': attachment.byteSize,
      'checksum': attachment.checksum,
      'metadata': {'fileName': attachment.fileName},
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (attachment.width != null) 'width': attachment.width,
      if (attachment.height != null) 'height': attachment.height,
    };

    if (attachment.waveform != null && attachment.waveform!.isNotEmpty) {
      media['waveform'] = attachment.waveform;
    }

    return api.sendStructuredMessage(
      current: current,
      conversationId: conversationId,
      kind: kind,
      body: caption,
      media: media,
    );
  }

  String _mapKind(ChatMediaType type) {
    switch (type) {
      case ChatMediaType.image:
        return 'image';
      case ChatMediaType.video:
        return 'video';
      case ChatMediaType.voice:
        return 'voice';
      case ChatMediaType.audio:
        return 'audio';
      case ChatMediaType.file:
        return 'file';
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap creates identities and loads messages', () async {
    final api = StubChatApi();
    api.messages.add(ChatMessage.text(
      id: 'initial',
      body: 'Hei der!',
      profileId: 'profile-peer',
      profileName: 'Buddy',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    ));

    final realtime = StubRealtime();
    final mediaUploader = StubChatMediaUploader(api: api);
    final viewModel = ChatViewModel(
      api: api,
      realtime: realtime,
      mediaUploader: mediaUploader,
    );
    await viewModel.bootstrap();

    expect(viewModel.identity, isNotNull);
    expect(viewModel.thread, equals(api.thread));
    expect(viewModel.messages, isNotEmpty);
    expect(realtime.wasConnected, isTrue);
    expect(realtime.conversationId, equals(api.thread.id));
  });

  test('sendMessage forwards to api and updates timeline', () async {
    final api = StubChatApi();
    final realtime = StubRealtime();
    final mediaUploader = StubChatMediaUploader(api: api);
    final viewModel = ChatViewModel(
      api: api,
      realtime: realtime,
      mediaUploader: mediaUploader,
    );
    await viewModel.bootstrap();

    await viewModel.sendMessage(
      const ComposerSubmission(text: 'Hallo verden', attachments: []),
    );

    expect(api.messages.map((m) => m.body), contains('Hallo verden'));
    expect(viewModel.messages.last.body, equals('Hallo verden'));
    expect(realtime.sentBodies, contains('Hallo verden'));
  });

  test('sendMessage uploads attachments with caption', () async {
    final api = StubChatApi();
    final realtime = StubRealtime();
    final mediaUploader = StubChatMediaUploader(api: api);
    final viewModel = ChatViewModel(
      api: api,
      realtime: realtime,
      mediaUploader: mediaUploader,
    );
    await viewModel.bootstrap();

    final attachment = ChatMediaAttachment(
      id: 'att-1',
      type: ChatMediaType.image,
      fileName: 'photo.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      width: 400,
      height: 200,
    );

    await viewModel.sendMessage(
      ComposerSubmission(text: 'Ferie', attachments: [attachment]),
    );

    expect(mediaUploader.uploads, hasLength(1));
    expect(api.uploadRequests, hasLength(1));
    final lastMessage = api.messages.last;
    expect(lastMessage.kind, equals(MsgrMessageKind.image));
    expect(lastMessage.body, equals('Ferie'));
    expect(lastMessage.message, isA<MsgrImageMessage>());
  });

  test('incoming realtime messages are merged into timeline', () async {
    final api = StubChatApi();
    final realtime = StubRealtime();
    final mediaUploader = StubChatMediaUploader(api: api);
    final viewModel = ChatViewModel(
      api: api,
      realtime: realtime,
      mediaUploader: mediaUploader,
    );
    await viewModel.bootstrap();

    final incoming = ChatMessage.text(
      id: 'incoming-1',
      body: 'Hei fra andre',
      profileId: 'peer-profile',
      profileName: 'Buddy',
      profileMode: 'private',
      status: 'sent',
      sentAt: DateTime.now(),
      insertedAt: DateTime.now(),
    );

    realtime.emit(incoming);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.messages.last, equals(incoming));
  });
}
