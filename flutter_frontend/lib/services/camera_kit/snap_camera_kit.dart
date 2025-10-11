import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Defines the contract that the chat media picker expects for interacting with
/// Snapchat Camera Kit.
abstract class SnapCameraKitClient {
  Future<bool> isSupported();

  Future<SnapCameraKitResult?> launchCapture(SnapCameraKitRequest request);
}

/// Implementation of [SnapCameraKitClient] backed by a [MethodChannel].
class SnapCameraKit implements SnapCameraKitClient {
  SnapCameraKit({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'dev.meeh.messngr/snap_camera_kit';
  static const String _methodIsSupported = 'isSupported';
  static const String _methodLaunch = 'openCameraKit';

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return false;
    }

    try {
      final supported = await _channel.invokeMethod<bool>(_methodIsSupported);
      return supported ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<SnapCameraKitResult?> launchCapture(
    SnapCameraKitRequest request,
  ) async {
    final payload = <String, dynamic>{
      'apiToken': request.apiToken,
      'applicationId': request.applicationId,
      'lensGroupIds': request.lensGroupIds,
    };

    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>(_methodLaunch, payload);
      if (response == null) {
        return null;
      }

      final path = response['path'] as String?;
      final mimeType = response['mime_type'] as String?;
      if (path == null || mimeType == null) {
        throw const SnapCameraKitException('Malformed response from Camera Kit');
      }
      return SnapCameraKitResult(path: path, mimeType: mimeType);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      if (_isCancellation(error)) {
        return null;
      }
      throw SnapCameraKitException(error.message ?? 'Unknown Camera Kit error');
    }
  }

  bool _isCancellation(PlatformException error) {
    return error.code.toLowerCase() == 'cancelled';
  }
}

/// Encapsulates the configuration needed to open Camera Kit on the platform
/// layers.
@immutable
class SnapCameraKitRequest {
  const SnapCameraKitRequest({
    required this.apiToken,
    required this.applicationId,
    required this.lensGroupIds,
  });

  final String apiToken;
  final String applicationId;
  final List<String> lensGroupIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'apiToken': apiToken,
        'applicationId': applicationId,
        'lensGroupIds': lensGroupIds,
      };
}

/// Result returned when the user successfully captured a photo or video using
/// Camera Kit.
@immutable
class SnapCameraKitResult {
  const SnapCameraKitResult({
    required this.path,
    required this.mimeType,
  });

  final String path;
  final String mimeType;
}

class SnapCameraKitException implements Exception {
  const SnapCameraKitException(this.message);

  final String message;

  @override
  String toString() => 'SnapCameraKitException($message)';
}
