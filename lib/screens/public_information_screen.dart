import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/external_link_service.dart';
import '../widgets/prismatic_surface.dart';

const _projectUrl = 'https://github.com/towersystemofficial/tower-lens';
const _issuesUrl = 'https://github.com/towersystemofficial/tower-lens/issues';
const _kofiUrl = 'https://ko-fi.com/towersys';

class PublicInformationScreen extends StatelessWidget {
  const PublicInformationScreen({
    super.key,
    required this.type,
    this.linkService = const ExternalLinkService(),
  });

  final PublicInformationType type;
  final ExternalLinkService linkService;

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      await linkService.open(url);
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: switch (type) {
          PublicInformationType.about => _about(context),
          PublicInformationType.terms => _terms(context),
          PublicInformationType.privacy => _privacy(context),
          PublicInformationType.contact => _contact(context),
        },
      ),
    );
  }

  List<Widget> _about(BuildContext context) => [
        _hero(
          context,
          icon: Icons.auto_awesome_outlined,
          title: 'Tower Lens',
          body: 'Scan or paste difficult text and turn it into something '
              'easier to understand.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'What it does',
          body: 'Tower Lens can summarize dense writing, simplify vocabulary, '
              'review Terms of Service and privacy policies, and help inspect '
              'ingredient labels against a personal watchlist.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Built around your data',
          body: 'Your library and watchlist stay on your device unless you '
              'choose an AI-powered action. You control what is saved and can '
              'delete it whenever you want.',
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.code,
          title: 'View the project',
          subtitle: 'Source code, releases, and development progress',
          onTap: () => _openLink(context, _projectUrl),
        ),
        const SizedBox(height: 16),
        Text(
          'Version 0.1.0 (1) · Pre-release beta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];

  List<Widget> _terms(BuildContext context) => [
        _documentNotice(context, 'Pre-release Terms of Service'),
        const _InfoCard(
          title: 'Using Tower Lens',
          body: 'Tower Lens provides automated reading and analysis tools. You '
              'are responsible for the text and images you submit and must '
              'have the right to use them. Do not use the app for unlawful, '
              'abusive, or harmful activity.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'AI output and important decisions',
          body: 'AI and OCR output may be incomplete, inaccurate, or misleading. '
              'Tower Lens does not provide legal, medical, financial, safety, '
              'allergy, authenticity, or appraisal advice. Check original '
              'sources and consult a qualified professional when a decision '
              'could seriously affect you or someone else.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Credits and purchases',
          body: 'Paid credits are consumable and are used when AI requests are '
              'completed. The app shows an estimate before a run; the final '
              'charge is based on actual usage. Purchases and refunds are also '
              'subject to Google Play policies. Subscriptions and automatic '
              'charges are not offered in the beta.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Availability and changes',
          body: 'This is pre-release software. Features may change, fail, or be '
              'temporarily unavailable. These terms may be updated before '
              'public release; material changes will be shown in the app.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Warranty and liability',
          body: 'Tower Lens is provided as available, without guarantees that '
              'it will be error-free or fit a particular purpose. To the extent '
              'allowed by law, the developer is not responsible for indirect '
              'losses caused by relying on app output.',
        ),
      ];

  List<Widget> _privacy(BuildContext context) => [
        _documentNotice(context, 'Pre-release Privacy Policy'),
        const _InfoCard(
          title: 'Stored on your device',
          body: 'Your saved library, watchlist, appearance settings, and refill '
              'preferences are stored locally. Tower Lens does not sell your '
              'personal data or use advertising trackers.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Sent for AI processing',
          body: 'When you choose an AI-powered action, the text needed for that '
              'request is sent for processing. High-Fidelity camera mode also '
              'sends the selected image and recent on-device OCR readings. '
              'Ordinary camera OCR and local watchlist matching remain on-device.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Photos and files',
          body: 'Temporary High-Fidelity images are deleted after processing. '
              'Imported documents are read locally before you choose whether '
              'to run an AI action. Saved results remain in the folder you '
              'selected until you delete them.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Accounts and purchases',
          body: 'The public beta will use Google sign-in to associate verified '
              'purchases, credit balance, and usage charges with an account. '
              'Tower Lens will not receive your Google password or complete '
              'payment-card details.',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Your choices',
          body: 'You can use local features without submitting an AI request, '
              'review text before sending it, delete saved files, and choose '
              'whether to enable High-Fidelity processing. Account deletion '
              'controls will be added when public accounts are connected.',
        ),
      ];

  List<Widget> _contact(BuildContext context) => [
        _hero(
          context,
          icon: Icons.forum_outlined,
          title: 'Contact the developer',
          body: 'Report a problem, request a feature, or ask for help with '
              'Tower Lens.',
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.bug_report_outlined,
          title: 'Feedback and support',
          subtitle: 'Open the Tower Lens issue tracker',
          onTap: () => _openLink(context, _issuesUrl),
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.volunteer_activism_outlined,
          title: 'Support Developer',
          subtitle: 'Help fund development through Ko-fi',
          onTap: () => _openLink(context, _kofiUrl),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Before reporting a bug',
          body: 'Please include what you were trying to do, what happened, your '
              'app version, and whether the problem happens again. Never post '
              'API keys, payment details, private documents, or other sensitive '
              'information in a public issue.',
        ),
      ];

  Widget _documentNotice(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _hero(
          context,
          icon: Icons.gavel_outlined,
          title: title,
          body: 'Last updated August 3, 2026. This document describes the '
              'pre-release build and will be finalized before public release.',
        ),
      );

  Widget _hero(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) =>
      GlassCard(
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      );
}

enum PublicInformationType {
  about('About Tower Lens'),
  terms('Terms of Service'),
  privacy('Privacy Policy'),
  contact('Contact & Support');

  const PublicInformationType(this.title);
  final String title;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.open_in_new),
          ],
        ),
      );
}
