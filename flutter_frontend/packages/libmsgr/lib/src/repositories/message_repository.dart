import 'dart:async';
import 'dart:math' as math;

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/database/daos/outgoing_message_dao.dart';
import 'package:libmsgr/src/models/outgoing_message.dart';
import 'package:libmsgr/src/repositories/base.dart';
import 'package:libmsgr/src/typedefs.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

typedef MsgrConnectionProvider = MsgrConnection? Function();

class MessageRepository extends BaseRepository<MMessage> {
  MessageRepository({
    required super.teamName,
    required MessageDao dao,
    OutgoingMessageDao? outgoingMessageDao,
    MsgrConnectionProvider? connectionProvider,
  })  : _dao = dao,
        _outgoingDao = outgoingMessageDao ??
            OutgoingMessageDao(LibMsgr().databaseService.instance),
        _connectionProvider = connectionProvider ??
            () => LibMsgr().getWebsocketConnection() {
    log.info('MessageRepository is starting up.');
    unawaited(_hydrateFromDisk());
  }

  static const Duration _baseBackoff = Duration(seconds: 2);
  static const int _maxAttempts = 5;

  final MessageDao _dao;
  final OutgoingMessageDao _outgoingDao;
  final MsgrConnectionProvider _connectionProvider;
  Timer? _retryTimer;
  bool _processingQueue = false;

  Future<void> _hydrateFromDisk() async {
    final stored = await _dao.getMessagesForTeam(teamName);
    if (stored.isNotEmpty) {
      super.fillLocalCache(stored);
    }
  }

  void updateDeliveryStatus(
    String messageId,
    MessageDeliveryStatus status, {
    bool? isServerAck,
  }) {
    final message = _findMessage(messageId);

    if (message == null) {
      return;
    }

    final updated = message.copyWith(
      deliveryStatus: status,
      isServerAck: isServerAck ?? message.isServerAck,
    );
    _saveMessage(updated);
  }

  MMessage? _findMessage(String messageId) {
    try {
      return items.firstWhere((m) => m.id == messageId);
    } catch (_) {
      log.warning('Message $messageId not found when updating status');
      return null;
    }
  }

  void _saveMessage(MMessage message) {
    final exists = items.any((element) => element.id == message.id);
    if (exists) {
      updateItem(message);
    } else {
      addItem(message);
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

  Future<Push?> sendMessageToRoom(MMessage msg) {
    return _enqueueAndSend(
      msg.copyWith(
        isServerAck: false,
        deliveryStatus: MessageDeliveryStatus.pending,
      ),
      '$teamName.${msg.roomID!}',
    );
  }

  Future<Push?> sendMessageToConversation(MMessage msg) {
    return _enqueueAndSend(
      msg.copyWith(
        isServerAck: false,
        deliveryStatus: MessageDeliveryStatus.pending,
      ),
      '$teamName.${msg.conversationID!}',
    );
  }

  Future<void> processPendingQueue() async {
    if (_processingQueue) {
      return;
    }
    _processingQueue = true;

    try {
      final pending = await _outgoingDao.getPending(teamName);

      if (pending.isEmpty) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }

      final now = DateTime.now();
      Duration? nextAttemptIn;

      for (final entry in pending) {
        final delay = _backoffFor(entry);
        final lastAttempt = entry.lastAttemptAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final nextAttemptAt = lastAttempt.add(delay);

        if (entry.attemptCount >= _maxAttempts) {
          log.warning(
            'Dropping message ${entry.message.id} after $_maxAttempts failed attempts',
          );
          updateDeliveryStatus(
            entry.message.id,
            MessageDeliveryStatus.failed,
          );
          await _outgoingDao.delete(teamName, entry.message.id);
          continue;
        }

        if (nextAttemptAt.isAfter(now)) {
          final remaining = nextAttemptAt.difference(now);
          if (nextAttemptIn == null || remaining < nextAttemptIn) {
            nextAttemptIn = remaining;
          }
          continue;
        }

        await _sendQueuedMessage(entry);
      }

      if (nextAttemptIn != null) {
        _retryTimer?.cancel();
        _retryTimer = Timer(nextAttemptIn, processPendingQueue);
      }
    } finally {
      _processingQueue = false;
    }
  }

  Future<void> onConnectionChanged({required bool isConnected}) async {
    if (isConnected) {
      await processPendingQueue();
    } else {
      _retryTimer?.cancel();
      _retryTimer = Timer(_baseBackoff, processPendingQueue);
    }
  }

  Future<Push?> _enqueueAndSend(MMessage msg, String topic) async {
    _saveMessage(msg);

    final entry = OutgoingMessage(message: msg, topic: topic);
    await _outgoingDao.enqueue(teamName, entry);
    final push = await _sendQueuedMessage(entry);
    await processPendingQueue();
    return push;
  }

  Future<Push?> _sendQueuedMessage(OutgoingMessage entry) async {
    final wsConn = _connectionProvider();
    if (wsConn == null || !wsConn.isConnected()) {
      log.warning('No active websocket connection; will retry ${entry.message.id}');
      _scheduleRetry();
      return null;
    }
    updateDeliveryStatus(entry.message.id, MessageDeliveryStatus.sending);

    final updatedEntry = entry.copyWith(
      message: entry.message.copyWith(
        deliveryStatus: MessageDeliveryStatus.sending,
      ),
      lastAttemptAt: DateTime.now(),
      attemptCount: entry.attemptCount + 1,
    );
    await _outgoingDao.markAttempt(
      teamName,
      entry.message.id,
      attemptedAt: updatedEntry.lastAttemptAt!,
      attemptCount: updatedEntry.attemptCount,
      message: updatedEntry.message,
    );

    final push = wsConn.sendMessage(entry.topic, updatedEntry.message);
    if (push == null) {
      log.severe('Error sending message: Push is null');
      _scheduleRetry();
      return null;
    }

    push.future.then((value) async {
      await _outgoingDao.delete(teamName, entry.message.id);
    }).catchError((e) async {
      log.severe('Error sending message ${entry.message.id}: $e');
      _scheduleRetry();
    });
    return push;
  }

  Duration _backoffFor(OutgoingMessage entry) {
    final multiplier = math.pow(2, entry.attemptCount).toInt();
    final seconds = (_baseBackoff.inSeconds * multiplier).clamp(
      _baseBackoff.inSeconds,
      60,
    );
    return Duration(seconds: seconds);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_baseBackoff, processPendingQueue);
  }
}
