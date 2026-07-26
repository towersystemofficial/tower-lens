import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/models/library_entry.dart';
import 'package:tower_lens/services/library_service.dart';

void main() {
  group('LibraryService', () {
    late Directory tempDir;
    late LibraryService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'tower_lens_library_test_',
      );
      SharedPreferences.setMockInitialValues({'library_path': tempDir.path});
      service = LibraryService();
      await service.load();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('notifies listeners when saved entries change', () async {
      var notifications = 0;
      service.addListener(() => notifications++);

      final entry = await service.saveEntry(
        type: 'general',
        folder: 'General',
        sourceText: 'source',
        instruction: 'summarize',
        output: 'output',
      );
      await service.deleteEntry(entry);

      expect(notifications, 2);
    });

    test('notifies listeners when folders change', () async {
      var notifications = 0;
      service.addListener(() => notifications++);

      await service.createFolder('Research');
      await service.deleteAll();

      expect(notifications, 2);
    });

    test('creates, lists, scans, and deletes nested folders', () async {
      await service.createFolder('Research');
      await service.createFolder('Papers', parentFolder: 'Research');
      await service.saveEntry(
        type: 'general',
        folder: 'Research/Papers',
        sourceText: 'Nested source',
        instruction: 'summarize',
        output: 'Nested output',
      );

      expect(await service.listFolders(), contains('Research'));
      expect(
        await service.listFolders(parentFolder: 'Research'),
        contains('Research/Papers'),
      );
      expect(
        await service.listEntries(folder: 'Research', recursive: false),
        isEmpty,
      );
      expect(
        await service.listEntries(folder: 'Research', recursive: true),
        hasLength(1),
      );

      await service.deleteFolder('Research');

      expect(await service.listFolders(), isNot(contains('Research')));
      expect(await service.listEntries(), isEmpty);
    });

    test('rejects folder paths that can escape the library root', () async {
      await expectLater(
        service.createFolder('../outside'),
        throwsArgumentError,
      );
      await expectLater(
        service.listFolders(parentFolder: '../outside'),
        throwsArgumentError,
      );
      await expectLater(
        service.deleteFolder(''),
        throwsArgumentError,
      );
    });

    test('preserves and searches structured output headings', () async {
      await service.saveEntry(
        type: 'tos',
        folder: 'ToS',
        sourceText: 'Policy source',
        instruction: 'Summarize ToS/privacy policy',
        output:
            '## Key points\n\nThe distinctive quasar clause limits account transfers.',
      );

      final entries = await service.listEntries();

      expect(entries, hasLength(1));
      expect(entries.single.output, contains('## Key points'));
      expect(entries.single.output, contains('distinctive quasar'));
      expect(entries.single.matchesSearch('  DISTINCTIVE QUASAR  '), isTrue);
    });

    test('lists every nested folder for save destination selection', () async {
      await service.createFolder('Research');
      await service.createFolder('Papers', parentFolder: 'Research');

      expect(
        await service.listAllFolders(),
        containsAll(['Research', 'Research/Papers']),
      );
    });

    test('uses chosen filenames, sanitizes them, and prevents overwrites',
        () async {
      final first = await service.saveEntry(
        type: 'general',
        folder: 'General',
        filename: 'My: Research / Notes',
        sourceText: 'source',
        instruction: 'summarize',
        output: 'output',
      );

      expect(first.filename, 'My- Research - Notes.md');
      expect(File(first.filePath!).existsSync(), isTrue);

      await expectLater(
        service.saveEntry(
          type: 'general',
          folder: 'General',
          filename: 'my- research - notes.MD',
          sourceText: 'source',
          instruction: 'summarize',
          output: 'output',
        ),
        throwsA(isA<LibraryFileExistsException>()),
      );
    });

    test('renames and moves files without losing content or metadata',
        () async {
      await service.createFolder('Research');
      final original = await service.saveEntry(
        type: 'general',
        folder: 'Research',
        filename: 'Original.md',
        sourceText: 'source',
        instruction: 'summarize',
        output: '## Structured output',
      );

      final renamed = await service.renameEntry(original, 'Better title');
      expect(renamed.filename, 'Better title.md');
      expect(File(original.filePath!).existsSync(), isFalse);

      final moved = await service.moveEntry(renamed, 'ToS');
      expect(moved.folder, 'ToS');
      expect(moved.filename, 'Better title.md');
      expect(File(renamed.filePath!).existsSync(), isFalse);

      final reopened = await service.listEntries(
        folder: 'ToS',
        recursive: false,
      );
      expect(reopened, hasLength(1));
      expect(reopened.single.sourceText, 'source');
      expect(reopened.single.output, '## Structured output');
      expect(reopened.single.folder, 'ToS');
    });

    test('file rename and move preserve overwrite protection', () async {
      final first = await service.saveEntry(
        type: 'general',
        folder: 'General',
        filename: 'First',
        sourceText: 'first',
        instruction: 'summarize',
        output: 'first',
      );
      await service.saveEntry(
        type: 'general',
        folder: 'General',
        filename: 'Taken',
        sourceText: 'taken',
        instruction: 'summarize',
        output: 'taken',
      );
      await service.saveEntry(
        type: 'tos',
        folder: 'ToS',
        filename: 'First',
        sourceText: 'destination',
        instruction: 'summarize',
        output: 'destination',
      );

      await expectLater(
        service.renameEntry(first, 'taken'),
        throwsA(isA<LibraryFileExistsException>()),
      );
      await expectLater(
        service.moveEntry(first, 'ToS'),
        throwsA(isA<LibraryFileExistsException>()),
      );
      expect(File(first.filePath!).existsSync(), isTrue);
    });

    test('renames and moves folders while updating descendant metadata',
        () async {
      await service.createFolder('Research');
      await service.createFolder('Papers', parentFolder: 'Research');
      await service.saveEntry(
        type: 'general',
        folder: 'Research/Papers',
        filename: 'Nested',
        sourceText: 'source',
        instruction: 'summarize',
        output: 'output',
      );

      final renamed = await service.renameFolder('Research', 'Sources');
      expect(renamed, 'Sources');
      expect(await service.listFolders(), contains('Sources'));
      expect(await service.listFolders(), isNot(contains('Research')));

      final moved = await service.moveFolder('Sources', 'ToS');
      expect(moved, 'ToS/Sources');
      expect(
        await service.listFolders(parentFolder: 'ToS'),
        contains('ToS/Sources'),
      );

      final entries = await service.listEntries(
        folder: 'ToS/Sources',
        recursive: true,
      );
      expect(entries, hasLength(1));
      expect(entries.single.folder, 'ToS/Sources/Papers');
      expect(
        await File(entries.single.filePath!).readAsString(),
        contains('folder: "ToS/Sources/Papers"'),
      );
    });

    test('prevents folder collisions and moves into descendants', () async {
      await service.createFolder('Research');
      await service.createFolder('Papers', parentFolder: 'Research');
      await service.createFolder('Archive');

      await expectLater(
        service.renameFolder('Research', 'archive'),
        throwsA(isA<LibraryFolderExistsException>()),
      );
      await expectLater(
        service.moveFolder('Research', 'Research/Papers'),
        throwsArgumentError,
      );
      expect(await service.listFolders(), contains('Research'));
    });

    test('rejects entry paths outside the library root', () async {
      final outside = LibraryEntry(
        id: 'outside',
        type: 'general',
        folder: 'General',
        sourceText: 'source',
        instruction: 'summarize',
        output: 'output',
        timestamp: DateTime(2026, 7, 25),
        filePath: p.join(tempDir.parent.path, 'outside.md'),
      );

      await expectLater(
        service.renameEntry(outside, 'renamed'),
        throwsArgumentError,
      );
      await expectLater(
        service.moveEntry(outside, 'General'),
        throwsArgumentError,
      );
    });
  });
}
