enum TextAiTaskType { general, summary, simplify, tosSummary }

class TextAiResult {
  const TextAiResult({
    required this.output,
    this.suggestedTitle,
  });

  final String output;
  final String? suggestedTitle;
}

abstract class TextAiService {
  Future<TextAiResult> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  });
}

class TextAiServiceException implements Exception {
  const TextAiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockTextAiService implements TextAiService {
  @override
  Future<TextAiResult> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    switch (taskType) {
      case TextAiTaskType.general:
        return const TextAiResult(
          suggestedTitle: 'Mock Text Summary',
          output:
              'Mock response: This is where the app will summarize, explain, '
              'or answer questions about your text.',
        );
      case TextAiTaskType.summary:
        return const TextAiResult(
          suggestedTitle: 'Mock Text Summary',
          output: 'Mock summary:\n\n'
              '## Quick summary\nA short overview.\n\n'
              '## Main points\n- A main point.\n\n'
              '## Detailed breakdown\nA detailed explanation.',
        );
      case TextAiTaskType.simplify:
        return const TextAiResult(
          suggestedTitle: 'Mock Simplified Text',
          output: 'Mock simplified text.',
        );
      case TextAiTaskType.tosSummary:
        return const TextAiResult(
          suggestedTitle: 'Mock Terms Summary',
          output: 'Mock ToS summary:\n\n'
              '• Key points: this is a placeholder until real AI analysis is wired up.\n'
              '• Concerning clauses: none detected yet (mock).\n'
              '• Data collected: unknown (mock).\n'
              '• Cancellation/refund terms: unknown (mock).\n\n'
              'This is an informational summary only, not legal advice.',
        );
    }
  }
}
