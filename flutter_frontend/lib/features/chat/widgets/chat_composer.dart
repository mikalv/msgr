import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messngr/features/chat/media/chat_media_attachment.dart';
import 'package:messngr/features/chat/media/chat_media_controller.dart';
import 'package:messngr/features/chat/media/chat_media_picker.dart';
import 'package:messngr/features/chat/models/composer_submission.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.isSending,
    this.errorMessage,
    this.mediaController,
    this.mediaPicker,
  });

  final ValueChanged<ComposerSubmission> onSend;
  final bool isSending;
  final String? errorMessage;
  final ChatMediaController? mediaController;
  final ChatMediaPicker? mediaPicker;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ValueNotifier<bool> _hasText;
  late final AnimationController _toolbarController;
  late final ChatMediaController _mediaController;
  late final bool _ownsMediaController;

  bool _showToolbar = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _hasText = ValueNotifier<bool>(false);
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _controller.addListener(_handleTextChanged);
    _ownsMediaController = widget.mediaController == null;
    _mediaController = widget.mediaController ?? ChatMediaController(picker: widget.mediaPicker);
    _mediaController.addListener(_handleMediaChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    _toolbarController.dispose();
    _hasText.dispose();
    _mediaController.removeListener(_handleMediaChanged);
    if (_ownsMediaController) {
      _mediaController.dispose();
    }
    super.dispose();
  }

  void _handleTextChanged() {
    _hasText.value = _controller.text.trim().isNotEmpty;
  }

  void _handleMediaChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ErrorBanner(message: widget.errorMessage!),
            ),
          DragTarget<List<XFile>>(
            onWillAccept: (_) => true,
            onAccept: (files) => _mediaController.addDropItems(files),
            builder: (context, candidateData, rejectedData) {
              final attachments = _mediaController.attachments;
              final hasAttachments = attachments.isNotEmpty;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: ChatTheme.composerDecoration(theme).copyWith(
                  border: candidateData.isNotEmpty
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AttachmentPreviewStrip(
                          attachments: attachments,
                          onRemove: (id) => _mediaController.removeAttachment(id),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ComposerIconButton(
                          icon: Icons.add,
                          tooltip: 'Vis hurtigmeny',
                          isActive: _showToolbar,
                          onTap: _toggleToolbar,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.send,
                              minLines: 1,
                              maxLines: 6,
                              onSubmitted: (_) => _handleSend(),
                              decoration: InputDecoration(
                                hintText: hasAttachments
                                    ? 'Legg til en bildetekst …'
                                    : 'Skriv noe strålende …',
                                border: InputBorder.none,
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ComposerIconButton(
                          icon: Icons.mic_none_rounded,
                          tooltip: 'Legg til stemmeklipp',
                          onTap: () => _mediaController.pickAudio(voiceMemo: true),
                        ),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<bool>(
                          valueListenable: _hasText,
                          builder: (context, hasText, _) {
                            final enabled = (hasText || hasAttachments) && !widget.isSending;
                            return _SendButton(
                              isEnabled: enabled,
                              isSending: widget.isSending,
                              onPressed: enabled ? _handleSend : null,
                            );
                          },
                        ),
                      ],
                    ),
                    SizeTransition(
                      sizeFactor: CurvedAnimation(
                        parent: _toolbarController,
                        curve: Curves.easeOut,
                      ),
                      axisAlignment: -1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _ComposerToolbar(onSelect: _handleToolbarAction),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleToolbar() {
    setState(() {
      _showToolbar = !_showToolbar;
      if (_showToolbar) {
        _focusNode.unfocus();
        _toolbarController.forward();
      } else {
        _toolbarController.reverse();
      }
    });
  }

  void _handleToolbarAction(_ComposerAction action) async {
    switch (action) {
      case _ComposerAction.attachFile:
        await _mediaController.pickFiles();
        break;
      case _ComposerAction.addPhoto:
        await _mediaController.pickFromGallery();
        break;
      case _ComposerAction.capturePhoto:
        await _mediaController.pickFromCamera();
        break;
      case _ComposerAction.pickAudio:
        await _mediaController.pickAudio(voiceMemo: false);
        break;
    }
    if (mounted) {
      setState(() {
        _showToolbar = false;
      });
      _toolbarController.reverse();
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if ((text.isEmpty && !_mediaController.hasAttachments) || widget.isSending) {
      return;
    }

    final submission = ComposerSubmission(
      text: text,
      attachments: List<ChatMediaAttachment>.from(_mediaController.attachments),
    );

    widget.onSend(submission);
    _controller.clear();
    _hasText.value = false;
    _mediaController.clear();
    _focusNode.requestFocus();
  }
}

class _AttachmentPreviewStrip extends StatelessWidget {
  const _AttachmentPreviewStrip({
    required this.attachments,
    required this.onRemove,
  });

  final List<ChatMediaAttachment> attachments;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _AttachmentPreviewTile(
            attachment: attachment,
            onRemove: () => onRemove(attachment.id),
          );
        },
      ),
    );
  }
}

class _AttachmentPreviewTile extends StatelessWidget {
  const _AttachmentPreviewTile({
    required this.attachment,
    required this.onRemove,
  });

  final ChatMediaAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget preview;

    switch (attachment.type) {
      case ChatMediaType.image:
        preview = ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.memory(
            attachment.bytes,
            fit: BoxFit.cover,
            width: 96,
            height: 96,
          ),
        );
        break;
      case ChatMediaType.video:
        preview = _PlaceholderPreview(
          icon: Icons.play_circle_outline,
          label: attachment.fileName,
          color: theme.colorScheme.primary,
        );
        break;
      case ChatMediaType.audio:
      case ChatMediaType.voice:
        preview = _AudioPreview(attachment: attachment);
        break;
      case ChatMediaType.file:
        preview = _PlaceholderPreview(
          icon: Icons.insert_drive_file,
          label: attachment.fileName,
          color: theme.colorScheme.tertiary,
        );
        break;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: preview,
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: theme.colorScheme.surface,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderPreview extends StatelessWidget {
  const _PlaceholderPreview({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPreview extends StatelessWidget {
  const _AudioPreview({required this.attachment});

  final ChatMediaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = attachment.type == ChatMediaType.voice ? Icons.mic : Icons.audiotrack;
    final waveform = attachment.waveform ?? const [];
    final bars = waveform.isEmpty
        ? const <double>[0.2, 0.5, 0.3, 0.6, 0.4]
        : waveform.take(24).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final sample in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: math.max(12, 40 * sample),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.isSending,
    this.onPressed,
  });

  final bool isEnabled;
  final bool isSending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedScale(
      scale: isEnabled || isSending ? 1 : 0.92,
      duration: const Duration(milliseconds: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ChatTheme.selfBubbleGradient(theme),
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          iconSize: 22,
          padding: const EdgeInsets.all(12),
          icon: isSending
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                )
              : const Icon(Icons.send_rounded),
          color: theme.colorScheme.onPrimaryContainer,
          onPressed: isEnabled ? onPressed : null,
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withOpacity(0.14)
                  : theme.colorScheme.surfaceVariant.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

enum _ComposerAction { attachFile, addPhoto, capturePhoto, pickAudio }

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({required this.onSelect});

  final ValueChanged<_ComposerAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = {
      _ComposerAction.attachFile: 'Legg ved fil',
      _ComposerAction.addPhoto: 'Velg bilder',
      _ComposerAction.capturePhoto: 'Ta bilde',
      _ComposerAction.pickAudio: 'Velg lyd',
    };
    final icons = {
      _ComposerAction.attachFile: Icons.attach_file,
      _ComposerAction.addPhoto: Icons.photo_outlined,
      _ComposerAction.capturePhoto: Icons.camera_alt_outlined,
      _ComposerAction.pickAudio: Icons.music_note,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          for (final action in _ComposerAction.values)
            _ToolbarChip(
              icon: icons[action]!,
              label: labels[action]!,
              onTap: () => onSelect(action),
            ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface.withOpacity(0.9),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
