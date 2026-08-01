import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:libmsgr_core/src/crypto/e2ee/kdf.dart';
import 'package:test/test.dart';

void main() {
  final file = File('test/vectors/kdf_vectors.json');

  test('KDF vectors match docs/e2ee_spec.md', () async {
    expect(file.existsSync(), isTrue, reason: 'run scripts/gen_e2ee_vectors.py');
    final vectors =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    final xx = vectors['xx_shared_secret'] as Map<String, dynamic>;
    final xxSk = await E2eeKdf.deriveXxSharedSecret(
      Uint8List.fromList(base64Decode(xx['ikm'] as String)),
    );
    expect(base64Encode(xxSk), xx['sk']);

    final x3dh = vectors['x3dh_shared_secret'] as Map<String, dynamic>;
    final x3dhSk = await E2eeKdf.deriveX3dhSharedSecret(
      Uint8List.fromList(base64Decode(x3dh['ikm'] as String)),
    );
    expect(base64Encode(x3dhSk), x3dh['sk']);

    final rk = vectors['kdf_rk'] as Map<String, dynamic>;
    final (newRk, ck) = await E2eeKdf.kdfRk(
      rootKey: Uint8List.fromList(base64Decode(rk['root_key'] as String)),
      dhOut: Uint8List.fromList(base64Decode(rk['dh_out'] as String)),
    );
    expect(base64Encode(newRk), rk['new_root_key']);
    expect(base64Encode(ck), rk['chain_key']);

    final ckVec = vectors['kdf_ck'] as Map<String, dynamic>;
    final (mk, nextCk) = await E2eeKdf.kdfCk(
      Uint8List.fromList(base64Decode(ckVec['chain_key'] as String)),
    );
    expect(base64Encode(mk), ckVec['message_key']);
    expect(base64Encode(nextCk), ckVec['next_chain_key']);

    final exp = vectors['expand_message_key'] as Map<String, dynamic>;
    final (aesKey, nonce) = await E2eeKdf.expandMessageKey(
      Uint8List.fromList(base64Decode(exp['message_key'] as String)),
    );
    expect(base64Encode(aesKey), exp['aes_key']);
    expect(base64Encode(nonce), exp['nonce']);
  });
}
