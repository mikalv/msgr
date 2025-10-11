import 'package:flutter/material.dart';
import 'package:flutter_profile_picture/flutter_profile_picture.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/ui/pages/conversation_page/conversation_page.dart';
import 'package:messngr/ui/pages/room_page/room_page.dart';
import 'package:messngr/utils/flutter_redux.dart';

class FavoriteContacts extends StatefulWidget {
  const FavoriteContacts({super.key});

  @override
  State<FavoriteContacts> createState() => _FavoriteContactsState();
}

class _FavoriteContactsState extends State<FavoriteContacts> {
  @override
  Widget build(BuildContext context) {
    final roomList = StoreProvider.of<AppState>(context).state.teamState!.rooms;
    print('roomList: ${roomList}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'Favorite Contacts',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                  ),
                  iconSize: 30.0,
                  color: Colors.blueGrey,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120.0,
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 10.0),
              scrollDirection: Axis.horizontal,
              itemCount: roomList.length,
              itemBuilder: (BuildContext context, int index) {
                return GestureDetector(
                  onTap: () => {},
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: <Widget>[
                        ProfilePicture(
                          name: roomList[index].name ?? 'Unknown',
                          radius: 35,
                          fontsize: 21,
                        ),
                        const SizedBox(height: 6.0),
                        Text(
                          roomList[index].name ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
