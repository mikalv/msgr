import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/theme/channel_list_view_theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:redux/redux.dart';
import 'package:timeago/timeago.dart' as timeago;

class RoomListItem extends StatefulWidget {
  final Store<AppState> store;
  final Room room;
  final int index;
  const RoomListItem(
      {super.key,
      required this.store,
      required this.room,
      required this.index});

  @override
  State<RoomListItem> createState() => _RoomListItemState();
}

class _RoomListItemState extends State<RoomListItem> {
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
    final lastMessage = messageRepository.getLastRoomMessage(widget.room.id);
    final unreadCount =
        messageRepository.getUnreadMessagesCount(widget.room.id);
    var lastMsgString = '';
    var lastMsgTimeString = timeago.format(widget.room.updatedAt);
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
          route: '${AppNavigation.roomsPath}/${widget.room.id}',
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 10.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '#${widget.room.name}'.toLowerCase(),
                      style: theme.data.titleStyle,
                    ),
                    const SizedBox(height: 5.0),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.45,
                      child: Text(
                        lastMsgString,
                        style: theme.data.messagePreviewStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
