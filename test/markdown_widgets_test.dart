import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart'
    show MarkdownEditingController;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/screens/watchlist_screen.dart';
import 'package:tower_lens/services/library_service.dart';
import 'package:tower_lens/widgets/markdown_content.dart';
import 'package:tower_lens/widgets/markdown_editor.dart';

void main() {
  testWidgets('renders Markdown content as selectable rich text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownContent(data: '## Heading\n\n**Bold text**'),
        ),
      ),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, contains('**Bold text**'));
    expect(markdown.selectable, isTrue);
    expect(find.text('Heading'), findsOneWidget);
    expect(find.text('Bold text'), findsOneWidget);
  });

  testWidgets('Markdown editor toolbar formats selected text', (tester) async {
    final controller = MarkdownEditingController(text: 'important');
    controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 9,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            hintText: 'Write Markdown',
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    expect(controller.text, '**important**');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Markdown editor formats input live without a preview action',
      (tester) async {
    final controller = MarkdownEditingController(
      text: '# Live heading\n\n**Bold text**',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarkdownEditor(
            controller: controller,
            hintText: 'Write Markdown',
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller, same(controller));
    expect(textField.controller, isA<MarkdownEditingController>());
    expect(controller.sourceText, contains('**Bold text**'));
    expect(find.text('Preview'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('Watchlist ingredient input remains plain text', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: WatchlistScreen(libraryService: LibraryService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check Text'));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Paste an ingredient list here...'),
    );
    expect(input.controller, isNot(isA<MarkdownEditingController>()));
    expect(find.byTooltip('Bold'), findsNothing);
    expect(find.text('Preview'), findsNothing);
  });
}
