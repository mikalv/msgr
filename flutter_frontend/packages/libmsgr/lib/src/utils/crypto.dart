import 'package:basic_utils/basic_utils.dart';

class Crypto {
  String generateCertificateSignRequest() {
    var pair = CryptoUtils.generateEcKeyPair();
    var privKey = pair.privateKey as ECPrivateKey;
    var pubKey = pair.publicKey as ECPublicKey;
    var dn = {
      'CN': 'Self-Signed',
    };
    var csr = X509Utils.generateEccCsrPem(dn, privKey, pubKey);
    return csr;
  }
}
