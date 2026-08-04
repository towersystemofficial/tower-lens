import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/credit_account_store.dart';

class CreditBalanceBadge extends StatelessWidget {
  const CreditBalanceBadge({
    super.key,
    required this.accountStore,
    required this.onTap,
  });

  final CreditAccountStore accountStore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: accountStore,
      builder: (context, _) => Semantics(
        button: true,
        label:
            '${NumberFormat.decimalPattern().format(accountStore.balance)} credits. Open shop.',
        child: ActionChip(
          avatar: const Icon(Icons.toll_outlined, size: 18),
          label: Text(NumberFormat.compact().format(accountStore.balance)),
          tooltip: 'Credit balance',
          onPressed: onTap,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),
    );
  }
}
