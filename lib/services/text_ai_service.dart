enum TextAiTaskType { general, tosSummary }

abstract class TextAiService {
  Future<String> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  });
}

class MockTextAiService implements TextAiService {
  @override
  Future<String> runTask({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    switch (taskType) {
      case TextAiTaskType.general:
        return 'Mock response: This is where the app will summarize, explain, '
            'or answer questions about your text.';
      case TextAiTaskType.tosSummary:
        return 'Mock ToS summary:\n\n'
            '• Key points: this is a placeholder until real AI analysis is wired up.\n'
            '• Concerning clauses: none detected yet (mock).\n'
            '• Data collected: unknown (mock).\n'
            '• Cancellation/refund terms: unknown (mock).\n\n'
            'This is an informational summary only, not legal advice.';
    }
  }
}
