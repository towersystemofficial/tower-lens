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
import 'package:tower_lens/screens/settings_screen.dart';
import 'package:tower_lens/theme/appearance_settings.dart';

void main() {
  testWidgets('first launch opens the tutorial and can be completed',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'appearance_motion_level': 'none',
    });

    await tester.pumpWidget(const TowerLensApp());
    for (var i = 0;
        i < 10 && find.text('Welcome to Tower Lens').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Welcome to Tower Lens'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('TowerLensApp loads and shows the bottom navigation destinations',
      (WidgetTester tester) async {
    // LibraryService.load() reads shared_preferences on startup; seed the
    // test-only mock store so that read resolves instead of throwing
    // MissingPluginException (there's no real platform channel in tests).
    SharedPreferences.setMockInitialValues({
      'appearance_motion_level': 'none',
      'first_launch_tutorial_completed': true,
    });

    // Build our app and trigger a frame.
    await tester.pumpWidget(const TowerLensApp());

    // The root shell shows an indeterminate loading spinner until the
    // library service finishes its async load. pumpAndSettle() never
    // settles against an indeterminate spinner's animation, so pump a
    // bounded number of frames instead to let the load complete.
    for (var i = 0; i < 10 && find.text('Tools').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify the main navigation destinations are present.
    final navigationBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Tools')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Library')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Settings')),
      findsOneWidget,
    );

    // The app follows the system display mode by default.
    final BuildContext context = tester.element(find.text('Tools').first);
    expect(Theme.of(context).brightness, tester.platformDispatcher.platformBrightness);
  });

  testWidgets('saving an API key dismisses the dialog without an exception',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'appearance_motion_level': 'none',
      'first_launch_tutorial_completed': true,
    });

    await tester.pumpWidget(const TowerLensApp());
    for (var i = 0;
        i < 10 &&
            find.text('Settings').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Your experience'), findsOneWidget);
    expect(find.text('Help and information'), findsOneWidget);
    expect(find.text('General Settings'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('General Settings')).dy,
      lessThan(tester.getTopLeft(find.text('Accessibility')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Accessibility')).dy,
      lessThan(tester.getTopLeft(find.text('Shop')).dy),
    );

    await tester.tap(find.text('General Settings'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('High-Fidelity Mode by default'), findsOneWidget);
    await tester.tap(find.text('Configure AI access'));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextFormField), 'sk-ant-test-key');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Anthropic AI configured'), findsOneWidget);
    expect(
      find.text('API key saved. Tower Lens will use real Anthropic responses.'),
      findsOneWidget,
    );

    for (final title in [
      'Tutorials',
      'About Tower Lens',
      'Terms of Service',
      'Privacy Policy',
      'Contact Developer',
      'Planned Features',
      'Support Developer',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('accessibility appearance controls are available',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccessibilitySettingsScreen(
          settings: AppearanceSettings(),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Color theme'), findsOneWidget);
    expect(find.text('Glass effect'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Motion'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Motion'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
  });
}
