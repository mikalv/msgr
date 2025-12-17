import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/config/theme.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/team_provider.dart';
import 'package:core/ui/widgets/conversation/conversations_list_item.dart';
import 'package:go_router/go_router.dart';

/// This widget is used to display a list of conversations.
/// So not to be confused with the [ConversationPage] widget which is used to display a single conversation.
class ConversationsListWidget extends ConsumerWidget {
  const ConversationsListWidget({
    super.key,
    required this.context,
    this.modeFilter,
  });

  final BuildContext context;
  final ProfileMode? modeFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use filtered providers based on modeFilter, or get all conversations
    final conversations = modeFilter == ProfileMode.private || modeFilter == ProfileMode.family
        ? ref.watch(personalConversationsProvider)
        : modeFilter == ProfileMode.work
            ? ref.watch(workConversationsProvider)
            : ref.watch(conversationsProvider);

    final filtered = conversations;

    final theList = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (BuildContext context, int index) {
        final Conversation conversation = filtered[index];
        return ConversationsListItem(
            key: Key(conversation.id),
            conversation: conversation,
            index: index);
      },
    );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 10.0),
            Text('Conversations',
                style: AppTheme.of(context)
                    .channelListViewTheme
                    .data
                    .mainListHeaderStyle),
            IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: () {
                final currentTeam = ref.read(currentTeamProvider);
                if (currentTeam != null) {
                  context.push(AppNavigation.createConversationPath + currentTeam.name);
                }
              },
            )
          ],
        ),
        theList
      ],
    );
  }
}
