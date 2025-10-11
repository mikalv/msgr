import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/config/camera_kit_environment.dart';

void main() {
  tearDown(() {
    CameraKitEnvironment.instance.clearOverride();
  });

  test('isConfigured returns false when integration is disabled', () {
    CameraKitEnvironment.instance.override(
      enabled: false,
      apiToken: 'token',
      applicationId: 'app',
      lensGroupIds: const ['group'],
    );

    expect(CameraKitEnvironment.instance.isConfigured, isFalse);
  });

  test('isConfigured requires token and lens groups', () {
    CameraKitEnvironment.instance.override(enabled: true);
    expect(CameraKitEnvironment.instance.isConfigured, isFalse);

    CameraKitEnvironment.instance.override(
      enabled: true,
      apiToken: 'token',
      lensGroupIds: const [],
    );
    expect(CameraKitEnvironment.instance.isConfigured, isFalse);
  });

  test('isConfigured succeeds with minimal configuration', () {
    CameraKitEnvironment.instance.override(
      enabled: true,
      apiToken: 'token',
      applicationId: 'app',
      lensGroupIds: const ['group-a', 'group-b'],
    );

    expect(CameraKitEnvironment.instance.isConfigured, isTrue);
    expect(CameraKitEnvironment.instance.lensGroupIds, ['group-a', 'group-b']);
  });

}
