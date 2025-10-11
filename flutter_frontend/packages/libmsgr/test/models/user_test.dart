import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/models/user.dart';

void main() {
  group('User Model Tests', () {
    final user = User(
      uid: '123',
      identifier: 'test_user',
      accessToken: 'access_token',
      refreshToken: 'refresh_token',
    );

    test('User equality', () {
      final user2 = User(
        uid: '123',
        identifier: 'test_user',
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
      );

      expect(user, equals(user2));
    });

    test('User inequality', () {
      final user2 = User(
        uid: '124',
        identifier: 'test_user2',
        accessToken: 'access_token2',
        refreshToken: 'refresh_token2',
      );

      expect(user, isNot(equals(user2)));
    });

    test('User hashCode', () {
      final user2 = User(
        uid: '123',
        identifier: 'test_user',
        accessToken: 'access_token',
        refreshToken: 'refresh_token',
      );

      expect(user.hashCode, equals(user2.hashCode));
    });

    test('User fromJson', () {
      final json = {
        'uid': '123',
        'identifier': 'test_user',
        'accessToken': 'access_token',
        'refreshToken': 'refresh_token',
      };

      final userFromJson = User.fromJson(json);

      expect(userFromJson, equals(user));
    });

    test('User toJson', () {
      final json = user.toJson();

      expect(json, {
        'uid': '123',
        'identifier': 'test_user',
        'accessToken': 'access_token',
        'refreshToken': 'refresh_token',
      });
    });

    test('User toString', () {
      final userString = user.toString();

      expect(userString,
          'User{uid: 123, identifier: test_user, accessToken: access_token, refreshToken: refresh_token}');
    });
  });
}
