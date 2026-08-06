import 'package:flutter/material.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart'
    show MarkdownEditingController;
import 'package:path/path.dart' as p;
import '../services/document_import_service.dart';
import '../services/credit_account_store.dart';
import '../services/feature_settings.dart';
import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../services/token_estimate.dart';
import '../widgets/markdown_content.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/library_save_dialog.dart';
import '../widgets/report_ai_output_button.dart';
import 'camera_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final LibraryService libraryService;
  final TextAiService textAiService;
  final bool usesRealAi;
  final VoidCallback onConfigureAi;
  final String title;
  final TextAiTaskType? initialPreset;
  final bool allowCustomInstructions;
  final bool showPresets;
  final CreditAccountStore? accountStore;
  final FeatureSettings? featureSettings;

  const HomeScreen({
    super.key,
    required this.libraryService,
    required this.textAiService,
    required this.usesRealAi,
    required this.onConfigureAi,
    this.title = 'Tower Lens',
    this.initialPreset,
    this.allowCustomInstructions = true,
    this.showPresets = true,
    this.accountStore,
    this.featureSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DocumentImportService _documentImportService = DocumentImportService();
  final MarkdownEditingController _sourceTextController =
      MarkdownEditingController();
  final MarkdownEditingController _instructionController =
      MarkdownEditingController();
  String _output = '';
  String? _suggestedTitle;
  String? _importedFilename;
  bool _isImporting = false;
  bool _isRunning = false;
  bool _hasSuccessfulOutput = false;
  TextAiTaskType? _selectedPreset;
  double _simplicityLevel = 0;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset;
  }

  bool get _canRun =>
      !_isImporting &&
      !_isRunning &&
      _sourceTextController.sourceText.trim().isNotEmpty &&
      _effectiveInstruction.trim().isNotEmpty;

  static const Map<TextAiTaskType, String> _presetTasks = {
    TextAiTaskType.summary: 'Summarize',
    TextAiTaskType.simplify: 'Simplify Text',
  };

  TextAiTaskType get _activeTaskType =>
      _selectedPreset ?? TextAiTaskType.general;

  int get _commonWordLimit =>
      10000 - (_simplicityLevel.round() * 1000);

  String get _effectiveInstruction => switch (_selectedPreset) {
        TextAiTaskType.summary => 'Summarize the supplied text.',
        TextAiTaskType.simplify =>
          'Simplify the supplied text using approximately the top '
              '$_commonWordLimit most common English words as the vocabulary '
              'cutoff.',
        _ => _instructionController.sourceText,
      };

  TokenEstimate get _tokenEstimate => TextAiTokenEstimator.estimate(
        taskType: _activeTaskType,
        sourceText: _sourceTextController.sourceText,
        instruction: _effectiveInstruction,
      );

  void _togglePreset(TextAiTaskType taskType) => setState(() {
        if (_selectedPreset == taskType) {
          if (!widget.allowCustomInstructions) return;
          _selectedPreset = null;
          return;
        }
        _selectedPreset = taskType;
        if (taskType == TextAiTaskType.simplify) {
          _simplicityLevel = 0;
        }
      });

  Future<void> _runTask() async {
    if (!_canRun) return;
    if (!_hasEnoughCredits(_tokenEstimate)) return;
    setState(() {
      _isRunning = true;
      _output = '';
      _suggestedTitle = null;
      _hasSuccessfulOutput = false;
    });
    try {
      final result = await widget.textAiService.runTask(
        taskType: _activeTaskType,
        sourceText: _sourceTextController.sourceText,
        instruction: _effectiveInstruction,
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
        _output = 'Sorry, Tower Lens could not complete this task. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  bool _hasEnoughCredits(TokenEstimate estimate) {
    final account = widget.accountStore;
    if (account == null || !account.isSignedIn) return true;
    final required = estimate.requiredStartingBalance;
    if (account.balance >= required) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Not enough credits. This tool requires at least '
          '${_formatCredits(required)} credits to start.',
        ),
      ),
    );
    return false;
  }

  static String _formatCredits(int value) => value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );

  Future<void> _scanText() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScanScreen(
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
          accountStore: widget.accountStore,
          initialHighFidelity:
              widget.featureSettings?.highFidelityDefault ?? false,
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _importedFilename = null;
        _output = '';
        _suggestedTitle = null;
        _hasSuccessfulOutput = false;
        _sourceTextController.value = TextEditingValue(
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
        _sourceTextController.value = TextEditingValue(
          text: document.text,
          selection: TextSelection.collapsed(offset: document.text.length),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${document.filename}. Review it before running.',
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
    if (!mounted) return;
    final destination = await showLibrarySaveDialog(
      context: context,
      libraryService: widget.libraryService,
      defaultFolder: 'General',
      defaultFilename: suggestedLibraryFilename(
        _suggestedTitle,
        fallbackType: 'summary',
      ),
    );
    if (destination == null) return;
    try {
      final entry = await widget.libraryService.saveEntry(
        type: 'general',
        folder: destination.folder,
        filename: destination.filename,
        sourceText: _sourceTextController.sourceText,
        instruction: _effectiveInstruction,
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
    _sourceTextController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
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
                    child: Text('Text to analyze', style: TextStyle(fontWeight: FontWeight.bold)),
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
                controller: _sourceTextController,
                onChanged: (_) => setState(() {}),
                maxLines: 10,
                minLines: 6,
                hintText: 'Paste or type the text you want help with...',
              ),
              const SizedBox(height: 20),
              if (widget.allowCustomInstructions) ...[
                const Text('What do you want done with it?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _selectedPreset == null ? 1 : 0.45,
                  child: MarkdownEditor(
                    controller: _instructionController,
                    onChanged: (_) => setState(() {}),
                    enabled: _selectedPreset == null && !_isRunning,
                    maxLines: 2,
                    hintText: 'e.g. Explain how these ideas connect',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.showPresets)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetTasks.entries
                      .map((preset) => ChoiceChip(
                            label: Text(preset.value),
                            selected: _selectedPreset == preset.key,
                            onSelected: _isRunning
                                ? null
                                : (_) => _togglePreset(preset.key),
                          ))
                      .toList(),
                ),
              if (_selectedPreset == TextAiTaskType.simplify) ...[
                const SizedBox(height: 16),
                Slider(
                  value: _simplicityLevel,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  onChanged: _isRunning
                      ? null
                      : (value) => setState(() => _simplicityLevel = value),
                ),
                const Row(
                  children: [
                    Expanded(child: Text('Highest accuracy')),
                    Expanded(
                      child: Text(
                        'Highest simplicity',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canRun ? _runTask : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isRunning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Run (est. ${_tokenEstimate.buttonLabel})',
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
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: MarkdownContent(
                  data: _output,
                  emptyPlaceholder: 'Results will appear here.',
                ),
              ),
              if (_hasSuccessfulOutput) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: ReportAiOutputButton(output: _output),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
