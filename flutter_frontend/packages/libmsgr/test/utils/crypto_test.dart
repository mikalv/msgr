import 'package:flutter_test/flutter_test.dart';
import 'package:libmsgr/src/utils/crypto.dart';

void main() {
  group('Crypto', () {
    test('generateCertificateSignRequest returns a non-empty string', () {
      final crypto = Crypto();
      final csr = crypto.generateCertificateSignRequest();
      expect(csr, isNotEmpty);
    });

    test('generateCertificateSignRequest returns a valid CSR PEM format', () {
      final crypto = Crypto();
      final csr = crypto.generateCertificateSignRequest();
      expect(csr, startsWith('-----BEGIN CERTIFICATE REQUEST-----'));
      expect(csr, endsWith('-----END CERTIFICATE REQUEST-----\n'));
    });
  });
}
