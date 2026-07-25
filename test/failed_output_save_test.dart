import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/screens/home_screen.dart';
import 'package:tower_lens/screens/tos_screen.dart';
import 'package:tower_lens/services/library_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';

class _FailingTextAiService implements TextAiService {
  @override
  Future<String> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) {
    throw const TextAiServiceException('No internet connection.');
  }
}

void main() {
  testWidgets('Home does not offer to save a failed AI attempt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          libraryService: LibraryService(),
          textAiService: _FailingTextAiService(),
          usesRealAi: true,
          onConfigureAi: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Source text');
    await tester.enterText(find.byType(TextField).at(1), 'Summarize');
    await tester.pump();
    final runButton = find.widgetWithText(FilledButton, 'Run');
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
  });

  testWidgets('ToS does not offer to save a failed AI attempt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TosScreen(
          libraryService: LibraryService(),
          textAiService: _FailingTextAiService(),
          usesRealAi: true,
          onConfigureAi: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Policy text');
    await tester.pump();
    final summarizeButton = find.widgetWithText(FilledButton, 'Summarize');
    await tester.ensureVisible(summarizeButton);
    await tester.tap(summarizeButton);
    await tester.pumpAndSettle();

    expect(find.text('No internet connection.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Save'), findsNothing);
  });
}
