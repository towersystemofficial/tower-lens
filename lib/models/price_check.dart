enum PriceCheckTier { standard, higherCredit }

enum PriceCheckGuidance { buyer, seller }

enum PriceCheckMockScenario {
  typical,
  lowEvidence,
  restricted,
  specialist,
  offline,
  recoverableError,
}

enum PriceCheckGate { clear, restricted, specialist }

class PriceCheckInput {
  const PriceCheckInput({
    required this.photos,
    required this.condition,
    required this.testedStatus,
    required this.knownIssues,
    required this.quantity,
    required this.postalCode,
    required this.country,
    required this.tier,
    required this.guidance,
    this.description = '',
    this.knownInformation = '',
    this.accessories = '',
    this.modifications = '',
    this.askingPrice = '',
    this.comparisonLinks = '',
  });

  final List<String> photos;
  final String condition;
  final String testedStatus;
  final String knownIssues;
  final int quantity;
  final String postalCode;
  final String country;
  final PriceCheckTier tier;
  final Set<PriceCheckGuidance> guidance;
  final String description;
  final String knownInformation;
  final String accessories;
  final String modifications;
  final String askingPrice;
  final String comparisonLinks;
}

class PriceCheckIdentification {
  const PriceCheckIdentification({
    required this.title,
    required this.observedFacts,
    required this.userClaims,
    required this.inferences,
    required this.confidence,
    this.gate = PriceCheckGate.clear,
    this.stopReason,
  });

  final String title;
  final List<String> observedFacts;
  final List<String> userClaims;
  final List<String> inferences;
  final String confidence;
  final PriceCheckGate gate;
  final String? stopReason;
}

class PriceCheckComparable {
  const PriceCheckComparable({
    required this.source,
    required this.title,
    required this.price,
    required this.status,
    required this.condition,
    required this.matchQuality,
    required this.date,
  });

  final String source;
  final String title;
  final String price;
  final String status;
  final String condition;
  final String matchQuality;
  final String date;
}

class PriceCheckMarketResult {
  const PriceCheckMarketResult({
    required this.range,
    required this.confidence,
    required this.confidenceReason,
    required this.context,
    required this.comparables,
    required this.valueFactors,
    this.noReliableEstimate = false,
  });

  final String range;
  final String confidence;
  final String confidenceReason;
  final String context;
  final List<PriceCheckComparable> comparables;
  final List<String> valueFactors;
  final bool noReliableEstimate;
}

class PriceCheckGuidanceResult {
  const PriceCheckGuidanceResult({
    required this.heading,
    required this.summary,
    required this.sections,
  });

  final String heading;
  final String summary;
  final Map<String, String> sections;
}
