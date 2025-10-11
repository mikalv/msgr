import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:messngr/features/chat/media/chat_media_attachment.dart';
import 'package:messngr/features/chat/media/chat_media_controller.dart';
import 'package:messngr/features/chat/media/chat_media_picker.dart';
import 'package:messngr/features/chat/models/composer_submission.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSubmit,
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
    this.availableCommands = SlashCommand.defaults,
    ChatVoiceRecorder? voiceRecorder,
  }) : voiceRecorder = voiceRecorder ?? SimulatedChatVoiceRecorder();

  final ChatComposerController controller;
  final ValueChanged<ChatComposerResult> onSubmit;
  final bool isSending;
  final String? errorMessage;
  final List<SlashCommand> availableCommands;
  final ChatVoiceRecorder voiceRecorder;

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
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  late final AnimationController _expanderController;
  late ChatComposerValue _value;
  StreamSubscription<ChatVoiceState>? _voiceSubscription;

  bool _showEmoji = false;
  int _commandSelection = 0;

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
    _value = widget.controller.value;
    _textController = TextEditingController(text: _value.text);
    _focusNode = FocusNode();
    _expanderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    widget.controller.addListener(_handleControllerChanged);
    _voiceSubscription = widget.voiceRecorder.stateStream.listen(_handleVoiceState);
    _textController.addListener(_handleDraftChanged);
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
    _focusNode.dispose();
    _toolbarController.dispose();
    _hasText.dispose();
    _mediaController.removeListener(_handleMediaChanged);
    if (_ownsMediaController) {
      _mediaController.dispose();
    }
    _expanderController.dispose();
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
    final isCompact = MediaQuery.of(context).size.width < 640;

    final attachments = _value.attachments;
    final voiceNote = _value.voiceNote;

    final showExpander = _showEmoji;
    if (showExpander) {
      _expanderController.forward();
    } else {
      _expanderController.reverse();
    }

    return SafeArea(
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: ChatTheme.composerDecoration(theme),
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
                          onPressed: _canSend ? _submit : null,
                        ),
                      ],
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
  void _handleDraftChanged() {
    widget.controller.setText(_textController.text);
    if (_shouldShowCommandPalette) {
      setState(() {
        _commandSelection = 0;
      });
    }
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
        offset: selection.start + emoji.length,
      );
    widget.controller.setText(newText);
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
  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
    });
    if (_showEmoji) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      final attachments = result.files
          .map((file) => ComposerAttachment.fromPlatformFile(file))
          .whereType<ComposerAttachment>()
          .toList();
      if (attachments.isEmpty) return;
      widget.controller.addAttachments(attachments);
    } on PlatformException catch (error) {
      widget.controller.setError('Kunne ikke hente filer: ${error.message}');
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

  void _handleEscape() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
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
    if (!_shouldShowCommandPalette) return;
    setState(() {
      _commandSelection =
          (_commandSelection + 1).clamp(0, _matchedCommands.length - 1);
    });
  }

  void _selectPreviousCommand() {
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

  void _submit() {
    if (!_canSend) return;
    final command =
        _shouldShowCommandPalette ? _matchedCommands[_commandSelection] : null;
    final result = widget.controller.buildResult(command: command);
    widget.onSubmit(result);
    widget.controller.clear();
    setState(() {
      _textController.clear();
      _showEmoji = false;
      _commandSelection = 0;
    });
    _focusNode.requestFocus();
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
        attachments: _value.attachments.where((a) => a.id != attachment.id).toList(),
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

  ChatComposerResult buildResult({SlashCommand? command}) {
    return ChatComposerResult(
      text: _value.text.trim(),
      attachments: List.unmodifiable(_value.attachments),
      voiceNote: _value.voiceNote,
      command: command ?? _value.command,
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
    this.error,
    this.command,
  });

  static const _unset = Object();

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final String? error;
  final SlashCommand? command;

  factory ChatComposerValue.empty() => const ChatComposerValue(
        text: '',
        attachments: [],
        voiceNote: null,
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
  }) {
    final resolvedError =
        error == _unset ? this.error : error as String?;
    final resolvedCommand =
        clearCommand ? null : (command ?? this.command);
    return ChatComposerValue(
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      voiceNote: clearVoiceNote
          ? null
          : (voiceNote ?? this.voiceNote),
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
        other.error == error &&
        other.command == command;
  }

  @override
  int get hashCode => Object.hash(
        text,
        Object.hashAll(attachments),
        voiceNote,
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
  });

  final String text;
  final List<ComposerAttachment> attachments;
  final ComposerVoiceNote? voiceNote;
  final SlashCommand? command;

  bool get hasCommand => command != null;
}

class ComposerAttachment {
  ComposerAttachment({
    required this.id,
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });

  factory ComposerAttachment.fromPlatformFile(PlatformFile file) {
    final id = file.identifier ?? '${file.name}-${DateTime.now().microsecondsSinceEpoch}';
    return ComposerAttachment(
      id: id,
      name: file.name,
      size: file.size,
      bytes: file.bytes,
      path: file.path,
    );
  }

  final String id;
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

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
      '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
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
      decoration: InputDecoration(
        hintText: placeholder,
        border: InputBorder.none,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const _emojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', '🤩', '🥳', '🤔', '🤯', '😴', '😇',
    '😡', '😭', '🙌', '👏', '👍', '👎', '🙏', '💡', '🔥', '🌟', '✨', '🎉', '🚀', '🎧',
    '🍕', '☕️', '🏖️', '📎',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final emoji in _emojis)
              GestureDetector(
                onTap: () => onSelect(emoji),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
          ],
        ),
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
        color: theme.colorScheme.surfaceVariant.withOpacity(0.52),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < commands.length; i++)
            InkWell(
              onTap: () => onSelect(commands[i]),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 18 : 0),
                bottom: Radius.circular(i == commands.length - 1 ? 18 : 0),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: i == highlightedIndex
                      ? theme.colorScheme.primary.withOpacity(0.12)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commands[i].name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            commands[i].description,
                            style: theme.textTheme.bodySmall?.copyWith(
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final attachment in attachments)
            Chip(
              label: Text('${attachment.name} • ${attachment.humanSize}'),
              onDeleted: () => onRemoveAttachment(attachment),
            ),
          if (voiceNote != null)
            Chip(
              avatar: const Icon(Icons.mic, size: 16),
              label: Text('Lydklipp ${voiceNote!.formattedDuration}'),
              onDeleted: onRemoveVoiceNote,
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
      message: isRecording ? 'Stopp opptak' : 'Spill inn lydklipp',
      child: GestureDetector(
        onTap: isRecording ? onStop : onStart,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isRecording
                ? theme.colorScheme.error.withOpacity(0.2)
                : theme.colorScheme.surfaceVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
            color: isRecording
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
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

/*class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.onTap,*/
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
