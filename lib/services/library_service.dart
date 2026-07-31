// Storage pattern mirrored from Fronter Log's VaultService: real files on a
// real user-chosen path (survives uninstall), permission_handler for the
// "All files access" grant, file_picker for the folder chooser, markdown +
// YAML-style frontmatter for each saved item.

import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_entry.dart';
import '../models/price_check.dart';

class LibraryFileExistsException implements Exception {
  final String filename;

  const LibraryFileExistsException(this.filename);

  @override
  String toString() => 'A Library file named "$filename" already exists.';
}

class LibraryFolderExistsException implements Exception {
  final String folderName;

  const LibraryFolderExistsException(this.folderName);

  @override
  String toString() => 'A Library folder named "$folderName" already exists.';
}

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

  String _validatedFolderPath(String folder) {
    final normalized = p.normalize(folder.trim());
    if (normalized == '.' || normalized.isEmpty) return '';
    if (p.isAbsolute(normalized) ||
        p.split(normalized).any((segment) => segment == '..')) {
      throw ArgumentError.value(folder, 'folder', 'Invalid library folder');
    }
    return normalized;
  }

  Directory _folderDirectory(String folder) {
    final safeFolder = _validatedFolderPath(folder);
    return safeFolder.isEmpty
        ? _rootDir
        : Directory(p.join(_rootDir.path, safeFolder));
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

  /// Lists the immediate child folders of [parentFolder].
  ///
  /// Returned paths are relative to the TowerLens root, so nested folders can
  /// be passed back to the other folder APIs without exposing storage paths.
  Future<List<String>> listFolders({String parentFolder = ''}) async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final safeParent = _validatedFolderPath(parentFolder);
    final parent = _folderDirectory(safeParent);
    if (!await parent.exists()) return [];
    final names = (await parent.list().toList())
        .whereType<Directory>()
        .map((directory) => p.relative(directory.path, from: _rootDir.path))
        .toList();
    const priority = {'General': 0, 'ToS': 1, 'Ingredient': 2};
    names.sort((a, b) {
      if (safeParent.isEmpty) {
        final pa = priority[a] ?? 99;
        final pb = priority[b] ?? 99;
        if (pa != pb) return pa.compareTo(pb);
      }
      return p.basename(a).toLowerCase().compareTo(
            p.basename(b).toLowerCase(),
          );
    });
    return names;
  }

  Future<List<String>> listAllFolders() async {
    final folders = <String>[];

    Future<void> visit(String parent) async {
      final children = await listFolders(parentFolder: parent);
      for (final child in children) {
        folders.add(child);
        await visit(child);
      }
    }

    await visit('');
    return folders;
  }

  Future<void> createFolder(
    String name, {
    String parentFolder = '',
  }) async {
    if (!isConfigured) return;
    final safeName = _validatedFolderName(name);
    final parent = _validatedFolderPath(parentFolder);
    if (await _folderNameExists(parent, safeName)) {
      throw LibraryFolderExistsException(safeName);
    }
    await Directory(p.join(_folderDirectory(parent).path, safeName)).create(
      recursive: true,
    );
    notifyListeners();
  }

  Future<void> deleteFolder(String folder) async {
    if (!isConfigured) return;
    final safeFolder = _validatedFolderPath(folder);
    if (safeFolder.isEmpty) {
      throw ArgumentError('The library root cannot be deleted');
    }
    final directory = _folderDirectory(safeFolder);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
      await _ensureStructure();
      notifyListeners();
    }
  }

  Future<LibraryEntry> saveEntry({
    required String type,
    required String folder,
    required String sourceText,
    required String instruction,
    required String output,
    String? filename,
  }) async {
    await _ensureStructure();
    final safeFolder = _validatedFolderPath(folder);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();
    final folderDir = _folderDirectory(safeFolder);
    await folderDir.create(recursive: true);
    final safeFilename = filename == null
        ? '${_slug(type)}_$id.md'
        : _sanitizedFilename(filename);
    final existingNames = (await folderDir.list().toList())
        .whereType<File>()
        .map((file) => p.basename(file.path).toLowerCase());
    if (existingNames.contains(safeFilename.toLowerCase())) {
      throw LibraryFileExistsException(safeFilename);
    }
    final file = File(p.join(folderDir.path, safeFilename));
    final entry = LibraryEntry(
      id: id,
      type: type,
      folder: safeFolder,
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

  Future<List<LibraryEntry>> listEntries({
    String? folder,
    bool recursive = true,
  }) async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final directory = _folderDirectory(folder ?? '');
    if (!await directory.exists()) return [];
    final files = await directory.list(recursive: recursive).toList();
    final entries = <LibraryEntry>[];
    for (final file in files.whereType<File>()) {
      if (!file.path.endsWith('.md')) continue;
      try {
        final content = await file.readAsString();
        entries.add(_entryFromMarkdown(content, file.path));
      } catch (_) {
        // Skip an unreadable/malformed file rather than crash the list.
      }
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> deleteEntry(LibraryEntry entry) async {
    final file = _validatedEntryFile(entry);
    if (file == null) return;
    if (await file.exists()) {
      await file.delete();
      notifyListeners();
    }
  }

  Future<LibraryEntry> renameEntry(
    LibraryEntry entry,
    String filename,
  ) async {
    final source = _validatedEntryFile(entry);
    if (source == null || !await source.exists()) return entry;
    final safeFilename = _sanitizedFilename(filename);
    final destination = File(p.join(source.parent.path, safeFilename));
    if (p.equals(source.path, destination.path)) return entry;
    await _ensureFileDestinationAvailable(
      destination,
      sourcePath: source.path,
    );
    final movedFile = await source.rename(destination.path);
    final updated = _entryWithLocation(
      entry,
      folder: entry.folder,
      filePath: movedFile.path,
    );
    await movedFile.writeAsString(_entryToMarkdown(updated));
    notifyListeners();
    return updated;
  }

  Future<LibraryEntry> moveEntry(
    LibraryEntry entry,
    String destinationFolder,
  ) async {
    final source = _validatedEntryFile(entry);
    if (source == null || !await source.exists()) return entry;
    final safeDestination = _validatedFolderPath(destinationFolder);
    final destinationDirectory = _folderDirectory(safeDestination);
    if (!await destinationDirectory.exists()) {
      throw ArgumentError.value(
        destinationFolder,
        'destinationFolder',
        'Library folder does not exist',
      );
    }
    final destination = File(
      p.join(destinationDirectory.path, p.basename(source.path)),
    );
    if (p.equals(source.path, destination.path)) return entry;
    await _ensureFileDestinationAvailable(destination);
    final movedFile = await source.rename(destination.path);
    final updated = _entryWithLocation(
      entry,
      folder: safeDestination,
      filePath: movedFile.path,
    );
    await movedFile.writeAsString(_entryToMarkdown(updated));
    notifyListeners();
    return updated;
  }

  Future<String> renameFolder(String folder, String name) async {
    final safeFolder = _validatedMovableFolder(folder);
    final safeName = _validatedFolderName(name);
    final parent = p.dirname(safeFolder);
    final safeParent = parent == '.' ? '' : parent;
    final destination = safeParent.isEmpty
        ? safeName
        : p.join(safeParent, safeName);
    return _relocateFolder(safeFolder, destination);
  }

  Future<String> moveFolder(
    String folder,
    String destinationFolder,
  ) async {
    final safeFolder = _validatedMovableFolder(folder);
    final safeDestination = _validatedFolderPath(destinationFolder);
    if (safeDestination == safeFolder ||
        p.isWithin(safeFolder, safeDestination)) {
      throw ArgumentError.value(
        destinationFolder,
        'destinationFolder',
        'A folder cannot be moved inside itself',
      );
    }
    final destinationDirectory = _folderDirectory(safeDestination);
    if (!await destinationDirectory.exists()) {
      throw ArgumentError.value(
        destinationFolder,
        'destinationFolder',
        'Library folder does not exist',
      );
    }
    final destination = safeDestination.isEmpty
        ? p.basename(safeFolder)
        : p.join(safeDestination, p.basename(safeFolder));
    return _relocateFolder(safeFolder, destination);
  }

  Future<void> deleteAll() async {
    if (!isConfigured) return;
    if (await _rootDir.exists()) {
      await _rootDir.delete(recursive: true);
    }
    await _ensureStructure();
    notifyListeners();
  }

  Future<List<String>> listPriceCheckFolders() async {
    if (!isConfigured) return [];
    await _ensureStructure();
    final folders = <String>[];
    await for (final entity in _rootDir.list(recursive: true)) {
      if (entity is File && p.basename(entity.path) == 'input-fields.md') {
        folders.add(p.relative(entity.parent.path, from: _rootDir.path));
      }
    }
    folders.sort();
    return folders;
  }

  Future<PriceCheckPreviousRun> importPriceCheckFolder(String folder) async {
    final directory = _folderDirectory(folder);
    final inputFile = File(p.join(directory.path, 'input-fields.md'));
    if (!await inputFile.exists()) {
      throw const FormatException('The selected folder is not a Price Check.');
    }
    final inputText = await inputFile.readAsString();
    final jsonStart = inputText.indexOf('```json\n');
    final jsonEnd = inputText.indexOf('\n```', jsonStart + 8);
    if (jsonStart < 0 || jsonEnd < 0) {
      throw const FormatException('The saved Price Check inputs are unreadable.');
    }
    final data = jsonDecode(inputText.substring(jsonStart + 8, jsonEnd))
        as Map<String, dynamic>;
    final photoDirectory = Directory(p.join(directory.path, 'photos'));
    final photos = await photoDirectory.exists()
        ? (await photoDirectory.list().where((entity) => entity is File).cast<File>().toList())
            .map((file) => file.path)
            .toList()
        : <String>[];
    final outputs = <String>[];
    for (final filename in const [
      'market-result.md', 'buyer-guidance.md', 'seller-guidance.md', 'market-changes.md',
    ]) {
      final file = File(p.join(directory.path, filename));
      if (await file.exists()) outputs.add(await file.readAsString());
    }
    data['photos'] = photos;
    return PriceCheckPreviousRun(
      folderPath: folder,
      input: PriceCheckInput.fromJson(data),
      priorOutputs: outputs.join('\n\n---\n\n'),
    );
  }

  Future<String> savePriceCheckFolder({
    required String parentFolder,
    required String folderName,
    required PriceCheckInput input,
    required PriceCheckIdentification identification,
    required PriceCheckMarketResult market,
    PriceCheckGuidanceResult? buyer,
    PriceCheckGuidanceResult? seller,
    String? marketChanges,
  }) async {
    await _ensureStructure();
    if (!isConfigured) throw StateError('Choose a Library location first.');
    final safeParent = _validatedFolderPath(parentFolder);
    final safeName = _validatedFolderName(folderName);
    if (await _folderNameExists(safeParent, safeName)) {
      throw LibraryFolderExistsException(safeName);
    }
    final folder = safeParent.isEmpty ? safeName : p.join(safeParent, safeName);
    final directory = _folderDirectory(folder);
    await directory.create(recursive: true);
    final photosDirectory = Directory(p.join(directory.path, 'photos'));
    await photosDirectory.create();
    final savedPhotoPaths = <String>[];
    for (var index = 0; index < input.photos.length; index++) {
      final source = File(input.photos[index]);
      if (!await source.exists()) continue;
      final filename = '${index + 1}-${_safeAssetName(p.basename(source.path))}';
      final destination = p.join(photosDirectory.path, filename);
      await source.copy(destination);
      savedPhotoPaths.add(p.join('photos', filename));
    }
    final savedInput = input.toJson(encodedPhotos: savedPhotoPaths);
    await File(p.join(directory.path, 'input-fields.md')).writeAsString(
      '# Price Check inputs\n\nSaved ${DateTime.now().toIso8601String()}\n\n```json\n'
      '${const JsonEncoder.withIndent('  ').convert(savedInput)}\n```\n',
    );
    await File(p.join(directory.path, 'market-result.md')).writeAsString(
      _marketMarkdown(identification, market),
    );
    if (buyer != null) {
      await File(p.join(directory.path, 'buyer-guidance.md')).writeAsString(_guidanceMarkdown(buyer));
    }
    if (seller != null) {
      await File(p.join(directory.path, 'seller-guidance.md')).writeAsString(_guidanceMarkdown(seller));
    }
    if (marketChanges != null && marketChanges.trim().isNotEmpty) {
      await File(p.join(directory.path, 'market-changes.md')).writeAsString('# Market changes\n\n$marketChanges\n');
    }
    notifyListeners();
    return folder;
  }

  String _safeAssetName(String name) => name
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-');

  String _marketMarkdown(PriceCheckIdentification id, PriceCheckMarketResult market) {
    final buffer = StringBuffer('# ${id.title}\n\n');
    buffer.writeln('**Range:** ${market.range}');
    buffer.writeln('**Confidence:** ${market.confidence} — ${market.confidenceReason}');
    buffer.writeln('**Context:** ${market.context}\n');
    buffer.writeln('## Comparables\n');
    for (final comparable in market.comparables) {
      buffer.writeln('- [${comparable.title}](${comparable.source}) — ${comparable.price}; ${comparable.status}; ${comparable.condition}; ${comparable.matchQuality}; ${comparable.date}');
    }
    buffer.writeln('\n## Value factors\n');
    for (final factor in market.valueFactors) {
      buffer.writeln('- $factor');
    }
    return buffer.toString();
  }

  String _guidanceMarkdown(PriceCheckGuidanceResult result) {
    final buffer = StringBuffer('# ${result.heading}\n\n${result.summary}\n\n');
    for (final entry in result.sections.entries) {
      buffer.writeln('## ${entry.key}\n\n${entry.value}\n');
    }
    return buffer.toString();
  }

  String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  String _validatedFolderName(String name) {
    final safeName = name.trim();
    if (safeName.isEmpty ||
        safeName == '.' ||
        safeName == '..' ||
        RegExp(r'[<>:"/\\|?*\x00-\x1f]').hasMatch(safeName) ||
        RegExp(r'[. ]$').hasMatch(safeName)) {
      throw ArgumentError.value(name, 'name', 'Invalid folder name');
    }
    return safeName;
  }

  String _validatedMovableFolder(String folder) {
    final safeFolder = _validatedFolderPath(folder);
    if (safeFolder.isEmpty) {
      throw ArgumentError.value(
        folder,
        'folder',
        'The library root cannot be moved or renamed',
      );
    }
    return safeFolder;
  }

  Future<bool> _folderNameExists(
    String parentFolder,
    String folderName, {
    String? sourcePath,
  }) async {
    final parent = _folderDirectory(parentFolder);
    if (!await parent.exists()) return false;
    final normalizedSource = sourcePath == null ? null : p.normalize(sourcePath);
    await for (final entity in parent.list()) {
      if (entity is! Directory ||
          p.basename(entity.path).toLowerCase() != folderName.toLowerCase()) {
        continue;
      }
      if (normalizedSource == null ||
          !p.equals(p.normalize(entity.path), normalizedSource)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _ensureFileDestinationAvailable(
    File destination, {
    String? sourcePath,
  }) async {
    final normalizedSource = sourcePath == null ? null : p.normalize(sourcePath);
    await for (final entity in destination.parent.list()) {
      if (entity is! File ||
          p.basename(entity.path).toLowerCase() !=
              p.basename(destination.path).toLowerCase()) {
        continue;
      }
      if (normalizedSource == null ||
          !p.equals(p.normalize(entity.path), normalizedSource)) {
        throw LibraryFileExistsException(p.basename(destination.path));
      }
    }
  }

  File? _validatedEntryFile(LibraryEntry entry) {
    final path = entry.filePath;
    if (path == null) return null;
    final normalizedRoot = p.normalize(_rootDir.path);
    final normalizedPath = p.normalize(path);
    if (!p.isWithin(normalizedRoot, normalizedPath)) {
      throw ArgumentError.value(
        path,
        'entry.filePath',
        'Library entry is outside the library root',
      );
    }
    return File(normalizedPath);
  }

  LibraryEntry _entryWithLocation(
    LibraryEntry entry, {
    required String folder,
    required String filePath,
  }) {
    return LibraryEntry(
      id: entry.id,
      type: entry.type,
      folder: folder,
      sourceText: entry.sourceText,
      instruction: entry.instruction,
      output: entry.output,
      timestamp: entry.timestamp,
      filePath: filePath,
    );
  }

  Future<String> _relocateFolder(
    String sourceFolder,
    String destinationFolder,
  ) async {
    final safeSource = _validatedMovableFolder(sourceFolder);
    final safeDestination = _validatedFolderPath(destinationFolder);
    final source = _folderDirectory(safeSource);
    if (!await source.exists()) return safeSource;
    final destinationParent = p.dirname(safeDestination);
    final safeDestinationParent =
        destinationParent == '.' ? '' : destinationParent;
    final destinationName = p.basename(safeDestination);
    if (await _folderNameExists(
      safeDestinationParent,
      destinationName,
      sourcePath: source.path,
    )) {
      throw LibraryFolderExistsException(destinationName);
    }
    final destination = _folderDirectory(safeDestination);
    if (p.equals(source.path, destination.path)) return safeSource;
    final movedDirectory = await source.rename(destination.path);
    await _rewriteFolderMetadata(movedDirectory);
    notifyListeners();
    return safeDestination;
  }

  Future<void> _rewriteFolderMetadata(Directory directory) async {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File ||
          !entity.path.toLowerCase().endsWith('.md')) {
        continue;
      }
      final content = await entity.readAsString();
      if (!content.trimLeft().startsWith('---') ||
          !content.contains('## Source Text') ||
          !content.contains('## Instruction') ||
          !content.contains('## Output')) {
        // Leave malformed/non-Library Markdown files untouched.
        continue;
      }
      final entry = _entryFromMarkdown(content, entity.path);
      final relativeParent = p.relative(
        entity.parent.path,
        from: _rootDir.path,
      );
      final folder = relativeParent == '.' ? '' : relativeParent;
      await entity.writeAsString(
        _entryToMarkdown(
          _entryWithLocation(
            entry,
            folder: folder,
            filePath: entity.path,
          ),
        ),
      );
    }
  }

  String _sanitizedFilename(String filename) {
    var safeName = filename
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (safeName.toLowerCase().endsWith('.md')) {
      safeName = safeName.substring(0, safeName.length - 3).trimRight();
    }
    if (safeName.isEmpty || safeName == '.' || safeName == '..') {
      throw ArgumentError.value(
        filename,
        'filename',
        'Choose a valid filename',
      );
    }
    return '$safeName.md';
  }

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
      if (value.length >= 2 &&
          value.startsWith('"') &&
          value.endsWith('"')) {
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
    const sourceMarker = '## Source Text';
    const instructionMarker = '## Instruction';
    const outputMarker = '## Output';

    final sourceMarkerIndex = body.indexOf(sourceMarker);
    final instructionMarkerIndex = body.indexOf(
      instructionMarker,
      sourceMarkerIndex + sourceMarker.length,
    );
    final outputMarkerIndex = body.indexOf(
      outputMarker,
      instructionMarkerIndex + instructionMarker.length,
    );

    if (sourceMarkerIndex == -1 ||
        instructionMarkerIndex == -1 ||
        outputMarkerIndex == -1) {
      return {};
    }

    return {
      'Source Text': body
          .substring(
            sourceMarkerIndex + sourceMarker.length,
            instructionMarkerIndex,
          )
          .trim(),
      'Instruction': body
          .substring(
            instructionMarkerIndex + instructionMarker.length,
            outputMarkerIndex,
          )
          .trim(),
      'Output': body.substring(outputMarkerIndex + outputMarker.length).trim(),
    };
  }
}
