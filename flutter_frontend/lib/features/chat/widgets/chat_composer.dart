import 'package:flutter/material.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.isSending,
    this.errorMessage,
  });

  final ValueChanged<String> onSend;
  final bool isSending;
  final String? errorMessage;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<bool> _hasText = ValueNotifier<bool>(false);

  bool _showToolbar = false;
  late final AnimationController _toolbarController;

  @override
  void initState() {
    super.initState();
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    _toolbarController.dispose();
    _hasText.dispose();
    super.dispose();
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: ChatTheme.composerDecoration(theme),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            hintText: 'Skriv noe strålende …',
                            border: InputBorder.none,
                            hintStyle: theme.textTheme.bodyLarge?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ComposerIconButton(
                      icon: Icons.mic_none_rounded,
                      tooltip: 'Spill inn lydklipp',
                      onTap: () {},
                    ),
                    const SizedBox(width: 4),
                    ValueListenableBuilder<bool>(
                      valueListenable: _hasText,
                      builder: (context, hasText, _) {
                        final enabled = hasText && !widget.isSending;
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
          ),
        ],
      ),
    );
  }

  void _handleTextChanged() {
    _hasText.value = _controller.text.trim().isNotEmpty;
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

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleToolbarAction(_ComposerAction action) {
    // Actions are placeholders for future rich input options.
    switch (action) {
      case _ComposerAction.attachFile:
      case _ComposerAction.addPhoto:
      case _ComposerAction.insertEmoji:
      case _ComposerAction.schedule:
        break;
    }
    _toggleToolbar();
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

enum _ComposerAction { attachFile, addPhoto, insertEmoji, schedule }

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({required this.onSelect});

  final ValueChanged<_ComposerAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = _ComposerAction.values;
    final labels = {
      _ComposerAction.attachFile: 'Legg ved fil',
      _ComposerAction.addPhoto: 'Del bilde',
      _ComposerAction.insertEmoji: 'Emoji',
      _ComposerAction.schedule: 'Planlegg',
    };
    final icons = {
      _ComposerAction.attachFile: Icons.attach_file,
      _ComposerAction.addPhoto: Icons.photo_outlined,
      _ComposerAction.insertEmoji: Icons.emoji_emotions_outlined,
      _ComposerAction.schedule: Icons.schedule_send,
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
          for (final action in actions)
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
