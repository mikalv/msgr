import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_media_attachment.dart';
import 'chat_media_picker.dart';
import '../../../services/camera_kit/snap_camera_kit_media_picker.dart';

/// Coordinates selection and lifecycle of pending chat media attachments.
class ChatMediaController extends ChangeNotifier {
  ChatMediaController({ChatMediaPicker? picker})
      : _picker =
            picker ?? SnapCameraKitMediaPicker(fallback: DefaultChatMediaPicker());

  final ChatMediaPicker _picker;
  final List<ChatMediaAttachment> _attachments = [];

  List<ChatMediaAttachment> get attachments => List.unmodifiable(_attachments);

  bool get hasAttachments => _attachments.isNotEmpty;

  Future<void> pickFromCamera() async {
    final selection = await _picker.pickFromCamera();
    _addAll(selection);
  }

  Future<void> pickFromGallery() async {
    final selection = await _picker.pickFromGallery();
    _addAll(selection);
  }

  Future<void> pickFiles() async {
    final selection = await _picker.pickFromFiles();
    _addAll(selection);
  }

  Future<void> pickAudio({bool voiceMemo = false}) async {
    final selection = await _picker.pickAudio(voiceMemo: voiceMemo);
    _addAll(selection);
  }

  Future<void> addDropItems(List<XFile> files) async {
    final attachments = <ChatMediaAttachment>[];
    for (final file in files) {
      attachments.add(await ChatMediaAttachment.fromXFile(file));
    }
    _addAll(attachments);
  }

  void addAttachments(List<ChatMediaAttachment> attachments) {
    _addAll(attachments);
  }

  void removeAttachment(String id) {
    _attachments.removeWhere((attachment) => attachment.id == id);
    notifyListeners();
  }

  void clear() {
    if (_attachments.isEmpty) return;
    _attachments.clear();
    notifyListeners();
  }

  void _addAll(List<ChatMediaAttachment> attachments) {
    if (attachments.isEmpty) return;
    _attachments.addAll(attachments);
    notifyListeners();
  }
}
