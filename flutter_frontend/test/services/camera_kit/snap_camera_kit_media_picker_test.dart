import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/config/camera_kit_environment.dart';
import 'package:messngr/features/chat/media/chat_media_attachment.dart';
import 'package:messngr/features/chat/media/chat_media_picker.dart';
import 'package:messngr/services/camera_kit/snap_camera_kit.dart';
import 'package:messngr/services/camera_kit/snap_camera_kit_media_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCameraKit cameraKit;
  late FakeChatMediaPicker fallback;

  setUp(() {
    cameraKit = FakeCameraKit();
    fallback = FakeChatMediaPicker();
    CameraKitEnvironment.instance.clearOverride();
  });

  tearDown(() {
    CameraKitEnvironment.instance.clearOverride();
  });

  test('falls back to default picker when not configured', () async {
    final picker = SnapCameraKitMediaPicker(
      cameraKit: cameraKit,
      fallback: fallback,
    );

    final attachments = await picker.pickFromCamera();

    expect(attachments, fallback.attachments);
    expect(fallback.pickFromCameraCount, 1);
  });

  test('uses Camera Kit when supported and configured', () async {
    final file = await _createTemporaryFile('camera-kit-test.mp4');
    cameraKit
      ..supported = true
      ..result = SnapCameraKitResult(path: file.path, mimeType: 'video/mp4');

    CameraKitEnvironment.instance.override(
      enabled: true,
      apiToken: 'token',
      applicationId: 'app',
      lensGroupIds: const ['group'],
    );

    final picker = SnapCameraKitMediaPicker(
      cameraKit: cameraKit,
      fallback: fallback,
    );

    final attachments = await picker.pickFromCamera();

    expect(fallback.pickFromCameraCount, 0);
    expect(attachments, hasLength(1));
    expect(attachments.first.mimeType, 'video/mp4');
  });

  test('falls back when Camera Kit throws', () async {
    cameraKit
      ..supported = true
      ..shouldThrow = true;

    CameraKitEnvironment.instance.override(
      enabled: true,
      apiToken: 'token',
      applicationId: 'app',
      lensGroupIds: const ['group'],
    );

    final picker = SnapCameraKitMediaPicker(
      cameraKit: cameraKit,
      fallback: fallback,
    );

    final attachments = await picker.pickFromCamera();

    expect(fallback.pickFromCameraCount, 1);
    expect(attachments, fallback.attachments);
  });
}

Future<File> _createTemporaryFile(String name) async {
  final directory = await Directory.systemTemp.createTemp('camera-kit');
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(Uint8List.fromList(List<int>.generate(16, (index) => index)));
  return file;
}

class FakeCameraKit implements SnapCameraKitClient {
  bool supported = false;
  bool shouldThrow = false;
  SnapCameraKitResult? result;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<SnapCameraKitResult?> launchCapture(SnapCameraKitRequest request) async {
    if (shouldThrow) {
      throw const SnapCameraKitException('boom');
    }
    return result;
  }
}

class FakeChatMediaPicker implements ChatMediaPicker {
  FakeChatMediaPicker()
      : attachments = [
          ChatMediaAttachment(
            id: 'fallback',
            type: ChatMediaType.image,
            fileName: 'fallback.jpg',
            mimeType: 'image/jpeg',
            bytes: Uint8List.fromList(const [0]),
          ),
        ];

  final List<ChatMediaAttachment> attachments;
  int pickFromCameraCount = 0;

  @override
  Future<List<ChatMediaAttachment>> pickFromCamera() async {
    pickFromCameraCount += 1;
    return attachments;
  }

  @override
  Future<List<ChatMediaAttachment>> pickFromFiles() async => attachments;

  @override
  Future<List<ChatMediaAttachment>> pickFromGallery() async => attachments;

  @override
  Future<List<ChatMediaAttachment>> pickAudio({bool voiceMemo = false}) async => attachments;
}
