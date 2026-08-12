import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/database/database_migrator.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/entries/domain/entry_exceptions.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late EntryRepository repository;
  var now = DateTime.utc(2026, 8, 11, 12);

  setUp(() {
    database = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL) STRICT',
      )
      ..execute('INSERT INTO vault_info VALUES (1, 1)');
    const DatabaseMigrator().migrate(database);
    repository = EntryRepository(database, clock: () => now);
  });

  tearDown(() => database.close());

  test('creates, reads and updates an entry', () {
    final created = repository.create('Первая строка\n#сон');
    expect(created.title, 'Первая строка');
    expect(created.tags, {'сон'});
    expect(created.createdAt, now);

    now = now.add(const Duration(minutes: 1));
    final updated = repository.update(id: created.id, content: 'Новый текст');

    expect(updated.content, 'Новый текст');
    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt, now);
    expect(repository.listActive(), hasLength(1));
  });

  test('moves an entry to trash, restores and permanently deletes it', () {
    final entry = repository.create('Удаляемая заметка');

    repository.moveToTrash(entry.id);
    expect(repository.listActive(), isEmpty);
    expect(repository.listTrash().single.id, entry.id);

    repository.restore(entry.id);
    expect(repository.listTrash(), isEmpty);
    expect(repository.listActive().single.id, entry.id);

    repository.moveToTrash(entry.id);
    repository.deletePermanently(entry.id);
    expect(
      () => repository.getById(entry.id),
      throwsA(isA<EntryNotFoundException>()),
    );
  });

  test('emptyTrash deletes only trashed entries', () {
    repository.create('Остаётся');
    final deleted = repository.create('Удаляется');
    repository.moveToTrash(deleted.id);

    expect(repository.emptyTrash(), 1);
    expect(repository.listActive().single.content, 'Остаётся');
  });

  test('search and tag filters exclude trash', () {
    repository.create('Сон про море #Сон');
    repository.create('Рабочая мысль #работа');
    repository.create('Без метки');
    final deleted = repository.create('Море #сон');
    repository.moveToTrash(deleted.id);

    expect(repository.search('МОРЕ'), hasLength(1));
    expect(repository.withTag('#СОН'), hasLength(1));
    expect(repository.withoutTags(), hasLength(1));
    expect(repository.listTags(), ['работа', 'сон']);
  });

  test('search checks both the title and note body', () {
    repository.create('Нужный заголовок\nОбычный текст');
    repository.create('Другой заголовок\nСекретное слово в тексте');

    expect(repository.search('нужный').single.title, 'Нужный заголовок');
    expect(repository.search('СЕКРЕТНОЕ').single.title, 'Другой заголовок');
  });

  test('pinned entries stay above newer regular entries', () {
    final pinned = repository.create('Закреплённая');
    now = now.add(const Duration(minutes: 1));
    repository.create('Новая обычная');

    repository.togglePinned(pinned.id);

    expect(repository.listActive().first.title, 'Закреплённая');
    expect(repository.listActive().first.isPinned, isTrue);
  });

  test('modifying a missing entry fails explicitly', () {
    expect(
      () => repository.update(id: 404, content: 'Нет'),
      throwsA(isA<EntryNotFoundException>()),
    );
  });

  test('version 2 migration preserves inline tags as separate metadata', () {
    final legacy = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL) STRICT',
      )
      ..execute('INSERT INTO vault_info VALUES (1, 2)')
      ..execute(
        'CREATE TABLE entries ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'content TEXT NOT NULL, deleted_at INTEGER) STRICT',
      )
      ..execute(
        "INSERT INTO entries VALUES (1, 0, 0, 'Старая заметка #Сон', NULL)",
      );
    addTearDown(legacy.close);

    const DatabaseMigrator().migrate(legacy);

    expect(EntryRepository(legacy).getById(1).tags, {'сон'});
  });
}
