import '../constants.dart';

/// Resolves API endpoints based on the active environment.
class ServerResolver {
  const ServerResolver();

  static const ServerResolver instance = ServerResolver();

  /// Returns the main (team) API URL for the given [path].
  Uri resolveMain(String path) {
    return MsgrConstants.localDevelopment
        ? Uri.http(MsgrHosts.localApiServer, path)
        : Uri.https(MsgrHosts.apiServer, path);
  }

  /// Returns the auth service URL for the given [path].
  Uri resolveAuth(String path) {
    return MsgrConstants.localDevelopment
        ? Uri.http(MsgrHosts.localAuthApiServer, path)
        : Uri.https(MsgrHosts.authApiServer, path);
  }

  /// Returns the per-team API URL for [teamName] and [path].
  Uri resolveTeam(String teamName, String path) {
    return MsgrConstants.localDevelopment
        ? Uri.http('$teamName.${MsgrHosts.localApiServer}', path)
        : Uri.https('$teamName.${MsgrHosts.apiServer}', path);
  }

  /// Returns the websocket endpoint base for the given [teamName].
  String resolveTeamWebSocket(String teamName) {
    return MsgrConstants.localDevelopment
        ? 'ws://$teamName.${MsgrHosts.localApiServer}/ws/$teamName/websocket'
        : 'wss://$teamName.${MsgrHosts.apiServer}/ws/$teamName/websocket';
  }

  // Static conveniences for legacy callers
  static Uri getMainServer(String path) => instance.resolveMain(path);
  static Uri getAuthServer(String path) => instance.resolveAuth(path);
  static Uri getTeamServer(String teamName, String path) =>
      instance.resolveTeam(teamName, path);
  static String getTeamWebSocketServer(String teamName) =>
      instance.resolveTeamWebSocket(teamName);
}
