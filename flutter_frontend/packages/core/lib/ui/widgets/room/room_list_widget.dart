import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:messngr/providers/team_provider.dart';
import 'package:messngr/ui/widgets/room/room_list_item.dart';
import 'package:go_router/go_router.dart';

class RoomListWidget extends ConsumerWidget {
  const RoomListWidget({
    super.key,
    required this.context,
    this.modeFilter,
  });

  final BuildContext context;
  final ProfileMode? modeFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final theList = ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rooms.length,
      itemBuilder: (BuildContext context, int index) {
        final Room room = rooms[index];
        return RoomListItem(
            key: Key(room.id), room: room, index: index);
      },
    );
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 10.0),
            Text('Rooms',
                style: AppTheme.of(context)
                    .channelListViewTheme
                    .data
                    .mainListHeaderStyle),
            IconButton(
              icon: const Icon(Icons.add_comment),
              onPressed: () {
                final currentTeam = ref.read(currentTeamProvider);
                if (currentTeam != null) {
                  context.push(AppNavigation.createRoomPath + currentTeam.name);
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
