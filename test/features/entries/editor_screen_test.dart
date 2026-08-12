import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/database/database_migrator.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/entries/presentation/editor_screen.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late EntryRepository repository;

  setUp(() {
    database = sqlite3.openInMemory()
      ..execute(
        'CREATE TABLE vault_info ('
        'id INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL) STRICT',
      )
      ..execute('INSERT INTO vault_info VALUES (1, 1)');
    const DatabaseMigrator().migrate(database);
    repository = EntryRepository(database);
  });

  tearDown(() => database.close());

  testWidgets('new note is saved when editor closes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(repository: repository)),
    );

    expect(
      tester.widget<TextField>(find.byKey(const Key('entry-title'))).autofocus,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'Новая заметка',
    );
    await tester.enterText(find.byKey(const Key('entry-editor')), '#сон');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(repository.listActive().single.content, 'Новая заметка\n#сон');
  });

  testWidgets('tag action uses a separate input and does not alter content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(repository: repository)),
    );

    await tester.enterText(find.byKey(const Key('entry-title')), 'Заголовок');
    await tester.enterText(find.byKey(const Key('entry-editor')), 'Текст');
    await tester.tap(find.text('Добавить метку…'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('tag-input')), 'Сон');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(repository.listActive().single.content, 'Заголовок\nТекст');
    expect(repository.listActive().single.tags, {'сон'});
  });

  testWidgets('system back closes the editor and saves the note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => EditorScreen(repository: repository),
                ),
              ),
              child: const Text('Открыть редактор'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть редактор'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'Назад работает',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsNothing);
    expect(repository.listActive().single.title, 'Назад работает');
  });
}
