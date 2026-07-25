import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/library_service.dart';

class LibrarySaveDestination {
  final String folder;
  final String filename;

  const LibrarySaveDestination({
    required this.folder,
    required this.filename,
  });
}

String generatedLibraryFilename(String type, {DateTime? now}) {
  final timestamp = DateFormat('yyyy-MM-dd-HHmmss').format(now ?? DateTime.now());
  return '$type-$timestamp.md';
}

Future<LibrarySaveDestination?> showLibrarySaveDialog({
  required BuildContext context,
  required LibraryService libraryService,
  required String defaultFolder,
  required String defaultFilename,
}) async {
  final folders = await libraryService.listAllFolders();
  if (!context.mounted) return null;

  return showDialog<LibrarySaveDestination>(
    context: context,
    builder: (context) => LibrarySaveDialog(
      folders: folders,
      defaultFolder: defaultFolder,
      defaultFilename: defaultFilename,
    ),
  );
}

class LibrarySaveDialog extends StatefulWidget {
  final List<String> folders;
  final String defaultFolder;
  final String defaultFilename;

  const LibrarySaveDialog({
    super.key,
    required this.folders,
    required this.defaultFolder,
    required this.defaultFilename,
  });

  @override
  State<LibrarySaveDialog> createState() => _LibrarySaveDialogState();
}

class _LibrarySaveDialogState extends State<LibrarySaveDialog> {
  late final TextEditingController _filenameController;
  late String _folder;

  @override
  void initState() {
    super.initState();
    _filenameController = TextEditingController(text: widget.defaultFilename);
    _folder = widget.folders.contains(widget.defaultFolder)
        ? widget.defaultFolder
        : '';
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  void _save() {
    final filename = _filenameController.text.trim();
    if (filename.isEmpty) return;
    Navigator.pop(
      context,
      LibrarySaveDestination(folder: _folder, filename: filename),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save to Library'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _folder,
            decoration: const InputDecoration(
              labelText: 'Folder',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('TowerLens (root)'),
              ),
              for (final folder in widget.folders)
                DropdownMenuItem(
                  value: folder,
                  child: Text(folder),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _folder = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _filenameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Filename',
              helperText: 'Saved as a Markdown (.md) file',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _filenameController.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
