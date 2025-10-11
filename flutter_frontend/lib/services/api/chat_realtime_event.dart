import 'package:messngr/features/chat/models/chat_message.dart';
import 'package:messngr/features/chat/models/reaction_aggregate.dart';

/// Base type for realtime events levert fra chatkanalen.
abstract class ChatRealtimeEvent {
  const ChatRealtimeEvent();
}

/// Event når en melding blir opprettet eller oppdatert.
class ChatMessageEvent extends ChatRealtimeEvent {
  const ChatMessageEvent(this.message, {this.kind = ChatMessageEventKind.created});

  final ChatMessage message;
  final ChatMessageEventKind kind;
}

/// Skiller mellom nye og oppdaterte meldinger.
enum ChatMessageEventKind { created, updated }

/// Event når en melding blir soft-slettet.
class ChatMessageDeletedEvent extends ChatRealtimeEvent {
  const ChatMessageDeletedEvent({required this.messageId, this.deletedAt});

  final String messageId;
  final DateTime? deletedAt;
}

/// Event når en reaksjon blir lagt til eller fjernet.
class ChatReactionEvent extends ChatRealtimeEvent {
  const ChatReactionEvent({
    required this.messageId,
    required this.emoji,
    required this.profileId,
    required this.isAddition,
    required this.aggregates,
    this.metadata = const <String, dynamic>{},
  });

  final String messageId;
  final String emoji;
  final String profileId;
  final bool isAddition;
  final List<ReactionAggregate> aggregates;
  final Map<String, dynamic> metadata;
}

/// Event når en melding blir festet eller løsnet.
class ChatPinnedEvent extends ChatRealtimeEvent {
  const ChatPinnedEvent({
    required this.messageId,
    required this.pinnedById,
    required this.pinnedAt,
    required this.isPinned,
    this.metadata = const <String, dynamic>{},
  });

  final String messageId;
  final String pinnedById;
  final DateTime pinnedAt;
  final bool isPinned;
  final Map<String, dynamic> metadata;
}

/// Event når en deltaker begynner eller stopper å skrive.
class ChatTypingEvent extends ChatRealtimeEvent {
  const ChatTypingEvent({
    required this.profileId,
    required this.profileName,
    required this.isTyping,
    this.threadId,
    this.expiresAt,
  });

  final String profileId;
  final String profileName;
  final bool isTyping;
  final String? threadId;
  final DateTime? expiresAt;
}

/// Event når en melding markeres som lest.
class ChatReadEvent extends ChatRealtimeEvent {
  const ChatReadEvent({
    required this.profileId,
    required this.messageId,
    this.readAt,
  });

  final String profileId;
  final String messageId;
  final DateTime? readAt;
}
