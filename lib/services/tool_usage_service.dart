import 'package:shared_preferences/shared_preferences.dart';

class ToolUsageService {
  const ToolUsageService();

  static const _preferencePrefix = 'tool_usage.';

  Future<Map<String, int>> load(Iterable<String> toolIds) async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final id in toolIds)
        id: preferences.getInt('$_preferencePrefix$id') ?? 0,
    };
  }

  Future<int> increment(String toolId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_preferencePrefix$toolId';
    final count = (preferences.getInt(key) ?? 0) + 1;
    await preferences.setInt(key, count);
    return count;
  }
}
