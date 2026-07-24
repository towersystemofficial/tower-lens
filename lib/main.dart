import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/library_service.dart';
import 'services/text_ai_service.dart';
import 'services/text_ai_service_factory.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/tos_screen.dart';
import 'screens/watchlist_screen.dart';

void main() {
  runApp(const TowerLensApp());
}

class TowerLensApp extends StatelessWidget {
  const TowerLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tower Lens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

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
    final controller = TextEditingController(text: _apiKey);
    var obscureText = true;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
              TextField(
                controller: controller,
                obscureText: obscureText,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API key',
                  hintText: 'sk-ant-...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: obscureText ? 'Show key' : 'Hide key',
                    onPressed: () =>
                        setDialogState(() => obscureText = !obscureText),
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (_apiKey.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, ''),
                child: const Text('Remove key'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
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
      HomeScreen(
        libraryService: _libraryService,
        textAiService: _textAiService,
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
      ),
      LibraryScreen(libraryService: _libraryService),
      TosScreen(
        libraryService: _libraryService,
        textAiService: _textAiService,
        usesRealAi: _usesRealAi,
        onConfigureAi: _configureApiKey,
      ),
      WatchlistScreen(libraryService: _libraryService),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.gavel_outlined), selectedIcon: Icon(Icons.gavel), label: 'ToS'),
          NavigationDestination(icon: Icon(Icons.warning_amber_outlined), selectedIcon: Icon(Icons.warning_amber), label: 'Watchlist'),
        ],
      ),
    );
  }
}
