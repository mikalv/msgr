import 'package:flutter_test/flutter_test.dart';
import 'package:messngr/app/bootstrap/device_context_bootstrap.dart';
import 'package:libmsgr/libmsgr.dart';

class _FakeDeviceInfo implements ADeviceInfo {
  @override
  Future<Map<dynamic, dynamic>> extractInformation() async {
    return {'os': 'android', 'version': '14'};
  }
}

class _FakeAppInfoProvider implements AppInfoProvider {
  const _FakeAppInfoProvider();

  @override
  Future<AppInfo> read() async {
    return const AppInfo(
      appName: 'TestApp',
      packageName: 'com.example.app',
      version: '1.0.0',
      buildNumber: '100',
      buildSignature: 'sig',
    );
  }
}

class _FakeRegistrar implements DeviceContextRegistrar {
  int registerCount = 0;
  int syncCount = 0;
  Map<String, dynamic>? lastRegisteredDeviceInfo;
  Map<String, dynamic>? lastRegisteredAppInfo;
  Map<String, dynamic>? lastSyncedDeviceInfo;
  Map<String, dynamic>? lastSyncedAppInfo;

  @override
  Future<void> registerIfNeeded({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  }) async {
    registerCount += 1;
    lastRegisteredDeviceInfo = deviceInfo;
    lastRegisteredAppInfo = appInfo;
  }

  @override
  Future<void> sync({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  }) async {
    syncCount += 1;
    lastSyncedDeviceInfo = deviceInfo;
    lastSyncedAppInfo = appInfo;
  }
}

void main() {
  test('initializes device context and syncs with normalized maps', () async {
    final registrar = _FakeRegistrar();
    final bootstrapper = DeviceContextBootstrapper(
      deviceInfo: _FakeDeviceInfo(),
      appInfoProvider: const _FakeAppInfoProvider(),
      registrar: registrar,
    );

    await bootstrapper.initialize();

    expect(registrar.registerCount, 1);
    expect(registrar.syncCount, 1);
    expect(registrar.lastRegisteredDeviceInfo, {'os': 'android', 'version': '14'});
    expect(registrar.lastRegisteredAppInfo, {
      'appName': 'TestApp',
      'packageName': 'com.example.app',
      'version': '1.0.0',
      'buildNumber': '100',
      'buildSignature': 'sig',
    });
    expect(registrar.lastSyncedDeviceInfo, registrar.lastRegisteredDeviceInfo);
    expect(registrar.lastSyncedAppInfo, registrar.lastRegisteredAppInfo);
  });
}
