import 'dart:async';

import 'package:flutter/material.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/redux/app_state.dart';
import 'package:messngr/redux/message/message_actions.dart';
import 'package:messngr/redux/navigation/navigation_actions.dart';
import 'package:messngr/ui/widgets/message/message_list_widget.dart';
import 'package:messngr/ui/widgets/message/message_widget.dart';
import 'package:messngr/ui/widgets/message_composer/message_composer.dart';
import 'package:messngr/utils/flutter_redux.dart';

class ConversationPage extends StatefulWidget {
  final String title;
  //final String roomID;
  late final Conversation conversation;
  final String conversationID;
  final String teamName;
  late final TeamRepositories repos;

  ConversationPage(
      {super.key,
      required this.title,
      required this.conversationID,
      required this.teamName}) {
    repos = LibMsgr().repositoryFactory.getRepositories(teamName);
    conversation = repos.conversationRepository.fetchByID(conversationID);
  }

  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _newMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode composerFocusNode = FocusNode();
  late TeamRepositories repos;
  late MessageRepository messageRepository;
  List<MMessage> messages = [];

  @override
  void initState() {
    super.initState();
    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    messages.addAll(repos.messageRepository
        .fetchConversationHistory(widget.conversation.id));
    messageRepository = repos.messageRepository;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _newMessageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _buildMessage(MMessage message) {
    return MessageWidget(message: message, teamName: widget.teamName);
  }

  Widget _buildMessageComposer({context}) {
    return MessageComposer(
        controller: _newMessageController,
        textCapitalization: TextCapitalization.sentences,
        focusNode: composerFocusNode,
        onMessageSent: (p0) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        },
        onChanged: (p0) {
          // TODO: Add a timer here, for signaling "is typing" to the server
          //print(p0);
        },
        onSubmitted: (String msg) {
          print('submitted: ${_newMessageController.text}');
          if (_newMessageController.text == '') {
            return;
          }
          final store = StoreProvider.of<AppState>(context);
          Completer completer = Completer();
          completer.future.then(
            (value) {
              _newMessageController.clear();
            },
          ).catchError((error) {
            print('Error: $error');
          });
          var msg = MMessage(
            content: _newMessageController.text,
            fromProfileID: store.state.authState.currentProfile!.id,
            conversationID: widget.conversation.id,
          );
          store.dispatch(
            SendMessageAction(
              msg: msg,
              completer: completer,
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => store.dispatch(NavigateShellToNewRouteAction(
              route: AppNavigation.dashboardPath, kRouteDoPopInstead: false)),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, //change your color here
        ),
        title: Text(widget.title), //widget.user.username ?? 'Unknown'),
        centerTitle: true,
        elevation: 0.00,
        backgroundColor: Colors.greenAccent[400],
        titleSpacing: 00.0,
        bottom: PreferredSize(
            preferredSize: Size.zero,
            child: GestureDetector(
              child: Text(widget.conversation.topic ??
                  'The conversation has no topic yet!'),
              onTap: () {
                print("tapped subtitle");
              },
            )),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                  child: MessageListWidget(
                      stream: messageRepository
                          .fetchConversationMessages(widget.conversationID),
                      scrollController: _scrollController,
                      padding: const EdgeInsets.only(top: 15.0),
                      teamName: widget.teamName),
                ),
              ),
            ),
            _buildMessageComposer(context: context),
          ],
        ),
      ),
    );
  }
}
