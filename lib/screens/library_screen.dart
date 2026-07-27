import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/library_entry.dart';
import '../services/library_service.dart';
import 'library_detail_screen.dart';

enum LibrarySort { newest, oldest, nameAscending, nameDescending, type }

class _LibraryItem {
  const _LibraryItem.entry(this.entry) : folder = null;
  const _LibraryItem.folder(this.folder) : entry = null;

  final LibraryEntry? entry;
  final String? folder;

  bool get isFolder => folder != null;

  String get name =>
      entry?.displayName ?? p.basename(folder!);
}

class LibraryScreen extends StatefulWidget {
  final LibraryService libraryService;
  const LibraryScreen({super.key, required this.libraryService});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryEntry> _entries = [];
  List<String> _folders = [];
  String _currentFolder = '';
  String _query = '';
  LibrarySort _sort = LibrarySort.newest;
  bool _loading = false;
  int _refreshGeneration = 0;
  _LibraryItem? _selectedItem;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.libraryService.addListener(_handleLibraryChanged);
    _refresh();
  }

  void _handleLibraryChanged() {
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final generation = ++_refreshGeneration;
    if (!widget.libraryService.isConfigured) {
      setState(() {
        _folders = [];
        _entries = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final folders = await widget.libraryService.listFolders(
      parentFolder: _currentFolder,
    );
    final entries = await widget.libraryService.listEntries(
      folder: _currentFolder,
      recursive: true,
    );
    if (!mounted || generation != _refreshGeneration) return;
    setState(() {
      _folders = folders;
      _entries = entries;
      _loading = false;
    });
  }

  @override
  void dispose() {
    widget.libraryService.removeListener(_handleLibraryChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setupFolder() async {
    final ok = await widget.libraryService.requestPermissionAndPickFolder();
    if (!mounted || !ok) return;
    setState(() => _currentFolder = '');
    await _refresh();
  }

  Future<void> _newFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NewFolderDialog(
        parentName:
            _currentFolder.isEmpty ? null : p.basename(_currentFolder),
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.libraryService.createFolder(
        name,
        parentFolder: _currentFolder,
      );
    } on LibraryFolderExistsException {
      _showError('A folder with that name already exists here.');
    } on ArgumentError {
      _showError('Choose a valid folder name.');
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear entire library?'),
        content: const Text(
          'This permanently deletes every saved item and folder from disk. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.libraryService.deleteAll();
      if (!mounted) return;
      setState(() => _currentFolder = '');
      await _refresh();
    }
  }

  Future<void> _deleteEntry(LibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved item?'),
        content: Text(
          '"${entry.preview}" will be permanently deleted from disk.',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.libraryService.deleteEntry(entry);
      _clearSelection();
    }
  }

  Future<void> _deleteFolder(String folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${p.basename(folder)}?'),
        content: const Text(
          'This permanently deletes the folder and everything inside it from '
          'disk. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.libraryService.deleteFolder(folder);
      _clearSelection();
    }
  }

  Future<void> _renameEntry(LibraryEntry entry) async {
    final filename = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(
        title: 'Rename file',
        initialValue: entry.displayName,
        hintText: 'Filename',
      ),
    );
    if (filename == null) return;
    try {
      await widget.libraryService.renameEntry(entry, filename);
      _clearSelection();
    } on LibraryFileExistsException {
      _showError('A file with that name already exists in this folder.');
    } on ArgumentError {
      _showError('Choose a valid filename.');
    }
  }

  Future<void> _moveEntry(LibraryEntry entry) async {
    final destination = await _chooseMoveDestination(
      title: 'Move ${entry.displayName}',
      currentFolder: entry.folder,
    );
    if (destination == null) return;
    try {
      await widget.libraryService.moveEntry(entry, destination);
      _clearSelection();
    } on LibraryFileExistsException {
      _showError('A file with that name already exists in that folder.');
    } on ArgumentError {
      _showError('Choose a valid destination folder.');
    }
  }

  Future<void> _renameFolder(String folder) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(
        title: 'Rename folder',
        initialValue: p.basename(folder),
        hintText: 'Folder name',
      ),
    );
    if (name == null) return;
    try {
      await widget.libraryService.renameFolder(folder, name);
      _clearSelection();
    } on LibraryFolderExistsException {
      _showError('A folder with that name already exists here.');
    } on ArgumentError {
      _showError('Choose a valid folder name.');
    }
  }

  Future<void> _moveFolder(String folder) async {
    final destination = await _chooseMoveDestination(
      title: 'Move ${p.basename(folder)}',
      currentFolder: p.dirname(folder) == '.' ? '' : p.dirname(folder),
      excludedFolder: folder,
    );
    if (destination == null) return;
    try {
      await widget.libraryService.moveFolder(folder, destination);
      _clearSelection();
    } on LibraryFolderExistsException {
      _showError('A folder with that name already exists there.');
    } on ArgumentError {
      _showError('A folder cannot be moved inside itself.');
    }
  }

  Future<String?> _chooseMoveDestination({
    required String title,
    required String currentFolder,
    String? excludedFolder,
  }) async {
    final allFolders = await widget.libraryService.listAllFolders();
    if (!mounted) return null;
    final destinations = <String>[
      '',
      ...allFolders.where(
        (folder) =>
            excludedFolder == null ||
            (folder != excludedFolder && !p.isWithin(excludedFolder, folder)),
      ),
    ];
    return showDialog<String>(
      context: context,
      builder: (context) => _MoveDialog(
        title: title,
        folders: destinations,
        initialFolder: currentFolder,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _selectItem(_LibraryItem item) {
    setState(() => _selectedItem = item);
  }

  void _clearSelection() {
    if (!mounted || _selectedItem == null) return;
    setState(() => _selectedItem = null);
  }

  bool _isSelected(_LibraryItem item) {
    final selected = _selectedItem;
    if (selected == null || selected.isFolder != item.isFolder) return false;
    return item.isFolder
        ? selected.folder == item.folder
        : selected.entry?.filePath == item.entry?.filePath;
  }

  String _parentFolder(String folder) {
    final parent = p.dirname(folder);
    return parent == '.' ? '' : parent;
  }

  bool _canDrop(_LibraryItem item, String destinationFolder) {
    if (item.isFolder) {
      final source = item.folder!;
      return destinationFolder != source &&
          !p.isWithin(source, destinationFolder) &&
          _parentFolder(source) != destinationFolder;
    }
    return item.entry!.folder != destinationFolder;
  }

  Future<void> _dropItem(
    _LibraryItem item,
    String destinationFolder,
  ) async {
    if (!_canDrop(item, destinationFolder)) return;
    try {
      if (item.isFolder) {
        await widget.libraryService.moveFolder(
          item.folder!,
          destinationFolder,
        );
      } else {
        await widget.libraryService.moveEntry(
          item.entry!,
          destinationFolder,
        );
      }
      if (!mounted) return;
      _clearSelection();
      _openFolder(destinationFolder);
    } on LibraryFileExistsException {
      _showError('A file with that name already exists in that folder.');
    } on LibraryFolderExistsException {
      _showError('A folder with that name already exists there.');
    } on ArgumentError {
      _showError('That item cannot be moved to this folder.');
    }
  }

  void _openFolder(String folder) {
    setState(() {
      _currentFolder = folder;
      _query = '';
      _selectedItem = null;
      _searchController.clear();
    });
    _refresh();
  }

  void _openBreadcrumb(int segmentCount) {
    final segments = p.split(_currentFolder);
    final destination = segmentCount == 0
        ? ''
        : p.joinAll(segments.take(segmentCount).toList());
    _openFolder(destination);
  }

  void _goUp() {
    if (_currentFolder.isEmpty) return;
    final parent = p.dirname(_currentFolder);
    _openFolder(parent == '.' ? '' : parent);
  }

  List<LibraryEntry> get _visibleEntries {
    final query = _query.trim();
    var list = _entries;
    if (query.isEmpty) {
      list = list.where((entry) => entry.folder == _currentFolder).toList();
    } else {
      list = list.where((entry) => entry.matchesSearch(query)).toList();
    }
    list = [...list];
    list.sort((a, b) {
      switch (_sort) {
        case LibrarySort.newest:
          return b.timestamp.compareTo(a.timestamp);
        case LibrarySort.oldest:
          return a.timestamp.compareTo(b.timestamp);
        case LibrarySort.nameAscending:
          return _name(a).compareTo(_name(b));
        case LibrarySort.nameDescending:
          return _name(b).compareTo(_name(a));
        case LibrarySort.type:
          final typeOrder = a.type.compareTo(b.type);
          return typeOrder != 0 ? typeOrder : _name(a).compareTo(_name(b));
      }
    });
    return list;
  }

  List<String> get _visibleFolders {
    final folders = [..._folders];
    folders.sort(
      (a, b) => p
          .basename(a)
          .toLowerCase()
          .compareTo(p.basename(b).toLowerCase()),
    );
    if (_sort == LibrarySort.nameDescending) {
      return folders.reversed.toList();
    }
    return folders;
  }

  String _name(LibraryEntry entry) => entry.displayName.toLowerCase();

  String _sortLabel(LibrarySort sort) {
    switch (sort) {
      case LibrarySort.newest:
        return 'Newest';
      case LibrarySort.oldest:
        return 'Oldest';
      case LibrarySort.nameAscending:
        return 'Name A–Z';
      case LibrarySort.nameDescending:
        return 'Name Z–A';
      case LibrarySort.type:
        return 'Type';
    }
  }

  Widget _breadcrumbs() {
    final segments = p.split(_currentFolder);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _breadcrumbTarget(
            folder: '',
            child: TextButton.icon(
              onPressed: () => _openBreadcrumb(0),
              icon: const Icon(Icons.home_outlined),
              label: const Text('TowerLens'),
            ),
          ),
          for (var index = 0; index < segments.length; index++) ...[
            const Icon(Icons.chevron_right, size: 18),
            _breadcrumbTarget(
              folder: p.joinAll(segments.take(index + 1).toList()),
              child: TextButton(
                onPressed: () => _openBreadcrumb(index + 1),
                child: Text(segments[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _breadcrumbTarget({
    required String folder,
    required Widget child,
  }) {
    return DragTarget<_LibraryItem>(
      key: ValueKey('breadcrumb-target:$folder'),
      onWillAcceptWithDetails: (details) =>
          _canDrop(details.data, folder),
      onAcceptWithDetails: (details) => _dropItem(details.data, folder),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: highlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        );
      },
    );
  }

  Widget _dragFeedback(_LibraryItem item) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: ListTile(
          dense: true,
          leading: Icon(
            item.isFolder
                ? Icons.folder_outlined
                : Icons.description_outlined,
          ),
          title: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _draggableItem({
    required _LibraryItem item,
    required Widget child,
  }) {
    return LongPressDraggable<_LibraryItem>(
      data: item,
      maxSimultaneousDrags: 1,
      onDragStarted: () => _selectItem(item),
      feedback: _dragFeedback(item),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Widget _folderTile(String folder) {
    final item = _LibraryItem.folder(folder);
    final tile = DragTarget<_LibraryItem>(
      key: ValueKey('folder-target:$folder'),
      onWillAcceptWithDetails: (details) =>
          _canDrop(details.data, folder),
      onAcceptWithDetails: (details) => _dropItem(details.data, folder),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return Material(
          color: highlighted
              ? Theme.of(context).colorScheme.primaryContainer
              : _isSelected(item)
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Colors.transparent,
          child: ListTile(
            key: ValueKey('folder:$folder'),
            leading: Icon(
              _isSelected(item)
                  ? Icons.check_circle
                  : Icons.folder_outlined,
            ),
            title: Text(p.basename(folder)),
            onTap: () {
              if (_selectedItem == null) {
                _openFolder(folder);
              } else if (_isSelected(item)) {
                _clearSelection();
              } else {
                _selectItem(item);
              }
            },
          ),
        );
      },
    );
    return _draggableItem(item: item, child: tile);
  }

  Widget _entryTile(LibraryEntry entry, DateFormat dateFormat) {
    final item = _LibraryItem.entry(entry);
    final tile = Material(
      color: _isSelected(item)
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      child: ListTile(
        key: ValueKey('entry:${entry.filePath}'),
        leading: Icon(
          _isSelected(item)
              ? Icons.check_circle
              : Icons.description_outlined,
        ),
        title: Text(entry.displayName),
        subtitle: Text(
          '${entry.preview}\n${entry.folder} • '
          '${dateFormat.format(entry.timestamp)}',
        ),
        isThreeLine: true,
        onTap: () {
          if (_selectedItem == null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LibraryDetailScreen(entry: entry),
              ),
            );
          } else if (_isSelected(item)) {
            _clearSelection();
          } else {
            _selectItem(item);
          }
        },
      ),
    );
    return _draggableItem(item: item, child: tile);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.libraryService.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Library')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose a folder on your device where Tower Lens will store '
                  'your saved items as real files. This folder is yours -- it '
                  'stays even if you uninstall the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _setupFolder,
                  child: const Text('Choose Library Folder'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final entries = _visibleEntries;
    final showFolders = _query.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedItem?.name ??
              (_currentFolder.isEmpty
                  ? 'Library'
                  : p.basename(_currentFolder)),
        ),
        leading: _selectedItem != null
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Clear selection',
                onPressed: _clearSelection,
              )
            : _currentFolder.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: 'Up one folder',
                    onPressed: _goUp,
                  ),
        actions: _selectedItem != null
            ? [
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  tooltip: 'Rename selected item',
                  onPressed: () {
                    final item = _selectedItem!;
                    if (item.isFolder) {
                      _renameFolder(item.folder!);
                    } else {
                      _renameEntry(item.entry!);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: 'Move selected item',
                  onPressed: () {
                    final item = _selectedItem!;
                    if (item.isFolder) {
                      _moveFolder(item.folder!);
                    } else {
                      _moveEntry(item.entry!);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete selected item',
                  onPressed: () {
                    final item = _selectedItem!;
                    if (item.isFolder) {
                      _deleteFolder(item.folder!);
                    } else {
                      _deleteEntry(item.entry!);
                    }
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: 'New folder',
                  onPressed: _newFolder,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') _clearAll();
                    if (value == 'change') _setupFolder();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'change',
                      child: Text('Change folder location'),
                    ),
                    PopupMenuItem(value: 'clear', child: Text('Clear all')),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _breadcrumbs(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search this folder...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Spacer(),
                DropdownButton<LibrarySort>(
                  value: _sort,
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                  items: LibrarySort.values
                      .map(
                        (sort) => DropdownMenuItem(
                          value: sort,
                          child: Text(_sortLabel(sort)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: (showFolders && _folders.isEmpty && entries.isEmpty) ||
                      (!showFolders && entries.isEmpty)
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Center(child: Text('No items found.')),
                      ],
                    )
                  : ListView(
                      children: [
                        if (showFolders)
                          for (final folder in _visibleFolders)
                            _folderTile(folder),
                        for (final entry in entries)
                          _entryTile(entry, dateFormat),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
  });

  final String title;
  final String initialValue;
  final String hintText;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.title,
    required this.folders,
    required this.initialFolder,
  });

  final String title;
  final List<String> folders;
  final String initialFolder;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late String _selectedFolder;

  @override
  void initState() {
    super.initState();
    _selectedFolder = widget.folders.contains(widget.initialFolder)
        ? widget.initialFolder
        : widget.folders.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: DropdownButtonFormField<String>(
        initialValue: _selectedFolder,
        decoration: const InputDecoration(labelText: 'Destination folder'),
        items: widget.folders
            .map(
              (folder) => DropdownMenuItem(
                value: folder,
                child: Text(folder.isEmpty ? 'TowerLens' : folder),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedFolder = value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedFolder),
          child: const Text('Move'),
        ),
      ],
    );
  }
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({this.parentName});

  final String? parentName;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.parentName == null
            ? 'New folder'
            : 'New folder in ${widget.parentName}',
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
