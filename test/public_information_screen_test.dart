import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tower_lens/screens/public_information_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.tower_lens/external_links');
  final openedUrls = <String>[];

  setUp(() {
    openedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      openedUrls.add((call.arguments as Map<Object?, Object?>)['url']! as String);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('privacy policy explains local and AI processing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.privacy),
      ),
    );

    expect(find.text('Pre-release Privacy Policy'), findsOneWidget);
    expect(find.text('Stored on your device'), findsOneWidget);
    expect(find.text('Sent for AI processing'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Accounts and purchases'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Accounts and purchases'), findsOneWidget);
  });

  testWidgets('support screen opens Ko-fi through the native link boundary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.support),
      ),
    );

    await tester.tap(find.text('Open Ko-fi'));
    await tester.pump();

    expect(openedUrls, ['https://ko-fi.com/towersys']);
  });

  testWidgets('contact form requires subject and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.contact),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Send message'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Send message'));
    await tester.pump();

    expect(find.text('Subject is required.'), findsOneWidget);
    expect(find.text('Message is required.'), findsOneWidget);
    expect(find.text('Only include this if you want a reply.'), findsOneWidget);
  });

  testWidgets('about screen uses the approved copy and version', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.about),
      ),
    );

    expect(find.textContaining('Version 0.0.64'), findsOneWidget);
    expect(find.textContaining('Developer: TowerSys'), findsOneWidget);
    expect(find.textContaining('human faculties or reasoning'), findsOneWidget);
    expect(find.text('View the project'), findsNothing);
  });

  testWidgets('reported output prefills the contact form', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(
          type: PublicInformationType.contact,
          initialContactSubject: 'Reported AI output',
          initialContactMessage: 'Example output',
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.controller?.text == 'Reported AI output',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField &&
            widget.controller?.text == 'Example output',
      ),
      findsOneWidget,
    );
  });

  testWidgets('terms explain the 3.5-times credit charge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.terms),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Credits and purchases'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.textContaining('multiplied by 3.5'), findsOneWidget);
    expect(find.textContaining('no credits are deducted'), findsOneWidget);
    expect(
      find.textContaining('Tower Systems absorbs that cost'),
      findsOneWidget,
    );
    expect(find.textContaining('direct AI processing costs'), findsOneWidget);
    expect(
      find.textContaining('server and infrastructure costs'),
      findsOneWidget,
    );
    expect(find.textContaining('developer compensation'), findsOneWidget);
    expect(find.textContaining('Google Play service fees'), findsOneWidget);
  });
}
