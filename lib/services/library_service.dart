// Storage pattern mirrored from Fronter Log's VaultService: real files on a
// real user-chosen path (survives uninstall), permission_handler for the
// "All files access" grant, file_picker for the folder chooser, markdown +
// YAML-style frontmatter for each saved item.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_entry.dart';

class LibraryService extends ChangeNotifier {
  static const _prefsPathKey = 'library_path';

  String? _libraryPath;
  String? get libraryPath => _libraryPath;
  bool get isConfigured => _libraryPath != null && _libraryPath!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _libraryPath = prefs.getString(_prefsPathKey);
  }

  Directory get _rootDir => Directory(p.join(_libraryPath!, 'TowerLens'));

  Future<void> _ensureStructure() async {
    if (!isConfigured) return;
    await _rootDir.create(recursive: true);
    for (final name in ['General', 'ToS', 'Ingredient']) {
      await Directory(p.join(_rootDir.path, name)).create(recursive: true);
    }
  }

  /// Requests "All files access" then opens the folder picker. Note: on
  /// Android this permission request opens the system Settings screen for
  /// the user to toggle manually, then returns to the app -- this matches
  /// the proven Fronter Log flow.
  Future<bool> requestPermissionAndPickFolder() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) return false;
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select where Tower Lens should store your library',
    );
    if (path == null) return false;
    _libraryPath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPathKey, path);
    await _ensureStructure();
    notifyListeners();
    return true;
  }

  Future<List<String>> listFolders() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final entries = await _rootDir.list().toList();
    final names = entries
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
    const priority = {'General': 0, 'ToS': 1, 'Ingredient': 2};
    names.sort((a, b) {
      final pa = priority[a] ?? 99;
      final pb = priority[b] ?? 99;
      if (pa != pb) return pa.compareTo(pb);
      return a.compareTo(b);
    });
    return names;
  }

  Future<void> createFolder(String name) async {
    if (!isConfigured) return;
    final safeName = name.trim();
    if (safeName.isEmpty) return;
    await Directory(p.join(_rootDir.path, safeName)).create(recursive: true);
    notifyListeners();
  }

  Future<LibraryEntry> saveEntry({
    required String type,
    required String folder,
    required String sourceText,
    required String instruction,
    required String output,
  }) async {
    await _ensureStructure();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();
    final folderDir = Directory(p.join(_rootDir.path, folder));
    await folderDir.create(recursive: true);
    final filename = '${_slug(type)}_$id.md';
    final file = File(p.join(folderDir.path, filename));
    final entry = LibraryEntry(
      id: id,
      type: type,
      folder: folder,
      sourceText: sourceText,
      instruction: instruction,
      output: output,
      timestamp: timestamp,
      filePath: file.path,
    );
    await file.writeAsString(_entryToMarkdown(entry));
    notifyListeners();
    return entry;
  }

  Future<List<LibraryEntry>> listEntries({String? folder}) async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final dirs = folder != null
        ? [Directory(p.join(_rootDir.path, folder))]
        : (await _rootDir.list().toList()).whereType<Directory>().toList();
    final entries = <LibraryEntry>[];
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      final files = await dir.list().toList();
      for (final f in files.whereType<File>()) {
        if (!f.path.endsWith('.md')) continue;
        try {
          final content = await f.readAsString();
          entries.add(_entryFromMarkdown(content, f.path));
        } catch (_) {
          // Skip an unreadable/malformed file rather than crash the list.
        }
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> deleteEntry(LibraryEntry entry) async {
    if (entry.filePath == null) return;
    final f = File(entry.filePath!);
    if (await f.exists()) {
      await f.delete();
      notifyListeners();
    }
  }

  Future<void> deleteAll() async {
    if (!isConfigured) return;
    if (await _rootDir.exists()) {
      await _rootDir.delete(recursive: true);
    }
    await _ensureStructure();
    notifyListeners();
  }

  String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  String _escape(String s) => s.replaceAll('"', '\\"');

  String _entryToMarkdown(LibraryEntry e) {
    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('id: ${e.id}');
    buffer.writeln('type: ${e.type}');
    buffer.writeln('folder: "${_escape(e.folder)}"');
    buffer.writeln('timestamp: ${e.timestamp.toIso8601String()}');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Source Text');
    buffer.writeln();
    buffer.writeln(e.sourceText);
    buffer.writeln();
    buffer.writeln('## Instruction');
    buffer.writeln();
    buffer.writeln(e.instruction);
    buffer.writeln();
    buffer.writeln('## Output');
    buffer.writeln();
    buffer.writeln(e.output);
    return buffer.toString();
  }

  LibraryEntry _entryFromMarkdown(String content, String filePath) {
    final parsed = _parseFrontmatter(content);
    final meta = parsed.$1;
    final body = parsed.$2;
    final sections = _parseSections(body);
    return LibraryEntry(
      id: meta['id'] ?? p.basenameWithoutExtension(filePath),
      type: meta['type'] ?? 'general',
      folder: meta['folder'] ?? 'General',
      sourceText: sections['Source Text'] ?? '',
      instruction: sections['Instruction'] ?? '',
      output: sections['Output'] ?? '',
      timestamp: DateTime.tryParse(meta['timestamp'] ?? '') ?? DateTime.now(),
      filePath: filePath,
    );
  }

  (Map<String, String>, String) _parseFrontmatter(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return (<String, String>{}, content.trim());
    }
    final meta = <String, String>{};
    int i = 1;
    for (; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        i++;
        break;
      }
      final line = lines[i];
      final idx = line.indexOf(':');
      if (idx == -1) continue;
      final key = line.substring(0, idx).trim();
      var value = line.substring(idx + 1).trim();
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      meta[key] = value.replaceAll('\\"', '"');
    }
    final bodyStr = (i <= lines.length)
        ? lines.sublist(i).join('\n').trim()
        : '';
    return (meta, bodyStr);
  }

  Map<String, String> _parseSections(String body) {
    final sections = <String, String>{};
    final regex = RegExp(r'^## (.+)$', multiLine: true);
    final matches = regex.allMatches(body).toList();
    for (int i = 0; i < matches.length; i++) {
      final name = matches[i].group(1)!.trim();
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : body.length;
      sections[name] = body.substring(start, end).trim();
    }
    return sections;
  }
}
