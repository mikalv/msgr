import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:core/l10n/strings.dart';
import 'package:core/providers/msgr_client_provider.dart';
import 'package:core/ui/theme/msgr_theme.dart';

/// Dialog for uploading/changing a profile avatar.
/// Supports: file picker, URL fetch, clipboard paste.
class AvatarUploadDialog extends ConsumerStatefulWidget {
  const AvatarUploadDialog({super.key, required this.teamSlug, required this.currentAvatarUrl});

  final String teamSlug;
  final String? currentAvatarUrl;

  @override
  ConsumerState<AvatarUploadDialog> createState() => _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends ConsumerState<AvatarUploadDialog> {
  Uint8List? _imageBytes;
  String? _imageSource;
  bool _uploading = false;
  String? _error;
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        setState(() {
          _imageBytes = bytes;
          _imageSource = result.files.first.name;
          _error = null;
        });
      }
    }
  }

  Future<void> _fetchUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() { _error = null; _imageSource = 'Henter...'; });

    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.startsWith('image/') || response.bodyBytes.length > 100) {
          setState(() {
            _imageBytes = response.bodyBytes;
            _imageSource = uri.host;
          });
        } else {
          setState(() => _error = 'URL-en inneholder ikke et bilde');
        }
      } else {
        setState(() => _error = 'Kunne ikke hente bilde (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Feil ved henting: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('image/png');
      if (data != null && data.text != null) {
        // Clipboard text might be a URL
        final text = data.text!;
        if (text.startsWith('http')) {
          _urlController.text = text;
          await _fetchUrl();
          return;
        }
      }

      // Try binary clipboard
      final clipData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipData?.text != null && clipData!.text!.startsWith('http')) {
        _urlController.text = clipData.text!;
        await _fetchUrl();
        return;
      }

      setState(() => _error = 'Ingen bilde på utklippstavlen. Prøv å lime inn en URL.');
    } catch (e) {
      setState(() => _error = 'Kunne ikke lime inn: $e');
    }
  }

  Future<void> _upload() async {
    if (_imageBytes == null) return;

    setState(() { _uploading = true; _error = null; });

    try {
      final client = ref.read(msgrApiProvider);

      // Upload via libmsgr's presigned upload flow
      final objectKey = await client.uploadFileToChannel(
        widget.teamSlug,
        'avatars', // virtual channel for avatar storage
        filename: 'avatar.jpg',
        bytes: _imageBytes!,
        contentType: 'image/jpeg',
      );

      // Get public URL and update profile
      final downloadUrl = await client.getDownloadUrl(widget.teamSlug, objectKey);
      await client.put('/api/teams/${widget.teamSlug}/profiles/me', body: {
        'avatar_url': downloadUrl,
      });

      if (mounted) Navigator.of(context).pop(downloadUrl);
    } catch (e) {
      setState(() { _error = 'Opplasting feilet: $e'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = MsgrTheme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF222529),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                S.changeProfilePicture,
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Preview
              Center(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1D21),
                    border: Border.all(color: const Color(0xFF2E3035), width: 2),
                  ),
                  child: ClipOval(
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover, width: 128, height: 128)
                        : widget.currentAvatarUrl != null
                            ? Image.network(widget.currentAvatarUrl!, fit: BoxFit.cover, width: 128, height: 128,
                                errorBuilder: (_, __, ___) => _placeholder())
                            : _placeholder(),
                  ),
                ),
              ),
              if (_imageSource != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _imageSource!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),

              // Source buttons
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.folder_open,
                      label: S.file,
                      onTap: _pickFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.content_paste,
                      label: S.paste,
                      onTap: _pasteFromClipboard,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // URL input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: S.pasteImageUrl,
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: const Color(0xFF1A1D21),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetchUrl(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download, color: Color(0xFFD1D2D3)),
                    onPressed: _fetchUrl,
                    tooltip: S.fetch,
                  ),
                ],
              ),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),

              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(S.cancel, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _imageBytes != null && !_uploading ? _upload : null,
                    child: _uploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(S.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const Center(
      child: Icon(Icons.person, size: 48, color: Color(0xFF4FC3F7)),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D21),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E3035)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFD1D2D3), size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Color(0xFFD1D2D3), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// Show the avatar upload dialog. Returns the new avatar URL if changed.
Future<String?> showAvatarUploadDialog(BuildContext context, {required String teamSlug, String? currentAvatarUrl}) {
  return showDialog<String>(
    context: context,
    builder: (_) => AvatarUploadDialog(teamSlug: teamSlug, currentAvatarUrl: currentAvatarUrl),
  );
}
