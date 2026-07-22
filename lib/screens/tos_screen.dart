import 'package:flutter/material.dart';
import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import 'camera_scan_screen.dart';

class TosScreen extends StatefulWidget {
  final LibraryService libraryService;
  final TextAiService textAiService;
  const TosScreen({super.key, required this.libraryService, required this.textAiService});

  @override
  State<TosScreen> createState() => _TosScreenState();
}

class _TosScreenState extends State<TosScreen> {
  final TextEditingController _textController = TextEditingController();
  String _output = '';
  bool _isRunning = false;

  bool get _canRun => !_isRunning && _textController.text.trim().isNotEmpty;

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _textController.text = result);
    }
  }

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() {
      _isRunning = true;
      _output = '';
    });
    try {
      final result = await widget.textAiService.runTask(
        taskType: TextAiTaskType.tosSummary,
        sourceText: _textController.text,
        instruction: 'Summarize ToS/privacy policy',
      );
      if (!mounted) return;
      setState(() => _output = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _output = 'Sorry, Tower Lens could not summarize this text. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _save() async {
    if (!widget.libraryService.isConfigured) {
      final ok = await widget.libraryService.requestPermissionAndPickFolder();
      if (!ok) return;
    }
    await widget.libraryService.saveEntry(
      type: 'tos',
      folder: 'ToS',
      sourceText: _textController.text,
      instruction: 'Summarize ToS/privacy policy',
      output: _output,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Library.')));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ToS / Privacy Mode')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Paste the ToS or privacy policy text', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    onPressed: _isRunning ? null : _scanText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                onChanged: (_) => setState(() {}),
                maxLines: 12,
                minLines: 6,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste text here...'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canRun ? _run : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isRunning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Summarize'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('Output', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (_output.isNotEmpty)
                    TextButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                child: Text(_output.isEmpty ? 'Results will appear here.' : _output),
              ),
              const SizedBox(height: 12),
              Text('Informational summary only -- not legal advice.',
                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}