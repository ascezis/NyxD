import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_saver/flutter_file_saver.dart';
import 'package:nyxd/app/theme/theme_controller.dart';
import 'package:nyxd/app/theme/theme_settings_dialog.dart';
import 'package:nyxd/core/security/external_activity_scope.dart';
import 'package:nyxd/core/vault/vault_service.dart';
import 'package:nyxd/features/entries/data/entry_repository.dart';
import 'package:nyxd/features/entries/domain/entry.dart';
import 'package:nyxd/features/entries/presentation/editor_screen.dart';

enum EntryView { all, trash, untagged, tag }

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.onLock,
    this.vault,
    this.onRestored,
    this.externalActivity,
    this.onActivity,
    this.settings,
  });

  final EntryRepository repository;
  final VoidCallback onLock;
  final VaultService? vault;
  final VoidCallback? onRestored;
  final ExternalActivityController? externalActivity;
  final VoidCallback? onActivity;
  final ThemeController? settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  EntryView _view = EntryView.all;
  String? _selectedTag;
  String _searchQuery = '';
  bool _searching = false;
  final Set<int> _selectedEntryIds = <int>{};

  Future<T> _runExternal<T>(Future<T> Function() action) {
    final controller = widget.externalActivity;
    return controller == null ? action() : controller.run(action);
  }

  String get _title => switch (_view) {
    EntryView.all => 'Все заметки',
    EntryView.trash => 'Корзина',
    EntryView.untagged => 'Заметки без меток',
    EntryView.tag => '#$_selectedTag',
  };

  List<Entry> get _entries {
    if (widget.vault != null && widget.vault!.status != VaultStatus.unlocked) {
      return const [];
    }
    try {
      if (_view == EntryView.trash) {
        return widget.repository.listTrash();
      }
      final entries = switch (_view) {
        EntryView.all => widget.repository.listActive(),
        EntryView.untagged => widget.repository.withoutTags(),
        EntryView.tag => widget.repository.withTag(_selectedTag!),
        EntryView.trash => widget.repository.listTrash(),
      };
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) {
        return entries;
      }
      return entries
          .where((entry) => entry.content.toLowerCase().contains(query))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<String> get _tags {
    if (widget.vault != null && widget.vault!.status != VaultStatus.unlocked) {
      return const [];
    }
    try {
      return widget.repository.listTags();
    } catch (_) {
      return const [];
    }
  }

  void _selectView(EntryView view, {String? tag}) {
    Navigator.pop(context);
    setState(() {
      _view = view;
      _selectedTag = tag;
      _searchQuery = '';
      _searching = false;
      _selectedEntryIds.clear();
    });
  }

  Future<void> _openEditor([Entry? entry]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          repository: widget.repository,
          entry: entry,
          vault: widget.vault,
          onActivity: widget.onActivity,
        ),
      ),
    );
    if (mounted) {
      setState(() => _selectedEntryIds.clear());
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedEntryIds.contains(id)) {
        _selectedEntryIds.remove(id);
      } else {
        _selectedEntryIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<Entry> entries) {
    setState(() {
      if (_selectedEntryIds.length == entries.length) {
        _selectedEntryIds.clear();
      } else {
        _selectedEntryIds
          ..clear()
          ..addAll(entries.map((e) => e.id));
      }
    });
  }

  void _deleteSelected() {
    for (final id in _selectedEntryIds.toList()) {
      if (_view == EntryView.trash) {
        widget.repository.deletePermanently(id);
      } else {
        widget.repository.moveToTrash(id);
      }
    }
    setState(() => _selectedEntryIds.clear());
  }

  void _togglePinnedSelected(List<Entry> entries) {
    final selectedEntries = entries
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
    final allPinned = selectedEntries.every((e) => e.isPinned);
    for (final entry in selectedEntries) {
      if (entry.isPinned == allPinned) {
        widget.repository.togglePinned(entry.id);
      }
    }
    setState(() => _selectedEntryIds.clear());
  }

  void _restore(Entry entry) {
    widget.repository.restore(entry.id);
    setState(() {});
  }

  void _deletePermanently(Entry entry) {
    widget.repository.deletePermanently(entry.id);
    setState(() {});
  }

  Future<void> _exportBackup() async {
    final vault = widget.vault;
    if (vault == null) return;
    final bytes = vault.createBackup();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final fileName = 'nyxd-$date.nyxd';
    await _runExternal(
      () =>
          FlutterFileSaver().writeFileAsBytes(bytes: bytes, fileName: fileName),
    );
    if (mounted) _showMessage('Резервная копия сохранена.');
  }

  Future<void> _restoreBackup() async {
    final vault = widget.vault;
    if (vault == null) return;
    final result = await _runExternal(
      () => openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'NyxD Backup', extensions: ['nyxd']),
        ],
      ),
    );
    if (result == null) return;
    final bytes = await result.readAsBytes();
    final password = await _askPassword('Введите пароль резервной копии');
    if (password == null) return;
    try {
      await vault.restoreBackup(bytes, password);
      widget.onRestored?.call();
      if (mounted) {
        setState(() {});
        _showMessage('Резервная копия восстановлена.');
      }
    } on Object {
      if (mounted) _showMessage('Не удалось восстановить копию.');
    }
  }

  Future<String?> _askPassword(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Пароль'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportMarkdown(Entry entry) async {
    final markdown = '# ${entry.title}\n\n${entry.body}';
    final fileName = '${entry.title.isEmpty ? 'note' : entry.title}.md';
    await _runExternal(
      () => FlutterFileSaver().writeFileAsBytes(
        bytes: Uint8List.fromList(utf8.encode(markdown)),
        fileName: fileName,
      ),
    );
    if (mounted) _showMessage('Заметка экспортирована.');
  }

  Future<void> _importMarkdown() async {
    final result = await _runExternal(
      () => openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Markdown', extensions: ['md', 'markdown', 'txt']),
        ],
      ),
    );
    if (result == null) return;
    final bytes = await result.readAsBytes();
    final text = utf8
        .decode(bytes, allowMalformed: false)
        .replaceAll('\r\n', '\n');
    final lines = text.split('\n');
    final title = lines.isEmpty
        ? 'Импортированная заметка'
        : lines.first.replaceFirst(RegExp(r'^#\s*'), '').trim();
    final body = lines.skip(1).join('\n').trimLeft();
    widget.repository.create(
      '${title.isEmpty ? 'Импортированная заметка' : title}\n$body',
    );
    if (mounted) setState(() {});
    _showMessage('Заметка импортирована.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDataActions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Создать резервную копию'),
              onTap: () {
                Navigator.pop(context);
                _exportBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Восстановить резервную копию'),
              onTap: () {
                Navigator.pop(context);
                _restoreBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Импортировать Markdown'),
              onTap: () {
                Navigator.pop(context);
                _importMarkdown();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить корзину?'),
        content: const Text(
          'Все заметки в корзине будут удалены без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      widget.repository.emptyTrash();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final isSelectionMode = _selectedEntryIds.isNotEmpty;
    final selectedEntries = entries
        .where((entry) => _selectedEntryIds.contains(entry.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                onPressed: () => setState(() => _selectedEntryIds.clear()),
                icon: const Icon(Icons.close),
                tooltip: 'Отменить выбор',
              )
            : null,
        title: isSelectionMode
            ? Text(
                'Выбрано: ${_selectedEntryIds.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Поиск',
                ),
                onChanged: (value) {
                  widget.onActivity?.call();
                  setState(() => _searchQuery = value);
                },
              )
            : Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              onPressed: () => _toggleSelectAll(entries),
              tooltip: _selectedEntryIds.length == entries.length
                  ? 'Снять выделение'
                  : 'Выбрать все',
              icon: Icon(
                _selectedEntryIds.length == entries.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
            ),
            if (_view != EntryView.trash)
              IconButton(
                onPressed: () => _togglePinnedSelected(entries),
                tooltip: 'Закрепить/открепить',
                icon: const Icon(Icons.push_pin_outlined),
              ),
            if (selectedEntries.length == 1 && _view != EntryView.trash)
              IconButton(
                onPressed: () => _exportMarkdown(selectedEntries.first),
                tooltip: 'Экспортировать Markdown',
                icon: const Icon(Icons.ios_share_outlined),
              ),
            IconButton(
              onPressed: _deleteSelected,
              tooltip: _view == EntryView.trash
                  ? 'Удалить навсегда'
                  : 'В корзину',
              icon: Icon(
                _view == EntryView.trash
                    ? Icons.delete_forever_outlined
                    : Icons.delete_outline,
              ),
            ),
          ],
          if (!isSelectionMode && _view != EntryView.trash)
            IconButton(
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchQuery = '';
                }
              }),
              tooltip: _searching ? 'Закрыть поиск' : 'Поиск',
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
          if (!isSelectionMode &&
              _view == EntryView.trash &&
              entries.isNotEmpty)
            IconButton(
              onPressed: _confirmEmptyTrash,
              tooltip: 'Очистить корзину',
              icon: const Icon(Icons.delete_forever_outlined),
            ),
        ],
      ),
      drawer: _NavigationDrawer(
        selectedView: _view,
        selectedTag: _selectedTag,
        tags: _tags,
        onSelect: _selectView,
        onLock: widget.onLock,
        onData: _showDataActions,
        settings: widget.settings,
      ),
      body: entries.isEmpty
          ? _EmptyState(view: _view, searching: _searchQuery.isNotEmpty)
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final isSelected = _selectedEntryIds.contains(entry.id);
                return _EntryTile(
                  entry: entry,
                  inTrash: _view == EntryView.trash,
                  selectionMode: isSelectionMode,
                  selected: isSelected,
                  onTap: () {
                    if (isSelectionMode) {
                      _toggleSelection(entry.id);
                    } else {
                      _openEditor(entry);
                    }
                  },
                  onLongPress: () => _toggleSelection(entry.id),
                  onRestore: () => _restore(entry),
                  onDelete: () => _deletePermanently(entry),
                );
              },
            ),
      floatingActionButton: _view == EntryView.trash || isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(),
              tooltip: 'Новая заметка',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.inTrash,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRestore,
    required this.onDelete,
  });

  final Entry entry;
  final bool inTrash;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.isEmpty ? 'Без названия' : entry.title;
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withAlpha(120),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      onTap: inTrash ? null : onTap,
      onLongPress: inTrash ? null : onLongPress,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      leading: selectionMode
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 22,
            )
          : entry.isPinned
          ? const Icon(Icons.push_pin, size: 20)
          : null,
      trailing: inTrash
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') onRestore();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'restore', child: Text('Восстановить')),
                PopupMenuItem(value: 'delete', child: Text('Удалить навсегда')),
              ],
            )
          : (selectionMode && entry.isPinned)
          ? const Icon(Icons.push_pin, size: 18)
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.view, required this.searching});

  final EntryView view;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final text = searching
        ? 'Ничего не найдено'
        : view == EntryView.trash
        ? 'Корзина пуста'
        : 'Заметок пока нет';
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.selectedView,
    required this.selectedTag,
    required this.tags,
    required this.onSelect,
    required this.onLock,
    required this.onData,
    required this.settings,
  });

  final EntryView selectedView;
  final String? selectedTag;
  final List<String> tags;
  final void Function(EntryView view, {String? tag}) onSelect;
  final VoidCallback onLock;
  final VoidCallback onData;
  final ThemeController? settings;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            _DrawerTile(
              icon: Icons.library_books_outlined,
              title: 'Все заметки',
              selected: selectedView == EntryView.all,
              onTap: () => onSelect(EntryView.all),
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              title: 'Настройки',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                showDialog<void>(
                  context: context,
                  builder: (context) =>
                      ThemeSettingsDialog(controller: settings!),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.delete_outline,
              title: 'Корзина',
              selected: selectedView == EntryView.trash,
              onTap: () => onSelect(EntryView.trash),
            ),
            _DrawerTile(
              icon: Icons.import_export,
              title: 'Данные и резервные копии',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                onData();
              },
            ),
            _DrawerTile(
              icon: Icons.lock_outline,
              title: 'Заблокировать',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                onLock();
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Метки',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final tag in tags)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                title: Text('#$tag'),
                selected: selectedView == EntryView.tag && selectedTag == tag,
                onTap: () => onSelect(EntryView.tag, tag: tag),
              ),
            const Divider(height: 32),
            _DrawerTile(
              icon: Icons.label_off_outlined,
              title: 'Заметки без меток',
              selected: selectedView == EntryView.untagged,
              onTap: () => onSelect(EntryView.untagged),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
