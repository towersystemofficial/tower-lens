import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_lens/models/price_check.dart';
import 'package:tower_lens/screens/price_check_screen.dart';
import 'package:tower_lens/services/price_check_mock_service.dart';

void main() {
  Widget buildScreen() => const MaterialApp(
        home: PriceCheckScreen(
          service: PriceCheckMockService(delay: Duration.zero),
        ),
      );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeRequiredInputs(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add-price-check-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full item photo'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const ValueKey('price-condition')));
    await tester.tap(find.byKey(const ValueKey('price-condition')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('price-tested-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tested and working').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('price-known-issues')),
      'None known',
    );
    await tester.enterText(
      find.byKey(const ValueKey('price-postal-code')),
      '84101',
    );
  }

  testWidgets('mock flow confirms identification before market research',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await completeRequiredInputs(tester);

    await scrollTo(
      tester,
      find.byKey(const ValueKey('seller-guidance-chip')),
    );
    await tester.tap(find.byKey(const ValueKey('seller-guidance-chip')));
    await tester.pump();

    await scrollTo(
      tester,
      find.byKey(const ValueKey('start-price-identification')),
    );
    await tester.tap(find.byKey(const ValueKey('start-price-identification')));
    await tester.pumpAndSettle();
    expect(find.text('Review before sending'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('approve-identification-upload')),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Confirm identification'));
    expect(find.text('Confirm identification'), findsOneWidget);
    expect(find.text('Shared market result'), findsNothing);

    await scrollTo(
      tester,
      find.byKey(const ValueKey('confirm-price-identification')),
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-price-identification')),
    );
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Shared market result'));
    expect(find.text('Shared market result'), findsOneWidget);
    await scrollTo(tester, find.text('Buyer guidance'));
    expect(find.text('Buyer guidance'), findsOneWidget);
    await scrollTo(tester, find.text('Seller guidance'));
    expect(find.text('Seller guidance'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('save-price-check')));
    expect(find.byKey(const ValueKey('save-price-check')), findsOneWidget);
  });

  testWidgets('previous run import fills editable photos and inputs',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await scrollTo(tester, find.text('Import previous Price Check'));
    await tester.tap(find.text('Import previous Price Check'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-import-price-check')),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Full item photo'));
    expect(find.text('Full item photo'), findsOneWidget);
    expect(find.text('Model label photo'), findsOneWidget);
    await scrollTo(
      tester,
      find.byKey(const ValueKey('price-postal-code')),
    );
    final postal = tester.widget<TextFormField>(
      find.byKey(const ValueKey('price-postal-code')),
    );
    expect(postal.controller?.text, '84101');
  });

  test('mock service exposes restricted and low-evidence states', () async {
    const service = PriceCheckMockService(delay: Duration.zero);
    const input = PriceCheckInput(
      photos: ['photo'],
      condition: 'Good',
      testedStatus: 'Tested and working',
      knownIssues: 'None known',
      quantity: 1,
      postalCode: '84101',
      country: 'United States',
      tier: PriceCheckTier.standard,
      guidance: {PriceCheckGuidance.buyer},
    );

    final restricted = await service.identify(
      input,
      PriceCheckMockScenario.restricted,
    );
    expect(restricted.gate, PriceCheckGate.restricted);

    final identified = await service.identify(
      input,
      PriceCheckMockScenario.typical,
    );
    final weak = await service.research(
      input,
      identified,
      PriceCheckMockScenario.lowEvidence,
    );
    expect(weak.noReliableEstimate, isTrue);
    expect(weak.range, isNotEmpty);
  });
}
