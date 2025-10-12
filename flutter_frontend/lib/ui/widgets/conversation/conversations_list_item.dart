import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/theme/channel_list_view_theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:redux/redux.dart';
import 'package:timeago/timeago.dart' as timeago;

/// This is the conversations list item widget, used to display a single conversation in the conversations list.
/// It is used by the [ConversationsListWidget] widget.
/// It is similar to the [RoomListItem] widget.
class ConversationsListItem extends StatefulWidget {
  final Store<AppState> store;
  final Conversation conversation;
  final int index;
  const ConversationsListItem(
      {super.key,
      required this.store,
      required this.conversation,
      required this.index});

  @override
  State<ConversationsListItem> createState() => _ConversationsListItemState();
}

class _ConversationsListItemState extends State<ConversationsListItem> {
  late final MessageRepository messageRepository;
  late final ProfileRepository profileRepository;

  @override
  void initState() {
    final repos = LibMsgr()
        .repositoryFactory
        .getRepositories(widget.store.state.teamState!.selectedTeam!.name);
    messageRepository = repos.messageRepository;
    profileRepository = repos.profileRepository;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context).channelListViewTheme;
    final lastMessage =
        messageRepository.getLastRoomMessage(widget.conversation.id);
    final unreadCount =
        messageRepository.getUnreadMessagesCount(widget.conversation.id);
    var lastMsgString = '';
    var lastMsgTimeString = timeago.format(widget.conversation.updatedAt);
    if (lastMessage == null) {
      lastMsgString = 'No messages yet';
    } else {
      final lastMsgProfile =
          profileRepository.fetchByID(lastMessage.fromProfileID);
      lastMsgString = '@${lastMsgProfile.username}: ${lastMessage.content}';
      lastMsgTimeString = timeago.format(lastMessage.updatedAt);
    }
    return GestureDetector(
      onTap: () => widget.store.dispatch(NavigateShellToNewRouteAction(
          route: '${AppNavigation.conversationsPath}/${widget.conversation.id}',
          context: context,
          kRouteArgs: {
            'teamName': widget.store.state.teamState!.selectedTeam!.name
          },
          kUsePush: false)),
      child: Container(
        margin: theme.data.margin,
        padding: theme.data.padding,
        decoration: theme.data.decoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.conversation
                              .conversationName(widget
                                  .store.state.teamState!.selectedTeam!.name)
                              .toLowerCase(),
                          style: theme.data.titleStyle,
                        ),
                        const SizedBox(height: 5.0),
                        Text(
                          lastMsgString,
                          style: theme.data.messagePreviewStyle,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  lastMsgTimeString,
                  style: theme.data.timestampStyle,
                ),
                const SizedBox(height: 5.0),
                unreadBox(theme, unreadCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget unreadBox(ChannelListViewTheme theme, int unreadCount) {
    return (unreadCount > 0)
        ? Container(
            width: 70.0,
            height: 30.0,
            decoration: theme.data.unreadMessageCountDecoration,
            alignment: Alignment.center,
            child: Text(
              'NEW ($unreadCount)',
              style: theme.data.unreadMessageCountStyle,
            ),
          )
        : const Text('');
  }
}
