import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/credit_account_store.dart';
import '../services/credit_pricing.dart';
import '../widgets/prismatic_surface.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.accountStore});

  final CreditAccountStore accountStore;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _presetDollars = [1, 2, 5, 10, 20];
  final _customController = TextEditingController();
  int _selectedDollars = 5;
  bool _customSelected = false;

  int get _purchaseDollars {
    if (!_customSelected) return _selectedDollars;
    return int.tryParse(_customController.text) ?? 0;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _notConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Purchases are not connected yet. Your balance has not changed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.accountStore;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListenableBuilder(
        listenable: account,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            GlassCard(
              tint: colors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your balance',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.toll_outlined, color: colors.primary, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${NumberFormat.decimalPattern().format(account.balance)} credits',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    account.isSignedIn
                        ? 'Your server balance will appear here.'
                        : 'Sign in when purchasing to keep credits across devices.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Choose credits', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'One-time purchases only. No subscription.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (account.firstPurchaseAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration_outlined,
                      color: colors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'First purchase bonus: 1.5× credits',
                        style: TextStyle(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final dollars in _presetDollars)
                  ChoiceChip(
                    label: Text('\$$dollars'),
                    selected: !_customSelected && _selectedDollars == dollars,
                    onSelected: (_) => setState(() {
                      _customSelected = false;
                      _selectedDollars = dollars;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _customSelected,
                  onSelected: (_) => setState(() => _customSelected = true),
                ),
              ],
            ),
            if (_customSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Whole-dollar amount',
                  prefixText: '\$ ',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 14),
            _PurchaseSummary(
              dollars: _purchaseDollars,
              showBonus: account.firstPurchaseAvailable,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _purchaseDollars > 0 ? _notConnected : null,
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                account.isSignedIn ? 'Buy with Google Play' : 'Continue with Google to buy',
              ),
            ),
            const SizedBox(height: 28),
            Text('Quick refill', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'When your balance is low, Switchboard can prompt you to '
              'refill. Google Play will still ask you to confirm every '
              'purchase.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prompt me when credits are low'),
                    value: account.quickRefillEnabled,
                    onChanged: account.setQuickRefillEnabled,
                  ),
                  const Divider(),
                  DropdownButtonFormField<int>(
                    initialValue: account.preferredRefillDollars,
                    decoration: const InputDecoration(
                      labelText: 'Preferred refill',
                    ),
                    items: [
                      for (final dollars in _presetDollars)
                        DropdownMenuItem(value: dollars, child: Text('\$$dollars')),
                    ],
                    onChanged: (value) {
                      if (value != null) account.setPreferredRefillDollars(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: account.lowBalanceThreshold,
                    decoration: const InputDecoration(
                      labelText: 'Low balance threshold',
                    ),
                    items: const [10000, 25000, 50000, 100000]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('${NumberFormat.compact().format(value)} credits'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) account.setLowBalanceThreshold(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: account.monthlyBudgetDollars,
                    decoration: const InputDecoration(
                      labelText: 'Monthly spending ceiling',
                    ),
                    items: const [1, 2, 5, 10, 20, 50]
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text('\$$value per month'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) account.setMonthlyBudgetDollars(value);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseSummary extends StatelessWidget {
  const _PurchaseSummary({required this.dollars, required this.showBonus});

  final int dollars;
  final bool showBonus;

  @override
  Widget build(BuildContext context) {
    final normalCredits = CreditPricing.normalPurchaseCredits(dollars);
    final grantedCredits = showBonus
        ? CreditPricing.firstPurchaseCredits(dollars)
        : normalCredits;
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dollars > 0 ? '\$$dollars purchase' : 'Enter an amount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (showBonus && dollars > 0)
                  Text(
                    '${NumberFormat.decimalPattern().format(normalCredits)} + '
                    '${NumberFormat.decimalPattern().format(grantedCredits - normalCredits)} bonus',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            NumberFormat.decimalPattern().format(grantedCredits),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.toll_outlined),
        ],
      ),
    );
  }
}
