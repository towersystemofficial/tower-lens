import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeatureSettings extends ChangeNotifier {
  static const _highFidelityDefaultKey = 'high_fidelity_ocr_default';

  bool _highFidelityDefault = false;

  bool get highFidelityDefault => _highFidelityDefault;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _highFidelityDefault =
        preferences.getBool(_highFidelityDefaultKey) ?? false;
    notifyListeners();
  }

  Future<void> setHighFidelityDefault(bool value) async {
    if (_highFidelityDefault == value) return;
    _highFidelityDefault = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_highFidelityDefaultKey, value);
  }
}
