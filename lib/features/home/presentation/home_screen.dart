import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nyxd/app/theme/theme_controller.dart';
import 'package:nyxd/app/theme/theme_settings_dialog.dart';
import 'package:nyxd/core/platform/file_export.dart';
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

  static const double _wideBreakpoint = 1040;
  static const double _sidebarWidth = 256;
  static const double _railWidth = 64;
  static const double _listPaneWidth = 360;

  final _searchFocusNode = FocusNode();
  bool _sidebarExpanded = false;
  bool _editorOpen = false;
  Entry? _editorEntry;
  int _editorToken = 0;
  int? _openEntryId;

  /// Desktop-style layout: sidebar, note list and editor side by side.
  bool get _wide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    widget.onActivity?.call();
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    final vault = widget.vault;
    if (vault != null && vault.status != VaultStatus.unlocked) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyN) {
      if (_view != EntryView.trash) _openEditor();
      return true;
    }
    if (key == LogicalKeyboardKey.keyF) {
      if (_view != EntryView.trash) _startSearch();
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      widget.onLock();
      return true;
    }
    return false;
  }

  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeEditorPane() {
    _editorOpen = false;
    _editorEntry = null;
    _openEntryId = null;
  }

  void _onEditorSaved(int token, Entry entry) {
    // Saves also happen while the editor is being disposed, so the list is
    // refreshed outside of the current frame.
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        if (token == _editorToken && _editorOpen) _openEntryId = entry.id;
      });
    });
  }

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
    setState(() {
      _closeEditorPane();
      _view = view;
      _selectedTag = tag;
      _searchQuery = '';
      _searching = false;
      _selectedEntryIds.clear();
    });
  }

  Future<void> _openEditor([Entry? entry]) async {
    if (_wide) {
      setState(() {
        _editorToken++;
        _editorOpen = true;
        _editorEntry = entry;
        _openEntryId = entry?.id;
        _selectedEntryIds.clear();
      });
      return;
    }
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
    setState(() {
      if (_openEntryId != null && _selectedEntryIds.contains(_openEntryId)) {
        _closeEditorPane();
      }
      _selectedEntryIds.clear();
    });
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
    final saved = await _runExternal(
      () => saveBytesToFile(
        bytes: bytes,
        fileName: fileName,
        typeLabel: 'NyxD Backup',
        extensions: const ['nyxd'],
      ),
    );
    if (mounted && saved) _showMessage('Резервная копия сохранена.');
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
    final fileName = '${sanitizeFileName(entry.title)}.md';
    final saved = await _runExternal(
      () => saveBytesToFile(
        bytes: Uint8List.fromList(utf8.encode(markdown)),
        fileName: fileName,
        typeLabel: 'Markdown',
        extensions: const ['md'],
      ),
    );
    if (mounted && saved) _showMessage('Заметка экспортирована.');
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

  void _seedDemoData() {
    final note1 = widget.repository.create(
      'Добро пожаловать в NyxD\n\n'
      'Ваш личный оффлайн-дневник с нулевым разглашением. Все данные шифруются алгоритмом SQLCipher (AES-256) с деривацией ключа Argon2id.\n\n'
      '# Особенности\n'
      '☑ Локальное сквозное шифрование\n'
      '☑ Форматирование списков и чекбоксов\n'
      '☑ Автоматическая блокировка при выходе\n'
      '☐ Настроить регулярный экспорт копий\n\n'
      '#nyxd #безопасность',
    );
    widget.repository.togglePinned(note1.id);

    widget.repository.create(
      'Список задач и планов\n\n'
      '☐ Протестировать ночной режим оформления\n'
      '☑ Проверить создание резервной копии\n'
      '☑ Настроить теги для каталогизации\n'
      '☐ Записать ключевые мысли за неделю\n\n'
      '#планы #продуктивность',
    );

    widget.repository.create(
      'Любимые книги и цитаты\n\n'
      '«Простота — необходимое условие прекрасного.»\n'
      '— Лев Толстой\n\n'
      '1. «Чистый код» — Роберт Мартин\n'
      '2. «Человек в поисках смысла» — Виктор Франкл\n'
      '3. «Антихрупкость» — Нассим Талеб\n\n'
      '#книги #мысли',
    );

    widget.repository.create(
      'Идеи для будущих обновлений\n\n'
      'Мысли по поводу дальнейшего развития дневника:\n\n'
      '- Поддержка биометрии для быстрого входа\n'
      '- Быстрый экспорт выбранной заметки\n'
      '- Счётчик слов и знаков в редакторе\n\n'
      '#идеи #разработка',
    );

    if (mounted) {
      setState(() {});
      _showMessage('Демо-заметки успешно созданы.');
    }
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
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Сгенерировать демо-заметки'),
              subtitle: const Text('Примеры для скриншотов и обзора'),
              onTap: () {
                Navigator.pop(context);
                _seedDemoData();
              },
            ),
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

  NavigationPanel _navigation({required bool permanent}) => NavigationPanel(
    selectedView: _view,
    selectedTag: _selectedTag,
    tags: _tags,
    onSelect: _selectView,
    onLock: widget.onLock,
    onData: _showDataActions,
    settings: widget.settings,
    permanent: permanent,
    collapsed: permanent && !_sidebarExpanded,
    onToggle: permanent
        ? () => setState(() => _sidebarExpanded = !_sidebarExpanded)
        : null,
  );

  Widget _buildEditorPane(BuildContext context) {
    if (!_editorOpen) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Text(
            'Выберите заметку или нажмите Ctrl+N',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final token = _editorToken;
    return EditorScreen(
      key: ValueKey<int>(token),
      repository: widget.repository,
      entry: _editorEntry,
      vault: widget.vault,
      onActivity: widget.onActivity,
      embedded: true,
      onClose: () => setState(_closeEditorPane),
      onSaved: (entry) => _onEditorSaved(token, entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = _wide;
    if (!wide && _editorOpen) {
      // The split view is gone; the editor saved itself when it was removed.
      _closeEditorPane();
    }
    final list = _buildListScaffold(context, wide: wide);
    if (!wide) return list;
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
    );
    return Scaffold(
      floatingActionButton:
          _view == EntryView.trash || _selectedEntryIds.isNotEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(),
              tooltip: 'Новая заметка (Ctrl+N)',
              child: const Icon(Icons.add),
            ),
      body: Row(
        children: [
          SizedBox(
            width: _sidebarExpanded ? _sidebarWidth : _railWidth,
            child: _navigation(permanent: true),
          ),
          divider,
          SizedBox(width: _listPaneWidth, child: list),
          divider,
          Expanded(child: _buildEditorPane(context)),
        ],
      ),
    );
  }

  Widget _buildListScaffold(BuildContext context, {required bool wide}) {
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
                focusNode: _searchFocusNode,
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
              onPressed: () {
                if (_searching) {
                  setState(() {
                    _searching = false;
                    _searchQuery = '';
                  });
                } else {
                  _startSearch();
                }
              },
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
      drawer: wide ? null : _navigation(permanent: false),
      body: entries.isEmpty
          ? _EmptyState(
              view: _view,
              searching: _searchQuery.isNotEmpty,
              onSeedDemo: _view == EntryView.all ? _seedDemoData : null,
            )
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
                  active: wide && entry.id == _openEntryId,
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
      floatingActionButton: wide || _view == EntryView.trash || isSelectionMode
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
    this.active = false,
  });

  final Entry entry;
  final bool inTrash;
  final bool selectionMode;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = entry.title.isEmpty ? 'Без названия' : entry.title;
    final theme = Theme.of(context);
    return ListTile(
      selected: selected || active,
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
  const _EmptyState({
    required this.view,
    required this.searching,
    this.onSeedDemo,
  });

  final EntryView view;
  final bool searching;
  final VoidCallback? onSeedDemo;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    if (view == EntryView.trash) {
      return Center(
        child: Text(
          'Корзина пуста',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Заметок пока нет',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (onSeedDemo != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onSeedDemo,
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Заполнить примерами'),
            ),
          ],
        ],
      ),
    );
  }
}

class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.selectedView,
    required this.selectedTag,
    required this.tags,
    required this.onSelect,
    required this.onLock,
    required this.onData,
    required this.settings,
    this.permanent = false,
    this.collapsed = false,
    this.onToggle,
  });

  final EntryView selectedView;
  final String? selectedTag;
  final List<String> tags;
  final void Function(EntryView view, {String? tag}) onSelect;
  final VoidCallback onLock;
  final VoidCallback onData;
  final ThemeController? settings;

  /// Shown as a fixed sidebar (desktop) instead of a modal drawer.
  final bool permanent;

  /// Icon-only rail (desktop). Only used together with [permanent].
  final bool collapsed;

  /// Expands or collapses the sidebar (desktop).
  final VoidCallback? onToggle;

  void _openSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => ThemeSettingsDialog(controller: settings!),
    );
  }

  Widget _railButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: selected
          ? IconButton.filledTonal(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon),
            )
          : IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: Icon(icon),
            ),
    );
  }

  Widget _buildRail(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _railButton(
              icon: Icons.menu,
              tooltip: 'Развернуть меню',
              onPressed: onToggle ?? () {},
            ),
            const SizedBox(height: 8),
            _railButton(
              icon: Icons.library_books_outlined,
              tooltip: 'Все заметки',
              selected: selectedView == EntryView.all,
              onPressed: () => onSelect(EntryView.all),
            ),
            _railButton(
              icon: Icons.tag,
              tooltip: 'Метки',
              selected: selectedView == EntryView.tag,
              onPressed: onToggle ?? () {},
            ),
            _railButton(
              icon: Icons.label_off_outlined,
              tooltip: 'Заметки без меток',
              selected: selectedView == EntryView.untagged,
              onPressed: () => onSelect(EntryView.untagged),
            ),
            _railButton(
              icon: Icons.delete_outline,
              tooltip: 'Корзина',
              selected: selectedView == EntryView.trash,
              onPressed: () => onSelect(EntryView.trash),
            ),
            const Spacer(),
            _railButton(
              icon: Icons.import_export,
              tooltip: 'Данные и резервные копии',
              onPressed: onData,
            ),
            _railButton(
              icon: Icons.settings_outlined,
              tooltip: 'Настройки',
              onPressed: () => _openSettings(context),
            ),
            _railButton(
              icon: Icons.lock_outline,
              tooltip: 'Заблокировать (Ctrl+L)',
              onPressed: onLock,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _dismiss(BuildContext context) {
    if (!permanent) Navigator.pop(context);
  }

  void _select(BuildContext context, EntryView view, {String? tag}) {
    _dismiss(context);
    onSelect(view, tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    if (permanent && collapsed) return _buildRail(context);
    final content = SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (permanent && onToggle != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: IconButton(
                  onPressed: onToggle,
                  tooltip: 'Свернуть меню',
                  icon: const Icon(Icons.menu_open),
                ),
              ),
            ),
          _DrawerTile(
            icon: Icons.library_books_outlined,
            title: 'Все заметки',
            selected: selectedView == EntryView.all,
            onTap: () => _select(context, EntryView.all),
          ),
          _DrawerTile(
            icon: Icons.settings_outlined,
            title: 'Настройки',
            selected: false,
            onTap: () {
              _dismiss(context);
              _openSettings(context);
            },
          ),
          _DrawerTile(
            icon: Icons.delete_outline,
            title: 'Корзина',
            selected: selectedView == EntryView.trash,
            onTap: () => _select(context, EntryView.trash),
          ),
          _DrawerTile(
            icon: Icons.import_export,
            title: 'Данные и резервные копии',
            selected: false,
            onTap: () {
              _dismiss(context);
              onData();
            },
          ),
          _DrawerTile(
            icon: Icons.lock_outline,
            title: 'Заблокировать',
            selected: false,
            onTap: () {
              _dismiss(context);
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
              onTap: () => _select(context, EntryView.tag, tag: tag),
            ),
          const Divider(height: 32),
          _DrawerTile(
            icon: Icons.label_off_outlined,
            title: 'Заметки без меток',
            selected: selectedView == EntryView.untagged,
            onTap: () => _select(context, EntryView.untagged),
          ),
        ],
      ),
    );
    if (permanent) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: content,
      );
    }
    return Drawer(child: content);
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
