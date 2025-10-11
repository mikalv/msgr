
class OnConnectedToServerAction {
  final bool connected;

  OnConnectedToServerAction(this.connected);

  @override
  String toString() {
    return 'OnConnectedToServerAction{connected: $connected}';
  }
}

class OnDisconnectedFromServerAction {
  final bool connected;

  OnDisconnectedFromServerAction(this.connected);

  @override
  String toString() {
    return 'OnDisconnectedFromServerAction{connected: $connected}';
  }
}
