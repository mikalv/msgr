import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/features/chat/models/chat_thread.dart';
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
  final TextEditingController _topicController = TextEditingController();
  late TeamRepositories repos;
  late ProfileRepository profileRepository;
  final List<Profile> selectedMembers = [];
  ChatThreadKind _selectedKind = ChatThreadKind.direct;
  ChatStructureType _selectedStructure = ChatStructureType.friends;
  bool _channelIsPrivate = false;

  @override
  void initState() {
    super.initState();

    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    profileRepository = repos.profileRepository;
  }

  @override
  void dispose() {
    _conversationMembersController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _createConversation() {
    final membersIDs = selectedMembers.map((e) => e.id).toList();
    final topic = _topicController.text.trim();
    final structureType = _selectedStructure;

    String? validationError;

    switch (_selectedKind) {
      case ChatThreadKind.direct:
        if (membersIDs.length != 1) {
          validationError = 'Velg én deltaker for en direkte samtale.';
        }
        break;
      case ChatThreadKind.group:
        if (membersIDs.isEmpty) {
          validationError = 'Velg minst én annen deltaker for gruppen.';
        } else if (topic.isEmpty) {
          validationError = 'Sett et navn eller tema for gruppen.';
        }
        break;
      case ChatThreadKind.channel:
        if (topic.isEmpty) {
          validationError = 'Kanaler må ha et navn eller tema.';
        }
        break;
    }

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    final visibility =
        _selectedKind == ChatThreadKind.channel && _channelIsPrivate
            ? 'private'
            : 'team';

    debugPrint(
        'Conversation create request ($_selectedKind): members=$membersIDs topic=$topic structure=$structureType visibility=$visibility');

    // TODO: Integrate conversationRepository when backend bindings are ready.
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<ChatThreadKind>(
                      value: _selectedKind,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedKind = value;
                          _selectedStructure = value == ChatThreadKind.channel
                              ? ChatStructureType.project
                              : ChatStructureType.friends;
                          _channelIsPrivate = false;
                        });
                      },
                      items: const [
                        DropdownMenuItem(
                          value: ChatThreadKind.direct,
                          child: Text('Direkte (1:1)'),
                        ),
                        DropdownMenuItem(
                          value: ChatThreadKind.group,
                          child: Text('Gruppe'),
                        ),
                        DropdownMenuItem(
                          value: ChatThreadKind.channel,
                          child: Text('Kanal'),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedKind != ChatThreadKind.direct)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          labelText: _selectedKind == ChatThreadKind.channel
                              ? 'Kanalnavn'
                              : 'Gruppenavn',
                        ),
                      ),
                    ),
                  if (_selectedKind != ChatThreadKind.direct)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: DropdownButtonFormField<ChatStructureType>(
                        value: _selectedStructure,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedStructure = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Struktur',
                        ),
                        items: ChatStructureType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_structureLabel(type)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  if (_selectedKind == ChatThreadKind.channel)
                    SwitchListTile(
                      title: const Text('Skjul kanal for andre'),
                      subtitle:
                          const Text('Kun inviterte medlemmer kan se kanalen'),
                      value: _channelIsPrivate,
                      onChanged: (value) {
                        setState(() {
                          _channelIsPrivate = value;
                        });
                      },
                    ),
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

  String _structureLabel(ChatStructureType type) {
    switch (type) {
      case ChatStructureType.family:
        return 'Familie';
      case ChatStructureType.business:
        return 'Bedrift';
      case ChatStructureType.friends:
        return 'Vennegjeng';
      case ChatStructureType.project:
        return 'Prosjekt';
      case ChatStructureType.other:
        return 'Annet';
    }
  }
}
