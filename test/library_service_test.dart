import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });
}
