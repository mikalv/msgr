import 'package:flutter/material.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/state/typing_participants_notifier.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';
import 'package:messngr/features/chat/widgets/pinned_message_banner.dart';
import 'package:messngr/features/chat/widgets/typing_indicator.dart';
import 'package:messngr/ui/chat_kit/chat_kit.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..bootstrap(),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ChatTheme.backgroundGradient(theme)),
      child: SafeArea(
        bottom: false,
        child: Consumer<ChatViewModel>(
          builder: (context, viewModel, _) {
            final identity = viewModel.identity;
            final profileThemes = _buildProfileThemes(theme, viewModel);
            final fallbackTheme = ChatProfileThemeData.resolve(
              identity?.profileId ?? 'self',
              theme: theme,
              messageTheme:
                  viewModel.messages.isNotEmpty ? viewModel.messages.first.theme : null,
            );

            return ChatProfileTheme(
              themes: profileThemes,
              fallback: fallbackTheme,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showChannelPanel = constraints.maxWidth >= 1024;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: ChatTheme.panelDecoration(theme),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: viewModel.isLoading
                            ? const _ChatLoadingState()
                            : Row(
                                children: [
                                  if (showChannelPanel)
                                    SizedBox(
                                      width: 280,
                                      child: _ChannelSidebar(viewModel: viewModel),
                                    ),
                                  if (showChannelPanel)
                                    const VerticalDivider(width: 1, thickness: 1),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: _ThreadColumn(
                                        viewModel: viewModel,
                                        showInlineChannels: !showChannelPanel,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

Map<String, ChatProfileThemeData> _buildProfileThemes(
  ThemeData theme,
  ChatViewModel viewModel,
) {
  final map = <String, ChatProfileThemeData>{};
  for (final message in viewModel.messages) {
    final profileId = message.profileId.isNotEmpty ? message.profileId : 'system';
    map.putIfAbsent(
      profileId,
      () => ChatProfileThemeData.resolve(
        profileId,
        theme: theme,
        messageTheme: message.theme,
      ),
    );
  }
  return map;
}

ChatThread _summaryToThread(ChatChannelSummary summary) {
  return ChatThread(
    id: summary.id,
    participantNames: [summary.title],
    kind: ChatThreadKind.direct,
  );
}

class _ChannelSidebar extends StatelessWidget {
  const _ChannelSidebar({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kanaler',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (viewModel.isOffline)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConnectionStatusBanner(
                isOnline: !viewModel.isOffline,
                message: 'Frakoblet – viser hurtigbufferte kanaler.',
                retry: viewModel.isOffline ? () => viewModel.fetchMessages() : null,
              ),
            ),
          Expanded(
            child: ChatChannelList(
              channels: [
                for (final channel in viewModel.channels)
                  ChatChannelSummary(
                    id: channel.id,
                    title: channel.displayName,
                    subtitle: 'Siste aktivitet',
                    profileId: channel.id,
                    lastActivity: DateTime.now(),
                    isOnline: !viewModel.isOffline,
                  ),
              ],
              selectedId: viewModel.selectedThreadId,
              onChannelTap: (summary) {
                final match = viewModel.channels
                    .firstWhere((thread) => thread.id == summary.id, orElse: () => _summaryToThread(summary));
                viewModel.selectThread(match);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadColumn extends StatelessWidget {
  const _ThreadColumn({
    required this.viewModel,
    required this.showInlineChannels,
  });

  final ChatViewModel viewModel;
  final bool showInlineChannels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = viewModel.identity;
    final currentProfileId = identity?.profileId ?? '';
    final pinnedMessages = viewModel.pinnedNotifier.pinnedMessages;
    final threadState = viewModel.threadViewNotifier.state;
    final typingKey = threadState.threadId ?? 'root';
    final typingParticipants =
        viewModel.typingNotifier.activeByThread[typingKey] ?? const <TypingParticipant>[];

    final pinnedIds = {for (final pinned in pinnedMessages) pinned.messageId};

    final filteredMessages = <ChatThreadMessage>[];
    for (final message in viewModel.messages) {
      final includePinned = threadState.showPinned && pinnedIds.contains(message.id);
      final includeThread =
          !threadState.showPinned && threadState.threadId != null &&
              (message.threadId == threadState.threadId ||
                  message.id == threadState.rootMessageId);
      final includeDefault =
          !threadState.showPinned && threadState.threadId == null;

      if (!(includePinned || includeThread || includeDefault)) {
        continue;
      }

      filteredMessages.add(
        ChatThreadMessage(
          id: message.id,
          profileId: message.profileId,
          author: message.profileName,
          body: message.body,
          timestamp: message.sentAt ?? message.insertedAt ?? DateTime.now(),
          isOwn: message.profileId == currentProfileId,
          reactions: viewModel.reactionsFor(message.id),
          isOnline: !viewModel.isOffline || message.profileId == currentProfileId,
          isEdited: message.isEdited,
          isDeleted: message.isDeleted,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showInlineChannels)
          SizedBox(
            height: 180,
            child: ChatChannelList(
              channels: [
                for (final channel in viewModel.channels)
                  ChatChannelSummary(
                    id: channel.id,
                    title: channel.displayName,
                    subtitle: 'Siste aktivitet',
                    profileId: channel.id,
                    lastActivity: DateTime.now(),
                    isOnline: !viewModel.isOffline,
                  ),
              ],
              selectedId: viewModel.selectedThreadId,
              onChannelTap: (summary) {
                final match = viewModel.channels
                    .firstWhere((thread) => thread.id == summary.id, orElse: () => _summaryToThread(summary));
                viewModel.selectThread(match);
              },
            ),
          ),
        if (showInlineChannels)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ConnectionStatusBanner(
              isOnline: !viewModel.isOffline,
              message: viewModel.isOffline
                  ? 'Frakoblet – meldinger sendes når du er online igjen.'
                  : 'Tilkoblet til msgr-nettet.',
              retry: viewModel.isOffline ? () => viewModel.fetchMessages() : null,
            ),
          ),
        Text(
          viewModel.thread?.displayName ?? 'Samtale',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          viewModel.isOffline
              ? 'Viser lagrede meldinger'
              : 'Direkte samtale',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        PinnedMessageBanner(
          pinned: pinnedMessages,
          isActive: threadState.showPinned,
          onTap: pinnedMessages.isEmpty
              ? null
              : () {
                  final shouldShow = !threadState.showPinned;
                  viewModel.threadViewNotifier.setPinnedView(shouldShow);
                },
        ),
        if (threadState.showPinned)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => viewModel.threadViewNotifier.setPinnedView(false),
              icon: const Icon(Icons.close),
              label: const Text('Tilbake til samtale'),
            ),
          ),
        if (threadState.threadId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: viewModel.threadViewNotifier.closeThread,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Tilbake til hovedtråd'),
              ),
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: DecoratedBox(
              decoration: ChatTheme.timelineDecoration(theme),
              child: ChatThreadViewer(
                messages: filteredMessages,
                onReaction: (message, reaction) {
                  viewModel.recordReaction(message.id, reaction);
                },
                onMessageLongPress: (_) {},
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TypingIndicator(participants: typingParticipants),
        const SizedBox(height: 12),
        ChatComposer(
          controller: viewModel.composerController,
          onSubmit: viewModel.submitComposer,
          isSending: viewModel.isSending || viewModel.thread == null,
          errorMessage: viewModel.error,
        ),
      ],
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Setter opp samtalen …',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
