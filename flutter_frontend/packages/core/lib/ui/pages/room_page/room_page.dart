import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/config/AppNavigation.dart';
import 'package:messngr/providers/auth_provider.dart';
import 'package:messngr/providers/websocket_provider.dart';
import 'package:messngr/ui/widgets/message/message_list_widget.dart';
import 'package:messngr/ui/widgets/message_composer/message_composer.dart';

class RoomPage extends ConsumerStatefulWidget {
  final String roomID;
  //final String roomID;
  late final Room room;
  final String teamName;
  late final TeamRepositories repos;

  RoomPage({super.key, required this.roomID, required this.teamName}) {
    repos = LibMsgr().repositoryFactory.getRepositories(teamName);
    room = repos.roomRepository.fetchByID(roomID);
  }

  @override
  ConsumerState<RoomPage> createState() => RoomPageState();
}

class RoomPageState extends ConsumerState<RoomPage> with WidgetsBindingObserver {
  final TextEditingController _newMessageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode composerFocusNode = FocusNode();
  late TeamRepositories repos;
  late MessageRepository messageRepository;
  var _isInForeground = true;

  @override
  void initState() {
    super.initState();
    print('Fetching room history for ${widget.room.id}');
    repos = LibMsgr().repositoryFactory.getRepositories(widget.teamName);
    messageRepository = repos.messageRepository;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: $state');
    if (state == AppLifecycleState.resumed) {
      print('AppLifecycleState: $state');
    }
    _isInForeground = [
      AppLifecycleState.resumed,
      AppLifecycleState.inactive,
    ].contains(state);
    if (_isInForeground) {
      _onForeground();
    } else {
      _onBackground();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  /// Function to scroll to last messages in chat view
  void scrollToLastMessage() => Timer(
        const Duration(milliseconds: 300),
        () => _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          curve: Curves.easeIn,
          duration: const Duration(milliseconds: 300),
        ),
      );

  @override
  void didUpdateWidget(RoomPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomID != widget.roomID) {
      // Clear messages when roomID changes
      setState(() {});
      WidgetsBinding.instance
          .addPostFrameCallback((_) => scrollToLastMessage());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up the controllers when the widget is disposed
    _newMessageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _buildMessageComposer(context) {
    return MessageComposer(
        key: const Key('messageComposer'),
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
                roomId: widget.room.id,
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
                  roomId: widget.room.id,
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
        title: Text(
            widget.room.formattedName), //widget.user.username ?? 'Unknown'),
        centerTitle: true,
        elevation: 0.00,
        backgroundColor: Colors.greenAccent[400],
        titleSpacing: 00.0,
        bottom: PreferredSize(
            preferredSize: Size.zero,
            child: GestureDetector(
              child: Text(widget.room.topic ?? 'The room has no topic yet!'),
              onTap: () {
                print('tapped subtitle');
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
                  color: Color.fromARGB(255, 9, 51, 64),
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
                      stream:
                          messageRepository.fetchRoomMessages(widget.roomID),
                      scrollController: _scrollController,
                      padding: const EdgeInsets.only(top: 15.0),
                      teamName: widget.teamName),
                ),
              ),
            ),
            _buildMessageComposer(context),
          ],
        ),
      ),
    );
  }

  void _onForeground() {
    // TODO: Find a better method to scroll to last message
    // because maybe the user wants to read at a certian point,
    // however the default should scroll down to the last message
    scrollToLastMessage();
  }

  void _onBackground() {}
}
