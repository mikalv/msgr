import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/models/channel.dart';
import 'package:libmsgr/src/repositories/channel_repository.dart';
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
  group('ChannelRepository', () {
    late ChannelRepository channelRepository;
    late MockObserver mockObserver;

    setUp(() {
      mockObserver = MockObserver();
      channelRepository = ChannelRepository(teamName: '');
    });

    test('should log info message on startup', () {
      final log = Logger('ConversationRepository');
      final logRecords = <LogRecord>[];
      log.onRecord.listen(logRecords.add);

      ChannelRepository(teamName: '');

      expect(logRecords, isNotEmpty);
      expect(logRecords.first.message, 'ChannelRepository is starting up');
    });

    test('fillLocalCache should notify observers', () {
      final channels = <Channel>[];
      channelRepository.fillLocalCache(channels);

      verify(mockObserver.update({'channels': 'updated'})).called(1);
    });
  });
}
