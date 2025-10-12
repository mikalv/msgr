part of 'package:messngr/features/chat/widgets/chat_composer.dart';

class _ComposerTextField extends StatelessWidget {
  const _ComposerTextField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.isSending,
    required this.placeholder,
    required this.minLines,
    required this.maxLines,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool isSending;
  final String placeholder;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      minLines: minLines,
      maxLines: maxLines,
      enabled: !isSending,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: placeholder,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
    final enabled = onTap != null;
    final color = isActive
        ? theme.colorScheme.primary
        : enabled
            ? theme.colorScheme.onSurfaceVariant
            : theme.disabledColor;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isEnabled,
    required this.isSending,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isSending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = isEnabled && !isSending;
    return SizedBox(
      height: 44,
      width: 44,
      child: Semantics(
        button: true,
        enabled: isActive,
        label: isSending ? 'Sender melding' : 'Send melding',
        child: FilledButton(
          onPressed: isActive ? onPressed : null,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: isSending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.send_rounded),
        ),
      ),
    );
  }
}

class _VoiceRecorderButton extends StatelessWidget {
  const _VoiceRecorderButton({
    required this.isRecording,
    required this.onStart,
    required this.onStop,
    this.isEnabled = true,
  });

  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canInteract = isRecording || isEnabled;
    final color = !canInteract
        ? theme.disabledColor
        : isRecording
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: isRecording ? 'Stopp opptak' : 'Ta opp lyd',
      child: InkResponse(
        radius: 24,
        onTap: !canInteract
            ? null
            : (isRecording
                ? onStop
                : onStart),
        child: Icon(
          isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
          color: color,
        ),
      ),
    );
  }
}
