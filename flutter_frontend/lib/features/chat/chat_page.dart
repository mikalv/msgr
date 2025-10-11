import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:messngr/features/chat/state/chat_view_model.dart';
import 'package:messngr/features/chat/widgets/chat_composer.dart';
import 'package:messngr/features/chat/widgets/chat_theme.dart';
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

    return DecoratedBox(
      decoration: BoxDecoration(gradient: ChatTheme.backgroundGradient(theme)),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = min(constraints.maxWidth, 860.0);
            final height = constraints.maxHeight;

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SizedBox(
                    height: height,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: DecoratedBox(
                          decoration: ChatTheme.panelDecoration(theme),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                            child: Consumer<ChatViewModel>(
                              builder: (context, viewModel, _) {
                                final identity = viewModel.identity;

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: viewModel.isLoading
                                      ? const _ChatLoadingState()
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _ChatHeader(
                                              threadTitle:
                                                  viewModel.thread?.displayName,
                                              identityName:
                                                  identity != null ? 'Du' : null,
                                            ),
                                            const SizedBox(height: 12),
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                                child: DecoratedBox(
                                                  decoration: ChatTheme
                                                      .timelineDecoration(theme),
                                                  child: ChatTimeline(
                                                    messages:
                                                        viewModel.messages,
                                                    currentProfileId:
                                                        identity?.profileId ??
                                                            '',
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            ChatComposer(
                                              onSend: viewModel.sendMessage,
                                              isSending: viewModel.isSending ||
                                                  viewModel.thread == null,
                                              errorMessage: viewModel.error,
                                            ),
                                          ],
                                        ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    this.threadTitle,
    this.identityName,
  });

  final String? threadTitle;
  final String? identityName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = threadTitle?.trim().isNotEmpty == true
        ? threadTitle!
        : 'Direkte samtale';

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 26,
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: ChatTheme.headerTitleStyle(theme),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fokusmodus · Privat',
                    style: ChatTheme.headerSubtitleStyle(theme),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (identityName != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                identityName!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          tooltip: 'Flere innstillinger',
          onPressed: () {},
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
