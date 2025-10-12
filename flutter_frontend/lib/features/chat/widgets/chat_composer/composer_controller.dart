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
