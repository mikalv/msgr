import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/database/daos/outgoing_message_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/repositories/message_repository.dart';
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

    when(connection.isConnected()).thenAnswer((_) => connected);
    when(push.future).thenAnswer((_) => pushCompleter.future);
    when(connection.sendMessage(any, any)).thenReturn(push);

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
  });

  MMessage _sampleMessage({String id = 'msg-1', String? roomId, String? conversationId}) {
    return MMessage.raw(
      id: id,
      content: 'Hi',
      fromProfileID: 'profile-1',
      conversationID: conversationId,
      roomID: roomId,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
      isServerAck: false,
    );
  }

  test('writes queue entries before sending and clears on ack', () async {
    final msg = _sampleMessage(roomId: 'room-1');

    await repository.sendMessageToRoom(msg);

    var pending = await outgoingDao.getPending('team-a');
    expect(pending, hasLength(1));

    pushCompleter.complete({'status': 'ok'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    pending = await outgoingDao.getPending('team-a');
    expect(pending, isEmpty);
    verify(connection.sendMessage('team-a.room-1', any)).called(1);
  });

  test('retries pending messages when the connection comes back', () async {
    connected = false;
    when(connection.sendMessage(any, any)).thenReturn(null);
    final msg = _sampleMessage(roomId: 'room-2', id: 'retry-msg');

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
}
