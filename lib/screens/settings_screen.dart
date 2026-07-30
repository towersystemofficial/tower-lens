import 'package:flutter/material.dart';

import '../theme/appearance_settings.dart';

class SettingsScreen extends StatelessWidget {
  final bool usesRealAi;
  final VoidCallback onConfigureAi;
  final AppearanceSettings appearanceSettings;

  const SettingsScreen({
    super.key,
    required this.usesRealAi,
    required this.onConfigureAi,
    required this.appearanceSettings,
  });

  static const _sections = [
    (title: 'Tutorials', icon: Icons.school_outlined),
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
            leading: const Icon(Icons.accessibility_new_outlined),
            title: const Text('Accessibility'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => AccessibilitySettingsScreen(
                  settings: appearanceSettings,
                ),
              ),
            ),
          ),
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

class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key, required this.settings});

  final AppearanceSettings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle(title: 'Appearance'),
          SegmentedButton<AppDisplayMode>(
            segments: [
              for (final mode in AppDisplayMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {settings.displayMode},
            onSelectionChanged: (selection) =>
                settings.setDisplayMode(selection.first),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<AppPalette>(
            initialValue: settings.palette,
            decoration: const InputDecoration(
              labelText: 'Color theme',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final palette in AppPalette.values)
                DropdownMenuItem(
                  value: palette,
                  child: Text(palette.label),
                ),
            ],
            onChanged: (value) {
              if (value != null) settings.setPalette(value);
            },
          ),
          const SizedBox(height: 24),
          _SnappingSlider<GlassLevel>(
            title: 'Glass effect',
            values: GlassLevel.values,
            selected: settings.glassLevel,
            label: (value) => value.label,
            onChanged: settings.setGlassLevel,
          ),
          const SizedBox(height: 24),
          _SnappingSlider<AppTextSize>(
            title: 'Text size',
            values: AppTextSize.values,
            selected: settings.textSize,
            label: (value) => value.label,
            onChanged: settings.setTextSize,
          ),
          const SizedBox(height: 24),
          _SnappingSlider<MotionLevel>(
            title: 'Motion',
            values: MotionLevel.values,
            selected: settings.motionLevel,
            label: (value) => value.label,
            onChanged: settings.setMotionLevel,
          ),
          const SizedBox(height: 12),
          Text(
            'Motion controls transitions, ambient light, touch response, '
            'and future tool animations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      );
}

class _SnappingSlider<T> extends StatelessWidget {
  const _SnappingSlider({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(label(selected)),
          ],
        ),
        Slider(
          value: index.toDouble(),
          min: 0,
          max: (values.length - 1).toDouble(),
          divisions: values.length - 1,
          label: label(selected),
          onChanged: (value) => onChanged(values[value.round()]),
        ),
      ],
    );
  }
}
