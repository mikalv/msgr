import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../services/api/chat_api.dart';
import '../widgets/chat_composer.dart';

class MediaUploadResult {
  const MediaUploadResult({required this.kind, required this.message});

  final String kind;
  final Map<String, dynamic> message;
}

class ChatMediaUploader {
  ChatMediaUploader({
    required ChatApi api,
    required AccountIdentity identity,
    http.Client? httpClient,
  })  : _api = api,
        _identity = identity,
        _http = httpClient ?? http.Client();

  final ChatApi _api;
  final AccountIdentity _identity;
  final http.Client _http;

  Future<MediaUploadResult> uploadAttachment({
    required String conversationId,
    required ComposerAttachment attachment,
    String? caption,
  }) async {
    final bytes = await _resolveBytes(attachment);
    final contentType = _resolveContentType(attachment.name, bytes);
    final kind = _resolveKind(contentType);

    final session = await _api.createMediaUpload(
      current: _identity,
      conversationId: conversationId,
      kind: kind,
      contentType: contentType,
      byteSize: bytes.length,
      filename: attachment.name,
    );

    await _putObject(session.instructions, bytes);

    final sha = sha256.convert(bytes).toString();
    final metadata = <String, dynamic>{
      'upload_id': session.id,
      'sha256': sha,
      'contentType': contentType,
      'byteSize': bytes.length,
    };
    final encryption = session.instructions.encryption.toJson();
    final clientState = session.instructions.clientState.toJson();
    metadata['encryption'] = encryption;
    metadata['clientState'] = clientState;

    final trimmedCaption = caption?.trim();
    if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
      metadata['caption'] = trimmedCaption;
    }

    if (kind == 'image') {
      final dimensions = await _decodeImageDimensions(bytes);
      if (dimensions != null) {
        metadata['width'] = dimensions.width;
        metadata['height'] = dimensions.height;
      }

      final thumbnailInfo = session.instructions.thumbnail;
      if (thumbnailInfo != null) {
        final thumbnail = await _generateImageThumbnail(bytes);
        if (thumbnail != null) {
          await _putObjectWithBytes(thumbnailInfo, thumbnail.bytes);
          metadata['thumbnail'] = {
            'url': thumbnailInfo.publicUrl.toString(),
            'width': thumbnail.width,
            'height': thumbnail.height,
            'objectKey': thumbnailInfo.objectKey,
            'bucket': thumbnailInfo.bucket,
            'contentType': thumbnail.contentType,
          };
        }
      }
    } else if (kind == 'video') {
      final thumbnailInfo = session.instructions.thumbnail;
      if (thumbnailInfo != null) {
        final thumbnail = await _generateVideoThumbnail(attachment);
        if (thumbnail != null) {
          await _putObjectWithBytes(thumbnailInfo, thumbnail.bytes);
          metadata['thumbnail'] = {
            'url': thumbnailInfo.publicUrl.toString(),
            'width': thumbnail.width,
            'height': thumbnail.height,
            'objectKey': thumbnailInfo.objectKey,
            'bucket': thumbnailInfo.bucket,
            'contentType': thumbnail.contentType,
          };
          metadata['width'] = thumbnail.width;
          metadata['height'] = thumbnail.height;
        }
      }
    }

    final message = <String, dynamic>{
      'kind': kind,
      if (trimmedCaption != null && trimmedCaption.isNotEmpty)
        'body': trimmedCaption,
      'media': metadata,
      'encryption': encryption,
      'clientState': clientState,
    };

    return MediaUploadResult(kind: kind, message: message);
  }

  Future<MediaUploadResult> uploadVoiceNote({
    required String conversationId,
    required ComposerVoiceNote note,
    String? caption,
  }) async {
    final bytes = note.bytes;
    final contentType = 'audio/ogg';
    final session = await _api.createMediaUpload(
      current: _identity,
      conversationId: conversationId,
      kind: 'voice',
      contentType: contentType,
      byteSize: bytes.length,
      filename: 'voice-${DateTime.now().millisecondsSinceEpoch}.ogg',
    );

    await _putObject(session.instructions, bytes);

    final trimmedCaption = caption?.trim();
    final metadata = <String, dynamic>{
      'upload_id': session.id,
      'sha256': sha256.convert(bytes).toString(),
      'durationMs': note.duration.inMilliseconds,
      'waveform': _buildWaveform(bytes),
      'contentType': contentType,
      'byteSize': bytes.length,
    };
    final encryption = session.instructions.encryption.toJson();
    final clientState = session.instructions.clientState.toJson();
    metadata['encryption'] = encryption;
    metadata['clientState'] = clientState;

    if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
      metadata['caption'] = trimmedCaption;
    }

    final message = <String, dynamic>{
      'kind': 'voice',
      if (trimmedCaption != null && trimmedCaption.isNotEmpty)
        'body': trimmedCaption,
      'media': metadata,
      'encryption': encryption,
      'clientState': clientState,
    };

    return MediaUploadResult(kind: 'voice', message: message);
  }

  Future<Uint8List> _resolveBytes(ComposerAttachment attachment) async {
    if (attachment.bytes != null) {
      return attachment.bytes!;
    }
    throw ArgumentError('Attachment has no bytes data');
  }

  String _resolveContentType(String filename, Uint8List bytes) {
    final fromName = lookupMimeType(filename, headerBytes: bytes);
    return fromName ?? 'application/octet-stream';
  }

  String _resolveKind(String contentType) {
    if (contentType.startsWith('image/')) return 'image';
    if (contentType.startsWith('video/')) return 'video';
    if (contentType.startsWith('audio/')) return 'audio';
    return 'file';
  }

  Future<_ImageDimensions?> _decodeImageDimensions(Uint8List bytes) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      final image = await completer.future;
      return _ImageDimensions(image.width, image.height);
    } catch (_) {
      return null;
    }
  }

  Future<_ThumbnailData?> _generateImageThumbnail(Uint8List bytes) async {
    try {
      final original = img.decodeImage(bytes);
      if (original == null) return null;
      final maxDimension = 320;
      final resized = img.copyResize(original, width: maxDimension);
      final data = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      return _ThumbnailData(data, resized.width, resized.height, 'image/jpeg');
    } catch (_) {
      return null;
    }
  }

  Future<_ThumbnailData?> _generateVideoThumbnail(
      ComposerAttachment attachment) async {
    try {
      if (attachment.path == null) {
        return null;
      }
      final bytes = await VideoThumbnail.thumbnailData(
        video: attachment.path!,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );
      if (bytes == null) return null;
      final dims = await _decodeImageDimensions(bytes);
      if (dims == null) return null;
      return _ThumbnailData(bytes, dims.width, dims.height, 'image/jpeg');
    } catch (_) {
      return null;
    }
  }

  Future<void> _putObject(PresignedUploadInfo info, Uint8List bytes) async {
    final response =
        await _http.put(info.url, headers: info.headers, body: bytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<void> _putObjectWithBytes(
      ThumbnailUploadInfo info, Uint8List bytes) async {
    final response =
        await _http.put(info.url, headers: info.headers, body: bytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(response.statusCode, response.body);
  }

  List<int> _buildWaveform(Uint8List bytes) {
    if (bytes.isEmpty) return const [];
    const sampleCount = 64;
    final step = math.max(1, bytes.length ~/ sampleCount);
    final samples = <int>[];
    for (var i = 0; i < bytes.length; i += step) {
      final slice = bytes.sublist(i, math.min(bytes.length, i + step));
      final average = slice.fold<int>(0, (prev, element) => prev + element);
      final amplitude = (average / slice.length) / 255;
      samples.add((amplitude.clamp(0, 1) * 100).round());
      if (samples.length == sampleCount) break;
    }
    return samples;
  }
}

class _ImageDimensions {
  const _ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

class _ThumbnailData {
  const _ThumbnailData(this.bytes, this.width, this.height, this.contentType);

  final Uint8List bytes;
  final int width;
  final int height;
  final String contentType;
}
