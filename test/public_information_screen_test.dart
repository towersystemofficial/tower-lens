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
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Accounts and purchases'), findsOneWidget);
  });

  testWidgets('contact screen opens Ko-fi through the native link boundary',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PublicInformationScreen(type: PublicInformationType.contact),
      ),
    );

    await tester.tap(find.text('Support Developer'));
    await tester.pump();

    expect(openedUrls, ['https://ko-fi.com/towersys']);
  });
}
