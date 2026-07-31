import '../models/price_check.dart';

abstract interface class PriceCheckService {
  Future<PriceCheckIdentification> identify(
    PriceCheckInput input, [
    PriceCheckMockScenario scenario = PriceCheckMockScenario.typical,
  ]);

  Future<PriceCheckMarketResult> research(
    PriceCheckInput input,
    PriceCheckIdentification identification, [
    PriceCheckMockScenario scenario = PriceCheckMockScenario.typical,
  ]);

  Future<PriceCheckGuidanceResult> analyzeBuyer(
    PriceCheckMarketResult market,
  );

  Future<PriceCheckGuidanceResult> analyzeSeller(
    PriceCheckMarketResult market,
  );

  Future<String> compareMarketChanges({
    required String priorOutputs,
    required PriceCheckMarketResult currentMarket,
  });
}

class PriceCheckServiceException implements Exception {
  const PriceCheckServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
