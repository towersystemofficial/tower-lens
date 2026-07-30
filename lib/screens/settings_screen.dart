import 'package:flutter/material.dart';

import '../theme/appearance_settings.dart';
import '../widgets/prismatic_surface.dart';

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
    (
      title: 'Tutorials',
      subtitle: 'Learn how to use Switchboard',
      icon: Icons.school_outlined,
    ),
    (
      title: 'Shop',
      subtitle: 'Plans and future upgrades',
      icon: Icons.storefront_outlined,
    ),
    (
      title: 'Contact Developer',
      subtitle: 'Send feedback or ask for help',
      icon: Icons.mail_outline,
    ),
    (
      title: 'About App',
      subtitle: 'Version and project information',
      icon: Icons.info_outline,
    ),
    (
      title: 'ToS',
      subtitle: 'Read the app terms',
      icon: Icons.description_outlined,
    ),
  ];

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.push<void>(
      context,
      prismaticPageRoute(
        context: context,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _SectionTitle(title: 'Your experience'),
          _SettingsCard(
            icon: Icons.accessibility_new_outlined,
            title: const Text('Accessibility'),
            subtitle: const Text('Appearance, text size, and motion'),
            onTap: () => Navigator.push<void>(
              context,
              prismaticPageRoute(
                context: context,
                builder: (_) => AccessibilitySettingsScreen(
                  settings: appearanceSettings,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.settings_outlined,
            title: const Text('General Settings'),
            subtitle: Text(
              usesRealAi ? 'Anthropic AI configured' : 'Configure AI access',
            ),
            onTap: onConfigureAi,
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'Help and information'),
          for (final section in _sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SettingsCard(
                icon: section.icon,
                title: Text(section.title),
                subtitle: Text(section.subtitle),
                onTap: () => _openPlaceholder(context, section.title),
              ),
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
          const _SectionTitle(title: 'Appearance'),
          _ControlCard(
            title: 'Display mode',
            child: SegmentedButton<AppDisplayMode>(
              segments: [
                for (final mode in AppDisplayMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {settings.displayMode},
              onSelectionChanged: (selection) =>
                  settings.setDisplayMode(selection.first),
            ),
          ),
          const SizedBox(height: 12),
          _ControlCard(
            title: 'Color theme',
            child: DropdownButtonFormField<AppPalette>(
              initialValue: settings.palette,
              decoration: const InputDecoration(
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
          ),
          const SizedBox(height: 12),
          _ControlCard(
            child: _SnappingSlider<GlassLevel>(
              title: 'Glass effect',
              values: GlassLevel.values,
              selected: settings.glassLevel,
              label: (value) => value.label,
              onChanged: settings.setGlassLevel,
            ),
          ),
          const SizedBox(height: 12),
          _ControlCard(
            child: _SnappingSlider<AppTextSize>(
              title: 'Text size',
              values: AppTextSize.values,
              selected: settings.textSize,
              label: (value) => value.label,
              onChanged: settings.setTextSize,
            ),
          ),
          const SizedBox(height: 12),
          _ControlCard(
            child: _SnappingSlider<MotionLevel>(
              title: 'Motion',
              values: MotionLevel.values,
              selected: settings.motionLevel,
              label: (value) => value.label,
              onChanged: settings.setMotionLevel,
            ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleMedium,
                  child: title,
                ),
                const SizedBox(height: 3),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                  child: subtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
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
