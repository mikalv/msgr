import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/channel/channel_list_item.dart';
import 'package:messngr/utils/flutter_redux.dart';

class ChannelListWidget extends StatelessWidget {
  const ChannelListWidget({
    super.key,
    required this.context,
    required this.channels,
    required this.store,
  });

  final dynamic context;
  final dynamic channels;
  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final theList = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length,
      itemBuilder: (BuildContext context, int index) {
        final Channel channel = channels[index];
        return ChannelListItem(
            key: Key(channel.id), store: store, channel: channel, index: index);
      },
    );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 10.0),
            Text('Channels',
                style: AppTheme.of(context)
                    .channelListViewTheme
                    .data
                    .mainListHeaderStyle),
            IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: () {
                StoreProvider.of<AppState>(context).dispatch(
                    NavigateShellToNewRouteAction(
                        route: AppNavigation.createChannelPath +
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
