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

  testWidgets('existing tags are suggested and can be selected with one tap', (
    tester,
  ) async {
    repository.create('Старая заметка #важное #работа');

    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(repository: repository)),
    );

    await tester.enterText(find.byKey(const Key('entry-title')), 'Новая');
    await tester.enterText(find.byKey(const Key('entry-editor')), 'Тело');
    await tester.tap(find.text('Добавить метку…'));
    await tester.pump();

    expect(find.text('#важное'), findsOneWidget);
    expect(find.text('#работа'), findsOneWidget);

    await tester.tap(find.text('#важное'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final notes = repository.listActive();
    final newNote = notes.firstWhere((n) => n.title == 'Новая');
    expect(newNote.tags, contains('важное'));
  });

  testWidgets('toolbar formatting buttons toggle checkboxes and lists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(repository: repository)),
    );

    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'Список задач',
    );
    await tester.enterText(
      find.byKey(const Key('entry-editor')),
      'Купить хлеб',
    );

    // Test Checkbox toggle
    await tester.tap(find.byKey(const Key('format-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      '☐ Купить хлеб',
    );

    // Toggle to checked
    await tester.tap(find.byKey(const Key('format-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      '☑ Купить хлеб',
    );

    // Toggle off
    await tester.tap(find.byKey(const Key('format-checkbox')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      'Купить хлеб',
    );

    // Test Numbered List toggle
    await tester.tap(find.byKey(const Key('format-numbered-list')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      '1. Купить хлеб',
    );

    // Test Bullet List toggle
    await tester.tap(find.byKey(const Key('format-bullet-list')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      '- Купить хлеб',
    );

    // Test Heading toggle
    await tester.tap(find.byKey(const Key('format-heading')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('entry-editor')))
          .controller
          ?.text,
      '# - Купить хлеб',
    );
  });

  test(
    'SmartListInputFormatter auto-continues and terminates checklists and lists',
    () {
      const formatter = SmartListInputFormatter();

      // 1. Checklist continuation
      var oldVal = const TextEditingValue(
        text: '- [ ] Молоко',
        selection: TextSelection.collapsed(offset: 12),
      );
      var newVal = const TextEditingValue(
        text: '- [ ] Молоко\n',
        selection: TextSelection.collapsed(offset: 13),
      );
      var result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, '- [ ] Молоко\n- [ ] ');
      expect(result.selection.baseOffset, 19);

      // 2. Empty checklist item terminated
      oldVal = const TextEditingValue(
        text: '- [ ] Молоко\n- [ ] ',
        selection: TextSelection.collapsed(offset: 19),
      );
      newVal = const TextEditingValue(
        text: '- [ ] Молоко\n- [ ] \n',
        selection: TextSelection.collapsed(offset: 20),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, '- [ ] Молоко\n');
      expect(result.selection.baseOffset, 13);

      // 3. Numbered list continuation
      oldVal = const TextEditingValue(
        text: '1. Пункт',
        selection: TextSelection.collapsed(offset: 8),
      );
      newVal = const TextEditingValue(
        text: '1. Пункт\n',
        selection: TextSelection.collapsed(offset: 9),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, '1. Пункт\n2. ');
      expect(result.selection.baseOffset, 12);

      // 4. Empty numbered item terminated
      oldVal = const TextEditingValue(
        text: '1. Пункт\n2. ',
        selection: TextSelection.collapsed(offset: 12),
      );
      newVal = const TextEditingValue(
        text: '1. Пункт\n2. \n',
        selection: TextSelection.collapsed(offset: 13),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, '1. Пункт\n');
      expect(result.selection.baseOffset, 9);

      // 5. Bullet list continuation
      oldVal = const TextEditingValue(
        text: '- Пункт',
        selection: TextSelection.collapsed(offset: 7),
      );
      newVal = const TextEditingValue(
        text: '- Пункт\n',
        selection: TextSelection.collapsed(offset: 8),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, '- Пункт\n- ');
      expect(result.selection.baseOffset, 10);
    },
  );

  testWidgets('lifecycle inactive/paused immediately flushes save', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: EditorScreen(repository: repository)),
    );

    await tester.enterText(
      find.byKey(const Key('entry-title')),
      'Срочная мысль',
    );
    await tester.enterText(
      find.byKey(const Key('entry-editor')),
      'Текст, который нельзя потерять при сворачивании',
    );

    // Simulate app going into background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    final notes = repository.listActive();
    expect(notes, isNotEmpty);
    expect(notes.single.title, 'Срочная мысль');
    expect(
      notes.single.body,
      'Текст, который нельзя потерять при сворачивании',
    );
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
