import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';

enum _FormattingAction { bold, italic, strike, code, bullet, quote }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.isSending,
    this.errorMessage,
    this.availableCommands = SlashCommand.defaults,
    this.availableMentions = ComposerMention.defaults,
    ChatVoiceRecorder? voiceRecorder,
    this.filePicker,
  }) : voiceRecorder = voiceRecorder ?? SimulatedChatVoiceRecorder();

  final ChatComposerController controller;
  final ValueChanged<ChatComposerResult> onSubmit;
  final bool isSending;
  final String? errorMessage;
  final List<SlashCommand> availableCommands;
  final List<ComposerMention> availableMentions;
  final ChatVoiceRecorder voiceRecorder;
  final FilePickerPlatform? filePicker;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode;
  late final TextEditingController _textController;
  late final AnimationController _expanderController;
  late ChatComposerValue _value;
  StreamSubscription<ChatVoiceState>? _voiceSubscription;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isDropHover = false;

  bool _showEmoji = false;
  int _commandSelection = 0;
  int _mentionSelection = 0;
  int? _mentionTriggerIndex;
  String _mentionQuery = '';
  List<ComposerMention> _mentionCandidates = const <ComposerMention>[];

  List<SlashCommand> get _matchedCommands {
    final text = _textController.text;
    if (!text.startsWith('/')) return const [];
    final query = text.substring(1).toLowerCase();
    if (query.isEmpty) return widget.availableCommands;
    return widget.availableCommands
        .where((command) =>
            command.name.toLowerCase().startsWith(query) ||
            command.description.toLowerCase().contains(query))
        .toList();
  }

  bool get _shouldShowCommandPalette => _matchedCommands.isNotEmpty;
  bool get _shouldShowMentionPalette =>
      _mentionTriggerIndex != null && _mentionCandidates.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
    _textController = TextEditingController(text: widget.controller.value.text);
    _expanderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _value = widget.controller.value;
    widget.controller.addListener(_handleControllerChanged);
    _textController.addListener(_handleDraftChanged);
    _voiceSubscription =
        widget.voiceRecorder.stateStream.listen(_handleVoiceState);
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _value = widget.controller.value;
      _textController.text = _value.text;
    }
  }

  @override
  void dispose() {
    _voiceSubscription?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    _textController.dispose();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _expanderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 640;

    final attachments = _value.attachments;
    final voiceNote = _value.voiceNote;
    final showFormatting =
        _focusNode.hasFocus || _textController.text.trim().isNotEmpty;

    if (_showEmoji) {
      _expanderController.forward();
    } else {
      _expanderController.reverse();
    }

    final baseDecoration = ChatTheme.composerDecoration(theme);
    final decoration = baseDecoration.copyWith(
      border: _isDropHover
          ? Border.all(
              color: theme.colorScheme.primary.withOpacity(0.35), width: 2)
          : baseDecoration.border,
    );

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDropHover = true),
      onDragExited: (_) => setState(() => _isDropHover = false),
      onDragDone: _handleDrop,
      /*child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.errorMessage != null || _value.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ErrorBanner(message: widget.errorMessage ?? _value.error!),
              ),
            if (attachments.isNotEmpty || voiceNote != null)
              _AttachmentPreview(
                attachments: attachments,
                voiceNote: voiceNote,
                onRemoveAttachment: _removeAttachment,
                onRemoveVoiceNote: _clearVoiceNote,
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: decoration,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: isCompact ? 10 : 12,
              ),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter, control: true):
                      _submit,
                  const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
                  const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      _selectNextCommand,
                  const SingleActivator(LogicalKeyboardKey.arrowUp):
                      _selectPreviousCommand,
                },
                child: Focus(
                  autofocus: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [*/
      SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.errorMessage != null || _value.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    _ErrorBanner(message: widget.errorMessage ?? _value.error!),
              ),
            if (attachments.isNotEmpty || voiceNote != null)
              _AttachmentPreview(
                attachments: attachments,
                voiceNote: voiceNote,
                onRemoveAttachment: _removeAttachment,
                onRemoveVoiceNote: _clearVoiceNote,
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    color: theme.shadowColor.withOpacity(0.08),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: isCompact ? 10 : 12,
              ),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter,
                      control: true): () => _submit(forceSend: true),
                  const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                      () => _submit(forceSend: true),
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _handleEscape,
                  const SingleActivator(LogicalKeyboardKey.arrowDown):
                      _selectNextCommand,
                  const SingleActivator(LogicalKeyboardKey.arrowUp):
                      _selectPreviousCommand,
                },
                child: Focus(
                  autofocus: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ComposerIconButton(
                            icon: Icons.emoji_emotions_outlined,
                            tooltip: 'Emoji',
                            isActive: _showEmoji,
                            onTap: _toggleEmoji,
                          ),
                          if (!isCompact) const SizedBox(width: 8),
                          _ComposerIconButton(
                            icon: Icons.attach_file,
                            tooltip: 'Legg ved fil',
                            onTap: _pickFiles,
                          ),
                          const SizedBox(width: 8),
                          _ComposerIconButton(
                            icon: Icons.camera_alt_outlined,
                            tooltip: 'Åpne kamera',
                            onTap: _capturePhoto,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ComposerTextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              onSubmitted: (_) => _submit(),
                              isSending: widget.isSending,
                              placeholder: isCompact
                                  ? 'Melding'
                                  : 'Del en oppdatering eller skriv / for kommandoer',
                            ),
                          ),
                          const SizedBox(width: 12),
                          _VoiceRecorderButton(
                            isRecording: widget.voiceRecorder.isRecording,
                            onStart: _startRecording,
                            onStop: _stopRecording,
                          ),
                          const SizedBox(width: 8),
                          _SendButton(
                            isEnabled: _canSend,
                            isSending: widget.isSending,
                            onPressed:
                                _canSend ? () => _submit(forceSend: true) : null,
                          ),
                        ],
                      ),
                      if (showFormatting)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _ComposerIconButton(
                                  icon: Icons.format_bold,
                                  tooltip: 'Fet tekst',
                                  onTap: () =>
                                      _applyFormatting(_FormattingAction.bold),
                                ),
                                const SizedBox(width: 8),
                                _ComposerIconButton(
                                  icon: Icons.format_italic,
                                  tooltip: 'Kursiv',
                                  onTap: () => _applyFormatting(
                                      _FormattingAction.italic),
                                ),
                                const SizedBox(width: 8),
                                _ComposerIconButton(
                                  icon: Icons.format_strikethrough,
                                  tooltip: 'Gjennomstreking',
                                  onTap: () => _applyFormatting(
                                      _FormattingAction.strike),
                                ),
                                const SizedBox(width: 8),
                                _ComposerIconButton(
                                  icon: Icons.code,
                                  tooltip: 'Kode',
                                  onTap: () =>
                                      _applyFormatting(_FormattingAction.code),
                                ),
                                const SizedBox(width: 8),
                                _ComposerIconButton(
                                  icon: Icons.format_list_bulleted,
                                  tooltip: 'Punktliste',
                                  onTap: () => _applyFormatting(
                                      _FormattingAction.bullet),
                                ),
                                const SizedBox(width: 8),
                                _ComposerIconButton(
                                  icon: Icons.format_quote,
                                  tooltip: 'Sitér',
                                  onTap: () =>
                                      _applyFormatting(_FormattingAction.quote),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_shouldShowMentionPalette)
                        _MentionPalette(
                          mentions: _mentionCandidates,
                          highlightedIndex: _mentionSelection,
                          query: _mentionQuery,
                          onSelect: _applyMention,
                        ),
                      if (_shouldShowCommandPalette)
                        _CommandPalette(
                          commands: _matchedCommands,
                          highlightedIndex: _commandSelection,
                          onSelect: _applyCommand,
                        ),
                      SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: _expanderController,
                          curve: Curves.easeOut,
                        ),
                        axisAlignment: -1,
                        child: _EmojiPicker(onSelect: _insertEmoji),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSend {
    if (widget.isSending) return false;
    return _textController.text.trim().isNotEmpty ||
        _value.attachments.isNotEmpty ||
        _value.voiceNote != null;
  }

  void _handleControllerChanged() {
    final next = widget.controller.value;
    if (next.text != _textController.text) {
      _textController
        ..text = next.text
        ..selection = TextSelection.collapsed(offset: next.text.length);
    }
    setState(() {
      _value = next;
    });
  }

  Future<void> _pickFiles() async {
    try {
      final picker = widget.filePicker ?? FilePicker.platform;
      final result = await picker.pickFiles(allowMultiple: true);
      if (result == null) return;
      final attachments = result.files
          .map((file) => ComposerAttachment.fromPlatformFile(file))
          .where((attachment) => attachment.bytes != null)
          .toList();
      if (attachments.isEmpty) return;
      widget.controller.addAttachments(attachments);
    } on PlatformException catch (error) {
      widget.controller.setError('Kunne ikke hente filer: ${error.message}');
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    setState(() => _isDropHover = false);
    if (details.files.isEmpty) return;

    try {
      final attachments = <ComposerAttachment>[];
      for (final file in details.files) {
        final attachment = await ComposerAttachment.fromXFile(file);
        if (attachment != null && attachment.bytes != null) {
          attachments.add(attachment);
        }
      }
      if (attachments.isEmpty) return;
      if (!mounted) return;
      widget.controller.addAttachments(attachments);
    } catch (error) {
      if (!mounted) return;
      widget.controller.setError('Kunne ikke slippe filer.');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;
      final attachment = await ComposerAttachment.fromXFile(file);
      if (attachment != null) {
        widget.controller.addAttachments([attachment]);
      }
    } on PlatformException catch (error) {
      widget.controller.setError('Kunne ikke åpne kamera: ${error.message}');
    } catch (error) {
      widget.controller.setError('Klarte ikke å hente bildet.');
    }
  }

  void _removeAttachment(ComposerAttachment attachment) {
    widget.controller.removeAttachment(attachment);
  }

  void _clearVoiceNote() {
    widget.controller.clearVoiceNote();
  }

  Future<void> _startRecording() async {
    await widget.voiceRecorder.start();
  }

  Future<void> _stopRecording() async {
    final note = await widget.voiceRecorder.stop();
    if (!mounted) return;
    widget.controller.setVoiceNote(note);
  }

  void _handleVoiceState(ChatVoiceState state) {
    if (!mounted) return;
    setState(() {
      // Force rebuild to update recording indicator.
    });
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleDraftChanged() {
    final text = _textController.text;
    widget.controller.setText(text);
    widget.controller.syncMentionsWithText(text);
    _updateMentionSuggestions();
    if (_shouldShowCommandPalette) {
      setState(() {
        _commandSelection = 0;
      });
    }
  }

  void _updateMentionSuggestions() {
    final selection = _textController.selection;
    if (!selection.isValid) {
      if (_shouldShowMentionPalette) {
        setState(_clearMentionPalette);
      }
      return;
    }

    final text = _textController.text;
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      if (_shouldShowMentionPalette) {
        setState(_clearMentionPalette);
      }
      return;
    }

    final beforeCursor = text.substring(0, cursor);
    var index = cursor - 1;
    var found = false;
    while (index >= 0) {
      final char = beforeCursor.substring(index, index + 1);
      if (char == '@') {
        final previous = index > 0 ? beforeCursor.substring(index - 1, index) : ' ';
        final isValidBoundary = previous.trim().isEmpty || previous == '(';
        if (!isValidBoundary) {
          break;
        }
        final rawQuery = beforeCursor.substring(index + 1);
        if (rawQuery.contains(RegExp(r'[\s@]'))) {
          break;
        }
        final matches = widget.availableMentions
            .where((mention) => mention.matches(rawQuery))
            .toList(growable: false);
        setState(() {
          _mentionTriggerIndex = index;
          _mentionQuery = rawQuery;
          _mentionCandidates = matches;
          _mentionSelection = 0;
        });
        found = true;
        break;
      }
      if (char.trim().isEmpty) {
        break;
      }
      index--;
    }

    if (!found && _shouldShowMentionPalette) {
      setState(_clearMentionPalette);
    }
  }

  void _clearMentionPalette() {
    _mentionTriggerIndex = null;
    _mentionQuery = '';
    _mentionCandidates = const <ComposerMention>[];
    _mentionSelection = 0;
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
  }

  void _insertEmoji(String emoji) {
    final selection = _textController.selection;
    final text = _textController.text;
    final newText = selection.isValid
        ? text.replaceRange(
            selection.start,
            selection.end,
            emoji,
          )
        : '$text$emoji';
    _textController
      ..text = newText
      ..selection = TextSelection.collapsed(
        offset:
            selection.isValid ? selection.start + emoji.length : newText.length,
      );
    widget.controller.setText(newText);
    _focusNode.requestFocus();
  }

  void _handleEscape() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      return;
    }
    if (_shouldShowMentionPalette) {
      setState(_clearMentionPalette);
      return;
    }
    if (_shouldShowCommandPalette) {
      setState(() {
        _textController.clear();
        _commandSelection = 0;
      });
    }
  }

  void _selectNextCommand() {
    if (_shouldShowMentionPalette) {
      setState(() {
        _mentionSelection =
            (_mentionSelection + 1).clamp(0, _mentionCandidates.length - 1);
      });
      return;
    }
    if (!_shouldShowCommandPalette) return;
    setState(() {
      _commandSelection =
          (_commandSelection + 1).clamp(0, _matchedCommands.length - 1);
    });
  }

  void _selectPreviousCommand() {
    if (_shouldShowMentionPalette) {
      setState(() {
        _mentionSelection =
            (_mentionSelection - 1).clamp(0, _mentionCandidates.length - 1);
      });
      return;
    }
    if (!_shouldShowCommandPalette) return;
    setState(() {
      _commandSelection =
          (_commandSelection - 1).clamp(0, _matchedCommands.length - 1);
    });
  }

  void _applyCommand(SlashCommand command) {
    final replacement = '${command.name} ';
    _textController
      ..text = replacement
      ..selection = TextSelection.collapsed(offset: replacement.length);
    widget.controller.setText(_textController.text);
    widget.controller.setCommand(command);
    setState(() {
      _commandSelection = 0;
    });
  }

  void _applyMention(ComposerMention mention) {
    final triggerIndex = _mentionTriggerIndex;
    if (triggerIndex == null) {
      return;
    }
    final selection = _textController.selection;
    final end = selection.isValid ? selection.baseOffset : _textController.text.length;
    final replacement = '@${mention.handle} ';
    final text = _textController.text;
    final newText = text.replaceRange(triggerIndex, end, replacement);
    _textController
      ..text = newText
      ..selection = TextSelection.collapsed(offset: triggerIndex + replacement.length);
    widget.controller.setText(newText);
    widget.controller.addMention(mention);
    widget.controller.syncMentionsWithText(newText);
    setState(_clearMentionPalette);
    _focusNode.requestFocus();
  }

  void _applyFormatting(_FormattingAction action) {
    switch (action) {
      case _FormattingAction.bold:
        _applyInlineFormat(prefix: '**', suffix: '**');
        break;
      case _FormattingAction.italic:
        _applyInlineFormat(prefix: '_', suffix: '_');
        break;
      case _FormattingAction.strike:
        _applyInlineFormat(prefix: '~~', suffix: '~~');
        break;
      case _FormattingAction.code:
        _applyInlineFormat(prefix: '`', suffix: '`', placeholder: 'kode');
        break;
      case _FormattingAction.bullet:
        _applyLinePrefix('- ');
        break;
      case _FormattingAction.quote:
        _applyLinePrefix('> ');
        break;
    }
  }

  void _applyInlineFormat({
    required String prefix,
    required String suffix,
    String placeholder = 'tekst',
  }) {
    final selection = _textController.selection;
    final text = _textController.text;
    if (!selection.isValid) {
      final insertion = '$prefix$placeholder$suffix';
      final newText = '$text$insertion';
      final start = text.length + prefix.length;
      final end = start + placeholder.length;
      _textController
        ..text = newText
        ..selection = TextSelection(baseOffset: start, extentOffset: end);
    } else if (selection.isCollapsed) {
      final insertion = '$prefix$placeholder$suffix';
      final newText = text.replaceRange(selection.start, selection.end, insertion);
      final start = selection.start + prefix.length;
      final end = start + placeholder.length;
      _textController
        ..text = newText
        ..selection = TextSelection(baseOffset: start, extentOffset: end);
    } else {
      final selected = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selected$suffix',
      );
      final start = selection.start + prefix.length;
      final end = selection.end + prefix.length;
      _textController
        ..text = newText
        ..selection = TextSelection(baseOffset: start, extentOffset: end);
    }
    widget.controller.setText(_textController.text);
    _focusNode.requestFocus();
  }

  void _applyLinePrefix(String prefix) {
    final selection = _textController.selection;
    final text = _textController.text;
    if (!selection.isValid) {
      final newText = text.isEmpty ? prefix : '$text\n$prefix';
      _textController
        ..text = newText
        ..selection = TextSelection.collapsed(offset: newText.length);
      widget.controller.setText(newText);
      _focusNode.requestFocus();
      return;
    }

    if (selection.isCollapsed) {
      final cursor = selection.start;
      final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      _textController
        ..text = newText
        ..selection = TextSelection.collapsed(offset: cursor + prefix.length);
      widget.controller.setText(newText);
      _focusNode.requestFocus();
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final lines = selected.split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        buffer.write(prefix.trimRight());
      } else if (line.trimLeft().startsWith(prefix.trim())) {
        buffer.write(line);
      } else {
        buffer.write('$prefix$line');
      }
      if (i != lines.length - 1) {
        buffer.write('\n');
      }
    }
    final formatted = buffer.toString();
    final newText = text.replaceRange(selection.start, selection.end, formatted);
    _textController
      ..text = newText
      ..selection = TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + formatted.length,
      );
    widget.controller.setText(newText);
    _focusNode.requestFocus();
  }

  void _submit({bool forceSend = false}) {
    if (_shouldShowMentionPalette && !forceSend) {
      if (_mentionCandidates.isNotEmpty) {
        _applyMention(_mentionCandidates[_mentionSelection]);
      }
      return;
    }
    if (!_canSend) return;
    final command =
        _shouldShowCommandPalette ? _matchedCommands[_commandSelection] : null;
    final result = widget.controller.buildResult(command: command);
    widget.onSubmit(result);
    setState(() {
      _showEmoji = false;
      _commandSelection = 0;
      _clearMentionPalette();
    });
    _focusNode.requestFocus();
  }
}

class _ComposerTextField extends StatelessWidget {
  const _ComposerTextField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.isSending,
    required this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool isSending;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.send,
      minLines: 1,
      maxLines: 6,
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
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Icon(
          icon,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
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
    return SizedBox(
      height: 44,
      width: 44,
      child: FilledButton(
        onPressed: isEnabled && !isSending ? onPressed : null,
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
    );
  }
}

class _CommandPalette extends StatelessWidget {
  const _CommandPalette({
    required this.commands,
    required this.highlightedIndex,
    required this.onSelect,
  });

  final List<SlashCommand> commands;
  final int highlightedIndex;
  final ValueChanged<SlashCommand> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < commands.length; i++)
            _CommandTile(
              command: commands[i],
              isHighlighted: i == highlightedIndex,
              onTap: () => onSelect(commands[i]),
            ),
        ],
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({
    required this.command,
    required this.isHighlighted,
    required this.onTap,
  });

  final SlashCommand command;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isHighlighted
          ? theme.colorScheme.primary.withOpacity(0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                command.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  command.description,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.onSelect});

  static const _emoji = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😅',
    '😊',
    '😍',
    '🤩',
    '😎',
    '🤔',
    '🙌',
    '👍',
    '👏',
    '🙏',
    '🔥',
    '🎉',
    '💡',
    '🚀',
    '❤️',
    '🤝',
  ];

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final emoji in _emoji)
            GestureDetector(
              onTap: () => onSelect(emoji),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
        ],
      ),
    );
  }
}

class _VoiceRecorderButton extends StatelessWidget {
  const _VoiceRecorderButton({
    required this.isRecording,
    required this.onStart,
    required this.onStop,
  });

  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: isRecording ? 'Stopp opptak' : 'Ta opp lyd',
      child: InkResponse(
        radius: 24,
        onTap: isRecording ? onStop : onStart,
        child: Icon(
          isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
          color: isRecording
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MentionPalette extends StatelessWidget {
  const _MentionPalette({
    required this.mentions,
    required this.highlightedIndex,
    required this.query,
    required this.onSelect,
  });

  final List<ComposerMention> mentions;
  final int highlightedIndex;
  final String query;
  final ValueChanged<ComposerMention> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (mentions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Nevner: @$query',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (var i = 0; i < mentions.length; i++)
            InkWell(
              onTap: () => onSelect(mentions[i]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 18 : 0),
                bottom: Radius.circular(i == mentions.length - 1 ? 18 : 0),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i == highlightedIndex
                      ? theme.colorScheme.primary.withOpacity(0.12)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.18),
                      child: Text(
                        mentions[i].initials,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mentions[i].displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '@${mentions[i].handle}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_return, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
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

class ChatComposerController extends ChangeNotifier {
  ChatComposerController({ChatComposerValue? value})
      : _value = value ?? ChatComposerValue.empty();

  ChatComposerValue _value;

  ChatComposerValue get value => _value;

  void setText(String text) {
    final shouldClearCommand = !text.trimLeft().startsWith('/');
    _update(
      _value.copyWith(
        text: text,
        clearCommand: shouldClearCommand,
      ),
    );
  }

  void setError(String? error) {
    _update(_value.copyWith(error: error));
  }

  void addAttachments(List<ComposerAttachment> attachments) {
    _update(
      _value.copyWith(
        attachments: [..._value.attachments, ...attachments],
        error: null,
      ),
    );
  }

  void removeAttachment(ComposerAttachment attachment) {
    _update(
      _value.copyWith(
        attachments:
            _value.attachments.where((a) => a.id != attachment.id).toList(),
      ),
    );
  }

  void clearVoiceNote() {
    _update(_value.copyWith(clearVoiceNote: true));
  }

  void setVoiceNote(ComposerVoiceNote note) {
    _update(_value.copyWith(voiceNote: note));
  }

  void setCommand(SlashCommand? command) {
    _update(
      _value.copyWith(
        command: command,
        clearCommand: command == null,
      ),
    );
  }

  void addMention(ComposerMention mention) {
    final mentions = [..._value.mentions];
    if (mentions.any((m) => m.id == mention.id)) {
      return;
    }
    mentions.add(mention);
    _update(_value.copyWith(mentions: mentions));
  }

  void syncMentionsWithText(String text) {
    if (_value.mentions.isEmpty) {
      return;
    }
    final active = _value.mentions
        .where((mention) => text.contains('@${mention.handle}'))
        .toList();
    if (!listEquals(active, _value.mentions)) {
      _update(_value.copyWith(mentions: active));
    }
  }

  ChatComposerResult buildResult({SlashCommand? command}) {
    return ChatComposerResult(
      text: _value.text.trim(),
      attachments: List.unmodifiable(_value.attachments),
      voiceNote: _value.voiceNote,
      command: command ?? _value.command,
      mentions: List.unmodifiable(_value.mentions),
    );
  }

  void clear() {
    _update(ChatComposerValue.empty());
  }

  void _update(ChatComposerValue next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }
}

class ChatComposerValue {
  const ChatComposerValue({
    required this.text,
    required this.attachments,
    required this.voiceNote,
    required this.mentions,
    this.error,
    this.command,
  });

  static const _unset = Object();

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final List<ComposerMention> mentions;
  final String? error;
  final SlashCommand? command;

  factory ChatComposerValue.empty() => const ChatComposerValue(
        text: '',
        attachments: [],
        voiceNote: null,
        mentions: [],
        error: null,
        command: null,
      );

  ChatComposerValue copyWith({
    String? text,
    List<ComposerAttachment>? attachments,
    ComposerVoiceNote? voiceNote,
    bool clearVoiceNote = false,
    Object? error = _unset,
    SlashCommand? command,
    bool clearCommand = false,
    List<ComposerMention>? mentions,
    bool clearMentions = false,
  }) {
    final resolvedError = error == _unset ? this.error : error as String?;
    final resolvedCommand = clearCommand ? null : (command ?? this.command);
    final resolvedMentions =
        clearMentions ? <ComposerMention>[] : (mentions ?? this.mentions);
    return ChatComposerValue(
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      voiceNote: clearVoiceNote ? null : (voiceNote ?? this.voiceNote),
      mentions: resolvedMentions,
      error: resolvedError,
      command: resolvedCommand,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatComposerValue &&
        other.text == text &&
        listEquals(other.attachments, attachments) &&
        other.voiceNote == voiceNote &&
        listEquals(other.mentions, mentions) &&
        other.error == error &&
        other.command == command;
  }

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAll(attachments),
        voiceNote,
        Object.hashAll(mentions),
        error,
        command,
      );
}

class ChatComposerResult {
  const ChatComposerResult({
    required this.text,
    required this.attachments,
    this.voiceNote,
    this.command,
    required this.mentions,
  });

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final SlashCommand? command;
  final List<ComposerMention> mentions;

  bool get hasCommand => command != null;
  bool get hasMentions => mentions.isNotEmpty;
}

class ComposerAttachment {
  ComposerAttachment({
    required this.id,
    required this.name,
    required this.size,
    this.bytes,
    this.path,
    this.mimeType,
  });

  factory ComposerAttachment.fromPlatformFile(PlatformFile file) {
    final id = file.identifier ??
        '${file.name}-${DateTime.now().microsecondsSinceEpoch}';
    final bytes = file.bytes;
    final mimeType = lookupMimeType(file.name, headerBytes: bytes);
    if (bytes == null) {
      return ComposerAttachment(
          id: id,
          name: file.name,
          size: file.size,
          path: file.path,
          mimeType: mimeType);
    }
    return ComposerAttachment(
      id: id,
      name: file.name,
      size: file.size,
      bytes: bytes,
      path: file.path,
      mimeType: mimeType,
    );
  }

  static Future<ComposerAttachment?> fromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(file.name, headerBytes: bytes);
      final id = '${file.name}-${DateTime.now().microsecondsSinceEpoch}';
      return ComposerAttachment(
        id: id,
        name: file.name,
        size: bytes.length,
        bytes: bytes,
        path: file.path,
        mimeType: mimeType,
      );
    } catch (_) {
      return null;
    }
  }

  final String id;
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;
  final String? mimeType;

  bool get isImage => mimeType?.startsWith('image/') ?? false;
  bool get isVideo => mimeType?.startsWith('video/') ?? false;
  bool get isAudio => mimeType?.startsWith('audio/') ?? false;

  String get humanSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ComposerAttachment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class ComposerVoiceNote {
  const ComposerVoiceNote({required this.duration, required this.bytes});

  final Duration duration;
  final Uint8List bytes;

  String get formattedDuration =>
      '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
}

class SlashCommand {
  const SlashCommand(this.name, this.description);

  final String name;
  final String description;

  static const defaults = <SlashCommand>[
    SlashCommand('/giphy', 'Del en GIF'),
    SlashCommand('/standup', 'Start daglig standup'),
    SlashCommand('/remind', 'Opprett en påminnelse'),
    SlashCommand('/meeting', 'Planlegg et møte'),
    SlashCommand('/poll', 'Start en avstemning'),
  ];
}

class ComposerMention {
  const ComposerMention({
    required this.id,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String handle;
  final String? avatarUrl;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return handle.isNotEmpty ? handle.substring(0, 1).toUpperCase() : '?';
    }
    final buffer = StringBuffer();
    for (final part in parts.take(2)) {
      buffer.write(part.substring(0, 1).toUpperCase());
    }
    return buffer.toString();
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return displayName.toLowerCase().contains(lower) ||
        handle.toLowerCase().contains(lower);
  }

  static const defaults = <ComposerMention>[
    ComposerMention(id: '1', displayName: 'Ada Lovelace', handle: 'ada'),
    ComposerMention(id: '2', displayName: 'Nikola Tesla', handle: 'tesla'),
    ComposerMention(id: '3', displayName: 'Katherine Johnson', handle: 'kjohnson'),
    ComposerMention(id: '4', displayName: 'Jo Nesbø', handle: 'jnesbo'),
    ComposerMention(id: '5', displayName: 'Astrid Lindgren', handle: 'astrid'),
  ];
}

abstract class ChatVoiceRecorder {
  bool get isRecording;
  Stream<ChatVoiceState> get stateStream;
  Future<void> start();
  Future<ComposerVoiceNote> stop();
}

class ChatVoiceState {
  const ChatVoiceState({required this.isRecording});

  final bool isRecording;
}

class SimulatedChatVoiceRecorder implements ChatVoiceRecorder {
  final StreamController<ChatVoiceState> _controller =
      StreamController<ChatVoiceState>.broadcast();
  final Random _random = Random();
  Stopwatch? _stopwatch;

  @override
  bool get isRecording => _stopwatch?.isRunning == true;

  @override
  Stream<ChatVoiceState> get stateStream => _controller.stream;

  @override
  Future<void> start() async {
    _stopwatch ??= Stopwatch();
    _stopwatch!.start();
    _controller.add(const ChatVoiceState(isRecording: true));
  }

  @override
  Future<ComposerVoiceNote> stop() async {
    _stopwatch?.stop();
    final duration = _stopwatch?.elapsed ?? Duration.zero;
    _stopwatch?.reset();
    _controller.add(const ChatVoiceState(isRecording: false));
    final bytes = Uint8List.fromList(
      List<int>.generate(1200, (_) => _random.nextInt(255)),
    );
    return ComposerVoiceNote(duration: duration, bytes: bytes);
  }
}

