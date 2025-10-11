import 'package:libmsgr/src/lib_constants.dart';

class ServerResolver {
  static Uri getMainServer(String path) {
    return (localDevelopment)
        ? Uri.http(localApiServer, path)
        : Uri.https(apiServer, path);
  }

  static Uri getAuthServer(String path) {
    return (localDevelopment)
        ? Uri.http(localAuthApiServer, path)
        : Uri.https(authApiServer, path);
  }

  static Uri getTeamServer(String teamName, String path) {
    return (localDevelopment)
        ? Uri.http('$teamName.$localApiServer', path)
        : Uri.https('$teamName.$apiServer', path);
  }

  static String getTeamWebSocketServer(String teamName) {
    return (localDevelopment)
        ? 'ws://$teamName.$localApiServer/ws/$teamName/websocket'
        : 'wss://$teamName.$apiServer/ws/$teamName/websocket';
  }
}
