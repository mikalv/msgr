import 'package:libmsgr/libmsgr.dart';

class OnBootstrapAction {
  final List<Profile> profiles;
  final List<Conversation> conversations;
  final List<Channel> channels;
  final List<MMessage> messages;
  final String teamName;

  OnBootstrapAction({
    required this.profiles,
    required this.conversations,
    required this.channels,
    required this.messages,
    required this.teamName,
  });

  @override
  String toString() {
    return 'OnBootstrapAction{teamName: $teamName, profiles: $profiles, '
        'conversations: $conversations, channels: $channels, messages: $messages}';
  }
}
