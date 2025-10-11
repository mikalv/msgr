import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/repositories/base.dart';

class TeamRepository extends BaseRepository<Team> {
  TeamRepository({required super.teamName}) {
    log.info('TeamRepository is starting up');
  }
}
