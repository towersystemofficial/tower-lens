import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/library_service.dart';
import 'services/text_ai_service.dart';
import 'services/text_ai_service_factory.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'theme/appearance_settings.dart';

void main() {
  runApp(const TowerLensApp());
}

class TowerLensApp extends StatefulWidget {
  const TowerLensApp({super.key});

  @override
  State<TowerLensApp> createState() => _TowerLensAppState();
}

class _TowerLensAppState extends State<TowerLensApp> {
  static const _appearanceChannel =
      MethodChannel('com.example.tower_lens/appearance');

  final AppearanceSettings _appearanceSettings = AppearanceSettings();
  Color? _deviceAccentColor;

  @override
  void initState() {
    super.initState();
    _appearanceSettings.addListener(_refresh);
    _appearanceSettings.load();
    _loadDeviceAccentColor();
  }

  @override
  void dispose() {
    _appearanceSettings
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _loadDeviceAccentColor() async {
    try {
      final colorValue =
          await _appearanceChannel.invokeMethod<int>('getSystemAccentColor');
      if (colorValue != null && mounted) {
        setState(() => _deviceAccentColor = Color(colorValue));
      }
    } on PlatformException {
      // Android versions without wallpaper colors use the default palette.
    } on MissingPluginException {
      // Widget tests and non-Android platforms use the default palette.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPalette = _appearanceSettings.palette;
    final seed = selectedPalette == AppPalette.device
        ? _deviceAccentColor ?? AppPalette.prismatic.seedColor
        : selectedPalette.seedColor;
    final lightScheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF091224),
    );

    return MaterialApp(
      title: 'Switchboard',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(lightScheme),
      darkTheme: _buildTheme(darkScheme),
      themeMode: _appearanceSettings.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final systemScale = mediaQuery.textScaler.scale(16) / 16;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              systemScale * _appearanceSettings.textSize.multiplier,
            ),
          ),
          child: child!,
        );
      },
      home: RootShell(appearanceSettings: _appearanceSettings),
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(fontFamily: 'serif'),
      displayMedium: base.textTheme.displayMedium?.copyWith(fontFamily: 'serif'),
      displaySmall: base.textTheme.displaySmall?.copyWith(fontFamily: 'serif'),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(fontFamily: 'serif'),
      headlineMedium:
          base.textTheme.headlineMedium?.copyWith(fontFamily: 'serif'),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontFamily: 'serif'),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontFamily: 'serif'),
    );
    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.brightness == Brightness.dark
          ? const Color(0xFF091224)
          : const Color(0xFFF4F6FC),
      textTheme: textTheme,
      extensions: [
        GlassStyle.fromLevel(_appearanceSettings.glassLevel),
        MotionStyle.fromLevel(_appearanceSettings.motionLevel),
      ],
    );
  }
}

class RootShell extends StatefulWidget {
  final AppearanceSettings appearanceSettings;

  const RootShell({super.key, required this.appearanceSettings});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _anthropicApiKeyPreference = 'anthropic_api_key';

  final LibraryService _libraryService = LibraryService();
  late TextAiService _textAiService;
  int _index = 0;
  bool _ready = false;
  bool _usesRealAi = false;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final preferences = await SharedPreferences.getInstance();
    await _libraryService.load();
    final apiKey = preferences.getString(_anthropicApiKeyPreference) ?? '';
    if (!mounted) return;
    setState(() {
      _apiKey = apiKey;
      _usesRealAi = apiKey.isNotEmpty || hasBuildTimeAiCredential;
      _textAiService = createTextAiService(apiKey: apiKey);
      _ready = true;
    });
  }

  Future<void> _configureApiKey() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ApiKeyDialog(initialApiKey: _apiKey),
    );
    if (result == null) return;

    final preferences = await SharedPreferences.getInstance();
    if (result.isEmpty) {
      await preferences.remove(_anthropicApiKeyPreference);
    } else {
      await preferences.setString(_anthropicApiKeyPreference, result);
    }
    if (!mounted) return;
    setState(() {
      _apiKey = result;
      _usesRealAi = result.isNotEmpty || hasBuildTimeAiCredential;
      _textAiService = createTextAiService(apiKey: result);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEmpty
              ? 'API key removed. Tower Lens is using mock responses.'
              : 'API key saved. Tower Lens will use real Anthropic responses.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      ToolsScreen(
        libraryService: _libraryService,
        textAiService: _textAiService,
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
      ),
      LibraryScreen(libraryService: _libraryService),
      SettingsScreen(
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
        appearanceSettings: widget.appearanceSettings,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Tools'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  final String initialApiKey;

  const _ApiKeyDialog({required this.initialApiKey});

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late String _apiKey;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _apiKey = widget.initialApiKey;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anthropic API key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Temporary private-development setup. The key is stored in '
            'Tower Lens app settings on this device. Remove it before '
            'sharing the APK or device backup.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _apiKey,
            onChanged: (value) => _apiKey = value,
            obscureText: _obscureText,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: 'sk-ant-...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureText ? 'Show key' : 'Hide key',
                onPressed: () =>
                    setState(() => _obscureText = !_obscureText),
                icon: Icon(
                  _obscureText ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initialApiKey.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Remove key'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _apiKey.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
