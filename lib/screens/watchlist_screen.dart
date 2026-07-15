import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/watchlist_service.dart';
import 'camera_scan_screen.dart';

class WatchlistScreen extends StatefulWidget {
  final LibraryService libraryService;
  const WatchlistScreen({super.key, required this.libraryService});

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
  bool _checked = false;

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
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _checkTextController.text = result);
    }
  }

  void _runCheck() {
    final lower = _checkTextController.text.toLowerCase();
    final matches = _watchlist.where((term) => lower.contains(term.toLowerCase())).toList();
    setState(() {
      _matches = matches;
      _checked = true;
    });
  }

  Future<void> _save() async {
    if (!widget.libraryService.isConfigured) {
      final ok = await widget.libraryService.requestPermissionAndPickFolder();
      if (!ok) return;
    }
    final summary =
        _matches.isEmpty ? 'No watchlist matches found in this text.' : 'Watchlist matches found: ${_matches.join(", ")}';
    await widget.libraryService.saveEntry(
      type: 'ingredient',
      folder: 'Ingredient',
      sourceText: _checkTextController.text,
      instruction: 'Check ingredients against watchlist',
      output: summary,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library.')));
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
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste an ingredient list here...'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _watchlist.isEmpty ? null : _runCheck,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Check against watchlist')),
            ),
          ),
          if (_watchlist.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Add items to your watchlist first (My List tab).', style: TextStyle(color: Colors.grey.shade600)),
            ),
          if (_checked) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
                TextButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _matches.isEmpty ? Colors.green : Colors.red),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _matches.isEmpty ? 'No watchlist matches found.' : 'Matches found: ${_matches.join(", ")}',
                style: TextStyle(
                  color: _matches.isEmpty ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}