import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

extension Target on Object {
  bool isAndroid() {
    return Platform.isAndroid;
  }

  bool isIOS() {
    return Platform.isIOS;
  }

  bool isLinux() {
    return Platform.isLinux;
  }

  bool isWindows() {
    return Platform.isWindows;
  }

  bool isMacOS() {
    return Platform.isMacOS;
  }

  bool isWeb() {
    return kIsWeb;
  }

  bool get isMobile {
    if (kIsWeb) {
      return false;
    } else {
      return Platform.isIOS || Platform.isAndroid;
    }
  }

  bool get isDesktop {
    if (kIsWeb) {
      return false;
    } else {
      return Platform.isLinux ||
          Platform.isFuchsia ||
          Platform.isWindows ||
          Platform.isMacOS;
    }
  }
  // ···
}
