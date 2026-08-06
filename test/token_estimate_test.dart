import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/services/credit_pricing.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/services/token_estimate.dart';

void main() {
  test('shows a 3.5-times credit estimate for likely token usage', () {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: TextAiTaskType.summary,
      sourceText: List.filled(500, 'word').join(' '),
      instruction: 'Summarize the supplied text.',
    );

    expect(estimate.lowerBound, greaterThan(0));
    expect(estimate.upperBound, greaterThan(estimate.lowerBound));
    expect(
      estimate.creditLowerBound,
      CreditPricing.estimateLowerBound(estimate.lowerBound),
    );
    expect(
      estimate.creditUpperBound,
      CreditPricing.estimateUpperBound(estimate.upperBound),
    );
    expect(estimate.confidencePercent, 80);
    expect(estimate.buttonLabel, contains('credits, 80% confidence'));
  });

  test('rounds the authoritative 3.5-times actual-usage charge up', () {
    expect(
      CreditPricing.chargeForCompletedRequest(
        inputTokens: 60,
        outputTokens: 40,
        hasUsableOutput: true,
      ),
      350,
    );
    expect(
      CreditPricing.chargeForCompletedRequest(
        inputTokens: 60,
        outputTokens: 41,
        hasUsableOutput: true,
      ),
      354,
    );
  });

  test('requires the highest estimate rounded up to the next thousand', () {
    expect(CreditPricing.requiredBalanceForEstimate(1), 1000);
    expect(CreditPricing.requiredBalanceForEstimate(1000), 1000);
    expect(CreditPricing.requiredBalanceForEstimate(1001), 2000);
    expect(
      () => CreditPricing.requiredBalanceForEstimate(-1),
      throwsArgumentError,
    );
  });

  test('high-fidelity OCR includes image and OCR context in its estimate', () {
    final short = TextAiTokenEstimator.estimateHighFidelityOcr(
      frozenOcrText: 'Short label',
      previousOcrCaptures: const [],
    );
    final long = TextAiTokenEstimator.estimateHighFidelityOcr(
      frozenOcrText: List.filled(500, 'ingredient').join(' '),
      previousOcrCaptures: const ['Earlier OCR reading'],
    );

    expect(short.creditUpperBound, greaterThan(0));
    expect(short.requiredStartingBalance % 1000, 0);
    expect(long.upperBound, greaterThan(short.upperBound));
  });

  test('does not charge failed requests even when the provider used tokens', () {
    expect(
      CreditPricing.chargeForCompletedRequest(
        inputTokens: 1200,
        outputTokens: 83,
        hasUsableOutput: false,
      ),
      0,
    );
  });

  test('uses clean whole-dollar purchase grants and first-purchase bonus', () {
    expect(CreditPricing.normalPurchaseCredits(1), 50000);
    expect(CreditPricing.normalPurchaseCredits(20), 1000000);
    expect(CreditPricing.firstPurchaseCredits(1), 75000);
    expect(CreditPricing.firstPurchaseCredits(20), 1500000);
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
