import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/services/token_estimate.dart';

void main() {
  test('shows a three-times credit estimate for likely token usage', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.summary,
      sourceText: List.filled(500, 'word').join(' '),
      instruction: 'Summarize the supplied text.',
    );

    expect(estimate.lowerBound, greaterThan(0));
    expect(estimate.upperBound, greaterThan(estimate.lowerBound));
    expect(estimate.creditLowerBound, estimate.lowerBound * 3);
    expect(estimate.creditUpperBound, estimate.upperBound * 3);
    expect(estimate.confidencePercent, 80);
    expect(estimate.buttonLabel, contains('credits, 80% confidence'));
  });

  test('uses a generous API ceiling rather than the estimate as a hard cap', () {
    final maxTokens = TextAiTokenEstimator.requiredMaxOutputTokens(
      taskType: TextAiTaskType.general,
      sourceText: 'Short text',
      instruction: 'Explain this.',
    );

    expect(maxTokens, 4096);
  });

  test('keeps short requests at the 45 second minimum', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.simplify,
      sourceText: 'A short paragraph to simplify.',
      instruction: 'Simplify the supplied text.',
    );

    expect(estimate.requestTimeout, const Duration(seconds: 45));
    expect(estimate.durationWarning, isNull);
  });

  test('gives long simplification requests several minutes', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.simplify,
      sourceText: List.filled(5000, 'denseword').join(' '),
      instruction: 'Simplify the supplied text.',
    );

    expect(estimate.requestTimeout, greaterThanOrEqualTo(const Duration(minutes: 5)));
    expect(estimate.requestTimeout, lessThanOrEqualTo(const Duration(minutes: 10)));
    expect(estimate.durationWarning, contains('may take up to about'));
  });

  test('scales detailed ToS analysis beyond the fixed timeout', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.tosSummary,
      sourceText: List.filled(3000, 'policyword').join(' '),
      instruction: 'Analyze ToS/privacy policy',
    );

    expect(estimate.requestTimeout, greaterThan(const Duration(seconds: 45)));
    expect(estimate.durationWarning, isNotNull);
  });
}
