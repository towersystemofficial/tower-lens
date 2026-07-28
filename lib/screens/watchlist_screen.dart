import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/library_save_dialog.dart';
import 'camera_scan_screen.dart';

class WatchlistScreen extends StatefulWidget {
  final LibraryService libraryService;
  final TextAiService textAiService;
  final bool usesRealAi;

  const WatchlistScreen({
    super.key,
    required this.libraryService,
    required this.textAiService,
    required this.usesRealAi,
  });

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> with SingleTickerProviderStateMixin {
  final WatchlistService _watchlistService = WatchlistService();
  late TabController _tabController;
  List<String> _watchlist = [];
  final TextEditingController _newTermController = TextEditingController();
  final TextEditingController _checkTextController = TextEditingController();
  List<String> _matches = [];
  String? _analysis;
  String? _checkError;
  bool _checked = false;
  bool _isChecking = false;

  static const _suggestions = ['gluten', 'wheat', 'barley', 'rye', 'soy', 'peanuts', 'dairy', 'shellfish'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    final list = await _watchlistService.load();
    setState(() => _watchlist = list);
  }

  Future<void> _addTerm(String term) async {
    final t = term.trim();
    if (t.isEmpty || _watchlist.map((w) => w.toLowerCase()).contains(t.toLowerCase())) return;
    final updated = [..._watchlist, t];
    await _watchlistService.save(updated);
    setState(() {
      _watchlist = updated;
      _newTermController.clear();
    });
  }

  Future<void> _removeTerm(String term) async {
    final updated = _watchlist.where((t) => t != term).toList();
    await _watchlistService.save(updated);
    setState(() => _watchlist = updated);
  }

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScanScreen(
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
          requireHighFidelity: true,
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _checkTextController.text = result);
    }
  }

  Future<void> _runCheck() async {
    final sourceText = _checkTextController.text.trim();
    if (sourceText.isEmpty || _isChecking) return;
    final lower = sourceText.toLowerCase();
    final matches = _watchlist
        .where((term) => lower.contains(term.toLowerCase()))
        .toList();
    setState(() {
      _matches = matches;
      _analysis = null;
      _checkError = null;
      _checked = true;
      _isChecking = true;
    });

    if (!widget.usesRealAi || widget.textAiService is! WatchlistAiService) {
      setState(() => _isChecking = false);
      return;
    }

    try {
      final analysis =
          await (widget.textAiService as WatchlistAiService).analyzeWatchlist(
        sourceText: sourceText,
        watchlist: List<String>.unmodifiable(_watchlist),
      );
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } on TextAiServiceException catch (error) {
      if (!mounted) return;
      setState(() => _checkError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkError =
            'The AI analysis could not be completed. The local exact-match '
            'result is still shown below.';
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _save() async {
    if (!widget.libraryService.isConfigured) {
      final ok = await widget.libraryService.requestPermissionAndPickFolder();
      if (!ok) return;
    }
    final localSummary = _matches.isEmpty
        ? 'No local exact watchlist matches found in this text.'
        : 'Local exact watchlist matches: ${_matches.join(", ")}';
    final summary = _analysis == null
        ? '**Important:** This tool can make allergens easier to find, but it '
            'does not replace personally checking the original label.\n\n'
            '$localSummary'
        : _analysis!;
    if (!mounted) return;
    final destination = await showLibrarySaveDialog(
      context: context,
      libraryService: widget.libraryService,
      defaultFolder: 'Ingredient',
      defaultFilename: generatedLibraryFilename('ingredient-check'),
    );
    if (destination == null) return;
    try {
      final entry = await widget.libraryService.saveEntry(
        type: 'ingredient',
        folder: destination.folder,
        filename: destination.filename,
        sourceText: _checkTextController.text,
        instruction: 'Check ingredients against watchlist',
        output: summary,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${entry.filename} to Library.')),
        );
      }
    } on LibraryFileExistsException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A file with that name already exists in this folder.'),
          ),
        );
      }
    } on ArgumentError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a valid filename.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newTermController.dispose();
    _checkTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredient Watchlist'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'My List'), Tab(text: 'Check Text')]),
      ),
      body: TabBarView(controller: _tabController, children: [_buildListTab(), _buildCheckTab()]),
    );
  }

  Widget _buildListTab() {
    final unusedSuggestions =
        _suggestions.where((s) => !_watchlist.map((w) => w.toLowerCase()).contains(s)).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTermController,
                  decoration: const InputDecoration(
                    hintText: 'Add an ingredient or allergen...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _addTerm,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _addTerm(_newTermController.text), child: const Text('Add')),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Your watchlist', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _watchlist.isEmpty
              ? Text('Nothing added yet.', style: TextStyle(color: Colors.grey.shade600))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _watchlist.map((term) => Chip(label: Text(term), onDeleted: () => _removeTerm(term))).toList(),
                ),
          if (unusedSuggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Common allergens', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unusedSuggestions
                  .map((term) => ActionChip(
                        label: Text(term),
                        avatar: const Icon(Icons.add, size: 16),
                        onPressed: () => _addTerm(term),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Paste ingredient text', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.camera_alt_outlined), onPressed: _scanText),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _checkTextController,
            maxLines: 8,
            minLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste an ingredient list here...',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _watchlist.isEmpty || _isChecking
                  ? null
                  : _runCheck,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _isChecking
                      ? 'Running three safety checks…'
                      : 'Check against watchlist',
                ),
              ),
            ),
          ),
          if (_watchlist.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Add items to your watchlist first (My List tab).', style: TextStyle(color: Colors.grey.shade600)),
            ),
          if (_isChecking) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text(
              'Claude is running three independent checks, then synthesizing them.',
            ),
          ],
          if (_checked) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Result',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isChecking ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _analysis ??
                    '**Important:** This tool can make allergens easier to find, '
                        'but it does not replace personally checking the original '
                        'label.\n\n'
                        '${_matches.isEmpty ? "No local exact watchlist matches found." : "Local exact matches: ${_matches.join(", ")}"}'
                        '${widget.usesRealAi ? "" : "\n\nConfigure an Anthropic API key for categorical and contextual analysis."}',
              ),
            ),
            if (_checkError != null) ...[
              const SizedBox(height: 8),
              Text(
                _checkError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
