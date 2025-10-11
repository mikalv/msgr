import 'package:libmsgr/libmsgr.dart';

/// Represents the state of a team within the application.
///
/// This class holds all the necessary information and state related to a team,
/// which can be used throughout the application to manage and display team-related data.
class TeamState {
  final List<Conversation> conversations;
  final List<Room> rooms;
  final List<Profile> profiles;
  final Team? selectedTeam;
  final Conversation? currentConversation;
  final Room? currentRoom;

  TeamState({
    this.currentConversation,
    this.currentRoom,
    this.conversations = const [],
    this.rooms = const [],
    this.profiles = const [],
    required this.selectedTeam,
  });

  TeamState copyWith({
    List<Conversation>? conversations,
    List<Room>? rooms,
    List<Profile>? profiles,
    Team? selectedTeam,
    Conversation? currentConversation,
    Room? currentRoom,
  }) {
    return TeamState(
      conversations: conversations ?? this.conversations,
      rooms: rooms ?? this.rooms,
      profiles: profiles ?? this.profiles,
      selectedTeam: selectedTeam ?? this.selectedTeam,
      currentConversation: currentConversation ?? this.currentConversation,
      currentRoom: currentRoom ?? this.currentRoom,
    );
  }

  factory TeamState.fromJson(dynamic json) {
    return TeamState(
      conversations: (json['conversations'] as List)
          .map((e) => Conversation.fromJson(e))
          .toList(),
      rooms: (json['rooms'] as List).map((e) => Room.fromJson(e)).toList(),
      profiles:
          (json['profiles'] as List).map((e) => Profile.fromJson(e)).toList(),
      selectedTeam: Team.fromJson(json['selectedTeam']),
      currentConversation: json['currentConversation'] != null
          ? Conversation.fromJson(json['currentConversation'])
          : null,
      currentRoom: json['currentRoom'] != null
          ? Room.fromJson(json['currentRoom'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversations': conversations.map((e) => e.toJson()).toList(),
        'rooms': rooms,
        'profiles': profiles,
        'selectedTeam': selectedTeam?.toJson() ?? {},
        'currentConversation': currentConversation?.toJson(),
        'currentRoom': currentRoom?.toJson(),
      };
  @override
  String toString() {
    return 'TeamState{conversations: ${conversations.toString()}, rooms: ${rooms.toString()}, '
        'profiles: ${profiles.toString()}, selectedTeam: $selectedTeam, currentConversation: '
        '$currentConversation, currentRoom: $currentRoom}';
  }
}
