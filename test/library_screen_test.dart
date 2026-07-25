import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/screens/library_screen.dart';
import 'package:tower_lens/services/library_service.dart';

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('LibraryScreen', () {
    late Directory tempDir;
    late LibraryService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'tower_lens_library_screen_test_',
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

    testWidgets('navigates nested folders with breadcrumbs and up',
        (tester) async {
      await service.createFolder('Research');
      await service.createFolder('Papers', parentFolder: 'Research');

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);

      await tester.tap(find.text('Research'));
      await pumpFrames(tester);
      expect(find.text('Papers'), findsOneWidget);
      expect(find.text('TowerLens'), findsOneWidget);

      await tester.tap(find.text('Papers'));
      await pumpFrames(tester);
      expect(find.byTooltip('Up one folder'), findsOneWidget);

      await tester.tap(find.byTooltip('Up one folder'));
      await pumpFrames(tester);
      expect(find.text('Papers'), findsOneWidget);
    });

    testWidgets('file deletion requires confirmation and supports cancel',
        (tester) async {
      final entry = await service.saveEntry(
        type: 'general',
        folder: 'General',
        sourceText: 'Disposable source',
        instruction: 'summarize',
        output: 'Disposable output',
      );

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('General'));
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Delete saved item'));
      await pumpFrames(tester);
      expect(find.text('Delete saved item?'), findsOneWidget);
      expect(await File(entry.filePath!).exists(), isTrue);

      await tester.tap(find.text('Cancel'));
      await pumpFrames(tester);
      expect(await File(entry.filePath!).exists(), isTrue);

      await tester.tap(find.byTooltip('Delete saved item'));
      await pumpFrames(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await pumpFrames(tester);
      expect(await File(entry.filePath!).exists(), isFalse);
    });

    testWidgets('folder deletion requires confirmation and removes descendants',
        (tester) async {
      await service.createFolder('Research');
      final entry = await service.saveEntry(
        type: 'general',
        folder: 'Research',
        sourceText: 'Disposable folder source',
        instruction: 'summarize',
        output: 'Disposable folder output',
      );

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('Delete folder').last);
      await pumpFrames(tester);
      expect(find.text('Delete Research?'), findsOneWidget);
      expect(await File(entry.filePath!).exists(), isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await pumpFrames(tester);
      expect(await File(entry.filePath!).exists(), isFalse);
      expect(find.text('Research'), findsNothing);
    });
  });
}
