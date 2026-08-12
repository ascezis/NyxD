import 'package:nyxd/features/entries/domain/entry.dart';
import 'package:nyxd/features/entries/domain/entry_exceptions.dart';
import 'package:sqlite3/sqlite3.dart';

typedef Clock = DateTime Function();

final class EntryRepository {
  EntryRepository(this._database, {Clock? clock})
    : _clock = clock ?? DateTime.now;

  final Database _database;
  final Clock _clock;

  Entry create(String content, {Set<String>? tags}) {
    final timestamp = _clock().toUtc().millisecondsSinceEpoch;
    _database.execute(
      'INSERT INTO entries (created_at, updated_at, content, deleted_at) '
      'VALUES (?, ?, ?, NULL)',
      [timestamp, timestamp, content],
    );
    final id = _database.lastInsertRowId;
    _replaceTags(id, tags ?? extractTags(content));
    return getById(id);
  }

  Entry getById(int id, {bool includeDeleted = true}) {
    final rows = _database.select(
      'SELECT id, created_at, updated_at, content, deleted_at, is_pinned '
      'FROM entries WHERE id = ? '
      '${includeDeleted ? '' : 'AND deleted_at IS NULL'}',
      [id],
    );
    if (rows.isEmpty) {
      throw EntryNotFoundException(id);
    }
    return _entryFromRow(_database, rows.single);
  }

  List<Entry> listActive() {
    return _selectEntries(
      'SELECT id, created_at, updated_at, content, deleted_at, is_pinned '
      'FROM entries WHERE deleted_at IS NULL '
      'ORDER BY is_pinned DESC, updated_at DESC, id DESC',
    );
  }

  List<Entry> listTrash() {
    return _selectEntries(
      'SELECT id, created_at, updated_at, content, deleted_at, is_pinned '
      'FROM entries WHERE deleted_at IS NOT NULL '
      'ORDER BY deleted_at DESC, id DESC',
    );
  }

  Entry update({required int id, required String content, Set<String>? tags}) {
    final timestamp = _clock().toUtc().millisecondsSinceEpoch;
    _database.execute(
      'UPDATE entries SET content = ?, updated_at = ? '
      'WHERE id = ? AND deleted_at IS NULL',
      [content, timestamp, id],
    );
    _requireChanged(id);
    if (tags != null) _replaceTags(id, tags);
    return getById(id, includeDeleted: false);
  }

  void moveToTrash(int id) {
    final timestamp = _clock().toUtc().millisecondsSinceEpoch;
    _database.execute(
      'UPDATE entries SET deleted_at = ?, updated_at = ? '
      'WHERE id = ? AND deleted_at IS NULL',
      [timestamp, timestamp, id],
    );
    _requireChanged(id);
  }

  Entry restore(int id) {
    final timestamp = _clock().toUtc().millisecondsSinceEpoch;
    _database.execute(
      'UPDATE entries SET deleted_at = NULL, updated_at = ? '
      'WHERE id = ? AND deleted_at IS NOT NULL',
      [timestamp, id],
    );
    _requireChanged(id);
    return getById(id, includeDeleted: false);
  }

  Entry togglePinned(int id) {
    final timestamp = _clock().toUtc().millisecondsSinceEpoch;
    _database.execute(
      'UPDATE entries SET is_pinned = CASE is_pinned WHEN 0 THEN 1 ELSE 0 END, '
      'updated_at = ? WHERE id = ? AND deleted_at IS NULL',
      [timestamp, id],
    );
    _requireChanged(id);
    return getById(id, includeDeleted: false);
  }

  void deletePermanently(int id) {
    _database.execute('DELETE FROM entry_tags WHERE entry_id = ?', [id]);
    _database.execute(
      'DELETE FROM entries WHERE id = ? AND deleted_at IS NOT NULL',
      [id],
    );
    _requireChanged(id);
  }

  int emptyTrash() {
    _database.execute(
      'DELETE FROM entry_tags WHERE entry_id IN '
      '(SELECT id FROM entries WHERE deleted_at IS NOT NULL)',
    );
    _database.execute('DELETE FROM entries WHERE deleted_at IS NOT NULL');
    return _database.updatedRows;
  }

  List<Entry> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return listActive();
    }
    return listActive()
        .where((entry) => entry.content.toLowerCase().contains(normalizedQuery))
        .toList(growable: false);
  }

  List<Entry> withTag(String tag) {
    final normalizedTag = tag.replaceFirst(RegExp('^#'), '').toLowerCase();
    return listActive()
        .where((entry) => entry.tags.contains(normalizedTag))
        .toList(growable: false);
  }

  List<Entry> withoutTags() {
    return listActive()
        .where((entry) => entry.tags.isEmpty)
        .toList(growable: false);
  }

  List<String> listTags() {
    final tags = <String>{};
    for (final entry in listActive()) {
      tags.addAll(entry.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<Entry> _selectEntries(String sql) {
    final rows = _database.select(sql);
    return rows
        .map((row) => _entryFromRow(_database, row))
        .toList(growable: false);
  }

  void _replaceTags(int id, Set<String> tags) {
    _database.execute('DELETE FROM entry_tags WHERE entry_id = ?', [id]);
    final statement = _database.prepare(
      'INSERT INTO entry_tags (entry_id, tag) VALUES (?, ?)',
    );
    try {
      for (final tag in tags) {
        final normalized = tag
            .replaceFirst(RegExp(r'^#'), '')
            .trim()
            .toLowerCase();
        if (normalized.isNotEmpty) statement.execute([id, normalized]);
      }
    } finally {
      statement.close();
    }
  }

  void _requireChanged(int id) {
    if (_database.updatedRows == 0) {
      throw EntryNotFoundException(id);
    }
  }
}

Entry _entryFromRow(Database database, Row row) {
  final deletedAt = row['deleted_at'] as int?;
  final tags = database
      .select('SELECT tag FROM entry_tags WHERE entry_id = ? ORDER BY tag', [
        row['id'],
      ])
      .map((tagRow) => tagRow['tag']! as String)
      .toSet();
  return Entry(
    id: row['id']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row['created_at']! as int,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row['updated_at']! as int,
      isUtc: true,
    ),
    content: row['content']! as String,
    deletedAt: deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(deletedAt, isUtc: true),
    isPinned: (row['is_pinned']! as int) == 1,
    storedTags: tags,
  );
}
