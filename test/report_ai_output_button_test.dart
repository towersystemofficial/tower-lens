import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tower_lens/widgets/report_ai_output_button.dart';

void main() {
  testWidgets('reporter lets the user include generated output', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReportAiOutputButton(output: 'Generated example'),
        ),
      ),
    );

    await tester.tap(find.text('Report this result'));
    await tester.pumpAndSettle();

    expect(find.text('Include AI output'), findsOneWidget);
    expect(find.text('Do not include output'), findsOneWidget);

    await tester.tap(find.text('Include AI output'));
    await tester.pumpAndSettle();

    expect(find.text('Contact Developer'), findsOneWidget);
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
            widget.controller?.text.contains('Generated example') == true,
      ),
      findsOneWidget,
    );
  });
}
