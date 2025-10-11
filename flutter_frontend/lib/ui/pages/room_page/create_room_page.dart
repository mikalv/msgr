import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/config/themedata.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/custom_switch.dart';
import 'package:messngr/ui/widgets/dropdown_search/dropdown_search.dart';
import 'package:messngr/utils/flutter_redux.dart';

class CreateRoomPage extends StatefulWidget {
  final String teamName;
  const CreateRoomPage({super.key, required this.teamName});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _roomDescriptionController =
      TextEditingController();
  late TeamRepositories repos;
  late ProfileRepository profileRepository;
  bool _shouldBePrivateRoom = false;
  final List<Profile> selectedMembers = [];

  @override
  void initState() {
    super.initState();

    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    profileRepository = repos.profileRepository;
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _roomDescriptionController.dispose();
    super.dispose();
  }

  void _createRoom(context) {
    final String roomName = _roomNameController.text;
    final String roomDescription = _roomDescriptionController.text;

    if (roomName.isNotEmpty &&
        roomDescription.isNotEmpty &&
        selectedMembers.isNotEmpty) {
      // Logic to create a new chat room
      print(
          'Room create request: $roomName, Description: $roomDescription, Members: $selectedMembers');
      final store = StoreProvider.of<AppState>(context);

      final RoomRepository roomRepository = repos.roomRepository;
      final fpush = roomRepository.createRoom(
          profileID: store.state.authState.currentProfile?.id,
          roomName: roomName,
          roomDescription: roomDescription,
          isSecret: false,
          members: selectedMembers.map((e) => e.id).toList());
      fpush?.future.then((msg) {
        print('Room created successfully');
        store.dispatch(NavigateShellToNewRouteAction(
            route: AppNavigation.dashboardPath, kRouteDoPopInstead: true));
      }).onError((error, stackTrace) {
        print('Error creating room: $error');
      });
      // Navigate back or to the new chat room
    } else {
      // Show error message
      print('Please fill in all fields');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Chat Room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => AppNavigation.router.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextField(
                    controller: _roomNameController,
                    style: formTextStyle,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: 'Room name',
                        hintText: 'your-room-name',
                        hintTextDirection: TextDirection.ltr,
                        hintStyle: formHintTextStyle,
                        focusedBorder: borderStyle,
                        enabledBorder: borderStyle,
                        errorBorder: borderStyle,
                        disabledBorder: borderStyle,
                        fillColor: Colors.white,
                        filled: true,
                        focusColor: Colors.white,
                        hoverColor: Colors.white,
                        border: borderStyle),
                  ),
                  const SizedBox(height: 16.0),
                  DropdownSearch<Profile>.multiSelection(
                    onChanged: (List<Profile> selected) {
                      selectedMembers.clear();
                      selectedMembers.addAll(selected);
                    },
                    items: (filter, s) => getData(filter),
                    compareFn: (i, s) => i == s,
                    popupProps: PopupPropsMultiSelection.bottomSheet(
                      bottomSheetProps: BottomSheetProps(
                          backgroundColor: Colors.blueGrey[50]),
                      showSearchBox: true,
                      itemBuilder: profileModelPopupItem,
                      suggestedItemProps: SuggestedItemProps(
                        showSuggestedItems: true,
                        suggestedItems: (us) {
                          return us; //.where((e) => e.name.contains("Mrs")).toList();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _roomDescriptionController,
                    style: formTextStyle,
                    maxLines: 5,
                    decoration: InputDecoration(
                        labelText: 'Room Description',
                        hintText: 'My awesome room',
                        hintTextDirection: TextDirection.ltr,
                        hintStyle: formHintTextStyle,
                        focusedBorder: borderStyle,
                        enabledBorder: borderStyle,
                        errorBorder: borderStyle,
                        disabledBorder: borderStyle,
                        fillColor: Colors.white,
                        filled: true,
                        focusColor: Colors.white,
                        hoverColor: Colors.white,
                        border: borderStyle),
                  ),
                  const SizedBox(height: 16.0),
                  CustomSwitch(
                    activeText: 'Room is private',
                    activeTooltip:
                        'The room will be private which means it\'s only visible to members',
                    inactiveText: 'Room is public',
                    inactiveTooltip: 'Anyone on the team can join this room',
                    value: _shouldBePrivateRoom,
                    activeColor: Colors.red,
                    inactiveColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _shouldBePrivateRoom = value;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 16.0,
                  ),
                  ElevatedButton(
                    onPressed: () => _createRoom(context),
                    child: const Text('Create Room'),
                  ),
                ],
              )),
        ),
      ),
    );
  }

  Widget profileModelPopupItem(
      BuildContext context, Profile item, bool isDisabled, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: !isSelected
          ? null
          : BoxDecoration(
              border: Border.all(color: Theme.of(context).primaryColor),
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
      child: ListTile(
        selected: isSelected,
        title: Text(item.username),
        subtitle: Text('${item.firstName} ${item.lastName}'),
        leading: CircleAvatar(child: Text(item.username[0])),
      ),
    );
  }

  getData(String filter) {
    return profileRepository.listTeamProfiles();
  }
}
