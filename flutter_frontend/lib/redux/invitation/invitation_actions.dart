class InviteUserToTeamAction {
  final String teamName;
  final String identifier;

  InviteUserToTeamAction({required this.teamName, required this.identifier});

  @override
  String toString() {
    return 'InviteUserToTeamAction{teamName: $teamName, identifier: $identifier}';
  }
}

class OnInviteUserToTeamSuccessAction {
  final String msg;

  OnInviteUserToTeamSuccessAction(this.msg);

  @override
  String toString() {
    return 'OnInviteUserToTeamSuccessAction{msg: $msg}';
  }
}

class OnInviteUserToTeamFailureAction {
  final String msg;
  final StackTrace stackTrace;

  OnInviteUserToTeamFailureAction(this.msg, this.stackTrace);

  @override
  String toString() {
    return 'OnInviteUserToTeamFailureAction{msg: $msg}';
  }
}

class InviteProfileToRoomAction {
  final String roomID;
  final String profileID;

  InviteProfileToRoomAction(this.roomID, this.profileID);

  @override
  String toString() {
    return 'InviteProfileToRoomAction{roomID: $roomID, profileID: $profileID}';
  }
}

class OnInviteProfileToRoomSuccessAction {
  final String msg;

  OnInviteProfileToRoomSuccessAction(this.msg);

  @override
  String toString() {
    return 'OnInviteProfileToRoomSuccessAction{msg: $msg}';
  }
}

class OnInviteProfileToRoomFailureAction {
  final String msg;

  OnInviteProfileToRoomFailureAction(this.msg);

  @override
  String toString() {
    return 'OnInviteProfileToRoomFailureAction{msg: $msg}';
  }
}

class InviteProfileToConversationAction {
  final String conversationID;
  final String profileID;

  InviteProfileToConversationAction(this.conversationID, this.profileID);

  @override
  String toString() {
    return 'InviteProfileToConversationAction{conversationID: $conversationID, profileID: $profileID}';
  }
}

class OnInviteProfileToConversationSuccessAction {
  final String msg;

  OnInviteProfileToConversationSuccessAction(this.msg);

  @override
  String toString() {
    return 'OnInviteProfileToConversationSuccessAction{msg: $msg}';
  }
}

class OnInviteProfileToConversationFailureAction {
  final String msg;

  OnInviteProfileToConversationFailureAction(this.msg);

  @override
  String toString() {
    return 'OnInviteProfileToConversationFailureAction{msg: $msg}';
  }
}
