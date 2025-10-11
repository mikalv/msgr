// https://www.reddit.com/r/flutterhelp/comments/1cnb3q0/certificate_verify_failed_whats_the_right/
import 'dart:io';
import 'dart:typed_data';

class MyHttpOverrides extends HttpOverrides {
  MyHttpOverrides(this.host);
  final String host;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return this.host == host;
      };
  }
}

addRootCertificateToStore(isrgRootX1) {
  try {
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      Uint8List.fromList(isrgRootX1.codeUnits),
    );
  } catch (e) {
    // Ignore CERT_ALREADY_IN_HASH_TABLE
  }
}
