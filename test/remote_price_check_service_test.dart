import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tower_lens/models/price_check.dart';
import 'package:tower_lens/services/remote_price_check_service.dart';

void main() {
  const input = PriceCheckInput(
    photos: [], condition: 'Good', testedStatus: 'Tested and working',
    knownIssues: 'None known', quantity: 1, postalCode: '84101',
    country: 'United States', tier: PriceCheckTier.standard,
    guidance: {PriceCheckGuidance.buyer},
  );

  test('research uses staged backend and parses cited evidence', () async {
    late Uri requested;
    final service = RemotePriceCheckService(
      endpoint: Uri.parse('https://backend.example/price-check'),
      client: MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode({'result': {
          'range': r'$60–$90 USD', 'confidence': 'Medium',
          'confidenceReason': 'Comparable evidence varies.', 'context': 'Utah • USD',
          'comparables': [{'source': 'https://example.com/sale', 'title': 'Sold item',
            'price': r'$75', 'status': 'Completed sale', 'condition': 'Good',
            'matchQuality': 'High', 'date': '2026-07-20'}],
          'valueFactors': ['Accessories vary.'], 'noReliableEstimate': false,
        }}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    final result = await service.research(input, const PriceCheckIdentification(
      title: 'Example item', observedFacts: [], userClaims: [], inferences: [], confidence: 'Medium'));
    expect(requested.path, '/price-check/research');
    expect(result.comparables.single.source, 'https://example.com/sale');
  });

  test('backend errors preserve a useful message', () async {
    final service = RemotePriceCheckService(
      endpoint: Uri.parse('https://backend.example/price-check'),
      client: MockClient((_) async => http.Response('{"error":"Try later."}', 429)),
    );
    expect(
      () => service.research(input, const PriceCheckIdentification(
        title: 'Item', observedFacts: [], userClaims: [], inferences: [], confidence: 'Low')),
      throwsA(predicate((error) => error.toString() == 'Try later.')),
    );
  });
}
