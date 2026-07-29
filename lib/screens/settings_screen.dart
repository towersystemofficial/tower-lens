import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool usesRealAi;
  final VoidCallback onConfigureAi;

  const SettingsScreen({
    super.key,
    required this.usesRealAi,
    required this.onConfigureAi,
  });

  static const _sections = [
    (title: 'Tutorials', icon: Icons.school_outlined),
    (title: 'Accessibility', icon: Icons.accessibility_new_outlined),
    (title: 'Shop', icon: Icons.storefront_outlined),
    (title: 'Contact Developer', icon: Icons.mail_outline),
    (title: 'About App', icon: Icons.info_outline),
    (title: 'ToS', icon: Icons.description_outlined),
  ];

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$title will be filled out in a later redesign increment.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('General Settings'),
            subtitle: Text(
              usesRealAi ? 'Anthropic AI configured' : 'Configure AI access',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onConfigureAi,
          ),
          for (final section in _sections)
            ListTile(
              leading: Icon(section.icon),
              title: Text(section.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openPlaceholder(context, section.title),
            ),
        ],
      ),
    );
  }
}
