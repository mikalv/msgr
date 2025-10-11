import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:crypto/crypto.dart';

/// Supported attachment kinds handled by the chat composer.
enum ChatMediaType { image, video, audio, voice, file }

/// Represents a pending media attachment that can be uploaded to the backend.
class ChatMediaAttachment {
  ChatMediaAttachment({
    required this.id,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.width,
    this.height,
    this.durationSeconds,
    this.waveform,
  })  : byteSize = bytes.lengthInBytes,
        checksum = sha256.convert(bytes).toString(),
        createdAt = DateTime.now();

  final String id;
  final ChatMediaType type;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final int byteSize;
  final int? width;
  final int? height;
  final double? durationSeconds;
  final List<double>? waveform;
  final String checksum;
  final DateTime createdAt;

  static Future<ChatMediaAttachment> fromXFile(
    XFile file, {
    ChatMediaType? forcedType,
  }) async {
    final data = await file.readAsBytes();
    final headerLength = data.length > 12 ? 12 : data.length;
    final mime = lookupMimeType(
          file.name,
          headerBytes: headerLength > 0 ? data.sublist(0, headerLength) : null,
        ) ??
        'application/octet-stream';
    final type = forcedType ?? _inferType(mime);
    final dimensions = await _resolveDimensionsIfNeeded(type, data);
    final waveform = type == ChatMediaType.audio || type == ChatMediaType.voice
        ? _generateWaveform(data)
        : null;

    return ChatMediaAttachment(
      id: _generateId(),
      type: type,
      fileName: file.name,
      mimeType: mime,
      bytes: data,
      width: dimensions?.$1,
      height: dimensions?.$2,
      waveform: waveform,
    );
  }

  static Future<ChatMediaAttachment> fromPlatformFile(
    PlatformFile file, {
    ChatMediaType? forcedType,
  }) async {
    Uint8List? data = file.bytes;
    if (data == null && file.path != null) {
      data = await XFile(file.path!).readAsBytes();
    }

    data ??= Uint8List(0);
    final headerLength = data.length > 12 ? 12 : data.length;
    final mime = lookupMimeType(
          file.name,
          headerBytes: headerLength > 0 ? data.sublist(0, headerLength) : null,
        ) ??
        'application/octet-stream';
    final type = forcedType ?? _inferType(mime);
    final dimensions = await _resolveDimensionsIfNeeded(type, data);
    final waveform = type == ChatMediaType.audio || type == ChatMediaType.voice
        ? _generateWaveform(data)
        : null;

    return ChatMediaAttachment(
      id: _generateId(),
      type: type,
      fileName: file.name,
      mimeType: mime,
      bytes: data,
      width: dimensions?.$1,
      height: dimensions?.$2,
      waveform: waveform,
    );
  }

  Map<String, dynamic> toDebugMap() {
    return {
      'id': id,
      'type': type.name,
      'fileName': fileName,
      'mimeType': mimeType,
      'byteSize': byteSize,
      'width': width,
      'height': height,
      'durationSeconds': durationSeconds,
      'waveformSamples': waveform?.length,
    };
  }

  static String _generateId() {
    final random = Random();
    final nonce = random.nextInt(1 << 32).toRadixString(16);
    return 'att-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  static ChatMediaType _inferType(String mime, {ChatMediaType? fallback}) {
    final lower = mime.toLowerCase();
    if (lower.startsWith('image/')) return ChatMediaType.image;
    if (lower.startsWith('video/')) return ChatMediaType.video;
    if (lower.startsWith('audio/')) return fallback ?? ChatMediaType.audio;
    return fallback ?? ChatMediaType.file;
  }

  static Future<(int, int)?> _resolveDimensionsIfNeeded(
      ChatMediaType type, Uint8List data) async {
    if (type != ChatMediaType.image && type != ChatMediaType.video) {
      return null;
    }

    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(
        data,
        (image) => completer.complete(image),
      );
      final image = await completer.future;
      return (image.width, image.height);
    } catch (_) {
      return null;
    }
  }

  static List<double> _generateWaveform(Uint8List data) {
    if (data.isEmpty) {
      return const [];
    }

    const sampleCount = 64;
    final step = max(1, data.length ~/ sampleCount);
    final samples = <double>[];
    for (var i = 0;
        i < data.length && samples.length < sampleCount;
        i += step) {
      final value = data[i] / 255.0;
      samples.add(value.clamp(0, 1));
    }
    return samples;
  }
}
