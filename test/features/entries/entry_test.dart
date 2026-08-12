import 'package:flutter_test/flutter_test.dart';
import 'package:nyxd/features/entries/domain/entry.dart';

void main() {
  test('title is the trimmed first content line', () {
    final entry = Entry(
      id: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      content: '  Ночная мысль  \nОстальной текст',
      deletedAt: null,
    );

    expect(entry.title, 'Ночная мысль');
  });

  test('markdown level-one marker is not shown in the list title', () {
    final entry = Entry(
      id: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      content: '# Ночная мысль\nОстальной текст',
      deletedAt: null,
    );

    expect(entry.title, 'Ночная мысль');
    expect(entry.body, 'Остальной текст');
  });

  test('tags support Unicode, deduplicate case and ignore embedded hash', () {
    final tags = extractTags('#Сон #сон #night_owl email#not-a-tag #мысль42');

    expect(tags, {'сон', 'night_owl', 'мысль42'});
  });
}
