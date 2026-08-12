import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/entries/domain/entry.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.repository,
    this.entry,
    this.onActivity,
  });

  final EntryRepository repository;
  final Entry? entry;
  final VoidCallback? onActivity;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _tagController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();
  Timer? _saveTimer;
  Entry? _entry;
  bool _changed = false;
  bool _closing = false;
  bool _addingTag = false;
  late final Set<String> _tags;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _titleController = TextEditingController(text: _entry?.title ?? '');
    _bodyController = TextEditingController(text: _entry?.body ?? '');
    _tags = {...?_entry?.tags};
    _tagFocusNode.addListener(() {
      if (!_tagFocusNode.hasFocus && _tagController.text.trim().isNotEmpty) {
        _addTag();
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    widget.onActivity?.call();
    _changed = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveNow);
  }

  void _saveNow() {
    _saveTimer?.cancel();
    _commitPendingTag();
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    final content = body.isEmpty ? title : '$title\n$body';
    if (_entry == null) {
      if (content.isEmpty) {
        return;
      }
      _entry = widget.repository.create(content, tags: _tags);
    } else {
      _entry = widget.repository.update(
        id: _entry!.id,
        content: content,
        tags: _tags,
      );
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

  @override
  Widget build(BuildContext context) {
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
                  autofocus: true,
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
                  onChanged: (_) => _scheduleSave(),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                    hintText: 'Начните писать…',
                  ),
                ),
              ),
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
                      if (_addingTag)
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
                              hintText: 'Название метки',
                              prefixText: '#',
                              isDense: true,
                              suffixIcon: IconButton(
                                onPressed: _addTag,
                                tooltip: 'Добавить',
                                icon: const Icon(Icons.check),
                              ),
                            ),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _showTagInput,
                          icon: const Icon(Icons.tag),
                          label: const Text('Добавить метку…'),
                        ),
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
