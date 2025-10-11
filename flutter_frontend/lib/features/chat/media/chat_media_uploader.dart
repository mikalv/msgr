import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../services/api/chat_api.dart';
import '../models/chat_message.dart';
import 'chat_media_attachment.dart';

class ChatMediaUploadException implements Exception {
  ChatMediaUploadException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ChatMediaUploadException($message${statusCode != null ? ', status: $statusCode' : ''})';
}

/// Handles the multi-step upload process before creating a media message.
class ChatMediaUploader {
  ChatMediaUploader({ChatApi? api, http.Client? client})
      : _api = api ?? ChatApi(),
        _client = client ?? http.Client();

  final ChatApi _api;
  final http.Client _client;

  Future<ChatMessage> uploadAndSend({
    required AccountIdentity current,
    required String conversationId,
    required ChatMediaAttachment attachment,
    String? caption,
  }) async {
    final request = MediaUploadRequest(
      kind: _mapKind(attachment.type),
      contentType: attachment.mimeType,
      byteSize: attachment.byteSize,
      fileName: attachment.fileName,
    );

    final instructions =
        await _api.createMediaUpload(current: current, conversationId: conversationId, request: request);

    await _uploadBinary(instructions.uploadUrl, instructions.uploadHeaders, attachment.bytes);

    final mediaMetadata = _buildMediaMetadata(attachment, uploadId: instructions.id, caption: caption);

    return _api.sendStructuredMessage(
      current: current,
      conversationId: conversationId,
      kind: request.kind,
      body: caption,
      media: mediaMetadata,
    );
  }

  Future<void> _uploadBinary(Uri url, Map<String, String> headers, List<int> body) async {
    final response = await _client.put(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw ChatMediaUploadException(
      'Upload failed with status ${response.statusCode}',
      response.statusCode,
    );
  }

  Map<String, dynamic> _buildMediaMetadata(ChatMediaAttachment attachment,
      {required String uploadId, String? caption}) {
    final media = <String, dynamic>{
      'upload_id': uploadId,
      'checksum': attachment.checksum,
    };

    if (caption != null && caption.trim().isNotEmpty) {
      media['caption'] = caption.trim();
    }

    if (attachment.width != null) {
      media['width'] = attachment.width;
    }

    if (attachment.height != null) {
      media['height'] = attachment.height;
    }

    if (attachment.waveform != null && attachment.waveform!.isNotEmpty) {
      media['waveform'] = attachment.waveform;
    }

    if (attachment.durationSeconds != null) {
      media['duration'] = double.parse(attachment.durationSeconds!.toStringAsFixed(3));
      media['durationMs'] = (attachment.durationSeconds! * 1000).round();
    }

    if (attachment.fileName.isNotEmpty) {
      media['metadata'] = {'fileName': attachment.fileName};
    }

    return media;
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
