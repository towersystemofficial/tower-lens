import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/credit_account_store.dart';
import '../theme/appearance_settings.dart';
import '../widgets/prismatic_surface.dart';
import 'public_information_screen.dart';
import 'shop_screen.dart';

class SettingsScreen extends StatelessWidget {
  final bool usesRealAi;
  final VoidCallback onConfigureAi;
  final AppearanceSettings appearanceSettings;
  final CreditAccountStore accountStore;

  const SettingsScreen({
    super.key,
    required this.usesRealAi,
    required this.onConfigureAi,
    required this.appearanceSettings,
    required this.accountStore,
  });

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

  void _openInformation(BuildContext context, PublicInformationType type) {
    Navigator.push<void>(
      context,
      prismaticPageRoute(
        context: context,
        builder: (_) => PublicInformationScreen(type: type),
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
            icon: Icons.settings_outlined,
            title: const Text('General Settings'),
            subtitle: Text(
              usesRealAi ? 'Anthropic AI configured' : 'Configure AI access',
            ),
            onTap: onConfigureAi,
          ),
          const SizedBox(height: 10),
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
            icon: Icons.storefront_outlined,
            title: const Text('Shop'),
            subtitle: ListenableBuilder(
              listenable: accountStore,
              builder: (context, _) => Text(
                '${NumberFormat.compact().format(accountStore.balance)} '
                'credits · One-time credit packs',
              ),
            ),
            onTap: () => Navigator.push<void>(
              context,
              prismaticPageRoute(
                context: context,
                builder: (_) => ShopScreen(accountStore: accountStore),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle(title: 'Help and information'),
          _SettingsCard(
            icon: Icons.school_outlined,
            title: const Text('Tutorials'),
            subtitle: const Text('Coming in a separate build step'),
            onTap: () => _openPlaceholder(context, 'Tutorials'),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.info_outline,
            title: const Text('About Tower Lens'),
            subtitle: const Text('Version, purpose, and project information'),
            onTap: () =>
                _openInformation(context, PublicInformationType.about),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.description_outlined,
            title: const Text('Terms of Service'),
            subtitle: const Text('Pre-release terms for using Tower Lens'),
            onTap: () =>
                _openInformation(context, PublicInformationType.terms),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: const Text('Privacy Policy'),
            subtitle: const Text('How local and AI-processed data is handled'),
            onTap: () =>
                _openInformation(context, PublicInformationType.privacy),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.mail_outline,
            title: const Text('Contact Developer'),
            subtitle: const Text('Send a private message'),
            onTap: () =>
                _openInformation(context, PublicInformationType.contact),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.volunteer_activism_outlined,
            title: const Text('Support Developer'),
            subtitle: const Text('Support TowerSys through Ko-fi'),
            onTap: () =>
                _openInformation(context, PublicInformationType.support),
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
