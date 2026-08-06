import 'package:tower_lens/services/credit_account_store.dart';

class TestCreditAccountStore extends CreditAccountStore {
  TestCreditAccountStore({required this.balance, this.isSignedIn = true});

  @override
  final int balance;
  @override
  final bool isSignedIn;
  @override
  bool get firstPurchaseAvailable => false;
  @override
  bool get quickRefillEnabled => false;
  @override
  int get preferredRefillDollars => 5;
  @override
  int get lowBalanceThreshold => 50000;
  @override
  int get monthlyBudgetDollars => 10;

  @override
  Future<void> load() async {}
  @override
  Future<void> setLowBalanceThreshold(int value) async {}
  @override
  Future<void> setMonthlyBudgetDollars(int value) async {}
  @override
  Future<void> setPreferredRefillDollars(int value) async {}
  @override
  Future<void> setQuickRefillEnabled(bool value) async {}
}
