import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final controller = TextEditingController(text: 'important');
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
    controller.dispose();
  });

  testWidgets('Markdown editor previews formatted input', (tester) async {
    final controller = TextEditingController(text: '# Preview heading');

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

    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(find.text('Markdown preview'), findsOneWidget);
    expect(find.text('Preview heading'), findsOneWidget);
    controller.dispose();
  });
}
