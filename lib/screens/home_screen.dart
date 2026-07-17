import 'package:flutter/material.dart';
import '../services/library_service.dart';
import 'camera_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final LibraryService libraryService;
  const HomeScreen({super.key, required this.libraryService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _sourceTextController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  String _output = '';

  static const List<String> _presetTasks = [
    'Summarize',
    'Explain simply',
    'Define jargon',
    'Ask question',
    'Generate report',
  ];

  void _applyPreset(String task) => setState(() => _instructionController.text = task);

  void _runMockTask() {
    setState(() {
      _output = 'Mock response: This is where the app will summarize, explain, '
          'or answer questions about your text.';
    });
  }

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _sourceTextController.text = result);
    }
  }

  Future<void> _saveToLibrary() async {
    if (!widget.libraryService.isConfigured) {
      final ok = await widget.libraryService.requestPermissionAndPickFolder();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Library folder not set up.')));
        }
        return;
      }
    }
    await widget.libraryService.saveEntry(
      type: 'general',
      folder: 'General',
      sourceText: _sourceTextController.text,
      instruction: _instructionController.text,
      output: _output,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library.')));
    }
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tower Lens')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Text to analyze', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'Scan text with camera',
                    onPressed: _scanText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sourceTextController,
                maxLines: 10,
                minLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste or type the text you want help with...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('What do you want done with it?', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _instructionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Summarize this in plain language',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetTasks
                    .map((task) => ActionChip(label: Text(task), onPressed: () => _applyPreset(task)))
                    .toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _runMockTask,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Run'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Output', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (_output.isNotEmpty)
                    TextButton.icon(
                      onPressed: _saveToLibrary,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _output.isEmpty ? 'Results will appear here.' : _output,
                  style: TextStyle(
                    color: _output.isEmpty ? Colors.grey.shade600 : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}