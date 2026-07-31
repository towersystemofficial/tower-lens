import '../models/price_check.dart';
import 'price_check_service.dart';

class PriceCheckMockService implements PriceCheckService {
  const PriceCheckMockService({this.delay = const Duration(milliseconds: 250)});

  final Duration delay;

  Future<PriceCheckIdentification> identify(
    PriceCheckInput input,
    [PriceCheckMockScenario scenario = PriceCheckMockScenario.typical],
  ) async {
    await Future<void>.delayed(delay);
    if (scenario == PriceCheckMockScenario.offline) {
      throw const PriceCheckMockException(
        'Price Check needs an internet connection. Saved reports remain '
        'available in your Library.',
      );
    }
    if (scenario == PriceCheckMockScenario.recoverableError) {
      throw const PriceCheckMockException(
        'The mock identification request failed. Your inputs were kept.',
      );
    }
    if (scenario == PriceCheckMockScenario.restricted) {
      return const PriceCheckIdentification(
        title: 'Restricted item detected',
        observedFacts: ['The photo appears to show a regulated item.'],
        userClaims: ['Location information was supplied by the user.'],
        inferences: ['Local restrictions may apply.'],
        confidence: 'Medium',
        gate: PriceCheckGate.restricted,
        stopReason: 'This item may be restricted or illegal in the supplied '
            'location. Tower Lens will not research prices or provide '
            'transaction guidance for it.',
      );
    }
    if (scenario == PriceCheckMockScenario.specialist) {
      return const PriceCheckIdentification(
        title: 'Possible rare or specialist collectible',
        observedFacts: ['Visible age and markings may materially affect value.'],
        userClaims: ['No professional authentication was supplied.'],
        inferences: ['Provenance and an in-person condition review are needed.'],
        confidence: 'Low',
        gate: PriceCheckGate.specialist,
        stopReason: 'This item needs specialist authentication or individualized '
            'valuation. Tower Lens can identify the category, but will not '
            'provide a price estimate.',
      );
    }

    return PriceCheckIdentification(
      title: input.knownInformation.trim().isEmpty
          ? 'DeWalt DCD791 20V MAX XR drill/driver'
          : input.knownInformation.trim(),
      observedFacts: const [
        'Cordless drill/driver with visible DeWalt XR branding',
        'Compact brushless body and belt clip',
      ],
      userClaims: [
        '${input.condition} condition; ${input.testedStatus.toLowerCase()}',
        input.knownIssues.trim().isEmpty
            ? 'No known issues supplied'
            : input.knownIssues.trim(),
      ],
      inferences: const [
        'Likely DCD791 bare-tool configuration; exact kit contents need confirmation',
      ],
      confidence: 'Medium',
    );
  }

  Future<PriceCheckMarketResult> research(
    PriceCheckInput input,
    PriceCheckIdentification identification,
    [PriceCheckMockScenario scenario = PriceCheckMockScenario.typical],
  ) async {
    await Future<void>.delayed(delay);
    if (scenario == PriceCheckMockScenario.recoverableError) {
      throw const PriceCheckMockException(
        'The mock market search failed. Confirmed identification and inputs '
        'were kept so you can retry.',
      );
    }
    final lowEvidence = scenario == PriceCheckMockScenario.lowEvidence;
    return PriceCheckMarketResult(
      range: lowEvidence ? r'$35–$130 USD' : r'$65–$90 USD',
      confidence: lowEvidence ? 'Low' : 'Medium',
      confidenceReason: lowEvidence
          ? 'Only two imperfect active listings were available; no verified '
              'completed sales matched the exact configuration.'
          : 'Several recent sold and active comparables match the likely model, '
              'but battery and charger inclusion varies.',
      context: 'ZIP ${input.postalCode}, ${input.country} • USD • Mock evidence '
          'retrieved July 31, 2026',
      noReliableEstimate: lowEvidence,
      comparables: lowEvidence
          ? const [
              PriceCheckComparable(
                source: 'Example marketplace',
                title: 'Similar XR drill, model uncertain',
                price: r'$59',
                status: 'Active asking price',
                condition: 'Used',
                matchQuality: 'Low',
                date: 'Jul 2026',
              ),
              PriceCheckComparable(
                source: 'Example classifieds',
                title: '20V drill kit',
                price: r'$110',
                status: 'Active asking price',
                condition: 'Good',
                matchQuality: 'Low',
                date: 'Jul 2026',
              ),
            ]
          : const [
              PriceCheckComparable(
                source: 'Example sold listing',
                title: 'DCD791 bare tool',
                price: r'$72',
                status: 'Completed sale',
                condition: 'Used',
                matchQuality: 'High',
                date: 'Jul 2026',
              ),
              PriceCheckComparable(
                source: 'Example marketplace',
                title: 'DCD791 with belt clip',
                price: r'$84',
                status: 'Active asking price',
                condition: 'Good',
                matchQuality: 'High',
                date: 'Jul 2026',
              ),
              PriceCheckComparable(
                source: 'Example sold listing',
                title: '20V XR drill, tool only',
                price: r'$66',
                status: 'Completed sale',
                condition: 'Used',
                matchQuality: 'Medium',
                date: 'Jun 2026',
              ),
            ],
      valueFactors: const [
        'A tested battery and charger can raise the useful package value.',
        'Chuck damage, battery wear, or missing model labels reduce confidence.',
      ],
    );
  }

  Future<PriceCheckGuidanceResult> analyzeBuyer(
    PriceCheckMarketResult market,
  ) async {
    await Future<void>.delayed(delay);
    return const PriceCheckGuidanceResult(
      heading: 'Buyer guidance',
      summary: 'A reasonable deal if it tests cleanly and the configuration '
          'matches the confirmed identification.',
      sections: {
        'Deal assessment': 'The asking price is within the likely market range '
            'for a tested bare tool in this condition.',
        'Opening offer': r'$55–$65',
        'Walk-away ceiling': r'$80–$90',
        'Ask and test': 'Confirm the model label, run it under load, test the '
            'chuck and trigger, and ask about battery age.',
        'Risks': 'Watch for a worn chuck, weak battery, mismatched charger, '
            'removed serial label, or an account/ownership concern.',
        'Accessories and repairs': 'Price a compatible battery, charger, and '
            'chuck repair separately before deciding on a ceiling.',
      },
    );
  }

  Future<PriceCheckGuidanceResult> analyzeSeller(
    PriceCheckMarketResult market,
  ) async {
    await Future<void>.delayed(delay);
    return const PriceCheckGuidanceResult(
      heading: 'Seller guidance',
      summary: 'List with the exact model, included accessories, and honest '
          'test results to stay near the upper half of the range.',
      sections: {
        'Quick sale': r'$55–$70',
        'Fair listing': r'$75–$95',
        'Patient listing': r'$90–$110',
        'Negotiation floor': r'$60–$70',
        'Draft title': 'DeWalt DCD791 20V MAX XR Brushless Drill – Tested',
        'Draft description': 'Tested drill/driver in good used condition. '
            'Describe the exact battery, charger, wear, and known issues here.',
        'Photo and disclosure checklist': 'Photograph both sides, model label, '
            'chuck, battery contacts, accessories, and every damaged area.',
      },
    );
  }

  @override
  Future<String> compareMarketChanges({
    required String priorOutputs,
    required PriceCheckMarketResult currentMarket,
  }) async {
    await Future<void>.delayed(delay);
    return 'The current mock range is slightly narrower than the previous '
        'report. Recent completed sales support the lower half of the old '
        'range; differences in included accessories remain the largest '
        'uncertainty. The prior analysis was not used for the new research.';
  }
}

class PriceCheckMockException implements Exception {
  const PriceCheckMockException(this.message);

  final String message;

  @override
  String toString() => message;
}
