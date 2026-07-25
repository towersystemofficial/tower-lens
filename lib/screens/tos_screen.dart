import 'package:flutter/material.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart'
    show MarkdownEditingController;
import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../widgets/markdown_content.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/library_save_dialog.dart';
import 'camera_scan_screen.dart';

class TosScreen extends StatefulWidget {
  final LibraryService libraryService;
  final TextAiService textAiService;
  final bool usesRealAi;
  final VoidCallback onConfigureAi;

  const TosScreen({
    super.key,
    required this.libraryService,
    required this.textAiService,
    required this.usesRealAi,
    required this.onConfigureAi,
  });

  @override
  State<TosScreen> createState() => _TosScreenState();
}

class _TosScreenState extends State<TosScreen> {
  final MarkdownEditingController _textController =
      MarkdownEditingController();
  String _output = '';
  bool _isRunning = false;
  bool _hasSuccessfulOutput = false;

  bool get _canRun =>
      !_isRunning && _textController.sourceText.trim().isNotEmpty;

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScanScreen()),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _textController.value = TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: result.length),
        );
      });
    }
  }

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() {
      _isRunning = true;
      _output = '';
      _hasSuccessfulOutput = false;
    });
    try {
      final result = await widget.textAiService.runTask(
        taskType: TextAiTaskType.tosSummary,
        sourceText: _textController.sourceText,
        instruction: 'Summarize ToS/privacy policy',
      );
      if (!mounted) return;
      setState(() {
        _output = result;
        _hasSuccessfulOutput = true;
      });
    } on TextAiServiceException catch (error) {
      if (!mounted) return;
      setState(() => _output = error.message);
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
    if (!mounted) return;
    final destination = await showLibrarySaveDialog(
      context: context,
      libraryService: widget.libraryService,
      defaultFolder: 'ToS',
      defaultFilename: generatedLibraryFilename('tos-summary'),
    );
    if (destination == null) return;
    try {
      final entry = await widget.libraryService.saveEntry(
        type: 'tos',
        folder: destination.folder,
        filename: destination.filename,
        sourceText: _textController.sourceText,
        instruction: 'Summarize ToS/privacy policy',
        output: _output,
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
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ToS / Privacy Mode'),
        actions: [
          IconButton(
            tooltip: widget.usesRealAi
                ? 'Real Anthropic AI configured'
                : 'Configure Anthropic API key',
            onPressed: widget.onConfigureAi,
            icon: Icon(
              widget.usesRealAi ? Icons.cloud_done : Icons.key_outlined,
            ),
          ),
        ],
      ),
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
              MarkdownEditor(
                controller: _textController,
                onChanged: (_) => setState(() {}),
                maxLines: 12,
                minLines: 6,
                hintText: 'Paste text here...',
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
                  if (_hasSuccessfulOutput)
                    TextButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save')),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minHeight: 80),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                child: MarkdownContent(
                  data: _output,
                  emptyPlaceholder: 'Results will appear here.',
                ),
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
