import 'package:flutter/material.dart';

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
  bool _showToolbar = false;
  late final AnimationController _toolbarController;

  @override
  void initState() {
    super.initState();
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _toolbarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sendEnabled = _controller.text.trim().isNotEmpty && !widget.isSending;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.errorMessage!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ComposerIconButton(
                        icon: Icons.add_circle_outline,
                        tooltip: 'Flere valg',
                        onPressed: _toggleToolbar,
                        isActive: _showToolbar,
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 6,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Skriv en melding…',
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      _ComposerIconButton(
                        icon: Icons.mic_none_rounded,
                        tooltip: 'Ta opp lyd',
                        onPressed: () {},
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(right: 10, bottom: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primaryContainer,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: IconButton(
                            iconSize: 22,
                            padding: const EdgeInsets.all(12),
                            icon: widget.isSending
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            color: theme.colorScheme.onPrimary,
                            onPressed: sendEnabled ? _handleSend : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizeTransition(
                    sizeFactor: CurvedAnimation(
                      parent: _toolbarController,
                      curve: Curves.easeOut,
                    ),
                    axisAlignment: -1,
                    child: _ComposerToolbar(onSelect: _handleToolbarAction),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  void _handleToolbarAction(_ComposerAction action) {
    switch (action) {
      case _ComposerAction.attachFile:
        // TODO: implement attachments
        break;
      case _ComposerAction.addPhoto:
        break;
      case _ComposerAction.insertEmoji:
        break;
      case _ComposerAction.schedule:
        break;
    }
    _toggleToolbar();
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            radius: 24,
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withOpacity(0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ),
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
    const actions = _ComposerAction.values;
    final labels = {
      _ComposerAction.attachFile: 'Legg ved fil',
      _ComposerAction.addPhoto: 'Bilde',
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceVariant,
            theme.colorScheme.surface.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        spacing: 12,
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
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
