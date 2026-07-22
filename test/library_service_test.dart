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
  });
}
