import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/redux/app/app_actions.dart';

class RefreshClient {
  RefreshClient(this.clientId);

  final String clientId;
}

class LoadUserRequest implements StartLoading {}

class LoadUserFailure implements StopLoading {
  LoadUserFailure(this.error);

  final dynamic error;

  @override
  String toString() {
    return 'LoadUserFailure{error: $error}';
  }
}

class LoadUserSuccess implements StopLoading, PersistData {
  LoadUserSuccess(this.user);

  final User user;

  @override
  String toString() {
    return 'LoadUserSuccess{user: $user}';
  }
}
