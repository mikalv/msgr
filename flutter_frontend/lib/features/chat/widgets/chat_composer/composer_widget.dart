part of 'package:messngr/features/chat/widgets/chat_composer.dart';

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
      child: SafeArea(
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
              decoration: decoration,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: isCompact ? 10 : 12,
              ),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter, control: true):
                      () => _submit(forceSend: true),
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

  Future<void> _startRecording() async {
    await widget.voiceRecorder.start();
  }

  Future<void> _stopRecording() async {
    try {
      final note = await widget.voiceRecorder.stop();
      widget.controller.setVoiceNote(note);
    } catch (_) {
      widget.controller.setError('Kunne ikke lagre stemmeopptak.');
    }
  }

  void _removeAttachment(ComposerAttachment attachment) {
    widget.controller.removeAttachment(attachment);
  }

  void _clearVoiceNote() {
    widget.controller.clearVoiceNote();
  }

  void _handleDraftChanged() {
    widget.controller.setText(_textController.text);
    widget.controller.syncMentionsWithText(_textController.text);
    _updateMentionState();
  }

  void _handleVoiceState(ChatVoiceState state) {
    setState(() {});
    if (!state.isRecording) {
      widget.controller.setVoiceNote(widget.controller.value.voiceNote);
    }
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showEmoji = false;
        _clearMentionPalette();
      });
    }
  }

  void _updateMentionState() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (!selection.isValid) {
      setState(_clearMentionPalette);
      return;
    }

    final cursor = selection.baseOffset;
    if (cursor <= 0) {
      setState(_clearMentionPalette);
      return;
    }

    final beforeCursor = text.substring(0, cursor);
    var index = beforeCursor.length - 1;
    var found = false;
    while (index >= 0) {
      final char = beforeCursor[index];
      if (char == '@') {
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
    final end =
        selection.isValid ? selection.baseOffset : _textController.text.length;
    final replacement = '@${mention.handle} ';
    final text = _textController.text;
    final newText = text.replaceRange(triggerIndex, end, replacement);
    _textController
      ..text = newText
      ..selection = TextSelection.collapsed(
          offset: triggerIndex + replacement.length);
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
