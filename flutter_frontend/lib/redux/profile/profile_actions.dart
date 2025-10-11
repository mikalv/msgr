import 'package:libmsgr/libmsgr.dart';

class ProfileActions {}

class CreateProfileAction extends ProfileActions {
  final String username;
  final String firstName;
  final String lastName;

  CreateProfileAction(
      {required this.username,
      required this.firstName,
      required this.lastName});

  @override
  String toString() {
    return 'CreateProfileAction{username: $username, firstName: $firstName, lastName: $lastName}"}';
  }
}

class OnNewProfileInTeamAction extends ProfileActions {
  final Profile profile;

  OnNewProfileInTeamAction({
    required this.profile,
  });

  @override
  String toString() {
    return 'OnNewProfileInTeamAction{profile: $profile}"}';
  }
}

class OnCreateProfileSuccessAction extends ProfileActions {
  final Profile profile;

  OnCreateProfileSuccessAction({
    required this.profile,
  });

  @override
  String toString() {
    return 'OnCreateProfileSuccessAction{profile: $profile}"}';
  }
}

class OnCreateProfileFailureAction extends ProfileActions {
  final String msg;

  OnCreateProfileFailureAction({
    required this.msg,
  });

  @override
  String toString() {
    return 'OnCreateProfileFailureAction{msg: $msg}"}';
  }
}

class UpdateProfileAction extends ProfileActions {
  final String username;
  final String firstName;
  final String lastName;
  final Map<String, dynamic> settings;
  final String status;
  final String avatarUrl;

  UpdateProfileAction(
      {required this.username,
      required this.firstName,
      required this.lastName,
      required this.settings,
      required this.status,
      required this.avatarUrl});

  @override
  String toString() {
    return 'UpdateProfileAction{username: $username, firstName: $firstName, lastName: $lastName}"}';
  }
}

class OnUpdateProfileSuccessAction extends ProfileActions {
  final Profile profile;

  OnUpdateProfileSuccessAction({
    required this.profile,
  });

  @override
  String toString() {
    return 'OnUpdateProfileSuccessAction{profile: $profile}"}';
  }
}

class OnUpdateProfileFailureAction extends ProfileActions {
  final String msg;

  OnUpdateProfileFailureAction({
    required this.msg,
  });

  @override
  String toString() {
    return 'OnUpdateProfileFailureAction{msg: $msg}"}';
  }
}
