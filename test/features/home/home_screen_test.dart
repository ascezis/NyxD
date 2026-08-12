import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/core/database/database_migrator.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/home/presentation/home_screen.dart';
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
    repository = EntryRepository(database)
      ..create('Первая заметка #сон')
      ..create('Рабочий план #работа')
      ..create('Без метки');
  });

  tearDown(() => database.close());

  testWidgets('renders flat note list and reference navigation items', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, onLock: () {}),
      ),
    );

    expect(find.text('Первая заметка #сон'), findsOneWidget);
    expect(find.text('Рабочий план #работа'), findsOneWidget);
    expect(find.byTooltip('Новая заметка'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Корзина'), findsOneWidget);
    expect(find.text('#сон'), findsOneWidget);
    expect(find.text('Заметки без меток'), findsOneWidget);
  });

  testWidgets('search filters notes without showing previews', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, onLock: () {}),
      ),
    );

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'рабочий');
    await tester.pump();

    expect(find.text('Рабочий план #работа'), findsOneWidget);
    expect(find.text('Первая заметка #сон'), findsNothing);
  });

  testWidgets('long press selects a note and exposes actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, onLock: () {}),
      ),
    );

    await tester.longPress(find.text('Без метки'));
    await tester.pump();

    expect(find.text('Выбрано: 1'), findsOneWidget);
    expect(find.byTooltip('Редактировать'), findsOneWidget);
    expect(find.byTooltip('Закрепить'), findsOneWidget);
  });

  testWidgets('short tap opens a note for editing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, onLock: () {}),
      ),
    );

    await tester.tap(find.text('Без метки'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('entry-title')), findsOneWidget);
    expect(find.byKey(const Key('entry-editor')), findsOneWidget);
  });
}
