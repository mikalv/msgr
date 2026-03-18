import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:elliptic/elliptic.dart' as elliptic;
import 'package:http/http.dart' as http;
import 'package:libmsgr/noise_protocol_framework/noise_protocol_framework.dart';
import 'package:logging/logging.dart';
import 'package:pointycastle/export.dart';

final _log = Logger('NoiseHandshakeService');

/// Result of a successful NOISE handshake
class NoiseHandshakeResult {
  final String sessionToken;
  final CipherState sendCipher;
  final CipherState receiveCipher;
  final String sessionId;
  final DateTime expiresAt;

  NoiseHandshakeResult({
    required this.sessionToken,
    required this.sendCipher,
    required this.receiveCipher,
    required this.sessionId,
    required this.expiresAt,
  });
}

/// Service for performing NOISE protocol handshakes with the Rust Gateway
class NoiseHandshakeService {
  final String gatewayUrl;
  final Uint8List psk;

  NoiseHandshakeService({
    required this.gatewayUrl,
    required this.psk,
  });

  /// Perform NKpsk0 handshake with the gateway
  ///
  /// Flow:
  /// 1. POST /noise/handshake to initiate session
  /// 2. Receive server's public key and session info
  /// 3. Generate ephemeral key pair and create handshake message
  /// 4. POST handshake message to server
  /// 5. Both sides derive matching cipher states
  /// 6. Return cipher states and session token
  Future<NoiseHandshakeResult> performHandshake() async {
    _log.info('Starting NKpsk0 handshake with $gatewayUrl');

    try {
      // Step 1: Initiate handshake session with gateway
      final createResponse = await _createHandshakeSession();

      _log.info('Handshake session created: ${createResponse['session_id']}');

      // Step 2: Perform client-side handshake and send message to server
      final serverPubKey = base64Decode(createResponse['device_key'] as String);
      final sessionId = createResponse['session_id'] as String;
      final handshakeResult = await _performClientHandshake(serverPubKey, sessionId);

      // Step 3: Parse expiration time
      final expiresAt = DateTime.parse(createResponse['expires_at'] as String);

      _log.info('Handshake completed successfully');

      return NoiseHandshakeResult(
        sessionToken: createResponse['session_token'] as String,
        sendCipher: handshakeResult.sendCipher,
        receiveCipher: handshakeResult.receiveCipher,
        sessionId: sessionId,
        expiresAt: expiresAt,
      );
    } catch (e, stackTrace) {
      _log.severe('Handshake failed: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Create handshake session on the gateway
  Future<Map<String, dynamic>> _createHandshakeSession() async {
    final url = Uri.parse('$gatewayUrl/noise/handshake');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'pattern': 'NKpsk0',
        'psk': base64Encode(psk),
        'ttl_seconds': 3600, // 1 hour
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create handshake session: ${response.statusCode} ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Perform client-side NKpsk0 handshake
  Future<_ClientHandshakeResult> _performClientHandshake(
    Uint8List serverPublicKey,
    String sessionId,
  ) async {
    // Initialize NKpsk0 handshake as initiator (client)
    final curve = elliptic.getP256();
    final hash = NoiseHash(sha256);
    final cipher = AESFastEngine();

    final handshakeState = NKPSK0HandshakeState.initiator(
      serverPublicKey,
      psk,
      hash,
      curve,
    );

    final cipherState = CipherState.empty(cipher);
    handshakeState.init(cipherState, 'Noise_NKpsk0_P256_AESGCM_SHA256');

    // Write handshake message (-> e, es)
    final payload = Uint8List(0); // Empty payload
    final message = await handshakeState.writeMessageInitiator(payload);

    _log.fine('Client handshake message created: ${message.ne.length} bytes');

    // Send handshake message to server
    await _sendHandshakeMessage(sessionId, message.ne);

    // After sending message, both client and server can derive cipher states
    // Access the symmetric state to derive cipher states
    final ciphers = await handshakeState.symmetricState.split();

    _log.fine('Cipher states derived from handshake');

    return _ClientHandshakeResult(
      sendCipher: ciphers[0],  // Client send cipher
      receiveCipher: ciphers[1],  // Client receive cipher
    );
  }

  /// Send handshake message to server
  Future<void> _sendHandshakeMessage(String sessionId, Uint8List message) async {
    final url = Uri.parse('$gatewayUrl/noise/handshake/$sessionId/message');

    _log.fine('Sending handshake message to server: ${message.length} bytes');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/octet-stream'},
      body: message,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send handshake message: ${response.statusCode} ${response.body}');
    }

    final responseData = json.decode(response.body) as Map<String, dynamic>;
    final handshakeComplete = responseData['handshake_complete'] as bool;

    _log.fine('Handshake message processed, complete: $handshakeComplete');

    if (!handshakeComplete) {
      _log.warning('Handshake not marked as complete by server');
    }
  }
}

class _ClientHandshakeResult {
  final CipherState sendCipher;
  final CipherState receiveCipher;

  _ClientHandshakeResult({
    required this.sendCipher,
    required this.receiveCipher,
  });
}
