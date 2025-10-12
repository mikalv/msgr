import 'dart:io';

import 'package:libmsgr_core/libmsgr_core.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'storage/file_storage.dart';

class CliDeviceInfo implements DeviceInfoProvider {
  CliDeviceInfo({String? deviceId}) : _deviceId = deviceId;

  final String? _deviceId;

  @override
  Future<Map<String, dynamic>> deviceInfo() async {
    final deviceId = _deviceId ?? 'device-${DateTime.now().millisecondsSinceEpoch}';
    return <String, dynamic>{
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.version,
      'model': 'libmsgr-cli',
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'deviceId': deviceId,
    };
  }

  @override
  Future<Map<String, dynamic>> appInfo() async {
    return <String, dynamic>{
      'appName': 'libmsgr_cli',
      'appVersion': '0.1.0',
      'buildNumber': 'dev',
    };
  }
}

class CliEnvironment {
  CliEnvironment._({
    required this.rootDirectory,
    required this.secureStorage,
    required this.preferences,
    required this.deviceInfo,
    required this.keyManager,
    required this.registration,
  });

  final Directory rootDirectory;
  final SecureStorage secureStorage;
  final KeyValueStore preferences;
  final DeviceInfoProvider deviceInfo;
  final KeyManager keyManager;
  final RegistrationServiceCore registration;

  static Future<CliEnvironment> bootstrap({Directory? stateDir}) async {
    final dir = stateDir ?? _defaultStateDir();
    final secureStorage = FileSecureStorage(dir);
    final prefs = FileKeyValueStore(dir);
    final keyManager = KeyManager(storage: secureStorage);

    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((event) {
      stderr.writeln('[${event.level.name}] ${event.loggerName}: ${event.message}');
    });

    await keyManager.getOrGenerateDeviceId();
    final deviceInfo = CliDeviceInfo(deviceId: keyManager.deviceId);
    final registration = RegistrationServiceCore(
      keyManager: keyManager,
      secureStorage: secureStorage,
      deviceInfoProvider: deviceInfo,
    );
    final deviceInfoMap = await deviceInfo.deviceInfo();
    final appInfoMap = await deviceInfo.appInfo();

    registration.updateCachedContext(
      deviceInfo: deviceInfoMap,
      appInfo: appInfoMap,
    );

    await registration.maybeRegisterDevice(
      deviceInfo: deviceInfoMap,
      appInfo: appInfoMap,
    );

    await registration.syncDeviceContext(
      deviceInfo: deviceInfoMap,
      appInfo: appInfoMap,
    );

    return CliEnvironment._(
      rootDirectory: dir,
      secureStorage: secureStorage,
      preferences: prefs,
      deviceInfo: deviceInfo,
      keyManager: keyManager,
      registration: registration,
    );
  }

  static Directory _defaultStateDir() {
    final env = Platform.environment;
    final custom = env['MSGR_CLI_HOME'];
    if (custom != null && custom.isNotEmpty) {
      return Directory(custom);
    }
    final home = env['HOME'] ?? env['USERPROFILE'] ?? Directory.current.path;
    return Directory(p.join(home, '.msgr_cli'));
  }
}
