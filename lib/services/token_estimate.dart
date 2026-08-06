import 'credit_pricing.dart';
import 'text_ai_service.dart';

class TokenEstimate {
  const TokenEstimate({
    required this.lowerBound,
    required this.upperBound,
    required this.outputUpperBound,
    required this.requestTimeout,
    this.confidencePercent = 80,
  });

  final int lowerBound;
  final int upperBound;
  final int outputUpperBound;
  final Duration requestTimeout;
  final int confidencePercent;

  int get creditLowerBound => CreditPricing.estimateLowerBound(lowerBound);

  int get creditUpperBound => CreditPricing.estimateUpperBound(upperBound);

  int get requiredStartingBalance =>
      CreditPricing.requiredBalanceForEstimate(creditUpperBound);

  String get buttonLabel =>
      '${_format(creditLowerBound)}–${_format(creditUpperBound)} credits, '
      '$confidencePercent% confidence';

  String? get durationWarning {
    if (requestTimeout <= const Duration(seconds: 45)) return null;
    final minutes = (requestTimeout.inSeconds / 60).ceil();
    final unit = minutes == 1 ? 'minute' : 'minutes';
    return 'Large or complex request: this may take up to about '
        '$minutes $unit.';
  }

  static String _format(int value) {
    if (value < 1000) return value.toString();
    final thousands = value ~/ 1000;
    final remainder = value % 1000;
    return '$thousands,${remainder.toString().padLeft(3, '0')}';
  }
}

class TextAiTokenEstimator {
  const TextAiTokenEstimator._();

  static TokenEstimate estimate({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) {
    final sourceTokens = _approximateTokens(sourceText);
    final instructionTokens = _approximateTokens(instruction);
    final promptOverhead = switch (taskType) {
      TextAiTaskType.general => 190,
      TextAiTaskType.summary => 240,
      TextAiTaskType.simplify => 250,
      TextAiTaskType.tosSummary => 520,
    };
    final inputTokens = sourceTokens + instructionTokens + promptOverhead;

    final (outputLower, outputUpper) = switch (taskType) {
      TextAiTaskType.general => (
          _atLeast(120, (sourceTokens * 0.15).round()),
          _atLeast(350, (sourceTokens * 0.70).round()),
        ),
      TextAiTaskType.summary => (
          _atLeast(220, (sourceTokens * 0.45).round()),
          _atLeast(500, (sourceTokens * 1.10).round()),
        ),
      TextAiTaskType.simplify => (
          _atLeast(180, (sourceTokens * 0.85).round()),
          _atLeast(350, (sourceTokens * 1.25).round()),
        ),
      TextAiTaskType.tosSummary => (
          _atLeast(600, (sourceTokens * 0.30).round()),
          _atLeast(1200, (sourceTokens * 0.90).round()),
        ),
    };

    return TokenEstimate(
      lowerBound: _roundDown(inputTokens + outputLower),
      upperBound: _roundUp(inputTokens + outputUpper),
      outputUpperBound: outputUpper,
      requestTimeout: _requestTimeout(taskType, outputUpper),
    );
  }

  static int requiredMaxOutputTokens({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) {
    final estimate = TextAiTokenEstimator.estimate(
      taskType: taskType,
      sourceText: sourceText,
      instruction: instruction,
    );
    return (estimate.outputUpperBound * 2).clamp(4096, 64000);
  }

  static Duration requiredTimeout({
    required TextAiTaskType taskType,
    required String sourceText,
    required String instruction,
  }) =>
      estimate(
        taskType: taskType,
        sourceText: sourceText,
        instruction: instruction,
      ).requestTimeout;

  static Duration _requestTimeout(
    TextAiTaskType taskType,
    int outputUpperBound,
  ) {
    const minimumSeconds = 45;
    const scalingThreshold = 1500;
    const maximumSeconds = 600;
    if (outputUpperBound <= scalingThreshold) {
      return const Duration(seconds: minimumSeconds);
    }

    final tokensPerAdditionalSecond = switch (taskType) {
      TextAiTaskType.general => 30,
      TextAiTaskType.summary => 24,
      TextAiTaskType.simplify => 15,
      TextAiTaskType.tosSummary => 15,
    };
    final additionalTokens = outputUpperBound - scalingThreshold;
    final additionalSeconds =
        (additionalTokens + tokensPerAdditionalSecond - 1) ~/
            tokensPerAdditionalSecond;
    return Duration(
      seconds: (minimumSeconds + additionalSeconds).clamp(
        minimumSeconds,
        maximumSeconds,
      ),
    );
  }

  static int _approximateTokens(String text) =>
      _atLeast(1, (text.runes.length / 4).ceil());

  static int _roundDown(int value) => _atLeast(50, (value ~/ 50) * 50);

  static int _roundUp(int value) => ((value + 49) ~/ 50) * 50;

  static int _atLeast(int minimum, int value) =>
      value < minimum ? minimum : value;
}
