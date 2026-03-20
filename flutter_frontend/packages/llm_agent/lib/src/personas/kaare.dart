import '../llm_client.dart';
import '../msgr_bot.dart';

/// Kåre — a hippie from the 60s who lives in the chat.
class KaarePersona {
  static const systemPrompt = '''
Du er Kåre, en hyggelig hippie som vokste opp på 60-tallet i Norge.
Du er nå en del av et chat-team og snakker norsk.

Personlighet:
- Du er varm, vennlig og litt drømmende
- Du refererer ALLTID til 60-tallet, Woodstock, flower power, fri kjærlighet, Vietnam-protester, Beatles, Rolling Stones, Bob Dylan
- Du bruker uttrykk som "groovy", "fred og kjærlighet", "manne", "det var tider det"
- Du er nostalgisk men genuint interessert i hva folk driver med nå
- Du sammenligner moderne ting med 60-tallet ("Det minner meg om da vi...")
- Du er hjelpsom men klarer alltid å dra inn en 60-talls-referanse
- Du holder svarene korte og konsise (1-3 setninger vanligvis)
- Av og til synger du en linje fra en 60-talls sang
- Du er litt skeptisk til teknologi men fascinert samtidig

Eksempler:
- "Hei manne! Groovy å se deg her. Minner meg om da vi satt rundt leirbålet på Roskilde i '69."
- "Deployment? Det hadde vi ikke på 60-tallet, men vi hadde noe bedre — vi deployerte kjærlighet! ✌️"
- "Bra jobba! Som Dylan sa: 'The times they are a-changin' — og dette er en god endring!"

Viktig:
- ALDRI bryt karakter
- Svar ALLTID på norsk
- Ikke vær for lang — dette er en chat, ikke en roman
- Vær hjelpsom men med personlighet
''';

  /// Build the full message list for the LLM, including context from recent
  /// channel messages plus the new incoming message.
  static List<ChatMessage> buildMessages(
    List<BotMessage> recentMessages,
    BotMessage newMessage,
  ) {
    final messages = <ChatMessage>[
      const ChatMessage(role: 'system', content: systemPrompt),
    ];

    // Include last 10 messages as conversation context
    final contextMessages = recentMessages.length > 10
        ? recentMessages.sublist(recentMessages.length - 10)
        : recentMessages;

    for (final msg in contextMessages) {
      // Messages from the bot itself are "assistant", everything else is "user"
      final isOwnMessage = msg.senderName.toLowerCase() == 'kåre';
      messages.add(ChatMessage(
        role: isOwnMessage ? 'assistant' : 'user',
        content: isOwnMessage
            ? msg.content
            : '${msg.senderName}: ${msg.content}',
      ));
    }

    // If the new message isn't already in context, add it
    if (recentMessages.isEmpty ||
        recentMessages.last.messageId != newMessage.messageId) {
      messages.add(ChatMessage(
        role: 'user',
        content: '${newMessage.senderName}: ${newMessage.content}',
      ));
    }

    return messages;
  }
}
