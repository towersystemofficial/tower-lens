import 'dart:typed_data';

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

abstract class WatchlistAiService {
  Future<String> analyzeWatchlist({
    required String sourceText,
    required List<String> watchlist,
  });
}

abstract class HighFidelityOcrService {
  Future<String> reconstructScannedText({
    required String frozenOcrText,
    required List<String> previousOcrCaptures,
    required Uint8List imageBytes,
    required String imageMediaType,
  });
}

class TextAiServiceException implements Exception {
  const TextAiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MockTextAiService
    implements TextAiService, HighFidelityOcrService, WatchlistAiService {
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

  @override
  Future<String> analyzeWatchlist({
    required String sourceText,
    required List<String> watchlist,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lower = sourceText.toLowerCase();
    final matches = watchlist
        .where((term) => lower.contains(term.toLowerCase()))
        .toList();
    return '**Important:** This tool can make allergens easier to find, but it '
        'does not replace personally checking the original label.\n\n'
        'Mock analysis: ${matches.isEmpty ? "No exact watchlist matches found." : "Exact matches: ${matches.join(", ")}."}';
  }

  @override
  Future<String> reconstructScannedText({
    required String frozenOcrText,
    required List<String> previousOcrCaptures,
    required Uint8List imageBytes,
    required String imageMediaType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return frozenOcrText;
  }
}
