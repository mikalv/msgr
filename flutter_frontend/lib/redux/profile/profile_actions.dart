import 'dart:async';

import 'package:libmsgr/libmsgr.dart';
import 'package:messngr/services/api/chat_api.dart';
import 'package:messngr/services/api/profile_api.dart';

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

class RefreshProfilesAction extends ProfileActions {
  RefreshProfilesAction({required this.identity});

  final AccountIdentity identity;

  @override
  String toString() {
    return 'RefreshProfilesAction{identity: ${identity.accountId}/${identity.profileId}}';
  }
}

class RefreshProfilesSuccessAction extends ProfileActions {
  RefreshProfilesSuccessAction({required this.profiles});

  final List<Profile> profiles;

  @override
  String toString() => 'RefreshProfilesSuccessAction{profiles: ${profiles.length}}';
}

class RefreshProfilesFailureAction extends ProfileActions {
  RefreshProfilesFailureAction({required this.error});

  final String error;

  @override
  String toString() => 'RefreshProfilesFailureAction{error: $error}';
}

class SwitchProfileAction extends ProfileActions {
  SwitchProfileAction({
    required this.identity,
    required this.profileId,
    Completer<ProfileSwitchResult>? completer,
  }) : completer = completer ?? Completer<ProfileSwitchResult>();

  final AccountIdentity identity;
  final String profileId;
  final Completer<ProfileSwitchResult> completer;

  @override
  String toString() => 'SwitchProfileAction{profileId: $profileId}';
}

class SwitchProfileSuccessAction extends ProfileActions {
  SwitchProfileSuccessAction({
    required this.profile,
    required this.identity,
    this.device,
  });

  final Profile profile;
  final AccountIdentity identity;
  final Map<String, dynamic>? device;

  @override
  String toString() => 'SwitchProfileSuccessAction{profile: ${profile.id}}';
}

class SwitchProfileFailureAction extends ProfileActions {
  SwitchProfileFailureAction({required this.error});

  final String error;

  @override
  String toString() => 'SwitchProfileFailureAction{error: $error}';
}
