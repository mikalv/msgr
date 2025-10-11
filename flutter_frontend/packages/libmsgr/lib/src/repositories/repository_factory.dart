import 'package:libmsgr/src/database/daos/contact_dao.dart';
import 'package:libmsgr/src/database/daos/message_dao.dart';
import 'package:libmsgr/src/database/database.dart';
import 'package:libmsgr/src/typedefs.dart';

import 'room_repository.dart';
import 'conversation_repository.dart';
import 'message_repository.dart';
import 'profile_repository.dart';
import 'team_repository.dart';

class RepositoryFactory {
  RepositoryFactory({required this.database});

  final DatabaseService database;
  final Map<TeamNameType, TeamRepositories> _repositoriesCache = {};

  TeamRepositories getRepositories(TeamNameType teamName) {
    if (!_repositoriesCache.containsKey(teamName)) {
      _repositoriesCache[teamName] = TeamRepositories(teamName, database);
    }
    return _repositoriesCache[teamName]!;
  }
}

class TeamRepositories {
  final TeamNameType teamName;
  final DatabaseService database;
  late final RoomRepository roomRepository;
  late final ConversationRepository conversationRepository;
  late final MessageRepository messageRepository;
  late final ProfileRepository profileRepository;
  late final TeamRepository teamRepository;

  TeamRepositories(this.teamName, this.database) {
    final db = database.instance;
    final messageDao = MessageDao(db);
    final contactDao = ContactDao(db);

    roomRepository = RoomRepository(teamName: teamName);
    conversationRepository = ConversationRepository(teamName: teamName);
    messageRepository = MessageRepository(
      teamName: teamName,
      dao: messageDao,
    );
    profileRepository = ProfileRepository(
      teamName: teamName,
      dao: contactDao,
    );
    teamRepository = TeamRepository(teamName: teamName);
  }
}
