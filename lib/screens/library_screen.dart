import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/library_entry.dart';
import '../services/library_service.dart';
import 'library_detail_screen.dart';

enum LibrarySort { newest, oldest, nameAscending, nameDescending, type }

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
    if (!mounted) return;
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
    } on ArgumentError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a valid folder name.')),
      );
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
    }
  }

  void _openFolder(String folder) {
    setState(() {
      _currentFolder = folder;
      _query = '';
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
          TextButton.icon(
            onPressed: () => _openBreadcrumb(0),
            icon: const Icon(Icons.home_outlined),
            label: const Text('TowerLens'),
          ),
          for (var index = 0; index < segments.length; index++) ...[
            const Icon(Icons.chevron_right, size: 18),
            TextButton(
              onPressed: () => _openBreadcrumb(index + 1),
              child: Text(segments[index]),
            ),
          ],
        ],
      ),
    );
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
          _currentFolder.isEmpty ? 'Library' : p.basename(_currentFolder),
        ),
        leading: _currentFolder.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Up one folder',
                onPressed: _goUp,
              ),
        actions: [
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
                            ListTile(
                              key: ValueKey('folder:$folder'),
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(p.basename(folder)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete folder',
                                onPressed: () => _deleteFolder(folder),
                              ),
                              onTap: () => _openFolder(folder),
                            ),
                        for (final entry in entries)
                          ListTile(
                            key: ValueKey('entry:${entry.filePath}'),
                            leading: const Icon(Icons.description_outlined),
                            title: Text(entry.displayName),
                            subtitle: Text(
                              '${entry.preview}\n${entry.folder} • '
                              '${dateFormat.format(entry.timestamp)}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Delete saved item',
                              onPressed: () => _deleteEntry(entry),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LibraryDetailScreen(entry: entry),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
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
