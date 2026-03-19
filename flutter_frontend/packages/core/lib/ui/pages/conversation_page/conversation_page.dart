import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:core/config/AppNavigation.dart';
import 'package:core/providers/auth_provider.dart';
import 'package:core/providers/websocket_provider.dart';
import 'package:core/ui/widgets/message/message_list_widget.dart';
import 'package:core/ui/widgets/message/message_widget.dart';
import 'package:core/ui/widgets/message_composer/message_composer.dart';

class ConversationPage extends ConsumerStatefulWidget {
  final String title;
  //final String channelID;
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
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
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
          // Send typing indicator to server
          ref.read(webSocketProvider.notifier).sendTypingIndicator(
                conversationId: widget.conversation.id,
              );
        },
        onSubmitted: (String msg) {
          print('submitted: ${_newMessageController.text}');
          if (_newMessageController.text == '') {
            return;
          }

          // Send message via WebSocket provider
          try {
            ref.read(webSocketProvider.notifier).sendMessage(
                  content: _newMessageController.text,
                  conversationId: widget.conversation.id,
                );
            _newMessageController.clear();
          } catch (error) {
            print('Error sending message: $error');
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.go(AppNavigation.dashboardPath),
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
