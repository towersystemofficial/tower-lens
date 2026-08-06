class CreditPricing {
  const CreditPricing._();

  static const int usageMultiplierNumerator = 350;
  static const int usageMultiplierDenominator = 100;
  static const int creditsPerDollar = 50000;

  /// The authoritative charge for one AI request.
  ///
  /// A user is charged only when the request produced a usable result. Provider
  /// usage from failed, empty, invalid, or otherwise unusable responses is a
  /// Tower Systems cost and must never be deducted from the user's balance.
  static int chargeForCompletedRequest({
    required int inputTokens,
    required int outputTokens,
    required bool hasUsableOutput,
  }) {
    if (!hasUsableOutput) return 0;
    if (inputTokens < 0 || outputTokens < 0) {
      throw ArgumentError('Reported token usage cannot be negative.');
    }
    return _chargeForProviderTokens(inputTokens + outputTokens);
  }

  static int _chargeForProviderTokens(int providerTokens) =>
      _divideRoundUp(providerTokens * usageMultiplierNumerator,
          usageMultiplierDenominator);

  static int estimateLowerBound(int providerTokens) =>
      _roundDown(_chargeForProviderTokens(providerTokens), 50);

  static int estimateUpperBound(int providerTokens) =>
      _roundUp(_chargeForProviderTokens(providerTokens), 50);

  /// Credits that must be available before a tool may start.
  ///
  /// The highest estimate is deliberately rounded up to the next 1,000 so a
  /// request cannot begin on a balance that only narrowly covers an estimate.
  static int requiredBalanceForEstimate(int estimatedMaximumCredits) {
    if (estimatedMaximumCredits < 0) {
      throw ArgumentError('Estimated credits cannot be negative.');
    }
    return _roundUp(estimatedMaximumCredits, 1000);
  }

  static int normalPurchaseCredits(int wholeDollars) =>
      wholeDollars * creditsPerDollar;

  static int firstPurchaseCredits(int wholeDollars) =>
      normalPurchaseCredits(wholeDollars) * 3 ~/ 2;

  static int _divideRoundUp(int numerator, int denominator) =>
      (numerator + denominator - 1) ~/ denominator;

  static int _roundDown(int value, int interval) => value ~/ interval * interval;

  static int _roundUp(int value, int interval) =>
      _divideRoundUp(value, interval) * interval;
}
