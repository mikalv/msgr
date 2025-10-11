import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/conversation/conversations_list_item.dart';
import 'package:messngr/utils/flutter_redux.dart';

/// This widget is used to display a list of conversations.
/// So not to be confused with the [ConversationPage] widget which is used to display a single conversation.
class ConversationsListWidget extends StatelessWidget {
  const ConversationsListWidget({
    super.key,
    required this.context,
    required this.conversations,
    required this.store,
  });

  final dynamic context;
  final dynamic conversations;
  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final theList = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: conversations.length,
      itemBuilder: (BuildContext context, int index) {
        final Conversation conversation = conversations[index];
        return ConversationsListItem(
            key: Key(conversation.id),
            store: store,
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
                StoreProvider.of<AppState>(context).dispatch(
                    NavigateShellToNewRouteAction(
                        route: AppNavigation.createConversationPath +
                            store.state.authState.currentTeamName!,
                        kUsePush: true));
              },
            )
          ],
        ),
        theList
      ],
    );
  }
}
