part of 'package:messngr/features/chat/widgets/chat_composer.dart';

const _linkTextFieldKey = ValueKey('composerLinkTextField');
const _linkUrlFieldKey = ValueKey('composerLinkUrlField');

enum _FormattingAction { bold, italic, strike, code, link, bullet, quote }

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

  static const int _defaultLineSpan = 3;
  static const int _minResizableLines = 1;
  static const int _maxResizableLines = 12;
  static const double _lineDragSensitivity = 28;

  bool _isDropHover = false;

  bool _showEmoji = false;
  int _commandSelection = 0;
  int _mentionSelection = 0;
  int? _mentionTriggerIndex;
  String _mentionQuery = '';
  List<ComposerMention> _mentionCandidates = const <ComposerMention>[];

  late int _lineSpan;
  double? _resizeStartDy;
  int? _resizeStartLines;

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
    _lineSpan = _suggestedLineSpanForText(_value.text);
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
      _lineSpan = _suggestedLineSpanForText(_value.text);
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

    final sendState = _value.sendState;
    final autosaveStatus = _value.autosaveStatus;
    final isBusy = _isComposerBusy;
    final composerError = widget.errorMessage ?? _value.error;
    final isRetryable =
        sendState == ComposerSendState.failed && _value.error != null;
    final isQueuedOffline = sendState == ComposerSendState.queuedOffline;
    final errorIcon =
        isQueuedOffline ? Icons.cloud_upload_outlined : Icons.error_outline;
    final Color? errorBackground =
        isQueuedOffline ? theme.colorScheme.surfaceVariant : null;
    final Color? errorForeground =
        isQueuedOffline ? theme.colorScheme.onSurface : null;

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
            if (composerError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ErrorBanner(
                  message: composerError,
                  icon: errorIcon,
                  backgroundColor: errorBackground,
                  foregroundColor: errorForeground,
                  actionLabel: isRetryable ? 'Prøv igjen' : null,
                  onAction: isRetryable ? _retrySend : null,
                ),
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
                child: FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
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
                            onTap: isBusy ? null : _toggleEmoji,
                          ),
                          if (!isCompact) const SizedBox(width: 8),
                          _ComposerIconButton(
                            icon: Icons.attach_file,
                            tooltip: 'Legg ved fil',
                            onTap: isBusy ? null : _pickFiles,
                          ),
                          const SizedBox(width: 8),
                          _ComposerIconButton(
                            icon: Icons.camera_alt_outlined,
                            tooltip: 'Åpne kamera',
                            onTap: isBusy ? null : _capturePhoto,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ComposerTextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              onSubmitted: (_) => _submit(),
                              isSending: isBusy,
                              placeholder: isCompact
                                  ? 'Melding'
                                  : 'Del en oppdatering eller skriv / for kommandoer',
                              minLines: _lineSpan,
                              maxLines: _lineSpan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _VoiceRecorderButton(
                            isRecording: widget.voiceRecorder.isRecording,
                            onStart: _startRecording,
                            onStop: _stopRecording,
                            isEnabled: !isBusy,
                          ),
                          const SizedBox(width: 8),
                          _SendButton(
                            isEnabled: _canSend,
                            isSending: isBusy,
                            onPressed:
                                _canSend ? () => _submit(forceSend: true) : null,
                          ),
                        ],
                      ),
                      if (autosaveStatus != ComposerAutosaveStatus.idle)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _AutosaveStatusLabel(
                              status: autosaveStatus,
                              timestamp: _value.lastAutosave,
                            ),
                          ),
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
                                  icon: Icons.link,
                                  tooltip: 'Sett inn lenke',
                                  onTap:
                                      () => _applyFormatting(_FormattingAction.link),
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
                      if (showFormatting)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _ComposerResizeHandle(
                            key: const ValueKey('composerResizeHandle'),
                            lineSpan: _lineSpan,
                            minLines: _minResizableLines,
                            maxLines: _maxResizableLines,
                            onVerticalDragStart: _handleResizeStart,
                            onVerticalDragUpdate: _handleResizeUpdate,
                            onVerticalDragEnd: _handleResizeEnd,
                            onVerticalDragCancel: _handleResizeCancel,
                            onIncrease: _increaseLineSpan,
                            onDecrease: _decreaseLineSpan,
                            onReset: _resetLineSpan,
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

  bool get _isComposerBusy =>
      widget.isSending || _value.sendState == ComposerSendState.sending;

  bool get _canSend {
    if (_isComposerBusy) return false;
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
      final suggested = _suggestedLineSpanForText(next.text);
      if (suggested > _lineSpan) {
        _lineSpan = suggested;
      } else if (next.text.isEmpty && _lineSpan != _defaultLineSpan) {
        _lineSpan = _defaultLineSpan;
      }
    });
  }

  Future<void> _pickFiles() async {
    if (_isComposerBusy) return;
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
    if (_isComposerBusy) return;
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
    if (_isComposerBusy) return;
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
    if (_isComposerBusy) return;
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

  void _retrySend() {
    if (_isComposerBusy) return;
    final result = widget.controller.buildResult();
    widget.onSubmit(result);
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

  int _suggestedLineSpanForText(String text) {
    if (text.isEmpty) {
      return _defaultLineSpan;
    }
    final rawLines = text.split('\n').length;
    final clamped = rawLines.clamp(_minResizableLines, _maxResizableLines);
    return clamped is int ? clamped : (clamped as num).toInt();
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

  void _handleResizeStart(DragStartDetails details) {
    _resizeStartDy = details.globalPosition.dy;
    _resizeStartLines = _lineSpan;
    _focusNode.requestFocus();
  }

  void _handleResizeUpdate(DragUpdateDetails details) {
    final startDy = _resizeStartDy;
    final startLines = _resizeStartLines;
    if (startDy == null || startLines == null) {
      return;
    }
    final delta = startDy - details.globalPosition.dy;
    final linesDelta = (delta / _lineDragSensitivity).round();
    final nextLines =
        (startLines + linesDelta).clamp(_minResizableLines, _maxResizableLines);
    final int resolved =
        nextLines is int ? nextLines : (nextLines as num).toInt();
    if (resolved != _lineSpan) {
      setState(() => _lineSpan = resolved);
    }
  }

  void _handleResizeEnd(DragEndDetails details) {
    _resetResizeTracking();
  }

  void _handleResizeCancel() {
    _resetResizeTracking();
  }

  void _resetResizeTracking() {
    _resizeStartDy = null;
    _resizeStartLines = null;
  }

  void _increaseLineSpan() {
    if (_lineSpan >= _maxResizableLines) {
      return;
    }
    setState(() => _lineSpan += 1);
    _focusNode.requestFocus();
  }

  void _decreaseLineSpan() {
    if (_lineSpan <= _minResizableLines) {
      return;
    }
    setState(() => _lineSpan -= 1);
    _focusNode.requestFocus();
  }

  void _resetLineSpan() {
    if (_lineSpan == _defaultLineSpan) {
      return;
    }
    setState(() => _lineSpan = _defaultLineSpan);
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
      case _FormattingAction.link:
        unawaited(_applyLinkFormatting());
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

  Future<void> _applyLinkFormatting() async {
    final selection = _textController.selection;
    final text = _textController.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final selectedText = hasSelection
        ? text.substring(selection.start, selection.end)
        : '';

    final dialogResult = await _showLinkDialog(
      initialLabel: selectedText,
      initialUrl: hasSelection && _looksLikeUrl(selectedText)
          ? selectedText
          : null,
    );
    if (!mounted || dialogResult == null) {
      return;
    }

    final label = dialogResult.label.isNotEmpty
        ? dialogResult.label
        : dialogResult.url;
    final insertion = '[$label](${dialogResult.url})';

    if (!selection.isValid) {
      final insertionStart = text.length;
      final newText = '$text$insertion';
      _textController
        ..text = newText
        ..selection = TextSelection(
          baseOffset: insertionStart + 1,
          extentOffset: insertionStart + 1 + label.length,
        );
    } else if (selection.isCollapsed) {
      final start = selection.start;
      final newText = text.replaceRange(start, start, insertion);
      _textController
        ..text = newText
        ..selection = TextSelection(
          baseOffset: start + 1,
          extentOffset: start + 1 + label.length,
        );
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, insertion);
      _textController
        ..text = newText
        ..selection = TextSelection(
          baseOffset: start + 1,
          extentOffset: start + 1 + label.length,
        );
    }
    widget.controller.setText(_textController.text);
    _focusNode.requestFocus();
  }

  Future<_LinkData?> _showLinkDialog({
    required String initialLabel,
    String? initialUrl,
  }) {
    final normalizedInitialUrl =
        initialUrl != null && initialUrl.isNotEmpty ? initialUrl : 'https://';
    return showDialog<_LinkData>(
      context: context,
      builder: (context) {
        final labelController = TextEditingController(text: initialLabel);
        final urlController = TextEditingController(text: normalizedInitialUrl);
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Sett inn lenke'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: _linkTextFieldKey,
                    controller: labelController,
                    decoration: const InputDecoration(
                      labelText: 'Visningstekst',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: _linkUrlFieldKey,
                    controller: urlController,
                    decoration: InputDecoration(
                      labelText: 'URL',
                      errorText: errorText,
                    ),
                    keyboardType: TextInputType.url,
                    autofocus: initialLabel.isEmpty,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Avbryt'),
                ),
                FilledButton(
                  onPressed: () {
                    final rawUrl = urlController.text.trim();
                    if (rawUrl.isEmpty) {
                      setState(() => errorText = 'Oppgi en gyldig URL.');
                      return;
                    }
                    final normalized = _normaliseUrl(rawUrl);
                    if (!_looksLikeUrl(normalized)) {
                      setState(() => errorText = 'Oppgi en gyldig URL.');
                      return;
                    }
                    Navigator.of(context).pop(
                      _LinkData(
                        label: labelController.text.trim(),
                        url: normalized,
                      ),
                    );
                  },
                  child: const Text('Sett inn'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _looksLikeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }
    if (uri.scheme.isEmpty) {
      return trimmed.startsWith('www.');
    }
    return uri.hasScheme && uri.host.isNotEmpty;
  }

  String _normaliseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return trimmed;
    }
    if (uri.hasScheme) {
      return trimmed;
    }
    return 'https://$trimmed';
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

class _ComposerResizeHandle extends StatelessWidget {
  const _ComposerResizeHandle({
    super.key,
    required this.lineSpan,
    required this.minLines,
    required this.maxLines,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    required this.onIncrease,
    required this.onDecrease,
    required this.onReset,
  });

  final int lineSpan;
  final int minLines;
  final int maxLines;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final VoidCallback onVerticalDragCancel;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAtMin = lineSpan <= minLines;
    final isAtMax = lineSpan >= maxLines;
    return Semantics(
      label: 'Juster høyden på meldingsfeltet',
      value: '$lineSpan linjer',
      increasedValue: isAtMax ? null : '${lineSpan + 1} linjer',
      decreasedValue: isAtMin ? null : '${lineSpan - 1} linjer',
      onIncrease: isAtMax ? null : onIncrease,
      onDecrease: isAtMin ? null : onDecrease,
      child: Tooltip(
        message: 'Dra for å endre høyde (${lineSpan} linjer)',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: onVerticalDragStart,
          onVerticalDragUpdate: onVerticalDragUpdate,
          onVerticalDragEnd: onVerticalDragEnd,
          onVerticalDragCancel: onVerticalDragCancel,
          onDoubleTap: onReset,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Center(
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkData {
  const _LinkData({
    required this.label,
    required this.url,
  });

  final String label;
  final String url;
}

class _AutosaveStatusLabel extends StatelessWidget {
  const _AutosaveStatusLabel({
    required this.status,
    this.timestamp,
  });

  final ComposerAutosaveStatus status;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    if (status == ComposerAutosaveStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case ComposerAutosaveStatus.failed:
        color = theme.colorScheme.error;
        break;
      case ComposerAutosaveStatus.saving:
        color = theme.colorScheme.primary;
        break;
      default:
        color = theme.colorScheme.onSurfaceVariant;
    }

    Widget? indicator;
    String text;

    switch (status) {
      case ComposerAutosaveStatus.saving:
        text = 'Lagrer utkast …';
        indicator = SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
        break;
      case ComposerAutosaveStatus.saved:
        final stamp = timestamp != null
            ? TimeOfDay.fromDateTime(timestamp!).format(context)
            : null;
        text = stamp == null ? 'Utkast lagret' : 'Utkast lagret $stamp';
        break;
      case ComposerAutosaveStatus.failed:
        text = 'Kunne ikke lagre utkast';
        break;
      case ComposerAutosaveStatus.dirty:
        text = 'Endringer ikke lagret ennå';
        break;
      case ComposerAutosaveStatus.idle:
        text = '';
        break;
    }

    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (indicator != null) ...[
            indicator,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
