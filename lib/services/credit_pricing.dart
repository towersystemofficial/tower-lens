class CreditPricing {
  const CreditPricing._();

  static const int usageMultiplierNumerator = 315;
  static const int usageMultiplierDenominator = 100;
  static const int creditsPerDollar = 50000;

  /// The authoritative charge for completed Claude usage.
  ///
  /// The backend must pass the sum of Claude's reported input and output
  /// tokens and debit the returned whole-credit value.
  static int chargeForActualTokens(int providerTokens) =>
      _divideRoundUp(providerTokens * usageMultiplierNumerator,
          usageMultiplierDenominator);

  static int estimateLowerBound(int providerTokens) =>
      _roundDown(chargeForActualTokens(providerTokens), 50);

  static int estimateUpperBound(int providerTokens) =>
      _roundUp(chargeForActualTokens(providerTokens), 50);

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
