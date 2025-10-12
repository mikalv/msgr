/// Default hosts for the msgr backend environments.
class MsgrHosts {
  const MsgrHosts._();

  /// Production messaging API host.
  static const String apiServer = 'teams.msgr.no';

  /// Production auth API host.
  static const String authApiServer = 'auth.msgr.no';

  /// Local development auth host (nip.io).
  static const String localAuthApiServer = 'auth.7f000001.nip.io:4080';

  /// Local development messaging host (nip.io).
  static const String localApiServer = 'teams.7f000001.nip.io:4080';
}

/// Shared string constants used across adapters.
class MsgrConstants {
  const MsgrConstants._();

  static const bool localDevelopment = true;
  static const String kIsDeviceRegisteredWithServerNameStr =
      'isDeviceRegisteredWithServer';
  static const String kUserAgentNameString = 'MsgrApp-v1';
}
