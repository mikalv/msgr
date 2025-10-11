import 'package:flutter/material.dart';
import 'package:messngr/features/auth/auth_gate.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/state/typing_participants_notifier.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';
import 'package:messngr/features/chat/widgets/pinned_message_banner.dart';
import 'package:messngr/features/chat/widgets/typing_indicator.dart';
import 'package:messngr/ui/chat_kit/chat_kit.dart';
import 'package:provider/provider.dart';
import 'package:messngr/services/api/chat_api.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthGate(
      child: Builder(
        builder: (context) {
          final identity = Provider.of<AccountIdentity>(context);
          return ChangeNotifierProvider(
            create: (_) => ChatViewModel(identity: identity)..bootstrap(),
            child: const _ChatView(),
          );
        },
      ),
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
    final session = context.read<AuthSession>();
    final displayName = context.read<String?>();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName ?? 'Profil',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.identity.profileId,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Logg ut',
                onPressed: () => session.signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showStartConversationDialog(context, viewModel),
            icon: const Icon(Icons.chat_add_rounded),
            label: const Text('Ny samtale'),
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
    final currentProfileId = identity.profileId;
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

    if (viewModel.thread == null) {
      return _EmptyConversationState(
        isLoading: viewModel.isLoading,
        onStartConversation: () => _showStartConversationDialog(context, viewModel),
        showInlineChannels: showInlineChannels,
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

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({
    required this.isLoading,
    required this.onStartConversation,
    required this.showInlineChannels,
  });

  final bool isLoading;
  final VoidCallback onStartConversation;
  final bool showInlineChannels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Ingen samtale valgt',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              showInlineChannels
                  ? 'Opprett eller velg en samtale for å komme i gang.'
                  : 'Velg en samtale fra sidemenyen eller start en ny for å sende meldinger.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isLoading ? null : onStartConversation,
            icon: const Icon(Icons.chat_add_rounded),
            label: const Text('Start ny samtale'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showStartConversationDialog(BuildContext context, ChatViewModel viewModel) async {
  final emailController = TextEditingController();
  final profileIdController = TextEditingController();
  String? errorMessage;
  bool submitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> submit() async {
            if (submitting) return;

            final email = emailController.text.trim();
            final profileIdInput = profileIdController.text.trim();

            if (email.isEmpty && profileIdInput.isEmpty) {
              setState(() {
                errorMessage = 'Oppgi e-post eller profil-ID.';
              });
              return;
            }

            setState(() {
              submitting = true;
              errorMessage = null;
            });

            try {
              String targetProfileId = profileIdInput;

              if (targetProfileId.isEmpty && email.isNotEmpty) {
                final match = await viewModel.lookupContactByEmail(email);
                final profile = match?.match?.profile;
                if (profile == null) {
                  setState(() {
                    errorMessage = 'Fant ingen profil for oppgitt e-post.';
                  });
                  return;
                }
                targetProfileId = profile.id;
              }

              if (targetProfileId.isEmpty) {
                setState(() {
                  errorMessage = 'Kunne ikke bestemme profil-ID.';
                });
                return;
              }

              await viewModel.startDirectConversation(targetProfileId);
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            } on ApiException catch (error) {
              setState(() {
                errorMessage = 'Kunne ikke starte samtale (${error.statusCode}).';
              });
            } catch (error) {
              setState(() {
                errorMessage = 'Noe gikk galt: $error';
              });
            } finally {
              setState(() {
                submitting = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Start ny samtale'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-post',
                    hintText: 'kari@example.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: profileIdController,
                  decoration: const InputDecoration(
                    labelText: 'Profil-ID (valgfri)',
                    helperText: 'Brukes hvis du kjenner mottakerens profil-ID',
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(dialogContext).maybePop(),
                child: const Text('Avbryt'),
              ),
              FilledButton(
                onPressed: submitting ? null : submit,
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start'),
              ),
            ],
          );
        },
      );
    },
  );

  emailController.dispose();
  profileIdController.dispose();
}
