import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/repositories/base.dart';

class ProfileRepository extends BaseRepository<Profile> {
  ProfileRepository({required super.teamName}) {
    log.info('ProfileRepository is starting up');
    addItem(Profile(
      id: 'system',
      username: 'system',
      uid: 'system',
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      firstName: 'Msgr',
      lastName: 'System',
      roles: [],
    ));
  }

  List<Profile> listTeamProfiles() {
    return items.toList();
  }
}
