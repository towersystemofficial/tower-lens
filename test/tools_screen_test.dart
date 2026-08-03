import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/screens/tools_screen.dart';
import 'package:tower_lens/services/library_service.dart';
import 'package:tower_lens/services/text_ai_service.dart';
import 'package:tower_lens/widgets/prismatic_surface.dart';
import 'package:tower_lens/widgets/tool_visual.dart';

void main() {
  testWidgets('launcher hides deferred tools and ends with coming soon',
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
    expect(find.text('Price Check'), findsNothing);
    expect(find.text('More features coming soon'), findsOneWidget);
    expect(find.byType(ToolVisual), findsNWidgets(4));

    final cards = find.byType(GlassCard).evaluate().toList();
    final comingSoonCard = find.ancestor(
      of: find.text('More features coming soon'),
      matching: find.byType(GlassCard),
    );
    expect(comingSoonCard.evaluate().single, same(cards.last));
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
        (widget) => widget is SizedBox && widget.height == 184,
      ),
    );
    expect(featuredSize, findsOneWidget);
    final box = tester.widget<SizedBox>(featuredSize);
    expect(box.height, 184);
    expect(tester.getSize(featuredCard).width, 768);

    final visualRegion = find.descendant(
      of: featuredCard,
      matching: find.byKey(
        const ValueKey('featured-tool-visual-region'),
      ),
    );
    expect(visualRegion, findsOneWidget);
    expect(tester.getSize(visualRegion).width, 120);
  });
}
