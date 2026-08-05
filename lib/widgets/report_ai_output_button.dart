import 'package:flutter/material.dart';

import '../screens/public_information_screen.dart';

class ReportAiOutputButton extends StatelessWidget {
  const ReportAiOutputButton({
    super.key,
    required this.output,
  });

  final String output;

  Future<void> _report(BuildContext context) async {
    final includeOutput = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report this result',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'You can include the AI output in your private report, or '
                'send only what you choose to write.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Include AI output'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Do not include output'),
              ),
            ],
          ),
        ),
      ),
    );

    if (includeOutput == null || !context.mounted) return;

    final message = includeOutput
        ? 'Please describe what was offensive or concerning:\n\n'
            '--- AI output ---\n$output'
        : 'Please describe what was offensive or concerning:';

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PublicInformationScreen(
          type: PublicInformationType.contact,
          initialContactSubject: 'Reported AI output',
          initialContactMessage: message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => _report(context),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Report this result'),
      );
}
