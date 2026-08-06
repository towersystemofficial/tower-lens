import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/library_service.dart';
import 'services/credit_account_store.dart';
import 'services/feature_settings.dart';
import 'services/text_ai_service.dart';
import 'services/text_ai_service_factory.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/tutorial_screen.dart';
import 'theme/appearance_settings.dart';
import 'widgets/prismatic_surface.dart';

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
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: child!,
          ),
        );
      },
      home: RootShell(appearanceSettings: _appearanceSettings),
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
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
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: colorScheme.brightness == Brightness.dark
          ? const Color(0xFF091224)
          : const Color(0xFFF4F6FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: roundedShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: roundedShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: roundedShape),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(roundedShape)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return base.textTheme.labelMedium?.copyWith(
            fontWeight:
                states.contains(WidgetState.selected) ? FontWeight.w700 : null,
          );
        }),
      ),
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
  static const _tutorialCompletedPreference = 'first_launch_tutorial_completed';

  final LibraryService _libraryService = LibraryService();
  final CreditAccountStore _creditAccountStore = PreviewCreditAccountStore();
  final FeatureSettings _featureSettings = FeatureSettings();
  late TextAiService _textAiService;
  int _index = 0;
  bool _ready = false;
  bool _usesRealAi = false;
  String _apiKey = '';
  bool _showFirstLaunchTutorial = false;

  @override
  void dispose() {
    _creditAccountStore.dispose();
    _featureSettings.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      _libraryService.load(),
      _creditAccountStore.load(),
      _featureSettings.load(),
    ]);
    final apiKey = preferences.getString(_anthropicApiKeyPreference) ?? '';
    final tutorialCompleted =
        preferences.getBool(_tutorialCompletedPreference) ?? false;
    if (!mounted) return;
    setState(() {
      _apiKey = apiKey;
      _usesRealAi = apiKey.isNotEmpty || hasBuildTimeAiCredential;
      _textAiService = createTextAiService(apiKey: apiKey);
      _showFirstLaunchTutorial = !tutorialCompleted;
      _ready = true;
    });
  }

  Future<void> _completeTutorial() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_tutorialCompletedPreference, true);
    if (mounted) setState(() => _showFirstLaunchTutorial = false);
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

    if (_showFirstLaunchTutorial) {
      return PrismaticBackground(
        child: TutorialScreen(onComplete: _completeTutorial),
      );
    }

    final screens = [
      ToolsScreen(
        libraryService: _libraryService,
        textAiService: _textAiService,
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
        accountStore: _creditAccountStore,
        featureSettings: _featureSettings,
      ),
      LibraryScreen(libraryService: _libraryService),
      SettingsScreen(
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
        appearanceSettings: widget.appearanceSettings,
        accountStore: _creditAccountStore,
        featureSettings: _featureSettings,
      ),
    ];

    return PrismaticBackground(
      child: Scaffold(
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: GlassNavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Tools',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
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
