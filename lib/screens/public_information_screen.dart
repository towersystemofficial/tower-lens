import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/external_link_service.dart';
import '../widgets/prismatic_surface.dart';

const _kofiUrl = 'https://ko-fi.com/towersys';
const _web3FormsAccessKey = '048fc029-bddf-43ef-9bae-a2564ff4caa2';

class PublicInformationScreen extends StatelessWidget {
  const PublicInformationScreen({
    super.key,
    required this.type,
    this.linkService = const ExternalLinkService(),
    this.contactFormService = const Web3FormsContactFormService(),
  });

  final PublicInformationType type;
  final ExternalLinkService linkService;
  final ContactFormService contactFormService;

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
          PublicInformationType.support => _support(context),
        },
      ),
    );
  }

  List<Widget> _about(BuildContext context) => [
        const _InfoCard(
          title: 'Tower Lens',
          body: 'Version 0.0.63\n\nDeveloper: TowerSys',
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'About the app',
          body: 'Tower Lens is an AI-powered application designed to assist '
              'its users in extracting information from everyday sources. '
              'Paste text, import documents/images, or use your camera to '
              'quickly parse and simplify information.\n\n'
              'Tower Lens is an assistive tool, and is not a replacement for '
              'human faculties or reasoning. It is designed to assist human '
              'capabilities, not replace them, as your ability to reason '
              'exists for a purpose. Because of this, all tools are designed '
              'to convert information into more accessible formats, without '
              'doing any thinking for the users.\n\n'
              'Tower Lens was developed for my own personal use, to do jobs '
              'that would help friends of mine and me. It is designed with a '
              'philosophy of transparency, and catering to the user-first. '
              'All user data is kept as local and private as possible, I '
              'store none of it. The only information that goes onto the '
              'internet is the bare minimum necessary for the AI to process, '
              'and any information you receive from using the app is stored '
              'on your device so you may access it at any time, even without '
              'the app installed.\n\n'
              'Note that AI-generated results may contain mistakes, so legal, '
              'medical, financial, safety, and other important information '
              'should always be verified.',
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
          body: 'Send a private message about Tower Lens.',
        ),
        const SizedBox(height: 12),
        _ContactForm(service: contactFormService),
      ];

  List<Widget> _support(BuildContext context) => [
        _hero(
          context,
          icon: Icons.volunteer_activism_outlined,
          title: 'Support the developer',
          body: 'If Tower Lens helps you, you can support its continued '
              'development through Ko-fi.',
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.volunteer_activism_outlined,
          title: 'Open Ko-fi',
          subtitle: 'ko-fi.com/towersys',
          onTap: () => _openLink(context, _kofiUrl),
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
  contact('Contact Developer'),
  support('Support Developer');

  const PublicInformationType(this.title);
  final String title;
}

abstract class ContactFormService {
  const ContactFormService();

  Future<void> submit({
    required String subject,
    required String message,
    String? email,
  });
}

class Web3FormsContactFormService extends ContactFormService {
  const Web3FormsContactFormService();

  @override
  Future<void> submit({
    required String subject,
    required String message,
    String? email,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.web3forms.com/submit'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'access_key': _web3FormsAccessKey,
        'subject': subject,
        'message': message,
        'from_name': 'Tower Lens contact form',
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Web3Forms rejected the message.');
    }
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({required this.service});

  final ContactFormService service;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.service.submit(
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      _subjectController.clear();
      _messageController.clear();
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent. Thank you!')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your message. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value, String field) =>
      value == null || value.trim().isEmpty ? '$field is required.' : null;

  String? _email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Enter a valid email address.';
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) => _required(value, 'Subject'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 5,
                maxLines: 10,
                validator: (value) => _required(value, 'Message'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  helperText: 'Only include this if you want a reply.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _email,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? 'Sending…' : 'Send message'),
              ),
            ],
          ),
        ),
      );
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
