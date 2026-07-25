// Basic smoke test for the Tower Lens root widget.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tower_lens/main.dart';

void main() {
  testWidgets('TowerLensApp loads and shows the bottom navigation destinations',
      (WidgetTester tester) async {
    // LibraryService.load() reads shared_preferences on startup; seed the
    // test-only mock store so that read resolves instead of throwing
    // MissingPluginException (there's no real platform channel in tests).
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const TowerLensApp());

    // The root shell shows an indeterminate loading spinner until the
    // library service finishes its async load. pumpAndSettle() never
    // settles against an indeterminate spinner's animation, so pump a
    // bounded number of frames instead to let the load complete.
    for (var i = 0; i < 10 && find.text('Home').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify the main navigation destinations are present.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('ToS'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);

    // The app must always launch in dark theme, regardless of system setting.
    final BuildContext context = tester.element(find.text('Home'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('saving an API key dismisses the dialog without an exception',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TowerLensApp());
    for (var i = 0;
        i < 10 &&
            find.byTooltip('Configure Anthropic API key').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(find.byTooltip('Configure Anthropic API key').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'sk-ant-test-key');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Real Anthropic AI configured'), findsOneWidget);
    expect(
      find.text('API key saved. Tower Lens will use real Anthropic responses.'),
      findsOneWidget,
    );
  });
}
