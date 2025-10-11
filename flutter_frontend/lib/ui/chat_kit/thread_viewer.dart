import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:messngr/features/chat/models/reaction_aggregate.dart';

import 'presence_badge.dart';
import 'reaction_picker.dart';
import 'theme/chat_profile_theme.dart';

class ChatThreadMessage {
  const ChatThreadMessage({
    required this.id,
    required this.profileId,
    required this.author,
    required this.body,
    required this.timestamp,
    required this.isOwn,
    this.avatar,
    this.reactions = const <ReactionAggregate>[],
    this.isOnline = false,
    this.isEdited = false,
    this.isDeleted = false,
  });

  final String id;
  final String profileId;
  final String author;
  final String body;
  final DateTime timestamp;
  final bool isOwn;
  final ImageProvider<Object>? avatar;
  final List<ReactionAggregate> reactions;
  final bool isOnline;
  final bool isEdited;
  final bool isDeleted;
}

class ChatThreadViewer extends StatelessWidget {
  const ChatThreadViewer({
    super.key,
    required this.messages,
    required this.onReaction,
    this.onMessageLongPress,
    this.scrollController,
  });

  final List<ChatThreadMessage> messages;
  final void Function(ChatThreadMessage message, String reaction) onReaction;
  final ValueChanged<ChatThreadMessage>? onMessageLongPress;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyThreadView();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _ThreadMessageTile(
          message: message,
          onReaction: (reaction) => onReaction(message, reaction),
          onLongPress: onMessageLongPress,
        );
      },
    );
  }
}

class _ThreadMessageTile extends StatelessWidget {
  const _ThreadMessageTile({
    required this.message,
    required this.onReaction,
    this.onLongPress,
  });

  final ChatThreadMessage message;
  final ValueChanged<String> onReaction;
  final ValueChanged<ChatThreadMessage>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileTheme = ChatProfileTheme.of(context, message.profileId);
    final formatted = DateFormat.Hm().format(message.timestamp);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: message.isOwn
            ? profileTheme.bubbleGradient
            : LinearGradient(
                colors: [
                  theme.colorScheme.surfaceVariant.withOpacity(0.76),
                  theme.colorScheme.surfaceVariant.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment:
            message.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.isDeleted ? 'Denne meldingen ble slettet.' : message.body,
            style: profileTheme.textStyle.copyWith(
              color: message.isOwn
                  ? profileTheme.textStyle.color
                  : theme.colorScheme.onSurface,
              fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (message.isEdited && !message.isDeleted)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Redigert',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatted,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showReactionPicker(context),
                child: Icon(
                  Icons.add_reaction_outlined,
                  size: 18,
                  color: profileTheme.accentColor,
                ),
              ),
            ],
          ),
          if (message.reactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final aggregate in message.reactions)
                  _ReactionPill(
                    emoji: aggregate.emoji,
                    count: aggregate.count,
                    accentColor: profileTheme.accentColor,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Align(
      alignment: message.isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.isOwn)
              _MessageAvatar(
                message: message,
                profileTheme: profileTheme,
              ),
            GestureDetector(
              onLongPress: onLongPress != null
                  ? () => onLongPress!(message)
                  : null,
              child: bubble,
            ),
            if (message.isOwn)
              _MessageAvatar(
                message: message,
                profileTheme: profileTheme,
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) async {
    final reaction = await showDialog<String>(
      context: context,
      builder: (context) {
        return Center(
          child: ChatReactionPicker(
            onReactionSelected: Navigator.of(context).pop,
            onDismissed: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
    if (reaction != null) {
      onReaction(reaction);
    }
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.accentColor,
  });

  final String emoji;
  final int count;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      child: Text(
        '$emoji  $count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.message, required this.profileTheme});

  final ChatThreadMessage message;
  final ChatProfileThemeData profileTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: message.avatar,
            backgroundColor: profileTheme.accentColor.withOpacity(0.18),
            child: message.avatar == null
                ? Text(
                    message.author.characters.first,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: profileTheme.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          PresenceBadge(
            isOnline: message.isOnline,
            size: 10,
            color: profileTheme.presenceColor,
          ),
        ],
      ),
    );
  }
}

class _EmptyThreadView extends StatelessWidget {
  const _EmptyThreadView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 54, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Start samtalen', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ingen meldinger ennå. Si hei eller del dagens høydepunkt!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
