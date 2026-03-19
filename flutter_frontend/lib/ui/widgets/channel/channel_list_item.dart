import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/config/theme/channel_list_view_theme.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChannelListItem extends ConsumerStatefulWidget {
  final Channel channel;
  final int index;
  const ChannelListItem(
      {super.key,
      required this.channel,
      required this.index});

  @override
  ConsumerState<ChannelListItem> createState() => _ChannelListItemState();
}

class _ChannelListItemState extends ConsumerState<ChannelListItem> {
  late final MessageRepository messageRepository;
  late final ProfileRepository profileRepository;

  @override
  void initState() {
    final currentTeam = ref.read(currentTeamProvider);
    if (currentTeam != null) {
      final repos = LibMsgr()
          .repositoryFactory
          .getRepositories(currentTeam.name);
      messageRepository = repos.messageRepository;
      profileRepository = repos.profileRepository;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context).channelListViewTheme;
    final lastMessage = messageRepository.getLastChannelMessage(widget.channel.id);
    final unreadCount =
        messageRepository.getUnreadMessagesCount(widget.channel.id);
    var lastMsgString = '';
    var lastMsgTimeString = timeago.format(widget.channel.updatedAt);
    if (lastMessage == null) {
      lastMsgString = 'No messages yet';
    } else {
      final lastMsgProfile =
          profileRepository.fetchByID(lastMessage.fromProfileID);
      lastMsgString = '@${lastMsgProfile.username}: ${lastMessage.content}';
      lastMsgTimeString = timeago.format(lastMessage.updatedAt);
    }
    return GestureDetector(
      onTap: () {
        final currentTeam = ref.read(currentTeamProvider);
        if (currentTeam != null) {
          context.go('${AppNavigation.channelsPath}/${widget.channel.id}');
        }
      },
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
                          '#${widget.channel.name}'.toLowerCase(),
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
