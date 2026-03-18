/// Default hosts for the msgr backend environments.
class MsgrHosts {
  const MsgrHosts._();

  /// Production messaging API host.
  static const String apiServer = 'teams.msgr.no';

  /// Production auth API host.
  static const String authApiServer = 'auth.msgr.no';

  /// Local development auth host (nip.io) - points to Rust Gateway with NOISE.
  static const String localAuthApiServer = 'clients.7f000001.nip.io:8443';

  /// Local development messaging host (nip.io) - points to Rust Gateway with NOISE.
  static const String localApiServer = 'clients.7f000001.nip.io:8443';
}

/// Shared string constants used across adapters.
class MsgrConstants {
  const MsgrConstants._();

  static const bool localDevelopment = true;
  static const String kIsDeviceRegisteredWithServerNameStr =
      'isDeviceRegisteredWithServer';
  static const String kUserAgentNameString = 'MsgrApp-v1';

  /// Enable NOISE protocol for WebSocket connections (local development only)
  static const bool useNoiseProtocol = localDevelopment;

  /// Gateway URL for NOISE handshake (local development)
  static const String noiseGatewayUrl = 'http://clients.7f000001.nip.io:8443';

  /// Pre-shared key for NOISE protocol (development only - replace in production!)
  /// This is a 32-byte key encoded as base64
  static const String noiseDevPsk = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
}
