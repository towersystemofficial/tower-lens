import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/services/anthropic_text_ai_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/services/text_ai_service_factory.dart';

void main() {
  group('TextAiService factory', () {
    test('uses the mock service without a runtime credential', () {
      expect(createTextAiService(), isA<MockTextAiService>());
    });

    test('uses Anthropic when a runtime API key is supplied', () {
      expect(
        createTextAiService(apiKey: 'runtime-test-key'),
        isA<AnthropicTextAiService>(),
      );
    });
  });

  group('MockTextAiService', () {
    final service = MockTextAiService();

    test('returns the general mock response', () async {
      final result = await service.runTask(
        taskType: TextAiTaskType.general,
        sourceText: 'some text',
        instruction: 'Summarize',
      );
      expect(
        result,
        'Mock response: This is where the app will summarize, explain, '
        'or answer questions about your text.',
      );
    });

    test('returns the ToS summary mock response', () async {
      final result = await service.runTask(
        taskType: TextAiTaskType.tosSummary,
        sourceText: 'some tos text',
        instruction: 'Summarize ToS/privacy policy',
      );
      expect(
        result,
        'Mock ToS summary:\n\n'
        '• Key points: this is a placeholder until real AI analysis is wired up.\n'
        '• Concerning clauses: none detected yet (mock).\n'
        '• Data collected: unknown (mock).\n'
        '• Cancellation/refund terms: unknown (mock).\n\n'
        'This is an informational summary only, not legal advice.',
      );
    });
  });
}
