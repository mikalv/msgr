part of 'package:messngr/features/chat/widgets/chat_composer.dart';

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
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
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
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void removeAttachment(ComposerAttachment attachment) {
    _update(
      _value.copyWith(
        attachments:
            _value.attachments.where((a) => a.id != attachment.id).toList(),
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void clearVoiceNote() {
    _update(
      _value.copyWith(
        clearVoiceNote: true,
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void setVoiceNote(ComposerVoiceNote note) {
    _update(
      _value.copyWith(
        voiceNote: note,
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void setCommand(SlashCommand? command) {
    _update(
      _value.copyWith(
        command: command,
        clearCommand: command == null,
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void addMention(ComposerMention mention) {
    final mentions = [..._value.mentions];
    if (mentions.any((m) => m.id == mention.id)) {
      return;
    }
    mentions.add(mention);
    _update(
      _value.copyWith(
        mentions: mentions,
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
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

  void setSendState(ComposerSendState state, {String? error}) {
    final resolvedError =
        state == ComposerSendState.failed ? error ?? _value.error : null;
    _update(
      _value.copyWith(
        sendState: state,
        error: resolvedError,
      ),
    );
  }

  void markAutosaveInProgress() {
    if (_value.autosaveStatus == ComposerAutosaveStatus.saving) {
      return;
    }
    _update(
      _value.copyWith(
        autosaveStatus: ComposerAutosaveStatus.saving,
      ),
    );
  }

  void markAutosaveSuccess(DateTime timestamp) {
    _update(
      _value.copyWith(
        autosaveStatus: ComposerAutosaveStatus.saved,
        lastAutosave: timestamp,
      ),
    );
  }

  void markAutosaveFailure() {
    _update(
      _value.copyWith(
        autosaveStatus: ComposerAutosaveStatus.failed,
      ),
    );
  }

  void markAutosaveDirty() {
    if (_value.autosaveStatus == ComposerAutosaveStatus.dirty &&
        _value.lastAutosave == null) {
      return;
    }
    _update(
      _value.copyWith(
        autosaveStatus: ComposerAutosaveStatus.dirty,
        clearLastAutosave: true,
      ),
    );
  }

  void restoreSnapshot(ChatDraftSnapshot snapshot) {
    _update(snapshot.applyTo(_value));
  }

  ChatDraftSnapshot snapshot() {
    return ChatDraftSnapshot.fromComposerValue(_value);
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
