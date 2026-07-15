import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../models/library_entry.dart';
import '../services/library_service.dart';
import 'library_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  final LibraryService libraryService;
  const LibraryScreen({super.key, required this.libraryService});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<LibraryEntry> _entries = [];
  List<String> _folders = [];
  String _selectedFolder = 'All';
  String _query = '';
  bool _newestFirst = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!widget.libraryService.isConfigured) {
      setState(() {});
      return;
    }
    setState(() => _loading = true);
    final folders = await widget.libraryService.listFolders();
    final entries = await widget.libraryService.listEntries();
    setState(() {
      _folders = folders;
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _setupFolder() async {
    final ok = await widget.libraryService.requestPermissionAndPickFolder();
    if (ok) await _refresh();
  }

  Future<void> _newFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.libraryService.createFolder(name);
      await _refresh();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear entire library?'),
        content: const Text('This permanently deletes every saved item and folder from disk. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      await _refresh();
    }
  }

  Future<void> _deleteEntry(LibraryEntry entry) async {
    await widget.libraryService.deleteEntry(entry);
    await _refresh();
  }

  List<LibraryEntry> get _visibleEntries {
    var list = _entries;
    if (_selectedFolder != 'All') {
      list = list.where((e) => e.folder == _selectedFolder).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((e) =>
              e.sourceText.toLowerCase().contains(q) ||
              e.instruction.toLowerCase().contains(q) ||
              e.output.toLowerCase().contains(q))
          .toList();
    }
    list = [...list];
    list.sort((a, b) =>
        _newestFirst ? b.timestamp.compareTo(a.timestamp) : a.timestamp.compareTo(b.timestamp));
    return list;
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
                  'Choose a folder on your device where Tower Lens will store your saved items '
                  'as real files. This folder is yours -- it stays even if you uninstall the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _setupFolder, child: const Text('Choose Library Folder')),
              ],
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'New folder', onPressed: _newFolder),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') _clearAll();
              if (value == 'change') _setupFolder();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'change', child: Text('Change folder location')),
              PopupMenuItem(value: 'clear', child: Text('Clear all')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search saved items...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', ..._folders].map((folder) {
                          final selected = folder == _selectedFolder;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(folder),
                              selected: selected,
                              onSelected: (_) => setState(() => _selectedFolder = folder),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward),
                    tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                    onPressed: () => setState(() => _newestFirst = !_newestFirst),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _visibleEntries.isEmpty
                  ? const Center(child: Text('No saved items yet.'))
                  : ListView.builder(
                      itemCount: _visibleEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _visibleEntries[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(entry.folder.isNotEmpty ? entry.folder[0].toUpperCase() : '?'),
                          ),
                          title: Text(entry.preview),
                          subtitle: Text('${entry.folder} • ${dateFormat.format(entry.timestamp)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteEntry(entry),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LibraryDetailScreen(entry: entry)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}