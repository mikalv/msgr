import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libmsgr/libmsgr.dart';

/// Team state class holding team-related data
class TeamState {
  final List<Conversation> conversations;
  final List<Room> rooms;
  final List<Profile> profiles;
  final Conversation? currentConversation;
  final Room? currentRoom;
  final bool isLoading;
  final Exception? error;

  const TeamState({
    this.conversations = const [],
    this.rooms = const [],
    this.profiles = const [],
    this.currentConversation,
    this.currentRoom,
    this.isLoading = false,
    this.error,
  });

  TeamState copyWith({
    List<Conversation>? conversations,
    List<Room>? rooms,
    List<Profile>? profiles,
    Conversation? currentConversation,
    Room? currentRoom,
    bool? isLoading,
    Exception? error,
  }) {
    return TeamState(
      conversations: conversations ?? this.conversations,
      rooms: rooms ?? this.rooms,
      profiles: profiles ?? this.profiles,
      currentConversation: currentConversation ?? this.currentConversation,
      currentRoom: currentRoom ?? this.currentRoom,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Team notifier class
class TeamNotifier extends StateNotifier<TeamState> {
  TeamNotifier() : super(const TeamState());

  /// Load team data (bootstrap)
  Future<void> loadTeamData(String teamName) async {
    state = state.copyWith(isLoading: true);
    try {
      // Get repositories from LibMsgr for this team
      final repositories = LibMsgr().repositoryFactory.getRepositories(teamName);

      // Subscribe to repository changes
      repositories.conversationRepository.addListener((conversations) {
        state = state.copyWith(conversations: conversations);
      });

      repositories.roomRepository.addListener((rooms) {
        state = state.copyWith(rooms: rooms);
      });

      repositories.profileRepository.addListener((profiles) {
        state = state.copyWith(profiles: profiles);
      });

      // Load initial data from repositories
      final conversations = repositories.conversationRepository.items;
      final rooms = repositories.roomRepository.items;
      final profiles = repositories.profileRepository.items;

      state = state.copyWith(
        conversations: conversations,
        rooms: rooms,
        profiles: profiles,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e as Exception,
      );
      rethrow;
    }
  }

  /// Set current conversation
  void setCurrentConversation(Conversation? conversation) {
    state = state.copyWith(currentConversation: conversation);
  }

  /// Set current room
  void setCurrentRoom(Room? room) {
    state = state.copyWith(currentRoom: room);
  }

  /// Add or update conversation
  void upsertConversation(Conversation conversation) {
    final conversations = List<Conversation>.from(state.conversations);
    final index = conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }
    state = state.copyWith(conversations: conversations);
  }

  /// Add or update room
  void upsertRoom(Room room) {
    final rooms = List<Room>.from(state.rooms);
    final index = rooms.indexWhere((r) => r.id == room.id);
    if (index != -1) {
      rooms[index] = room;
    } else {
      rooms.add(room);
    }
    state = state.copyWith(rooms: rooms);
  }

  /// Add or update profile
  void upsertProfile(Profile profile) {
    final profiles = List<Profile>.from(state.profiles);
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    state = state.copyWith(profiles: profiles);
  }

  /// Clear team data
  void clear() {
    state = const TeamState();
  }

  /// Send invitation to a user
  Future<void> inviteUser({
    required String teamName,
    required String profileId,
    required String identifier,
  }) async {
    try {
      final connection = LibMsgr().getWebsocketConnection();
      if (connection == null) {
        throw Exception('No websocket connection available');
      }
      connection.sendInvitation(teamName, profileId, identifier);
    } catch (e) {
      state = state.copyWith(error: e as Exception);
      rethrow;
    }
  }
}

/// Team state provider
final teamProvider = StateNotifierProvider<TeamNotifier, TeamState>((ref) {
  return TeamNotifier();
});

/// Convenience providers for specific team state

final conversationsProvider = Provider<List<Conversation>>((ref) {
  return ref.watch(teamProvider).conversations;
});

final roomsProvider = Provider<List<Room>>((ref) {
  return ref.watch(teamProvider).rooms;
});

final profilesProvider = Provider<List<Profile>>((ref) {
  return ref.watch(teamProvider).profiles;
});

final currentConversationProvider = Provider<Conversation?>((ref) {
  return ref.watch(teamProvider).currentConversation;
});

final currentRoomProvider = Provider<Room?>((ref) {
  return ref.watch(teamProvider).currentRoom;
});

/// Filtered conversations for personal app (based on profile mode)
final personalConversationsProvider = Provider<List<Conversation>>((ref) {
  final conversations = ref.watch(conversationsProvider);
  final profiles = ref.watch(profilesProvider);

  // Filter conversations where members have profile mode = private or family
  final personalProfiles = profiles
      .where(
          (p) => p.mode == ProfileMode.private || p.mode == ProfileMode.family)
      .toList();

  return conversations
      .where((c) =>
          c.members.any((m) => personalProfiles.any((p) => p.id == m)))
      .toList();
});

/// Filtered conversations for workspace app (based on profile mode)
final workConversationsProvider = Provider<List<Conversation>>((ref) {
  final conversations = ref.watch(conversationsProvider);
  final profiles = ref.watch(profilesProvider);

  // Filter conversations where members have profile mode = work
  final workProfiles =
      profiles.where((p) => p.mode == ProfileMode.work).toList();

  return conversations
      .where((c) => c.members.any((m) => workProfiles.any((p) => p.id == m)))
      .toList();
});
