import 'package:image_picker/image_picker.dart';

import '../../config/camera_kit_environment.dart';
import '../../features/chat/media/chat_media_attachment.dart';
import '../../features/chat/media/chat_media_picker.dart';
import 'snap_camera_kit.dart';

/// [ChatMediaPicker] implementation that delegates camera capture to Snapchat
/// Camera Kit when it is configured and supported on the current platform.
class SnapCameraKitMediaPicker implements ChatMediaPicker {
  SnapCameraKitMediaPicker({
    CameraKitEnvironment? environment,
    SnapCameraKitClient? cameraKit,
    ChatMediaPicker? fallback,
  })  : _environment = environment ?? CameraKitEnvironment.instance,
        _cameraKit = cameraKit ?? SnapCameraKit(),
        _fallback = fallback ?? DefaultChatMediaPicker();

  final CameraKitEnvironment _environment;
  final SnapCameraKitClient _cameraKit;
  final ChatMediaPicker _fallback;

  @override
  Future<List<ChatMediaAttachment>> pickFromCamera() async {
    if (!_environment.isConfigured) {
      return _fallback.pickFromCamera();
    }

    final supported = await _cameraKit.isSupported();
    if (!supported) {
      return _fallback.pickFromCamera();
    }

    try {
      final result = await _cameraKit.launchCapture(
        SnapCameraKitRequest(
          apiToken: _environment.apiToken,
          applicationId: _environment.applicationId,
          lensGroupIds: _environment.lensGroupIds,
        ),
      );

      if (result == null) {
        return const [];
      }

      final file = XFile(
        result.path,
        mimeType: result.mimeType,
      );
      final attachment = await ChatMediaAttachment.fromXFile(file);
      return [attachment];
    } on SnapCameraKitException {
      return _fallback.pickFromCamera();
    }
  }

  @override
  Future<List<ChatMediaAttachment>> pickFromGallery() {
    return _fallback.pickFromGallery();
  }

  @override
  Future<List<ChatMediaAttachment>> pickFromFiles() {
    return _fallback.pickFromFiles();
  }

  @override
  Future<List<ChatMediaAttachment>> pickAudio({bool voiceMemo = false}) {
    return _fallback.pickAudio(voiceMemo: voiceMemo);
  }
}
