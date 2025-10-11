import 'package:flutter/material.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/ui/widgets/conversation/conversations_list_widget.dart';
import 'package:messngr/ui/widgets/room/room_list_widget.dart';
import 'package:messngr/utils/flutter_redux.dart';

class RecentChats extends StatelessWidget {
  const RecentChats({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return StoreProvider(
      store: store,
      child: Expanded(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              RoomListWidget(
                  context: context,
                  rooms: store.state.teamState?.rooms ?? [],
                  store: store),
              ConversationsListWidget(
                  context: context,
                  conversations: store.state.teamState?.conversations ?? [],
                  store: store)
            ],
          ),
        ),
      ),
    );
  }
}
