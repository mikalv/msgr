import 'dart:async';

import 'package:libmsgr/libmsgr.dart';
import 'package:libmsgr/src/database/daos/contact_dao.dart';
import 'package:libmsgr/src/repositories/base.dart';

class ProfileRepository extends BaseRepository<Profile> {
  ProfileRepository({required super.teamName, required ContactDao dao})
      : _dao = dao {
    log.info('ProfileRepository is starting up');
    unawaited(_hydrateFromDisk());
    _ensureSystemProfile();
  }

  final ContactDao _dao;

  Future<void> _hydrateFromDisk() async {
    final stored = await _dao.getContacts(teamName);
    if (stored.isNotEmpty) {
      super.fillLocalCache(stored);
    }
    _ensureSystemProfile();
  }

  void _ensureSystemProfile() {
    final hasSystem = items.any((profile) => profile.id == 'system');
    if (!hasSystem) {
      addItem(
        Profile(
          id: 'system',
          username: 'system',
          uid: 'system',
          updatedAt: DateTime.now(),
          createdAt: DateTime.now(),
          firstName: 'Msgr',
          lastName: 'System',
          roles: const [],
        ),
      );
    }
  }

  @override
  void fillLocalCache(List<Profile> items) {
    super.fillLocalCache(items);
    unawaited(_dao.upsertContacts(teamName, items));
    _ensureSystemProfile();
  }

  @override
  void addItem(Profile item) {
    super.addItem(item);
    unawaited(_dao.upsertContacts(teamName, [item]));
  }

  @override
  void updateItem(Profile item) {
    super.updateItem(item);
    unawaited(_dao.upsertContacts(teamName, [item]));
  }

  @override
  void removeItem(String id) {
    super.removeItem(id);
    unawaited(_dao.deleteContacts(teamName, [id]));
  }

  List<Profile> listTeamProfiles() {
    return items.toList();
  }
}
