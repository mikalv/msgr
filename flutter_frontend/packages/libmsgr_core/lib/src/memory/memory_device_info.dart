import 'dart:io';

import '../contracts/device.dart';

/// Basic [DeviceInfoProvider] that reports CLI friendly metadata.
class MemoryDeviceInfo implements DeviceInfoProvider {
  MemoryDeviceInfo({String? deviceId})
      : _deviceId =
            deviceId ?? 'device-${DateTime.now().millisecondsSinceEpoch}';

  final String _deviceId;

  @override
  Future<Map<String, dynamic>> deviceInfo() async {
    return <String, dynamic>{
      'platform': 'dart-cli',
      'platformVersion': Platform.version,
      'model': 'libmsgr-core',
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'deviceId': _deviceId,
    };
  }

  @override
  Future<Map<String, dynamic>> appInfo() async {
    return <String, dynamic>{
      'appName': 'libmsgr-cli',
      'appVersion': '0.0.1',
      'buildNumber': 'dev',
    };
  }
}
