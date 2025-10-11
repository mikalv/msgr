import 'package:msgr_messages/msgr_messages.dart';
import 'package:test/test.dart';

void main() {
  group('MsgrLocationMessage', () {
    const base = MsgrLocationMessage(
      id: 'loc-1',
      latitude: 59.9139,
      longitude: 10.7522,
      profileId: 'profile-1',
      profileName: 'Alice',
      profileMode: 'public',
    );

    test('copyWith overrides provided fields', () {
      final copy = base.copyWith(
        address: 'Oslo, Norway',
        zoom: 14.5,
        theme: const MsgrMessageTheme(
          id: 'maplight',
          name: 'Map Light',
          primaryColor: '#22C55E',
          backgroundColor: '#ECFCCB',
        ),
      );

      expect(copy.address, equals('Oslo, Norway'));
      expect(copy.zoom, equals(14.5));
      expect(copy.theme.id, equals('maplight'));
    });

    test('fromMap coerces coordinates to double', () {
      final parsed = MsgrLocationMessage.fromMap({
        'type': 'location',
        'id': 'loc-1',
        'latitude': 59,
        'longitude': 10,
        'profileId': 'profile-1',
        'profileName': 'Alice',
        'profileMode': 'public',
      });

      expect(parsed.latitude, equals(59));
      expect(parsed.longitude, equals(10));
      expect(parsed.theme.id, equals('default'));
    });

    test('toMap serialises coordinates', () {
      final map = base.copyWith(address: 'Oslo', zoom: 12).toMap();

      expect(map['type'], equals('location'));
      expect(map['address'], equals('Oslo'));
      expect(map['zoom'], equals(12));
      expect(map['theme'], isA<Map<String, dynamic>>());
    });
  });
}
