import 'package:libmsgr/src/typedefs.dart';

import 'room_repository.dart';
import 'conversation_repository.dart';
import 'message_repository.dart';
import 'profile_repository.dart';
import 'team_repository.dart';

class RepositoryFactory {
  final Map<TeamNameType, TeamRepositories> _repositoriesCache = {};

  TeamRepositories getRepositories(TeamNameType teamName) {
    if (!_repositoriesCache.containsKey(teamName)) {
      _repositoriesCache[teamName] = TeamRepositories(teamName);
    }
    return _repositoriesCache[teamName]!;
  }
}

class TeamRepositories {
  final TeamNameType teamName;
  late final RoomRepository roomRepository;
  late final ConversationRepository conversationRepository;
  late final MessageRepository messageRepository;
  late final ProfileRepository profileRepository;
  late final TeamRepository teamRepository;

  TeamRepositories(this.teamName) {
    roomRepository = RoomRepository(teamName: teamName);
    conversationRepository = ConversationRepository(teamName: teamName);
    messageRepository = MessageRepository(teamName: teamName);
    profileRepository = ProfileRepository(teamName: teamName);
    teamRepository = TeamRepository(teamName: teamName);
  }
}
