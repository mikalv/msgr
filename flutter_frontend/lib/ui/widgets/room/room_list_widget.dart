import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/theme.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/room/room_list_item.dart';
import 'package:messngr/utils/flutter_redux.dart';

class RoomListWidget extends StatelessWidget {
  const RoomListWidget({
    super.key,
    required this.context,
    required this.rooms,
    required this.store,
  });

  final dynamic context;
  final dynamic rooms;
  final dynamic store;

  @override
  Widget build(BuildContext context) {
    final theList = ListView.builder(
      shrinkWrap: true,
      itemCount: rooms.length,
      itemBuilder: (BuildContext context, int index) {
        final Room room = rooms[index];
        return RoomListItem(
            key: Key(room.id), store: store, room: room, index: index);
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
                StoreProvider.of<AppState>(context).dispatch(
                    NavigateShellToNewRouteAction(
                        route: AppNavigation.createRoomPath +
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
