import 'package:flutter/material.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/features/chat/widgets/chat_timeline.dart';
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

    return Consumer<ChatViewModel>(
      builder: (context, viewModel, _) {
        final identity = viewModel.identity;

        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _ChatHeader(threadTitle: viewModel.thread?.displayName),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ChatTimeline(
                  messages: viewModel.messages,
                  currentProfileId: identity?.profileId ?? '',
                ),
              ),
            ),
            ChatComposer(
              onSend: (text) => viewModel.sendMessage(text),
              isSending: viewModel.isSending || viewModel.thread == null,
              errorMessage: viewModel.error,
            ),
          ],
        );
      },
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({this.threadTitle});

  final String? threadTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = threadTitle?.isNotEmpty == true ? threadTitle : 'Direkte samtale';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
            child: Icon(Icons.auto_awesome,
                color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Fokusmodus: Privat',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Flere innstillinger',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
