import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/registration_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  const AppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
    this.buildSignature,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;
  final String? buildSignature;

  Map<String, dynamic> toJson() => {
        'appName': appName,
        'packageName': packageName,
        'version': version,
        'buildNumber': buildNumber,
        if (buildSignature != null && buildSignature!.isNotEmpty)
          'buildSignature': buildSignature,
      };
}

abstract class AppInfoProvider {
  Future<AppInfo> read();
}

class PackageInfoAppInfoProvider implements AppInfoProvider {
  const PackageInfoAppInfoProvider();

  @override
  Future<AppInfo> read() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      appName: info.appName,
      packageName: info.packageName,
      version: info.version,
      buildNumber: info.buildNumber,
      buildSignature: info.buildSignature,
    );
  }
}

abstract class DeviceContextRegistrar {
  Future<void> registerIfNeeded({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  });

  Future<void> sync({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  });
}

class RegistrationServiceDeviceContextRegistrar
    implements DeviceContextRegistrar {
  const RegistrationServiceDeviceContextRegistrar({RegistrationService? service})
      : _service = service ?? RegistrationService();

  final RegistrationService _service;

  @override
  Future<void> registerIfNeeded({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  }) async {
    _service.updateCachedContext(deviceInfo: deviceInfo, appInfo: appInfo);
    await _service.maybeRegisterDevice();
  }

  @override
  Future<void> sync({
    required Map<String, dynamic> deviceInfo,
    required Map<String, dynamic> appInfo,
  }) async {
    _service.updateCachedContext(deviceInfo: deviceInfo, appInfo: appInfo);
    await _service.syncDeviceContext(
      deviceInfo: deviceInfo,
      appInfo: appInfo,
    );
  }
}

class DeviceContextBootstrapper {
  DeviceContextBootstrapper({
    required ADeviceInfo deviceInfo,
    required AppInfoProvider appInfoProvider,
    required DeviceContextRegistrar registrar,
  })  : _deviceInfo = deviceInfo,
        _appInfoProvider = appInfoProvider,
        _registrar = registrar;

  factory DeviceContextBootstrapper.create() {
    return DeviceContextBootstrapper(
      deviceInfo: LibMsgr().deviceInfo,
      appInfoProvider: const PackageInfoAppInfoProvider(),
      registrar: const RegistrationServiceDeviceContextRegistrar(),
    );
  }

  final ADeviceInfo _deviceInfo;
  final AppInfoProvider _appInfoProvider;
  final DeviceContextRegistrar _registrar;

  Future<void> initialize() async {
    final deviceInfo = await _deviceInfo.extractInformation();
    final normalizedDeviceInfo = _normalize(deviceInfo);
    final appInfo = await _appInfoProvider.read();
    final appInfoMap = appInfo.toJson();

    await _registrar.registerIfNeeded(
      deviceInfo: normalizedDeviceInfo,
      appInfo: appInfoMap,
    );

    await _registrar.sync(
      deviceInfo: normalizedDeviceInfo,
      appInfo: appInfoMap,
    );
  }

  Map<String, dynamic> _normalize(Map<dynamic, dynamic> source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }
}
