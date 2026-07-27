import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/services/token_estimate.dart';

void main() {
  test('estimates a range containing input and likely output tokens', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.summary,
      sourceText: List.filled(500, 'word').join(' '),
      instruction: 'Summarize the supplied text.',
    );

    expect(estimate.lowerBound, greaterThan(0));
    expect(estimate.upperBound, greaterThan(estimate.lowerBound));
    expect(estimate.confidencePercent, 80);
    expect(estimate.buttonLabel, contains('tokens, 80% confidence'));
  });

  test('uses a generous API ceiling rather than the estimate as a hard cap', () {
    final maxTokens = TextAiTokenEstimator.requiredMaxOutputTokens(
      taskType: TextAiTaskType.general,
      sourceText: 'Short text',
      instruction: 'Explain this.',
    );

    expect(maxTokens, 4096);
  });
}
