import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/database/daos/outgoing_message_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/repositories/message_repository.dart';
import 'package:libmsgr/src/telemetry/socket_telemetry.dart';
import 'package:mockito/mockito.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockMsgrConnection extends Mock implements MsgrConnection {}

class MockPush extends Mock implements Push {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService databaseService;
  late MessageDao messageDao;
  late OutgoingMessageDao outgoingDao;
  late MessageRepository repository;
  late MockMsgrConnection connection;
  late MockPush push;
  late Completer<dynamic> pushCompleter;
  late StreamSubscription<SocketEvent> telemetrySubscription;
  final List<SocketEvent> telemetry = [];
  var connected = true;

  setUp(() async {
    databaseService = DatabaseService();
    await databaseService.initialize();
    messageDao = MessageDao(databaseService.instance);
    outgoingDao = OutgoingMessageDao(databaseService.instance);
    connection = MockMsgrConnection();
    push = MockPush();
    pushCompleter = Completer<dynamic>();
    connected = true;
    telemetry.clear();

    when(connection.isConnected()).thenAnswer((_) => connected);
    when(push.future).thenAnswer((_) => pushCompleter.future);
    when(connection.sendMessage(any, any)).thenReturn(push);

    telemetrySubscription =
        SocketTelemetry.instance.events.listen(telemetry.add);

    repository = MessageRepository(
      teamName: 'team-a',
      dao: messageDao,
      outgoingMessageDao: outgoingDao,
      connectionProvider: () => connection,
    );
  });

  tearDown(() async {
    final path = databaseService.instance.path;
    await databaseService.instance.close();
    await databaseFactory.deleteDatabase(path);
    await telemetrySubscription.cancel();
  });

  MMessage _sampleMessage({String id = 'msg-1', String? channelId, String? conversationId}) {
    return MMessage.raw(
      id: id,
      content: 'Hi',
      fromProfileID: 'profile-1',
      conversationID: conversationId,
      channelID: channelId,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      isServerAck: false,
    );
  }

  test('writes queue entries before sending and clears on ack', () async {
    final msg = _sampleMessage(channelId: 'channel-1');

    await repository.sendMessageToRoom(msg);

    var pending = await outgoingDao.getPending('team-a');
    expect(pending, hasLength(1));

    final storedMessages = await messageDao.getMessagesForTeam('team-a');
    expect(storedMessages.single.deliveryStatus, MessageDeliveryStatus.sending);

    pushCompleter.complete({'status': 'ok'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    pending = await outgoingDao.getPending('team-a');
    expect(pending, isEmpty);
    final delivered = await messageDao.getMessagesForTeam('team-a');
    expect(delivered.single.deliveryStatus, MessageDeliveryStatus.delivered);
    verify(connection.sendMessage('team-a.channel-1', any)).called(1);
  });

  test('emits telemetry for retry scheduling and success after reconnection',
      () async {
    connected = false;
    when(connection.sendMessage(any, any)).thenReturn(null);
    final msg = _sampleMessage(channelId: 'channel-telemetry');

    await repository.sendMessageToRoom(msg);

    expect(
      telemetry.where((e) => e.name == 'message.retry_scheduled'),
      isNotEmpty,
    );

    connected = true;
    pushCompleter = Completer<dynamic>();
    when(push.future).thenAnswer((_) => pushCompleter.future);
    when(connection.sendMessage(any, any)).thenReturn(push);

    // Mark the previous attempt as failed to trigger a retry attempt count > 1
    final pending = (await outgoingDao.getPending('team-a')).single;
    await outgoingDao.markAttempt(
      'team-a',
      pending.message.id,
      attemptedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      attemptCount: 1,
      message: pending.message.copyWith(
        deliveryStatus: MessageDeliveryStatus.pending,
      ),
    );

    await repository.processPendingQueue();

    pushCompleter.complete({'status': 'ok'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      telemetry.where((e) => e.name == 'message.retry_succeeded'),
      isNotEmpty,
    );
  });

  test('retries pending messages when the connection comes back', () async {
    connected = false;
    when(connection.sendMessage(any, any)).thenReturn(null);
    final msg = _sampleMessage(channelId: 'channel-2', id: 'retry-msg');

    await repository.sendMessageToRoom(msg);

    var pending = await outgoingDao.getPending('team-a');
    expect(pending.single.attemptCount, 0);

    connected = true;
    when(connection.sendMessage(any, any)).thenReturn(push);
    pushCompleter = Completer<dynamic>();
    when(push.future).thenAnswer((_) => pushCompleter.future);

    await repository.processPendingQueue();

    pending = await outgoingDao.getPending('team-a');
    expect(pending.single.attemptCount, 1);

    pushCompleter.complete({'status': 'ok'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    pending = await outgoingDao.getPending('team-a');
    expect(pending, isEmpty);
  });

  test('marks message as failed on socket error', () async {
    final msg = _sampleMessage(channelId: 'channel-3', id: 'fail-msg');

    await repository.sendMessageToRoom(msg);

    pushCompleter.completeError(Exception('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final stored = await messageDao.getMessagesForTeam('team-a');
    expect(stored.single.deliveryStatus, MessageDeliveryStatus.failed);
  });

  test('emits telemetry when retries are exhausted', () async {
    connected = true;
    final msg = _sampleMessage(channelId: 'channel-4', id: 'exhaust-msg');

    await repository.sendMessageToRoom(msg);

    // Force the entry to exceed the max attempts
    final entry = (await outgoingDao.getPending('team-a')).single;
    await outgoingDao.markAttempt(
      'team-a',
      entry.message.id,
      attemptedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      attemptCount: 5,
      message: entry.message,
    );

    await repository.processPendingQueue();

    final stored = await messageDao.getMessagesForTeam('team-a');
    expect(stored.single.deliveryStatus, MessageDeliveryStatus.failed);
    expect(
      telemetry.where((e) => e.name == 'message.retry_exhausted'),
      isNotEmpty,
    );
  });
}
