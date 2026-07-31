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

  factory PriceCheckInput.fromJson(Map<String, dynamic> json) => PriceCheckInput(
        photos: (json['photos'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        condition: json['condition'] as String? ?? '',
        testedStatus: json['testedStatus'] as String? ?? '',
        knownIssues: json['knownIssues'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        postalCode: json['postalCode'] as String? ?? '',
        country: json['country'] as String? ?? 'United States',
        tier: PriceCheckTier.values.firstWhere(
          (value) => value.name == json['tier'],
          orElse: () => PriceCheckTier.standard,
        ),
        guidance: (json['guidance'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map((name) => PriceCheckGuidance.values.firstWhere(
                  (value) => value.name == name,
                  orElse: () => PriceCheckGuidance.buyer,
                ))
            .toSet(),
        description: json['description'] as String? ?? '',
        knownInformation: json['knownInformation'] as String? ?? '',
        accessories: json['accessories'] as String? ?? '',
        modifications: json['modifications'] as String? ?? '',
        askingPrice: json['askingPrice'] as String? ?? '',
        comparisonLinks: json['comparisonLinks'] as String? ?? '',
      );

  Map<String, dynamic> toJson({List<String>? encodedPhotos}) => {
        'photos': encodedPhotos ?? photos,
        'condition': condition,
        'testedStatus': testedStatus,
        'knownIssues': knownIssues,
        'quantity': quantity,
        'postalCode': postalCode,
        'country': country,
        'tier': tier.name,
        'guidance': guidance.map((value) => value.name).toList(),
        'description': description,
        'knownInformation': knownInformation,
        'accessories': accessories,
        'modifications': modifications,
        'askingPrice': askingPrice,
        'comparisonLinks': comparisonLinks,
      };
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

  factory PriceCheckIdentification.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? const []).whereType<String>().toList();
    return PriceCheckIdentification(
      title: json['title'] as String? ?? '',
      observedFacts: strings('observedFacts'),
      userClaims: strings('userClaims'),
      inferences: strings('inferences'),
      confidence: json['confidence'] as String? ?? 'Low',
      gate: PriceCheckGate.values.firstWhere(
        (value) => value.name == json['gate'],
        orElse: () => PriceCheckGate.clear,
      ),
      stopReason: json['stopReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'observedFacts': observedFacts,
        'userClaims': userClaims,
        'inferences': inferences,
        'confidence': confidence,
        'gate': gate.name,
        if (stopReason != null) 'stopReason': stopReason,
      };
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

  factory PriceCheckComparable.fromJson(Map<String, dynamic> json) =>
      PriceCheckComparable(
        source: json['source'] as String? ?? '',
        title: json['title'] as String? ?? '',
        price: json['price'] as String? ?? '',
        status: json['status'] as String? ?? '',
        condition: json['condition'] as String? ?? '',
        matchQuality: json['matchQuality'] as String? ?? '',
        date: json['date'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'source': source,
        'title': title,
        'price': price,
        'status': status,
        'condition': condition,
        'matchQuality': matchQuality,
        'date': date,
      };
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

  factory PriceCheckMarketResult.fromJson(Map<String, dynamic> json) =>
      PriceCheckMarketResult(
        range: json['range'] as String? ?? '',
        confidence: json['confidence'] as String? ?? 'Low',
        confidenceReason: json['confidenceReason'] as String? ?? '',
        context: json['context'] as String? ?? '',
        comparables: (json['comparables'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PriceCheckComparable.fromJson)
            .toList(),
        valueFactors: (json['valueFactors'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        noReliableEstimate: json['noReliableEstimate'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'range': range,
        'confidence': confidence,
        'confidenceReason': confidenceReason,
        'context': context,
        'comparables': comparables.map((value) => value.toJson()).toList(),
        'valueFactors': valueFactors,
        'noReliableEstimate': noReliableEstimate,
      };
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

  factory PriceCheckGuidanceResult.fromJson(Map<String, dynamic> json) =>
      PriceCheckGuidanceResult(
        heading: json['heading'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        sections: (json['sections'] as Map<String, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key, value.toString())),
      );

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'summary': summary,
        'sections': sections,
      };
}

class PriceCheckPreviousRun {
  const PriceCheckPreviousRun({
    required this.folderPath,
    required this.input,
    required this.priorOutputs,
  });

  final String folderPath;
  final PriceCheckInput input;
  final String priorOutputs;
}
