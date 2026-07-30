import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/screens/tools_screen.dart';
import 'package:tower_lens/services/library_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/widgets/prismatic_surface.dart';
import 'package:tower_lens/widgets/tool_visual.dart';

void main() {
  testWidgets('launcher shows implemented tools and hides Appraiser',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: ToolsScreen(
          libraryService: LibraryService(),
          textAiService: MockTextAiService(),
          usesRealAi: false,
          onConfigureAi: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text Analysis'), findsOneWidget);
    expect(find.text('ToS Analysis'), findsOneWidget);
    expect(find.text('Allergy Watchlist'), findsOneWidget);
    expect(find.text('Custom Instructions'), findsOneWidget);
    expect(find.byType(ToolVisual), findsNWidgets(4));
    expect(find.text('Appraiser'), findsNothing);
  });

  testWidgets('most-used tool becomes the full-width featured card',
      (tester) async {
    SharedPreferences.setMockInitialValues({'tool_usage.tos_analysis': 3});
    await tester.pumpWidget(
      MaterialApp(
        home: ToolsScreen(
          libraryService: LibraryService(),
          textAiService: MockTextAiService(),
          usesRealAi: false,
          onConfigureAi: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final featuredCard = find.ancestor(
      of: find.text('ToS Analysis'),
      matching: find.byType(GlassCard),
    );
    final featuredSize = find.descendant(
      of: featuredCard,
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 148,
      ),
    );
    expect(featuredSize, findsOneWidget);
    final box = tester.widget<SizedBox>(featuredSize);
    expect(box.height, 148);
  });
}
