// TODO: rewrite this as a better solution. this is used under device registration
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:libmsgr/libmsgr.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Dbkeys {
  //------- device info
  static const String deviceInfoDEVICEIDStr = 'Device ID String';
  static const String deviceInfoDEVICEID = 'Device ID';
  static const String deviceInfoOSID = 'Os ID';
  static const String deviceInfoMODEL = 'Model';
  static const String deviceInfoOSVERSION = 'OS version';
  static const String deviceInfoOS = 'OS type';
  static const String deviceInfoDEVICENAME = 'Device name';
  static const String deviceInfoMANUFACTURER = 'Manufacturer';
  static const String deviceInfoLOGINTIMESTAMP = 'Device login Time';
  static const String deviceInfoISPHYSICAL = 'Is Physical';
}

class DeviceInfoImpl implements ADeviceInfo {
  static DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  @override
  Future<Map<dynamic, dynamic>> extractInformation() async {
    var mapDeviceInfo = {};
    if (kIsWeb) {
      WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
      // TODO: Maybe we should use a more unique identifier?
      var randomString = DateTime.now().toIso8601String();
      var deviceIdStr =
          '${webInfo.userAgent}|${webInfo.product}|${webInfo.vendor}|$randomString';
      mapDeviceInfo = {
        Dbkeys.deviceInfoDEVICEIDStr: deviceIdStr,
        Dbkeys.deviceInfoMODEL: webInfo.product,
        Dbkeys.deviceInfoOS: 'web',
        Dbkeys.deviceInfoISPHYSICAL: 'Unsure',
        Dbkeys.deviceInfoDEVICEID: webInfo.productSub,
        Dbkeys.deviceInfoOSID: webInfo.platform,
        Dbkeys.deviceInfoOSVERSION: webInfo.appVersion,
        Dbkeys.deviceInfoMANUFACTURER: webInfo.vendor,
        Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now().toIso8601String(),
      };
    } else {
      if (Platform.isAndroid == true) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        var deviceIdStr = androidInfo.id + androidInfo.board;
        mapDeviceInfo = {
          Dbkeys.deviceInfoDEVICEIDStr: deviceIdStr,
          Dbkeys.deviceInfoMODEL: androidInfo.model,
          Dbkeys.deviceInfoOS: 'android',
          Dbkeys.deviceInfoISPHYSICAL: androidInfo.isPhysicalDevice,
          Dbkeys.deviceInfoDEVICEID: androidInfo.id,
          Dbkeys.deviceInfoOSID: androidInfo.board,
          Dbkeys.deviceInfoOSVERSION: androidInfo.version.baseOS,
          Dbkeys.deviceInfoMANUFACTURER: androidInfo.manufacturer,
          Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now().toIso8601String(),
        };
      } else if (Platform.isIOS == true) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        var deviceIdStr =
            iosInfo.systemName + iosInfo.model + iosInfo.systemVersion;
        mapDeviceInfo = {
          Dbkeys.deviceInfoDEVICEIDStr: deviceIdStr,
          Dbkeys.deviceInfoMODEL: iosInfo.model,
          Dbkeys.deviceInfoOS: 'ios',
          Dbkeys.deviceInfoISPHYSICAL: iosInfo.isPhysicalDevice,
          Dbkeys.deviceInfoDEVICEID: iosInfo.identifierForVendor,
          Dbkeys.deviceInfoOSID: iosInfo.name,
          Dbkeys.deviceInfoOSVERSION: iosInfo.name,
          Dbkeys.deviceInfoMANUFACTURER: iosInfo.name,
          Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now().toIso8601String(),
        };
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macOSInfo = await deviceInfo.macOsInfo;
        var deviceIdStr = macOSInfo.systemGUID! +
            macOSInfo.arch +
            macOSInfo.model +
            macOSInfo.computerName;
        mapDeviceInfo = {
          Dbkeys.deviceInfoDEVICEIDStr: deviceIdStr,
          Dbkeys.deviceInfoMODEL: macOSInfo.model,
          Dbkeys.deviceInfoOS: 'macos',
          Dbkeys.deviceInfoISPHYSICAL:
              'Unsure', // TODO: Should maybe be confident about this?
          Dbkeys.deviceInfoDEVICEID: macOSInfo.systemGUID,
          Dbkeys.deviceInfoOSID: macOSInfo.kernelVersion,
          Dbkeys.deviceInfoOSVERSION: macOSInfo.osRelease,
          Dbkeys.deviceInfoMANUFACTURER: 'Apple',
          Dbkeys.deviceInfoLOGINTIMESTAMP: DateTime.now().toIso8601String(),
        };
      }
    }
    return mapDeviceInfo;
  }

  @override
  Future<Map<String, dynamic>> appInfo() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'appName': info.appName,
      'packageName': info.packageName,
      'version': info.version,
      'buildNumber': info.buildNumber,
      if (info.buildSignature.isNotEmpty) 'buildSignature': info.buildSignature,
    };
  }
}
