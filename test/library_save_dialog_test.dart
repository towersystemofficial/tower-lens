import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/widgets/library_save_dialog.dart';

void main() {
  testWidgets('chooses a nested folder and custom filename', (tester) async {
    LibrarySaveDestination? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<LibrarySaveDestination>(
                  context: context,
                  builder: (_) => const LibrarySaveDialog(
                    folders: ['General', 'Research', 'Research/Papers'],
                    defaultFolder: 'General',
                    defaultFilename: 'summary.md',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('summary.md'), findsOneWidget);

    await tester.tap(find.text('General').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Research/Papers').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My paper notes');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(result?.folder, 'Research/Papers');
    expect(result?.filename, 'My paper notes');
  });
}
