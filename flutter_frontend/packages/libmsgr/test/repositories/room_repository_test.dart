import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/models/room.dart';
import 'package:libmsgr/src/repositories/room_repository.dart';
import 'package:libmsgr/src/utils/observable.dart';
import 'package:logging/logging.dart';
import 'package:mockito/mockito.dart';

import '../libmsgr_test.dart';

class MockObserver extends Mock implements Observer {
  @override
  void update(Map<String, dynamic> data) {
    // Mock implementation
  }
}

void main() {
  group('RoomRepository', () {
    late RoomRepository roomRepository;
    late MockObserver mockObserver;

    setUp(() {
      mockObserver = MockObserver();
      roomRepository = RoomRepository(teamName: '');
    });

    test('should log info message on startup', () {
      final log = Logger('ConversationRepository');
      final logRecords = <LogRecord>[];
      log.onRecord.listen(logRecords.add);

      RoomRepository(teamName: '');

      expect(logRecords, isNotEmpty);
      expect(logRecords.first.message, 'RoomRepository is starting up');
    });

    test('fillLocalCache should notify observers', () {
      final rooms = <Room>[];
      roomRepository.fillLocalCache(rooms);

      verify(mockObserver.update({'rooms': 'updated'})).called(1);
    });
  });
}
