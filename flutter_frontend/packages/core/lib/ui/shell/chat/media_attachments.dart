part of 'simple_chat_content.dart';

// ---------------------------------------------------------------------------
// Media attachments: inline images + file download cards
// ---------------------------------------------------------------------------

/// Known image extensions for client-side type inference from object keys.
const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'};

bool _isImageRef(String ref) {
  final lower = ref.toLowerCase();
  return _imageExtensions.any((ext) => lower.endsWith(ext));
}

String _filenameFromRef(String ref) {
  final parts = ref.split('/');
  return parts.isNotEmpty ? parts.last : ref;
}

/// Renders media attachments (images inline, other files as download cards).
class _MediaAttachments extends ConsumerWidget {
  const _MediaAttachments({required this.mediaRefs});

  final List<String> mediaRefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mediaRefs.isEmpty) return const SizedBox.shrink();

    final images = mediaRefs.where(_isImageRef).toList();
    final files = mediaRefs.where((r) => !_isImageRef(r)).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inline image thumbnails
          if (images.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in images)
                  _ImageThumbnail(objectKey: key),
              ],
            ),
          // File download cards
          if (files.isNotEmpty)
            ...files.map((key) => _FileCard(objectKey: key)),
        ],
      ),
    );
  }
}

/// Inline image thumbnail that can be clicked to expand.
class _ImageThumbnail extends ConsumerStatefulWidget {
  const _ImageThumbnail({required this.objectKey});

  final String objectKey;

  @override
  ConsumerState<_ImageThumbnail> createState() => _ImageThumbnailState();
}

class _ImageThumbnailState extends ConsumerState<_ImageThumbnail> {
  String? _url;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;
      final client = ref.read(msgrApiProvider);
      final url = await client.getDownloadUrl(team.slug, widget.objectKey);
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error || _url == null || _url!.isEmpty) {
      return Container(
        width: 200,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _filenameFromRef(widget.objectKey),
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 300),
          child: Image.network(
            _url!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: Colors.white.withOpacity(0.05),
                child: const Center(
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              return Container(
                width: 200,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Kunne ikke laste bilde',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    if (_url == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ImageOverlay(url: _url!, filename: _filenameFromRef(widget.objectKey)),
    );
  }
}

/// Full-size image overlay dialog.
class _ImageOverlay extends StatelessWidget {
  const _ImageOverlay({required this.url, required this.filename});

  final String url;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) {
                  return Center(
                    child: Text(
                      'Kunne ikke laste bilde',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Download card for non-image files.
class _FileCard extends ConsumerStatefulWidget {
  const _FileCard({required this.objectKey});

  final String objectKey;

  @override
  ConsumerState<_FileCard> createState() => _FileCardState();
}

class _FileCardState extends ConsumerState<_FileCard> {
  bool _downloading = false;

  IconData _iconForFile(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz')) return Icons.folder_zip;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi')) return Icons.videocam;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.ogg')) return Icons.audiotrack;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final team = ref.read(selectedTeamProvider);
      if (team == null) return;
      final client = ref.read(msgrApiProvider);
      final url = await client.getDownloadUrl(team.slug, widget.objectKey);
      if (url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nedlasting feilet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = _filenameFromRef(widget.objectKey);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: _downloading ? null : _download,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForFile(filename),
                color: const Color(0xFF4FC3F7),
                size: 28,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: const TextStyle(
                        color: Color(0xFF4FC3F7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Klikk for aa laste ned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_downloading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.download,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
