import 'dart:io';

class DeviceInfo {
  static String get label {
    var platform = Platform.operatingSystem ?? 'Web';
    return 'Flutter ' +
         platform +
        '(' +
        Platform.localHostname +
        ")";
  }

  static String get userAgent {
    return 'flutter-webrtc/' + Platform.operatingSystem + '-plugin 0.0.1';
  }
}
