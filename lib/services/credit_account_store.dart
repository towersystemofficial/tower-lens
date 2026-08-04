import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only account data plus local refill preferences.
///
/// The production implementation will obtain identity and balance from the
/// server. Balance mutation must never be implemented by the app.
abstract class CreditAccountStore extends ChangeNotifier {
  int get balance;
  bool get isSignedIn;
  bool get firstPurchaseAvailable;
  bool get quickRefillEnabled;
  int get preferredRefillDollars;
  int get lowBalanceThreshold;
  int get monthlyBudgetDollars;

  Future<void> load();
  Future<void> setQuickRefillEnabled(bool value);
  Future<void> setPreferredRefillDollars(int value);
  Future<void> setLowBalanceThreshold(int value);
  Future<void> setMonthlyBudgetDollars(int value);
}

/// Temporary UI implementation used until authentication, balance, and Play
/// purchase verification are available. It intentionally grants no credits.
class PreviewCreditAccountStore extends CreditAccountStore {
  static const _quickRefillKey = 'credit_quick_refill_enabled';
  static const _preferredPackKey = 'credit_preferred_refill_dollars';
  static const _thresholdKey = 'credit_low_balance_threshold';
  static const _budgetKey = 'credit_monthly_budget_dollars';

  bool _quickRefillEnabled = false;
  int _preferredRefillDollars = 5;
  int _lowBalanceThreshold = 50000;
  int _monthlyBudgetDollars = 10;

  @override
  int get balance => 0;

  @override
  bool get isSignedIn => false;

  @override
  bool get firstPurchaseAvailable => true;

  @override
  bool get quickRefillEnabled => _quickRefillEnabled;

  @override
  int get preferredRefillDollars => _preferredRefillDollars;

  @override
  int get lowBalanceThreshold => _lowBalanceThreshold;

  @override
  int get monthlyBudgetDollars => _monthlyBudgetDollars;

  @override
  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _quickRefillEnabled = preferences.getBool(_quickRefillKey) ?? false;
    _preferredRefillDollars = preferences.getInt(_preferredPackKey) ?? 5;
    _lowBalanceThreshold = preferences.getInt(_thresholdKey) ?? 50000;
    _monthlyBudgetDollars = preferences.getInt(_budgetKey) ?? 10;
    notifyListeners();
  }

  @override
  Future<void> setQuickRefillEnabled(bool value) async {
    _quickRefillEnabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_quickRefillKey, value);
  }

  @override
  Future<void> setPreferredRefillDollars(int value) async {
    _preferredRefillDollars = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_preferredPackKey, value);
  }

  @override
  Future<void> setLowBalanceThreshold(int value) async {
    _lowBalanceThreshold = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_thresholdKey, value);
  }

  @override
  Future<void> setMonthlyBudgetDollars(int value) async {
    _monthlyBudgetDollars = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_budgetKey, value);
  }
}
