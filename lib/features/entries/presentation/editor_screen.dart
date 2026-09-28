import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyxd/core/vault/vault_service.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/entries/domain/entry.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.repository,
    this.entry,
    this.vault,
    this.onActivity,
  });

  final EntryRepository repository;
  final Entry? entry;
  final VaultService? vault;
  final VoidCallback? onActivity;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _tagController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();
  Timer? _saveTimer;
  Timer? _heartbeatTimer;
  Entry? _entry;
  bool _changed = false;
  bool _closing = false;
  bool _addingTag = false;
  late final Set<String> _tags;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.vault?.addFlushCallback(_saveNow);

    _entry = widget.entry;
    _titleController = TextEditingController(text: _entry?.title ?? '');
    _bodyController = RichNoteEditingController(text: _entry?.body ?? '');
    _tags = {...?_entry?.tags};

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        widget.onActivity?.call();
      }
    });

    _tagFocusNode.addListener(() {
      if (!_tagFocusNode.hasFocus && _tagController.text.trim().isNotEmpty) {
        _addTag();
      }
    });

    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        _saveNow();
      }
    });

    _bodyFocusNode.addListener(() {
      if (!_bodyFocusNode.hasFocus) {
        _saveNow();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.vault?.removeFlushCallback(_saveNow);
    _heartbeatTimer?.cancel();
    _saveTimer?.cancel();
    try {
      _saveNow();
    } catch (_) {}
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _saveNow();
    }
  }

  void _scheduleSave() {
    widget.onActivity?.call();
    _changed = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveNow);
  }

  String _buildContent() {
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    if (title.isEmpty) {
      return body;
    }
    if (body.isEmpty) {
      return title;
    }
    return '$title\n$body';
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _commitPendingTag();
    final content = _buildContent();
    final inTextTags = extractTags(content);
    final allTags = {..._tags, ...inTextTags};

    try {
      if (_entry == null) {
        if (content.trim().isEmpty && allTags.isEmpty) {
          return;
        }
        _entry = widget.repository.create(content, tags: allTags);
      } else {
        _entry = widget.repository.update(
          id: _entry!.id,
          content: content,
          tags: allTags,
        );
      }
    } catch (_) {
      // Ignored if DB was closed
    }
  }

  void _showTagInput() {
    setState(() => _addingTag = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tagFocusNode.requestFocus();
    });
  }

  void _addTag() {
    final added = _commitPendingTag();
    if (!added) return;
    if (mounted) {
      setState(() => _addingTag = false);
    }
    _scheduleSave();
  }

  void _selectExistingTag(String tag) {
    _tags.add(tag.toLowerCase());
    _scheduleSave();
    setState(() {});
  }

  bool _commitPendingTag() {
    final tag = _tagController.text
        .replaceFirst(RegExp(r'^#'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
    if (tag.isEmpty) return false;
    _tags.add(tag);
    _tagController.clear();
    return true;
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _scheduleSave();
  }

  void _close() {
    if (_closing) {
      return;
    }
    _closing = true;
    _saveNow();
    Navigator.pop(context, _changed);
  }

  void _delete() {
    final entry = _entry;
    if (entry != null) {
      widget.repository.moveToTrash(entry.id);
      _changed = true;
    }
    _closing = true;
    Navigator.pop(context, _changed);
  }

  // --- Formatting Helpers ---

  void _toggleCheckbox() {
    _applyLinePrefixTransform((line) {
      if (line.startsWith('☐ ')) {
        return '☑ ${line.substring(2)}';
      } else if (line.startsWith('☑ ')) {
        return line.substring(2);
      } else if (line.startsWith('- [ ] ')) {
        return '☑ ${line.substring(6)}';
      } else if (line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
        return line.substring(6);
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        return '☐ ${line.substring(2)}';
      } else if (RegExp(r'^\d+\.\s*').hasMatch(line)) {
        return '☐ ${line.replaceFirst(RegExp(r'^\d+\.\s*'), '')}';
      } else {
        return '☐ $line';
      }
    });
  }

  void _toggleNumberedList() {
    _applyLinePrefixTransform((line) {
      if (RegExp(r'^\d+\.\s*').hasMatch(line)) {
        return line.replaceFirst(RegExp(r'^\d+\.\s*'), '');
      } else if (line.startsWith('☐ ') || line.startsWith('☑ ')) {
        return '1. ${line.substring(2)}';
      } else if (line.startsWith('- [ ] ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        return '1. ${line.substring(6)}';
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        return '1. ${line.substring(2)}';
      } else {
        return '1. $line';
      }
    });
  }

  void _toggleBulletList() {
    _applyLinePrefixTransform((line) {
      if (line.startsWith('- ') || line.startsWith('* ')) {
        return line.substring(2);
      } else if (line.startsWith('☐ ') || line.startsWith('☑ ')) {
        return '- ${line.substring(2)}';
      } else if (line.startsWith('- [ ] ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        return '- ${line.substring(6)}';
      } else if (RegExp(r'^\d+\.\s*').hasMatch(line)) {
        return '- ${line.replaceFirst(RegExp(r'^\d+\.\s*'), '')}';
      } else {
        return '- $line';
      }
    });
  }

  void _toggleHeading() {
    _applyLinePrefixTransform((line) {
      if (line.startsWith('### ')) {
        return line.substring(4);
      } else if (line.startsWith('## ')) {
        return '### ${line.substring(3)}';
      } else if (line.startsWith('# ')) {
        return '## ${line.substring(2)}';
      } else {
        return '# $line';
      }
    });
  }

  void _applyLinePrefixTransform(String Function(String line) transform) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final cursor = selection.isValid
        ? selection.baseOffset.clamp(0, text.length)
        : text.length;

    final lineStart = text.lastIndexOf('\n', cursor == 0 ? 0 : cursor - 1) + 1;
    final lineEndIndex = text.indexOf('\n', cursor);
    final lineEnd = lineEndIndex == -1 ? text.length : lineEndIndex;
    final currentLine = text.substring(lineStart, lineEnd);

    final newLine = transform(currentLine);
    final delta = newLine.length - currentLine.length;

    final newText =
        text.substring(0, lineStart) + newLine + text.substring(lineEnd);
    final newCursor = (cursor + delta).clamp(0, newText.length);

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _scheduleSave();
    if (!_bodyFocusNode.hasFocus) {
      _bodyFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> allAvailableTags;
    try {
      allAvailableTags = widget.repository
          .listTags()
          .where((t) => !_tags.contains(t.toLowerCase()))
          .toList();
    } catch (_) {
      allAvailableTags = const [];
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _saveNow();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            if (_entry != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _delete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('В корзину')),
                ],
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: TextField(
                  key: const Key('entry-title'),
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  autofocus: _entry == null,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _bodyFocusNode.requestFocus(),
                  onChanged: (_) => _scheduleSave(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Заголовок',
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('entry-editor'),
                  controller: _bodyController,
                  focusNode: _bodyFocusNode,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: const [SmartListInputFormatter()],
                  onChanged: (_) => _scheduleSave(),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                    hintText: 'Начните писать…',
                  ),
                ),
              ),
              // Formatting Toolbar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('format-checkbox'),
                      icon: const Icon(Icons.check_box_outlined, size: 22),
                      tooltip: 'Чекбокс',
                      onPressed: _toggleCheckbox,
                    ),
                    IconButton(
                      key: const Key('format-numbered-list'),
                      icon: const Icon(Icons.format_list_numbered, size: 22),
                      tooltip: 'Нумерованный список',
                      onPressed: _toggleNumberedList,
                    ),
                    IconButton(
                      key: const Key('format-bullet-list'),
                      icon: const Icon(Icons.format_list_bulleted, size: 22),
                      tooltip: 'Маркированный список',
                      onPressed: _toggleBulletList,
                    ),
                    IconButton(
                      key: const Key('format-heading'),
                      icon: const Icon(Icons.title, size: 22),
                      tooltip: 'Заголовок',
                      onPressed: _toggleHeading,
                    ),
                    const Spacer(),
                    if (!_addingTag)
                      TextButton.icon(
                        key: const Key('add-tag-button'),
                        onPressed: _showTagInput,
                        icon: const Icon(Icons.tag, size: 18),
                        label: const Text('Добавить метку…'),
                      ),
                  ],
                ),
              ),
              // Tags Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in _tags)
                        InputChip(
                          label: Text('#$tag'),
                          onDeleted: () => _removeTag(tag),
                        ),
                      if (_addingTag) ...[
                        if (allAvailableTags.isNotEmpty) ...[
                          for (final suggestedTag in allAvailableTags)
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text('#$suggestedTag'),
                              onPressed: () => _selectExistingTag(suggestedTag),
                            ),
                        ],
                        SizedBox(
                          width: 180,
                          child: TextField(
                            key: const Key('tag-input'),
                            controller: _tagController,
                            focusNode: _tagFocusNode,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addTag(),
                            onTapOutside: (_) => _addTag(),
                            decoration: InputDecoration(
                              hintText: 'Новая метка',
                              prefixText: '#',
                              isDense: true,
                              suffixIcon: IconButton(
                                onPressed: _addTag,
                                tooltip: 'Добавить',
                                icon: const Icon(Icons.check),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RichNoteEditingController extends TextEditingController {
  RichNoteEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant.withAlpha(140);
    final defaultStyle =
        style ?? theme.textTheme.bodyLarge ?? const TextStyle();

    if (text.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }

    final lines = text.split('\n');
    final lineSpans = <TextSpan>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLastLine = i == lines.length - 1;
      final lineSuffix = isLastLine ? '' : '\n';

      // 1. Completed checkbox: starts with "☑ " or "- [x] " or "- [X] "
      if (line.startsWith('☑ ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        final prefixLength = line.startsWith('☑ ') ? 2 : 6;
        final prefix = line.substring(0, prefixLength);
        final content = line.substring(prefixLength);

        lineSpans.add(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: defaultStyle.copyWith(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '$content$lineSuffix',
                style: defaultStyle.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: muted,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      // 2. Uncompleted checkbox: starts with "☐ " or "- [ ] "
      if (line.startsWith('☐ ') || line.startsWith('- [ ] ')) {
        final prefixLength = line.startsWith('☐ ') ? 2 : 6;
        final prefix = line.substring(0, prefixLength);
        final content = line.substring(prefixLength);

        lineSpans.add(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: defaultStyle.copyWith(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildContentWithTagHighlights(
                '$content$lineSuffix',
                defaultStyle,
                primary,
              ),
            ],
          ),
        );
        continue;
      }

      // 3. Headings: "# ", "## ", "### "
      if (line.startsWith('# ') ||
          line.startsWith('## ') ||
          line.startsWith('### ')) {
        final hashCount = line.indexOf(' ') + 1;
        final prefix = line.substring(0, hashCount);
        final content = line.substring(hashCount);
        final factor = hashCount == 2 ? 1.25 : (hashCount == 3 ? 1.15 : 1.05);

        lineSpans.add(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: defaultStyle.copyWith(
                  color: primary.withAlpha(120),
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: '$content$lineSuffix',
                style: defaultStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (defaultStyle.fontSize ?? 16) * factor,
                ),
              ),
            ],
          ),
        );
        continue;
      }

      // 4. Numbered list: "1. ", "2. ", etc.
      final numMatch = RegExp(r'^(\s*\d+\.\s*)(.*)$').firstMatch(line);
      if (numMatch != null) {
        final prefix = numMatch.group(1)!;
        final content = numMatch.group(2)!;
        lineSpans.add(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: defaultStyle.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildContentWithTagHighlights(
                '$content$lineSuffix',
                defaultStyle,
                primary,
              ),
            ],
          ),
        );
        continue;
      }

      // 5. Bullet list: "- ", "* ", "• "
      final bulletMatch = RegExp(r'^(\s*[-*•]\s*)(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final prefix = bulletMatch.group(1)!;
        final content = bulletMatch.group(2)!;
        lineSpans.add(
          TextSpan(
            children: [
              TextSpan(
                text: prefix,
                style: defaultStyle.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildContentWithTagHighlights(
                '$content$lineSuffix',
                defaultStyle,
                primary,
              ),
            ],
          ),
        );
        continue;
      }

      // Standard line: highlight hashtags
      lineSpans.add(
        _buildContentWithTagHighlights(
          '$line$lineSuffix',
          defaultStyle,
          primary,
        ),
      );
    }

    return TextSpan(children: lineSpans);
  }

  TextSpan _buildContentWithTagHighlights(
    String content,
    TextStyle defaultStyle,
    Color primaryColor,
  ) {
    final tagRegex = RegExp(
      r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)',
      unicode: true,
    );
    final matches = tagRegex.allMatches(content).toList();
    if (matches.isEmpty) {
      return TextSpan(text: content, style: defaultStyle);
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: defaultStyle,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: defaultStyle.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < content.length) {
      spans.add(
        TextSpan(text: content.substring(lastIndex), style: defaultStyle),
      );
    }
    return TextSpan(children: spans);
  }
}

class SmartListInputFormatter extends TextInputFormatter {
  const SmartListInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length != oldValue.text.length + 1) {
      return newValue;
    }
    final insertionIndex = newValue.selection.baseOffset - 1;
    if (insertionIndex < 0 ||
        insertionIndex >= newValue.text.length ||
        newValue.text[insertionIndex] != '\n') {
      return newValue;
    }

    final textBeforeNewline = newValue.text.substring(0, insertionIndex);
    final lastLineBreak = textBeforeNewline.lastIndexOf('\n');
    final line = lastLineBreak == -1
        ? textBeforeNewline
        : textBeforeNewline.substring(lastLineBreak + 1);

    // Unicode Checklist: "☐ " or "☑ "
    final unicodeChecklist = RegExp(r'^(\s*)([☐☑])\s*(.*)$').firstMatch(line);
    if (unicodeChecklist != null) {
      final indent = unicodeChecklist.group(1) ?? '';
      final content = unicodeChecklist.group(3) ?? '';
      if (content.trim().isEmpty) {
        final lineStartIndex = lastLineBreak == -1 ? 0 : lastLineBreak + 1;
        final newText =
            newValue.text.substring(0, lineStartIndex) +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = lineStartIndex;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      } else {
        final prefix = '$indent☐ ';
        final newText =
            newValue.text.substring(0, insertionIndex + 1) +
            prefix +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = insertionIndex + 1 + prefix.length;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      }
    }

    // Markdown Checklist: "- [ ] " or "- [x] "
    final checklistMatch = RegExp(
      r'^(\s*)-\s*\[([ xX])\]\s*(.*)$',
    ).firstMatch(line);
    if (checklistMatch != null) {
      final indent = checklistMatch.group(1) ?? '';
      final content = checklistMatch.group(3) ?? '';
      if (content.trim().isEmpty) {
        final lineStartIndex = lastLineBreak == -1 ? 0 : lastLineBreak + 1;
        final newText =
            newValue.text.substring(0, lineStartIndex) +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = lineStartIndex;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      } else {
        final prefix = '$indent- [ ] ';
        final newText =
            newValue.text.substring(0, insertionIndex + 1) +
            prefix +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = insertionIndex + 1 + prefix.length;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      }
    }

    // Numbered list: "1. "
    final numberedMatch = RegExp(r'^(\s*)(\d+)\.\s*(.*)$').firstMatch(line);
    if (numberedMatch != null) {
      final indent = numberedMatch.group(1) ?? '';
      final num = int.tryParse(numberedMatch.group(2)!) ?? 1;
      final content = numberedMatch.group(3) ?? '';
      if (content.trim().isEmpty) {
        final lineStartIndex = lastLineBreak == -1 ? 0 : lastLineBreak + 1;
        final newText =
            newValue.text.substring(0, lineStartIndex) +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = lineStartIndex;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      } else {
        final prefix = '$indent${num + 1}. ';
        final newText =
            newValue.text.substring(0, insertionIndex + 1) +
            prefix +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = insertionIndex + 1 + prefix.length;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      }
    }

    // Bullet list: "- " or "* " or "• "
    final bulletMatch = RegExp(r'^(\s*)([-*•])\s*(.*)$').firstMatch(line);
    if (bulletMatch != null) {
      final indent = bulletMatch.group(1) ?? '';
      final bullet = bulletMatch.group(2) ?? '-';
      final content = bulletMatch.group(3) ?? '';
      if (content.trim().isEmpty) {
        final lineStartIndex = lastLineBreak == -1 ? 0 : lastLineBreak + 1;
        final newText =
            newValue.text.substring(0, lineStartIndex) +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = lineStartIndex;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      } else {
        final prefix = '$indent$bullet ';
        final newText =
            newValue.text.substring(0, insertionIndex + 1) +
            prefix +
            newValue.text.substring(insertionIndex + 1);
        final newOffset = insertionIndex + 1 + prefix.length;
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newOffset),
        );
      }
    }

    return newValue;
  }
}
