final class Entry {
  const Entry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.content,
    required this.deletedAt,
    this.isPinned = false,
    this.storedTags,
  });

  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String content;
  final DateTime? deletedAt;
  final bool isPinned;
  final Set<String>? storedTags;

  bool get isDeleted => deletedAt != null;

  String get title {
    final lineBreak = content.indexOf('\n');
    final firstLine = lineBreak == -1
        ? content
        : content.substring(0, lineBreak);
    return firstLine.trim().replaceFirst(RegExp(r'^#\s+'), '');
  }

  String get body {
    final lineBreak = content.indexOf('\n');
    return lineBreak == -1 ? '' : content.substring(lineBreak + 1);
  }

  Set<String> get tags => storedTags ?? extractTags(content);
}

final _tagPattern = RegExp(
  r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)',
  unicode: true,
);

Set<String> extractTags(String content) {
  final tags = <String>{};
  for (final match in _tagPattern.allMatches(content)) {
    tags.add(match.group(1)!.toLowerCase());
  }
  return tags;
}
