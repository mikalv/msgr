import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/config/theme.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/team_provider.dart';
import 'package:core/ui/widgets/channel/channel_list_item.dart';
import 'package:go_router/go_router.dart';

class ChannelListWidget extends ConsumerWidget {
  const ChannelListWidget({
    super.key,
    required this.context,
    this.modeFilter,
  });

  final BuildContext context;
  final ProfileMode? modeFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final theList = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: channels.length,
      itemBuilder: (BuildContext context, int index) {
        final Channel channel = channels[index];
        return ChannelListItem(
            key: Key(channel.id), channel: channel, index: index);
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
                final currentTeam = ref.read(currentTeamProvider);
                if (currentTeam != null) {
                  context.push(AppNavigation.createChannelPath + currentTeam.name);
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
