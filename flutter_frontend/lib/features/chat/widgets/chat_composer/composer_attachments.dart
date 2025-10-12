part of 'package:messngr/features/chat/widgets/chat_composer.dart';

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.attachments,
    required this.voiceNote,
    required this.onRemoveAttachment,
    required this.onRemoveVoiceNote,
  });

  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final ValueChanged<ComposerAttachment> onRemoveAttachment;
  final VoidCallback onRemoveVoiceNote;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty && voiceNote == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AttachmentChip(
                  attachment: attachment,
                  onRemove: () => onRemoveAttachment(attachment),
                ),
              ),
            if (voiceNote != null)
              _VoiceNoteChip(
                note: voiceNote!,
                onRemove: onRemoveVoiceNote,
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.onRemove});

  final ComposerAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputChip(
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.cancel, size: 18),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attachment.name,
            style:
                theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            attachment.humanSize,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _VoiceNoteChip extends StatelessWidget {
  const _VoiceNoteChip({required this.note, required this.onRemove});

  final ComposerVoiceNote note;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.graphic_eq_rounded),
      label: Text('Stemmeopptak • ${note.formattedDuration}'),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.cancel, size: 18),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
