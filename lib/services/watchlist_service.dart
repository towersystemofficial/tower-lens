import 'package:shared_preferences/shared_preferences.dart';

class WatchlistService {
  static const _key = 'ingredient_watchlist';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> save(List<String> terms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, terms);
  }
}