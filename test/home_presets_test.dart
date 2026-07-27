import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/screens/home_screen.dart';
import 'package:tower_lens/services/library_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';

class _RecordingTextAiService implements TextAiService {
  TextAiTaskType? taskType;
  String? instruction;

  @override
  Future<TextAiResult> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) async {
    this.taskType = taskType;
    this.instruction = instruction;
    return const TextAiResult(output: 'Done');
  }
}

void main() {
  testWidgets('preset selection disables custom instructions and toggles off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          libraryService: LibraryService(),
          textAiService: _RecordingTextAiService(),
          usesRealAi: true,
          onConfigureAi: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).at(1),
      'Keep this custom instruction',
    );
    await tester.tap(find.text('Summarize'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField).at(1)).enabled, false);

    await tester.tap(find.text('Summarize'));
    await tester.pump();

    final instructionField =
        tester.widget<TextField>(find.byType(TextField).at(1));
    expect(instructionField.enabled, true);
    expect(instructionField.controller?.text, 'Keep this custom instruction');
  });

  testWidgets('Simplify Text resets to accuracy and sends the chosen cutoff', (
    tester,
  ) async {
    final service = _RecordingTextAiService();
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          libraryService: LibraryService(),
          textAiService: service,
          usesRealAi: true,
          onConfigureAi: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Source text');
    await tester.tap(find.text('Simplify Text'));
    await tester.pump();

    expect(find.text('Highest accuracy'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);

    final sliderBounds = tester.getRect(find.byType(Slider));
    await tester.tapAt(
      Offset(sliderBounds.right - 24, sliderBounds.center.dy),
    );
    await tester.pump();
    final runButton = find.byType(FilledButton);
    await tester.ensureVisible(runButton);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    expect(service.taskType, TextAiTaskType.simplify);
    expect(service.instruction, contains('top 5000'));
  });

  testWidgets('Run button shows a local token estimate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          libraryService: LibraryService(),
          textAiService: _RecordingTextAiService(),
          usesRealAi: true,
          onConfigureAi: () {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Source text');
    await tester.enterText(find.byType(TextField).at(1), 'Explain this');
    await tester.pump();

    expect(find.textContaining('tokens, 80% confidence'), findsOneWidget);
  });
}
