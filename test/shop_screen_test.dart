import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/screens/shop_screen.dart';
import 'package:tower_lens/services/credit_account_store.dart';

void main() {
  testWidgets('shop shows balance, packs, bonus, and safe disconnected state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PreviewCreditAccountStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(home: ShopScreen(accountStore: store)));

    expect(find.text('0 credits'), findsOneWidget);
    expect(find.text('First purchase bonus: 1.5× credits'), findsOneWidget);
    for (final price in ['\$1', '\$2', '\$5', '\$10', '\$20']) {
      expect(find.text(price), findsOneWidget);
    }
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('375,000'), findsOneWidget);
    expect(find.textContaining('No subscription.'), findsOneWidget);

    await tester.tap(find.text('Continue with Google to buy'));
    await tester.pump();
    expect(
      find.text('Purchases are not connected yet. Your balance has not changed.'),
      findsOneWidget,
    );
    expect(store.balance, 0);
  });

  testWidgets('custom amount updates first-purchase credits', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = PreviewCreditAccountStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(home: ShopScreen(accountStore: store)));
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '3');
    await tester.pump();

    expect(find.text('\$3 purchase'), findsOneWidget);
    expect(find.text('225,000'), findsOneWidget);
  });
}
