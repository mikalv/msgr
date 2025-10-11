import 'package:libmsgr/libmsgr.dart';

class OnReceiveProfilesAction {
  final List<Profile> profiles;

  OnReceiveProfilesAction({required this.profiles});

  @override
  String toString() {
    return 'OnReceiveProfilesAction{profiles: $profiles}';
  }
}
