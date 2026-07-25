import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tower_lens/models/library_entry.dart';
import 'package:tower_lens/screens/library_screen.dart';
import 'package:tower_lens/services/library_service.dart';

class FakeLibraryService extends LibraryService {
  final folders = <String>[
    'General',
    'ToS',
    'Ingredient',
    'Research',
    'Research/Papers',
  ];
  final entries = <LibraryEntry>[];
  LibraryEntry? deletedEntry;
  String? deletedFolder;

  @override
  bool get isConfigured => true;

  @override
  Future<List<String>> listFolders({String parentFolder = ''}) async {
    return folders.where((folder) {
      final parent = p.dirname(folder);
      return parentFolder.isEmpty ? parent == '.' : parent == parentFolder;
    }).toList();
  }

  @override
  Future<List<LibraryEntry>> listEntries({
    String? folder,
    bool recursive = true,
  }) async {
    final current = folder ?? '';
    return entries.where((entry) {
      if (recursive) {
        return current.isEmpty ||
            entry.folder == current ||
            p.isWithin(current, entry.folder);
      }
      return entry.folder == current;
    }).toList();
  }

  @override
  Future<void> deleteEntry(LibraryEntry entry) async {
    deletedEntry = entry;
    entries.remove(entry);
    notifyListeners();
  }

  @override
  Future<void> deleteFolder(String folder) async {
    deletedFolder = folder;
    folders.removeWhere(
      (candidate) => candidate == folder || p.isWithin(folder, candidate),
    );
    entries.removeWhere(
      (entry) => entry.folder == folder || p.isWithin(folder, entry.folder),
    );
    notifyListeners();
  }
}

Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('LibraryScreen', () {
    late FakeLibraryService service;

    setUp(() {
      service = FakeLibraryService();
    });

    testWidgets(
      'navigates nested folders with breadcrumbs and up',
      (tester) async {
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
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'file deletion requires confirmation and supports cancel',
      (tester) async {
        final entry = LibraryEntry(
          id: 'entry-1',
          type: 'general',
          folder: 'General',
          sourceText: 'Disposable source',
          instruction: 'summarize',
          output: 'Disposable output',
          timestamp: DateTime(2026, 7, 25),
          filePath: '/library/TowerLens/General/disposable.md',
        );
        service.entries.add(entry);

        await tester.pumpWidget(
          MaterialApp(home: LibraryScreen(libraryService: service)),
        );
        await pumpFrames(tester);
        await tester.tap(find.text('General'));
        await pumpFrames(tester);

        await tester.tap(find.byTooltip('Delete saved item'));
        await pumpFrames(tester);
        expect(find.text('Delete saved item?'), findsOneWidget);
        expect(service.deletedEntry, isNull);

        await tester.tap(find.text('Cancel'));
        await pumpFrames(tester);
        expect(service.deletedEntry, isNull);

        await tester.tap(find.byTooltip('Delete saved item'));
        await pumpFrames(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await pumpFrames(tester);
        expect(service.deletedEntry, same(entry));
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets(
      'folder deletion requires confirmation and removes descendants',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: LibraryScreen(libraryService: service)),
        );
        await pumpFrames(tester);

        await tester.tap(find.byTooltip('Delete folder').last);
        await pumpFrames(tester);
        expect(find.text('Delete Research?'), findsOneWidget);
        expect(service.deletedFolder, isNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await pumpFrames(tester);
        expect(service.deletedFolder, 'Research');
        expect(find.text('Research'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    testWidgets('name sorting uses the visible filename', (tester) async {
      service.entries.addAll([
        LibraryEntry(
          id: 'newer-zebra',
          type: 'general',
          folder: 'General',
          sourceText: 'Alpha preview',
          instruction: 'summarize',
          output: 'output',
          timestamp: DateTime(2026, 7, 25, 12),
          filePath: '/library/TowerLens/General/Zebra.md',
        ),
        LibraryEntry(
          id: 'older-apple',
          type: 'general',
          folder: 'General',
          sourceText: 'Zebra preview',
          instruction: 'summarize',
          output: 'output',
          timestamp: DateTime(2026, 7, 24, 12),
          filePath: '/library/TowerLens/General/Apple.md',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('General'));
      await pumpFrames(tester);

      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name A–Z').last);
      await pumpFrames(tester);

      final apple = tester.getTopLeft(find.text('Apple')).dy;
      final zebra = tester.getTopLeft(find.text('Zebra')).dy;
      expect(apple, lessThan(zebra));

      await tester.tap(find.text('Name A–Z'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name Z–A').last);
      await pumpFrames(tester);

      final zebraDescending = tester.getTopLeft(find.text('Zebra')).dy;
      final appleDescending = tester.getTopLeft(find.text('Apple')).dy;
      expect(zebraDescending, lessThan(appleDescending));
    });
  });
}
