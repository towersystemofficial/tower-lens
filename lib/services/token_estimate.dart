import 'text_ai_service.dart';

class TokenEstimate {
  const TokenEstimate({
    required this.lowerBound,
    required this.upperBound,
    required this.outputUpperBound,
    this.confidencePercent = 80,
  });

  final int lowerBound;
  final int upperBound;
  final int outputUpperBound;
  final int confidencePercent;

  String get buttonLabel =>
      '${_format(lowerBound)}–${_format(upperBound)} tokens, '
      '$confidencePercent% confidence';

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

  static int _approximateTokens(String text) =>
      _atLeast(1, (text.runes.length / 4).ceil());

  static int _roundDown(int value) => _atLeast(50, (value ~/ 50) * 50);

  static int _roundUp(int value) => ((value + 49) ~/ 50) * 50;

  static int _atLeast(int minimum, int value) =>
      value < minimum ? minimum : value;
}
