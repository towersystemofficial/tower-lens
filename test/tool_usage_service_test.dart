import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tower_lens/services/tool_usage_service.dart';

void main() {
  test('tool usage counts persist under stable tool IDs', () async {
    SharedPreferences.setMockInitialValues({});
    const service = ToolUsageService();

    expect(
      await service.load(['text_analysis', 'tos_analysis']),
      {'text_analysis': 0, 'tos_analysis': 0},
    );

    expect(await service.increment('tos_analysis'), 1);
    expect(await service.increment('tos_analysis'), 2);
    expect(
      await service.load(['text_analysis', 'tos_analysis']),
      {'text_analysis': 0, 'tos_analysis': 2},
    );
  });
}
