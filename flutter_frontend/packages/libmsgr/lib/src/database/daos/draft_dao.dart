import 'package:libmsgr/src/database/constants.dart';
import 'package:libmsgr/src/storage/storage_interface.dart';

/// Data access object for channel drafts.
///
/// Drafts are permanent until explicitly sent or deleted by the user.
/// They survive app restarts via SQLite persistence.
class DraftDao {
  const DraftDao(this._db);

  final DatabaseConnection _db;

  /// Save or update a draft for a channel.
  ///
  /// Uses INSERT OR REPLACE (UPSERT) since the primary key is
  /// (channel_id, team_slug).
  Future<void> saveDraft(
    String channelId,
    String teamSlug,
    String content,
  ) async {
    await _db.insert(
      draftsTable,
      <String, Object?>{
        'channel_id': channelId,
        'team_slug': teamSlug,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the draft text for a specific channel, or null if none exists.
  Future<String?> getDraft(String channelId, String teamSlug) async {
    final rows = await _db.query(
      draftsTable,
      columns: ['content'],
      where: 'channel_id = ? AND team_slug = ?',
      whereArgs: [channelId, teamSlug],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final content = rows.first['content'] as String?;
    return (content != null && content.isNotEmpty) ? content : null;
  }

  /// Delete the draft for a specific channel (e.g., after sending).
  Future<void> deleteDraft(String channelId, String teamSlug) async {
    await _db.delete(
      draftsTable,
      where: 'channel_id = ? AND team_slug = ?',
      whereArgs: [channelId, teamSlug],
    );
  }

  /// Get all drafts for a team. Returns a map of channelId -> content.
  Future<Map<String, String>> getAllDrafts(String teamSlug) async {
    final rows = await _db.query(
      draftsTable,
      where: 'team_slug = ?',
      whereArgs: [teamSlug],
      orderBy: 'updated_at DESC',
    );

    final drafts = <String, String>{};
    for (final row in rows) {
      final channelId = row['channel_id'] as String;
      final content = row['content'] as String;
      if (content.isNotEmpty) {
        drafts[channelId] = content;
      }
    }
    return drafts;
  }
}
