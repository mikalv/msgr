import 'dart:async';

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:libmsgr/src/typedefs.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class MessageRepository extends BaseRepository<MMessage> {
  final MessagesInTransit _outgoingMessages = [];
  final MessageDao _dao;

  MessageRepository({required super.teamName, required MessageDao dao})
      : _dao = dao {
    log.info('MessageRepository is starting up.');
    unawaited(_hydrateFromDisk());
  }

  Future<void> _hydrateFromDisk() async {
    final stored = await _dao.getMessagesForTeam(teamName);
    if (stored.isNotEmpty) {
      super.fillLocalCache(stored);
    }
  }

  @override
  void fillLocalCache(List<MMessage> items) {
    super.fillLocalCache(items);
    unawaited(_dao.upsertMessages(teamName, items));
  }

  @override
  void addItem(MMessage item) {
    super.addItem(item);
    unawaited(_dao.upsertMessages(teamName, [item]));
  }

  @override
  void updateItem(MMessage item) {
    super.updateItem(item);
    unawaited(_dao.upsertMessages(teamName, [item]));
  }

  @override
  void removeItem(String id) {
    super.removeItem(id);
    unawaited(_dao.deleteMessages(teamName, [id]));
  }

  List<MMessage> fetchRoomHistory(String roomID) {
    log.info('Will get room messages for $roomID');
    return items.cast<MMessage>().where((x) => x.roomID == roomID).toList();
  }

  int getUnreadMessagesCount(String roomID) {
    return items
        .cast<MMessage>()
        .where((x) => x.roomID == roomID && !x.isMsgRead)
        .length;
  }

  MMessage? getLastRoomMessage(String roomID) {
    return items
        .cast<MMessage>()
        .where((x) => x.roomID == roomID)
        .toList()
        .lastOrNull;
  }

  void markMessageAsRead(String messageID) {
    items.map((message) {
      if (message.id == messageID) {
        final msg = message.copyWith(isMsgRead: true);
        updateItem(msg);
      }
    }).length;
  }

  Stream<List<MMessage>> fetchRoomMessages(String roomID) {
    late final StreamController<List<MMessage>> controller;

    void selfListener(List<MMessage> messages) {
      final allMessages =
          items.cast<MMessage>().where((x) => x.roomID == roomID).toList();
      controller.add(allMessages);
    }

    void startStream() {
      log.info('Starting stream for room $roomID');
      addListener(selfListener);
      final listen =
          items.cast<MMessage>().where((x) => x.roomID == roomID).toList();
      /*listen.forEach((element) {
        _log.info('Adding message to stream: ${element.roomID}');
      });*/
      controller.add(listen);
    }

    void stopStream() {
      log.info('Stopping stream for room $roomID');
      removeListener(selfListener);
    }

    controller = StreamController<List<MMessage>>(
      onListen: startStream,
      onPause: stopStream,
      onResume: startStream,
      onCancel: stopStream,
    );
    return controller.stream;
  }

  Stream<List<MMessage>> fetchConversationMessages(String conversationID) {
    late final StreamController<List<MMessage>> controller;
    void selfListener(List<MMessage> messages) {
      final allMessages = items
          .cast<MMessage>()
          .where((x) => x.conversationID == conversationID)
          .toList();
      controller.add(allMessages);
    }

    void startStream() {
      log.info('Starting stream for conversation $conversationID');
      addListener(selfListener);
      final listen = items
          .cast<MMessage>()
          .where((x) => x.conversationID == conversationID)
          .toList();
      controller.add(listen);
    }

    void stopStream() {
      log.info('Stopping stream for conversation $conversationID');
      removeListener(selfListener);
    }

    controller = StreamController<List<MMessage>>(
      onListen: startStream,
      onPause: stopStream,
      onResume: startStream,
      onCancel: stopStream,
    );
    return controller.stream;
  }

  List<MMessage> fetchConversationHistory(String conversationID) {
    final List<MMessage> listen = items
        .where((x) => x.conversationID == conversationID)
        .cast<MMessage>()
        .toList();
    return listen;
  }

  Push? sendMessageToRoom(MMessage msg) {
    _outgoingMessages.add(msg);
    final wsConn = LibMsgr().getWebsocketConnection();
    Push? p = wsConn?.sendMessage('$teamName.${msg.roomID!}', msg);
    if (p == null) {
      log.severe('Error sending message: Push is null');
      return null;
    }
    p.future.then((value) {
      _outgoingMessages.remove(msg);
    });
    p.future.catchError((e) {
      log.severe('Error sending message: $e');
    });
    return p;
  }

  Push? sendMessageToConversation(MMessage msg) {
    _outgoingMessages.add(msg);
    final wsConn = LibMsgr().getWebsocketConnection();
    Push? p = wsConn?.sendMessage('$teamName.${msg.conversationID!}', msg);
    if (p == null) {
      log.severe('Error sending message: Push is null');
      return null;
    }
    p.future.then((value) {
      _outgoingMessages.remove(msg);
    });
    p.future.catchError((e) {
      log.severe('Error sending message: $e');
    });
    return p;
  }
}
