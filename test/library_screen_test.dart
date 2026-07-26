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
  LibraryEntry? renamedEntry;
  LibraryEntry? movedEntry;
  String? renamedFolder;
  String? movedFolder;

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

  LibraryEntry _withLocation(
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

  @override
  Future<LibraryEntry> renameEntry(
    LibraryEntry entry,
    String filename,
  ) async {
    final updated = _withLocation(
      entry,
      folder: entry.folder,
      filePath: p.join(p.dirname(entry.filePath!), '$filename.md'),
    );
    entries[entries.indexOf(entry)] = updated;
    renamedEntry = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<LibraryEntry> moveEntry(
    LibraryEntry entry,
    String destinationFolder,
  ) async {
    final updated = _withLocation(
      entry,
      folder: destinationFolder,
      filePath: p.join(
        '/library/TowerLens',
        destinationFolder,
        entry.filename,
      ),
    );
    entries[entries.indexOf(entry)] = updated;
    movedEntry = updated;
    notifyListeners();
    return updated;
  }

  String _relocate(String value, String source, String destination) {
    if (value == source) return destination;
    return p.join(destination, p.relative(value, from: source));
  }

  @override
  Future<String> renameFolder(String folder, String name) async {
    final parent = p.dirname(folder);
    final destination = parent == '.' ? name : p.join(parent, name);
    for (var index = 0; index < folders.length; index++) {
      if (folders[index] == folder || p.isWithin(folder, folders[index])) {
        folders[index] = _relocate(folders[index], folder, destination);
      }
    }
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.folder == folder || p.isWithin(folder, entry.folder)) {
        final newFolder = _relocate(entry.folder, folder, destination);
        entries[index] = _withLocation(
          entry,
          folder: newFolder,
          filePath: p.join(
            '/library/TowerLens',
            newFolder,
            entry.filename,
          ),
        );
      }
    }
    renamedFolder = destination;
    notifyListeners();
    return destination;
  }

  @override
  Future<String> moveFolder(
    String folder,
    String destinationFolder,
  ) async {
    final destination = destinationFolder.isEmpty
        ? p.basename(folder)
        : p.join(destinationFolder, p.basename(folder));
    for (var index = 0; index < folders.length; index++) {
      if (folders[index] == folder || p.isWithin(folder, folders[index])) {
        folders[index] = _relocate(folders[index], folder, destination);
      }
    }
    movedFolder = destination;
    notifyListeners();
    return destination;
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

        await tester.tap(find.byTooltip('File actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await pumpFrames(tester);
        expect(find.text('Delete saved item?'), findsOneWidget);
        expect(service.deletedEntry, isNull);

        await tester.tap(find.text('Cancel'));
        await pumpFrames(tester);
        expect(service.deletedEntry, isNull);

        await tester.tap(find.byTooltip('File actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
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

        final researchFolder = find.byKey(
          const ValueKey('folder:Research'),
        );
        await tester.tap(
          find.descendant(
            of: researchFolder,
            matching: find.byTooltip('Folder actions'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
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

    testWidgets('renames a file from its action menu', (tester) async {
      service.entries.add(
        LibraryEntry(
          id: 'entry-1',
          type: 'general',
          folder: 'General',
          sourceText: 'source',
          instruction: 'summarize',
          output: 'output',
          timestamp: DateTime(2026, 7, 25),
          filePath: '/library/TowerLens/General/Old name.md',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('General'));
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('File actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'New name');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await pumpFrames(tester);

      expect(service.renamedEntry?.displayName, 'New name');
      expect(find.text('New name'), findsOneWidget);
    });

    testWidgets('moves a file to a selected nested folder', (tester) async {
      service.entries.add(
        LibraryEntry(
          id: 'entry-1',
          type: 'general',
          folder: 'General',
          sourceText: 'source',
          instruction: 'summarize',
          output: 'output',
          timestamp: DateTime(2026, 7, 25),
          filePath: '/library/TowerLens/General/Move me.md',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);
      await tester.tap(find.text('General'));
      await pumpFrames(tester);

      await tester.tap(find.byTooltip('File actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('General').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research/Papers').last);
      await tester.pumpAndSettle();
      final moveButton = find.widgetWithText(FilledButton, 'Move');
      await tester.ensureVisible(moveButton);
      await tester.tap(moveButton);
      await pumpFrames(tester);

      expect(service.movedEntry?.folder, 'Research/Papers');
      expect(find.text('Move me'), findsNothing);
    });

    testWidgets('renames and moves folders from their action menus',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(libraryService: service)),
      );
      await pumpFrames(tester);

      var researchFolder = find.byKey(const ValueKey('folder:Research'));
      await tester.tap(
        find.descendant(
          of: researchFolder,
          matching: find.byTooltip('Folder actions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Sources');
      await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
      await pumpFrames(tester);
      expect(service.renamedFolder, 'Sources');
      expect(find.text('Sources'), findsOneWidget);

      researchFolder = find.byKey(const ValueKey('folder:Sources'));
      await tester.tap(
        find.descendant(
          of: researchFolder,
          matching: find.byTooltip('Folder actions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('TowerLens').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ToS').last);
      await tester.pumpAndSettle();
      final moveButton = find.widgetWithText(FilledButton, 'Move');
      await tester.ensureVisible(moveButton);
      await tester.tap(moveButton);
      await pumpFrames(tester);
      expect(service.movedFolder, 'ToS/Sources');
      expect(find.text('Sources'), findsNothing);
    });
  });
}
