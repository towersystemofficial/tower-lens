import 'package:flutter/material.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart'
    show MarkdownEditingController;
import 'package:path/path.dart' as p;
import '../services/document_import_service.dart';
import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../services/token_estimate.dart';
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
  final DocumentImportService _documentImportService = DocumentImportService();
  final MarkdownEditingController _textController =
      MarkdownEditingController();
  String _output = '';
  String? _suggestedTitle;
  String? _importedFilename;
  bool _isImporting = false;
  bool _isRunning = false;
  bool _hasSuccessfulOutput = false;

  bool get _canRun =>
      !_isImporting &&
      !_isRunning &&
      _textController.sourceText.trim().isNotEmpty;

  TokenEstimate get _tokenEstimate => TextAiTokenEstimator.estimate(
        taskType: TextAiTaskType.tosSummary,
        sourceText: _textController.sourceText,
        instruction: 'Analyze ToS/privacy policy',
      );

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScanScreen(
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _importedFilename = null;
        _output = '';
        _suggestedTitle = null;
        _hasSuccessfulOutput = false;
        _textController.value = TextEditingValue(
          text: result,
          selection: TextSelection.collapsed(offset: result.length),
        );
      });
    }
  }

  Future<void> _importDocument() async {
    if (_isImporting || _isRunning) return;
    setState(() => _isImporting = true);
    try {
      final document = await _documentImportService.pickDocument();
      if (!mounted || document == null) return;
      setState(() {
        _importedFilename = document.filename;
        _output = '';
        _suggestedTitle = null;
        _hasSuccessfulOutput = false;
        _textController.value = TextEditingValue(
          text: document.text,
          selection: TextSelection.collapsed(offset: document.text.length),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${document.filename}. Review it before summarizing.',
          ),
        ),
      );
    } on DocumentImportException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tower Lens could not import that file.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _run() async {
    if (!_canRun) return;
    setState(() {
      _isRunning = true;
      _output = '';
      _suggestedTitle = null;
      _hasSuccessfulOutput = false;
    });
    try {
      final result = await widget.textAiService.runTask(
        taskType: TextAiTaskType.tosSummary,
        sourceText: _textController.sourceText,
        instruction: 'Analyze ToS/privacy policy',
      );
      if (!mounted) return;
      setState(() {
        _output = result.output;
        _suggestedTitle = _importedFilename == null
            ? result.suggestedTitle
            : p.basenameWithoutExtension(_importedFilename!);
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
      defaultFilename: suggestedLibraryFilename(
        _suggestedTitle,
        fallbackType: 'tos-summary',
      ),
    );
    if (destination == null) return;
    try {
      final entry = await widget.libraryService.saveEntry(
        type: 'tos',
        folder: destination.folder,
        filename: destination.filename,
        sourceText: _textController.sourceText,
        instruction: 'Analyze ToS/privacy policy',
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
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_open_outlined),
                    tooltip: 'Import PDF, TXT, or Markdown',
                    onPressed:
                        _isRunning || _isImporting ? null : _importDocument,
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'Scan text with camera',
                    onPressed:
                        _isRunning || _isImporting ? null : _scanText,
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
                        : Text(
                            'Summarize (est. ${_tokenEstimate.buttonLabel})',
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ),
              if (_tokenEstimate.durationWarning != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tokenEstimate.durationWarning!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
