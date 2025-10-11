import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_media_attachment.dart';

/// Abstraction around platform pickers to simplify testing and composition.
abstract class ChatMediaPicker {
  Future<List<ChatMediaAttachment>> pickFromCamera();

  Future<List<ChatMediaAttachment>> pickFromGallery();

  Future<List<ChatMediaAttachment>> pickFromFiles();

  Future<List<ChatMediaAttachment>> pickAudio({bool voiceMemo = false});
}

class DefaultChatMediaPicker implements ChatMediaPicker {
  DefaultChatMediaPicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<List<ChatMediaAttachment>> pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file == null) return const [];
      return [await ChatMediaAttachment.fromXFile(file)];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ChatMediaAttachment>> pickFromGallery() async {
    try {
      final files = await _imagePicker.pickMultiImage();
      if (files.isEmpty) return const [];
      final attachments = <ChatMediaAttachment>[];
      for (final file in files) {
        attachments.add(await ChatMediaAttachment.fromXFile(file));
      }
      return attachments;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ChatMediaAttachment>> pickFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return const [];
      final attachments = <ChatMediaAttachment>[];
      for (final file in result.files) {
        attachments.add(await ChatMediaAttachment.fromPlatformFile(file));
      }
      return attachments;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ChatMediaAttachment>> pickAudio({bool voiceMemo = false}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: !voiceMemo,
        type: FileType.audio,
      );
      if (result == null || result.files.isEmpty) return const [];
      final attachments = <ChatMediaAttachment>[];
      for (final file in result.files) {
        attachments.add(
          await ChatMediaAttachment.fromPlatformFile(
            file,
            forcedType: voiceMemo ? ChatMediaType.voice : ChatMediaType.audio,
          ),
        );
      }
      return attachments;
    } catch (_) {
      return const [];
    }
  }
}
