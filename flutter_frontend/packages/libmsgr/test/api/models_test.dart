import 'package:libmsgr/src/api/models.dart';
import 'package:test/test.dart';

void main() {
  group('ChallengeResult', () {
    test('construction with all fields', () {
      const result = ChallengeResult(
        id: 'chal-1',
        channel: 'email',
        debugCode: '123456',
        targetHint: 'u***@example.com',
      );

      expect(result.id, equals('chal-1'));
      expect(result.channel, equals('email'));
      expect(result.debugCode, equals('123456'));
      expect(result.targetHint, equals('u***@example.com'));
    });

    test('construction with required fields only', () {
      const result = ChallengeResult(id: 'chal-2');

      expect(result.id, equals('chal-2'));
      expect(result.channel, isNull);
      expect(result.debugCode, isNull);
      expect(result.targetHint, isNull);
    });
  });

  group('SessionResult', () {
    test('construction with all fields', () {
      const result = SessionResult(
        accountId: 'acc-1',
        profileId: 'prof-1',
        email: 'user@example.com',
        displayName: 'Alice',
        accessToken: 'jwt-access',
        refreshToken: 'jwt-refresh',
        profiles: [
          {'id': 'prof-1', 'display_name': 'Alice'}
        ],
      );

      expect(result.accountId, equals('acc-1'));
      expect(result.profileId, equals('prof-1'));
      expect(result.email, equals('user@example.com'));
      expect(result.displayName, equals('Alice'));
      expect(result.accessToken, equals('jwt-access'));
      expect(result.refreshToken, equals('jwt-refresh'));
      expect(result.profiles, hasLength(1));
    });

    test('construction with required fields only', () {
      const result = SessionResult(
        accountId: 'acc-2',
        profileId: 'prof-2',
      );

      expect(result.accountId, equals('acc-2'));
      expect(result.profileId, equals('prof-2'));
      expect(result.email, isNull);
      expect(result.displayName, isNull);
      expect(result.accessToken, isNull);
      expect(result.refreshToken, isNull);
      expect(result.profiles, isNull);
    });
  });

  group('MsgrApiException', () {
    test('toString includes status code and message', () {
      const ex = MsgrApiException(statusCode: 404, message: 'Not found');
      expect(ex.toString(), equals('MsgrApiException(404): Not found'));
    });

    test('fields are accessible', () {
      const ex = MsgrApiException(statusCode: 500, message: 'Server error');
      expect(ex.statusCode, equals(500));
      expect(ex.message, equals('Server error'));
    });

    test('implements Exception', () {
      const ex = MsgrApiException(statusCode: 400, message: 'Bad request');
      expect(ex, isA<Exception>());
    });
  });

  group('PresignedUpload', () {
    test('construction with all fields', () {
      const upload = PresignedUpload(
        uploadId: 'upload-1',
        objectKey: 'team/uploads/file.png',
        uploadUrl: 'https://s3.example.com/presigned',
        uploadMethod: 'PUT',
        uploadHeaders: {'x-amz-acl': 'private'},
        expiresAt: '2025-01-01T00:00:00Z',
      );

      expect(upload.uploadId, equals('upload-1'));
      expect(upload.objectKey, equals('team/uploads/file.png'));
      expect(upload.uploadUrl, equals('https://s3.example.com/presigned'));
      expect(upload.uploadMethod, equals('PUT'));
      expect(upload.uploadHeaders, containsPair('x-amz-acl', 'private'));
      expect(upload.expiresAt, equals('2025-01-01T00:00:00Z'));
    });

    test('defaults uploadMethod to PUT and empty headers', () {
      const upload = PresignedUpload(
        uploadId: 'u1',
        objectKey: 'key',
        uploadUrl: 'https://example.com',
      );

      expect(upload.uploadMethod, equals('PUT'));
      expect(upload.uploadHeaders, isEmpty);
      expect(upload.expiresAt, isNull);
    });
  });
}
