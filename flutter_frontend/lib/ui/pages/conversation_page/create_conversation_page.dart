import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/ui/widgets/dropdown_search/dropdown_search.dart';

class CreateConversationPage extends StatefulWidget {
  final String teamName;
  const CreateConversationPage({super.key, required this.teamName});

  @override
  State<CreateConversationPage> createState() => _CreateConversationPageState();
}

class _CreateConversationPageState extends State<CreateConversationPage> {
  final TextEditingController _conversationMembersController =
      TextEditingController();
  late TeamRepositories repos;
  late ProfileRepository profileRepository;
  final List<Profile> selectedMembers = [];

  @override
  void initState() {
    super.initState();

    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    profileRepository = repos.profileRepository;
  }

  @override
  void dispose() {
    _conversationMembersController.dispose();
    super.dispose();
  }

  void _createConversation() {
    if (selectedMembers.isNotEmpty) {
      final membersIDs = selectedMembers.map((e) => e.id).toList();
      // Logic to create a new chat room
      print('Conversation create request: $selectedMembers => $membersIDs');
      // Navigate back or to the new chat room
      final ConversationRepository conversationRepository =
          repos.conversationRepository;
    } else {
      // Show error message
      print('Please fill in all fields');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Conversation'),
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
                  DropdownSearch<Profile>.multiSelection(
                    onChanged: (List<Profile> selected) {
                      selectedMembers.clear();
                      selectedMembers.addAll(selected);
                    },
                    items: (filter, s) => getData(filter),
                    compareFn: (i, s) => i == s,
                    popupProps: PopupPropsMultiSelection.bottomSheet(
                      bottomSheetProps: const BottomSheetProps(
                          backgroundColor: Color.fromARGB(255, 87, 135, 167)),
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
                  ElevatedButton(
                    onPressed: _createConversation,
                    child: const Text('Create Conversation'),
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
