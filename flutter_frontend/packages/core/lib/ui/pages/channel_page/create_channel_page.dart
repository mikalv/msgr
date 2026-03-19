import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/config/themedata.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/ui/widgets/custom_switch.dart';
import 'package:core/ui/widgets/dropdown_search/dropdown_search.dart';

class CreateChannelPage extends ConsumerStatefulWidget {
  final String teamName;
  const CreateChannelPage({super.key, required this.teamName});

  @override
  ConsumerState<CreateChannelPage> createState() => _CreateChannelPageState();
}

class _CreateChannelPageState extends ConsumerState<CreateChannelPage> {
  final TextEditingController _channelNameController = TextEditingController();
  final TextEditingController _channelDescriptionController =
      TextEditingController();
  late TeamRepositories repos;
  late ProfileRepository profileRepository;
  bool _shouldBePrivateChannel = false;
  final List<Profile> selectedMembers = [];

  @override
  void initState() {
    super.initState();

    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    profileRepository = repos.profileRepository;
  }

  @override
  void dispose() {
    _channelNameController.dispose();
    _channelDescriptionController.dispose();
    super.dispose();
  }

  void _createChannel(context) {
    final String channelName = _channelNameController.text;
    final String channelDescription = _channelDescriptionController.text;

    if (channelName.isNotEmpty &&
        channelDescription.isNotEmpty &&
        selectedMembers.isNotEmpty) {
      // Logic to create a new chat channel
      print(
          'Channel create request: $channelName, Description: $channelDescription, Members: $selectedMembers');

      final currentProfile = ref.read(currentProfileProvider);
      if (currentProfile == null) {
        print('No current profile');
        return;
      }

      final ChannelRepository channelRepository = repos.channelRepository;
      final fpush = channelRepository.createChannel(
          profileID: currentProfile.id,
          channelName: channelName,
          channelDescription: channelDescription,
          isSecret: false,
          members: selectedMembers.map((e) => e.id).toList());
      fpush?.future.then((msg) {
        print('Channel created successfully');
        if (!mounted) return;
        context.go(AppNavigation.dashboardPath);
      }).onError((error, stackTrace) {
        print('Error creating channel: $error');
      });
      // Navigate back or to the new chat channel
    } else {
      // Show error message
      print('Please fill in all fields');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Chat Channel'),
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
                    controller: _channelNameController,
                    style: formTextStyle,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: 'Channel name',
                        hintText: 'your-channel-name',
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
                    controller: _channelDescriptionController,
                    style: formTextStyle,
                    maxLines: 5,
                    decoration: InputDecoration(
                        labelText: 'Channel Description',
                        hintText: 'My awesome channel',
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
                    activeText: 'Channel is private',
                    activeTooltip:
                        'The channel will be private which means it\'s only visible to members',
                    inactiveText: 'Channel is public',
                    inactiveTooltip: 'Anyone on the team can join this channel',
                    value: _shouldBePrivateChannel,
                    activeColor: Colors.red,
                    inactiveColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _shouldBePrivateChannel = value;
                      });
                    },
                  ),
                  const SizedBox(
                    height: 16.0,
                  ),
                  ElevatedButton(
                    onPressed: () => _createChannel(context),
                    child: const Text('Create Channel'),
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
