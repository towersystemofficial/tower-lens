import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_check.dart';
import '../services/price_check_mock_service.dart';
import '../services/price_check_service.dart';
import '../services/library_service.dart';
import '../widgets/prismatic_surface.dart';
import 'price_check_camera_screen.dart';

typedef PriceCheckCameraPicker = Future<String?> Function(
  BuildContext context,
);
typedef PriceCheckFilePicker = Future<List<String>> Function(int remaining);

enum _PhotoSource { camera, files }

class PriceCheckScreen extends StatefulWidget {
  const PriceCheckScreen({
    super.key,
    this.service = const PriceCheckMockService(),
    this.cameraPicker,
    this.filePicker,
    this.prototypeMode = true,
    this.libraryService,
  });

  final PriceCheckService service;
  final PriceCheckCameraPicker? cameraPicker;
  final PriceCheckFilePicker? filePicker;
  final bool prototypeMode;
  final LibraryService? libraryService;

  @override
  State<PriceCheckScreen> createState() => _PriceCheckScreenState();
}

class _PriceCheckScreenState extends State<PriceCheckScreen> {
  static const _privacyWarningDisabledPreference =
      'price_check_privacy_warning_disabled';
  final _formKey = GlobalKey<FormState>();
  final _issuesController = TextEditingController();
  final _postalController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _descriptionController = TextEditingController();
  final _knownInformationController = TextEditingController();
  final _accessoriesController = TextEditingController();
  final _modificationsController = TextEditingController();
  final _askingPriceController = TextEditingController();
  final _comparisonsController = TextEditingController();
  final _identificationController = TextEditingController();

  final List<String> _photos = [];
  String? _condition;
  String? _testedStatus;
  int _quantity = 1;
  String _country = 'United States';
  PriceCheckTier _tier = PriceCheckTier.standard;
  final Set<PriceCheckGuidance> _guidance = {
    PriceCheckGuidance.buyer,
  };
  PriceCheckMockScenario _scenario = PriceCheckMockScenario.typical;
  bool _showOptional = false;
  bool _busy = false;
  String? _error;
  PriceCheckIdentification? _identification;
  PriceCheckMarketResult? _market;
  PriceCheckGuidanceResult? _buyer;
  PriceCheckGuidanceResult? _seller;
  bool _identificationConfirmed = false;
  bool _hasPreviousRun = false;
  String? _marketChanges;
  String _previousOutputs = '';

  @override
  void dispose() {
    _issuesController.dispose();
    _postalController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _knownInformationController.dispose();
    _accessoriesController.dispose();
    _modificationsController.dispose();
    _askingPriceController.dispose();
    _comparisonsController.dispose();
    _identificationController.dispose();
    super.dispose();
  }

  PriceCheckInput get _input => PriceCheckInput(
        photos: List.unmodifiable(_photos),
        condition: _condition ?? '',
        testedStatus: _testedStatus ?? '',
        knownIssues: _issuesController.text.trim(),
        quantity: _quantity,
        postalCode: _postalController.text.trim(),
        country: _country,
        tier: _tier,
        guidance: Set.unmodifiable(_guidance),
        description: _descriptionController.text.trim(),
        knownInformation: _knownInformationController.text.trim(),
        accessories: _accessoriesController.text.trim(),
        modifications: _modificationsController.text.trim(),
        askingPrice: _askingPriceController.text.trim(),
        comparisonLinks: _comparisonsController.text.trim(),
      );

  bool get _canStart =>
      _photos.isNotEmpty &&
      _guidance.isNotEmpty &&
      _scenario != PriceCheckMockScenario.offline &&
      !_busy;

  void _resetResults() {
    _identification = null;
    _identificationConfirmed = false;
    _market = null;
    _buyer = null;
    _seller = null;
    _marketChanges = null;
    _error = null;
  }

  Future<String?> _takePhoto(BuildContext context) => Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PriceCheckCameraScreen()),
      );

  Future<List<String>> _pickPhotoFiles(int remaining) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose item photos',
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return const [];
    return result.files
        .take(remaining)
        .map((file) => file.path ?? file.name)
        .toList(growable: false);
  }

  Future<void> _addPhotos() async {
    if (_photos.length >= 5) return;
    final source = await showModalBottomSheet<_PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Add photo'),
              subtitle: Text('Use the camera or choose existing image files.'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Open camera'),
              onTap: () => Navigator.pop(context, _PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Upload from files'),
              onTap: () => Navigator.pop(context, _PhotoSource.files),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final additions = switch (source) {
      _PhotoSource.camera => [
          if (await (widget.cameraPicker ?? _takePhoto)(context)
              case final String path)
            path,
        ],
      _PhotoSource.files => await (widget.filePicker ?? _pickPhotoFiles)(
          5 - _photos.length,
        ),
    };
    if (additions.isNotEmpty && mounted) {
      setState(() {
        _photos.addAll(additions.take(5 - _photos.length));
        _resetResults();
      });
    }
  }

  Future<bool> _showPrivacyPreview() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return false;
    if (preferences.getBool(_privacyWarningDisabledPreference) ?? false) {
      return true;
    }
    var doNotShowAgain = false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review before sending'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The selected photos and completed item fields will be sent for '
                  'identification. Photo location metadata will be removed. No market '
                  'research starts until you confirm the identification.',
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey('price-check-warning-dismissal'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: doNotShowAgain,
                  onChanged: (value) => setDialogState(
                    () => doNotShowAgain = value ?? false,
                  ),
                  title: const Text('Do not show again'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('approve-identification-upload'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Identify item'),
            ),
          ],
        ),
      ),
    );
    if (approved == true && doNotShowAgain) {
      await preferences.setBool(_privacyWarningDisabledPreference, true);
    }
    return approved ?? false;
  }

  Future<void> _identify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photos.isEmpty) {
      setState(() => _error = 'Add at least one photo.');
      return;
    }
    if (_guidance.isEmpty) {
      setState(() => _error = 'Select Buyer guidance, Seller guidance, or both.');
      return;
    }
    if (!await _showPrivacyPreview() || !mounted) return;

    setState(() {
      _busy = true;
      _resetResults();
    });
    try {
      final identification = await widget.service.identify(_input, _scenario);
      if (!mounted) return;
      setState(() {
        _identification = identification;
        _identificationController.text = identification.title;
      });
    } on PriceCheckServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PriceCheckMockException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndResearch() async {
    final identification = _identification;
    if (identification == null || identification.gate != PriceCheckGate.clear) {
      return;
    }
    final editedTitle = _identificationController.text.trim();
    if (editedTitle.isEmpty) {
      setState(() => _error = 'Enter or confirm the item identification.');
      return;
    }
    final confirmed = PriceCheckIdentification(
      title: editedTitle,
      observedFacts: identification.observedFacts,
      userClaims: identification.userClaims,
      inferences: identification.inferences,
      confidence: identification.confidence,
    );

    setState(() {
      _busy = true;
      _error = null;
      _identification = confirmed;
      _identificationConfirmed = true;
      _market = null;
      _buyer = null;
      _seller = null;
    });
    try {
      final market = await widget.service.research(_input, confirmed, _scenario);
      PriceCheckGuidanceResult? buyer;
      PriceCheckGuidanceResult? seller;
      if (_guidance.contains(PriceCheckGuidance.buyer)) {
        buyer = await widget.service.analyzeBuyer(market);
      }
      if (_guidance.contains(PriceCheckGuidance.seller)) {
        seller = await widget.service.analyzeSeller(market);
      }
      final marketChanges = _hasPreviousRun
          ? await widget.service.compareMarketChanges(
              priorOutputs: _previousOutputs,
              currentMarket: market,
            )
          : null;
      if (!mounted) return;
      setState(() {
        _market = market;
        _buyer = buyer;
        _seller = seller;
        _marketChanges = marketChanges;
      });
    } on PriceCheckServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PriceCheckMockException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importPreviousRun() async {
    if (!widget.prototypeMode && widget.libraryService != null) {
      await _importSavedRun();
      return;
    }
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import a previous Price Check'),
        content: const ListTile(
          leading: Icon(Icons.folder_outlined),
          title: Text('2026-06-15 – DeWalt drill'),
          subtitle: Text('Mock saved folder • photos and input fields'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-import-price-check'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import folder'),
          ),
        ],
      ),
    );
    if (shouldImport != true || !mounted) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(['Full item photo', 'Model label photo']);
      _condition = 'Good';
      _testedStatus = 'Tested and working';
      _issuesController.text = 'Cosmetic wear; no known functional issues';
      _postalController.text = '84101';
      _country = 'United States';
      _knownInformationController.text = 'DeWalt DCD791 drill/driver';
      _accessoriesController.text = 'Belt clip; no battery or charger';
      _showOptional = true;
      _hasPreviousRun = true;
      _resetResults();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Previous photos and inputs imported. Earlier analysis will only be '
          'used for a market-change comparison after the new run.',
        ),
      ),
    );
  }

  Future<void> _importSavedRun() async {
    final library = widget.libraryService!;
    final folders = await library.listPriceCheckFolders();
    if (!mounted) return;
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved Price Check folders were found.')),
      );
      return;
    }
    final folder = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Import a previous Price Check'),
        children: [
          for (final folder in folders)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, folder),
              child: Text(folder),
            ),
        ],
      ),
    );
    if (folder == null || !mounted) return;
    try {
      final saved = await library.importPriceCheckFolder(folder);
      final input = saved.input;
      setState(() {
        _photos..clear()..addAll(input.photos);
        _condition = input.condition;
        _testedStatus = input.testedStatus;
        _issuesController.text = input.knownIssues;
        _quantity = input.quantity;
        _quantityController.text = '${input.quantity}';
        _postalController.text = input.postalCode;
        _country = input.country;
        _tier = input.tier;
        _guidance..clear()..addAll(input.guidance);
        _descriptionController.text = input.description;
        _knownInformationController.text = input.knownInformation;
        _accessoriesController.text = input.accessories;
        _modificationsController.text = input.modifications;
        _askingPriceController.text = input.askingPrice;
        _comparisonsController.text = input.comparisonLinks;
        _showOptional = true;
        _hasPreviousRun = true;
        _previousOutputs = saved.priorOutputs;
        _resetResults();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Previous photos and inputs imported. Old analysis is reserved for comparison after the new run.')),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not import that Price Check: $error');
    }
  }

  Future<void> _saveMockFolder() async {
    final market = _market;
    if (market == null) return;
    final savedFiles = <String>[
      'saved photos',
      'input-fields.md',
      'market-result.md',
      if (_buyer != null) 'buyer-guidance.md',
      if (_seller != null) 'seller-guidance.md',
      if (_hasPreviousRun) 'market-changes.md',
    ];
    final controller = TextEditingController(
      text: _identificationController.text.trim().isEmpty
          ? 'Price Check'
          : _identificationController.text.trim(),
    );
    final folders = !widget.prototypeMode && widget.libraryService != null
        ? await widget.libraryService!.listAllFolders()
        : <String>[];
    var parentFolder = folders.contains('Price Check') ? 'Price Check' : '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Price Check folder'),
        content: StatefulBuilder(builder: (context, setDialogState) => SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Folder name'),
            ),
            const SizedBox(height: 16),
            if (!widget.prototypeMode) ...[
              DropdownButtonFormField<String>(
                initialValue: parentFolder,
                decoration: const InputDecoration(labelText: 'Save inside'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Library root')),
                  for (final folder in folders) DropdownMenuItem(value: folder, child: Text(folder)),
                ],
                onChanged: (value) => setDialogState(() => parentFolder = value ?? ''),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'This folder will contain:\n'
              '${savedFiles.map((file) => '• $file').join('\n')}',
            ),
          ]),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-save-price-check'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save folder'),
          ),
        ],
      ),
    );
    final folderName = controller.text.trim();
    controller.dispose();
    if (saved == true && mounted) {
      if (!widget.prototypeMode && widget.libraryService != null && _identification != null) {
        try {
          await widget.libraryService!.savePriceCheckFolder(
            parentFolder: parentFolder,
            folderName: folderName,
            input: _input,
            identification: _identification!,
            market: market,
            buyer: _buyer,
            seller: _seller,
            marketChanges: _marketChanges,
          );
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price Check saved to the Library.')));
        } on Object catch (error) {
          if (mounted) setState(() => _error = 'Could not save Price Check: $error');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mock Price Check folder saved to the Library.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Check')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Estimate an ordinary item’s current market range.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.prototypeMode
                      ? 'Prototype mode uses sample results and never uploads photos.'
                      : 'Photos and completed fields are sent only after your review.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.prototypeMode) ...[
                  const SizedBox(height: 16),
                  _PrototypeStateCard(
                    scenario: _scenario,
                    onChanged: (value) => setState(() {
                      _scenario = value;
                      _resetResults();
                    }),
                  ),
                ],
                if (_scenario == PriceCheckMockScenario.offline) ...[
                  const SizedBox(height: 12),
                  const _OfflineCard(),
                ],
                const SizedBox(height: 12),
                _buildPhotosCard(),
                const SizedBox(height: 12),
                _buildRequiredFieldsCard(),
                const SizedBox(height: 12),
                _buildOptionalFieldsCard(),
                const SizedBox(height: 12),
                _buildRunChoicesCard(),
                const SizedBox(height: 12),
                _buildEstimateCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(message: _error!, onRetry: _identify),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(widget.prototypeMode
                        ? 'Running deterministic mock…'
                        : 'Running Price Check…'),
                  ),
                ],
                if (_identification != null) ...[
                  const SizedBox(height: 12),
                  _buildIdentificationCard(_identification!),
                ],
                if (_market != null) ...[
                  const SizedBox(height: 12),
                  _MarketResultCard(result: _market!),
                ],
                if (_buyer != null) ...[
                  const SizedBox(height: 12),
                  _GuidanceCard(result: _buyer!),
                ],
                if (_seller != null) ...[
                  const SizedBox(height: 12),
                  _GuidanceCard(result: _seller!),
                ],
                if (_marketChanges != null) ...[
                  const SizedBox(height: 12),
                  _MarketChangesCard(summary: _marketChanges!),
                ],
                if (_market != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('save-price-check'),
                    onPressed: _saveMockFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Save Price Check folder'),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _importPreviousRun,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Import previous Price Check'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Informational only—not an appraisal, authentication, safety '
                  'inspection, legal opinion, or sale guarantee.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.photo_camera_outlined,
            title: 'Photos',
            subtitle: '${_photos.length}/5 • at least one required',
          ),
          const SizedBox(height: 12),
          if (_photos.isEmpty)
            const Text('Add the full item first. Labels and damage help accuracy.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _photos.length; index++)
                  InputChip(
                    avatar: const Icon(Icons.image_outlined, size: 18),
                    label: Text(p.basename(_photos[index])),
                    onDeleted: _busy
                        ? null
                        : () => setState(() {
                              _photos.removeAt(index);
                              _resetResults();
                            }),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('add-price-check-photo'),
            onPressed: _photos.length >= 5 || _busy ? null : _addPhotos,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_photos.isEmpty ? 'Add required photo' : 'Add another photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredFieldsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.fact_check_outlined,
            title: 'Required item details',
            subtitle: 'Tell the research what the photo cannot.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('price-condition'),
            initialValue: _condition,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: const [
              'New',
              'Like new',
              'Good',
              'Fair',
              'Poor',
              'For parts',
            ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            validator: (value) => value == null ? 'Select a condition.' : null,
            onChanged: _busy ? null : (value) => setState(() => _condition = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('price-tested-status'),
            initialValue: _testedStatus,
            decoration: const InputDecoration(labelText: 'Tested status'),
            items: const [
              'Tested and working',
              'Partially tested',
              'Untested',
              'Not working',
              'Not applicable',
            ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            validator: (value) => value == null ? 'Select a tested status.' : null,
            onChanged: _busy ? null : (value) => setState(() => _testedStatus = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('price-known-issues'),
            controller: _issuesController,
            decoration: const InputDecoration(
              labelText: 'Known issues',
              hintText: 'Damage, missing parts, wear, or “None known”',
            ),
            minLines: 2,
            maxLines: 4,
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Describe known issues or enter “None known”.'
                : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: const ValueKey('price-quantity'),
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');
                    return quantity == null || quantity < 1
                        ? 'Enter a quantity of 1 or more.'
                        : null;
                  },
                  onChanged: (value) {
                    final quantity = int.tryParse(value.trim());
                    if (quantity != null && quantity > 0) {
                      _quantity = quantity;
                      _resetResults();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('price-postal-code'),
                  controller: _postalController,
                  decoration: const InputDecoration(labelText: 'ZIP / postal code'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter a postal code.'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _country,
            decoration: const InputDecoration(labelText: 'Country'),
            items: const [
              'United States',
              'Canada',
              'United Kingdom',
              'Australia',
              'Other',
            ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: _busy ? null : (value) => setState(() => _country = value ?? _country),
          ),
          const SizedBox(height: 8),
          const Text('Prices will use the selected country’s default currency.'),
        ],
      ),
    );
  }

  Widget _buildOptionalFieldsCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _showOptional,
            onChanged: _busy ? null : (value) => setState(() => _showOptional = value),
            title: const Text('Optional accuracy details'),
            subtitle: const Text('Add anything that may improve identification or matching.'),
          ),
          if (_showOptional) ...[
            const SizedBox(height: 8),
            _OptionalField(
              controller: _descriptionController,
              label: 'Description or listing text/link',
              lines: 3,
            ),
            const SizedBox(height: 12),
            _OptionalField(
              controller: _knownInformationController,
              label: 'Known make, model, variant, age, or identifiers',
            ),
            const SizedBox(height: 12),
            _OptionalField(controller: _accessoriesController, label: 'Included accessories'),
            const SizedBox(height: 12),
            _OptionalField(controller: _modificationsController, label: 'User modifications'),
            const SizedBox(height: 12),
            _OptionalField(controller: _askingPriceController, label: 'Asking price'),
            const SizedBox(height: 12),
            _OptionalField(
              controller: _comparisonsController,
              label: 'Comparison links or screenshot notes',
              lines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRunChoicesCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.tune,
            title: 'Run choices',
            subtitle: 'Research depth and guidance are charged separately.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<PriceCheckTier>(
            segments: const [
              ButtonSegment(
                value: PriceCheckTier.standard,
                label: Text('Default'),
                icon: Icon(Icons.manage_search),
              ),
              ButtonSegment(
                value: PriceCheckTier.higherCredit,
                label: Text('In-depth'),
                icon: Icon(Icons.bolt_outlined),
              ),
            ],
            selected: {_tier},
            onSelectionChanged: _busy
                ? null
                : (value) => setState(() {
                      _tier = value.single;
                      _resetResults();
                    }),
          ),
          const SizedBox(height: 8),
          Text(
            _tier == PriceCheckTier.standard
                ? 'Focused identification and cited market research.'
                : 'Broader identification and deeper market research.',
          ),
          const SizedBox(height: 16),
          const Text('Select one or both modes:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                key: const ValueKey('buyer-guidance-chip'),
                selected: _guidance.contains(PriceCheckGuidance.buyer),
                label: const Text('Buyer guidance'),
                avatar: const Icon(Icons.shopping_cart_outlined, size: 18),
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                          selected
                              ? _guidance.add(PriceCheckGuidance.buyer)
                              : _guidance.remove(PriceCheckGuidance.buyer);
                          _resetResults();
                        }),
              ),
              FilterChip(
                key: const ValueKey('seller-guidance-chip'),
                selected: _guidance.contains(PriceCheckGuidance.seller),
                label: const Text('Seller guidance'),
                avatar: const Icon(Icons.sell_outlined, size: 18),
                onSelected: _busy
                    ? null
                    : (selected) => setState(() {
                          selected
                              ? _guidance.add(PriceCheckGuidance.seller)
                              : _guidance.remove(PriceCheckGuidance.seller);
                          _resetResults();
                        }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard() {
    final high = _tier == PriceCheckTier.higherCredit;
    final guidanceCount = _guidance.length;
    final lowTokens = (high ? 4200 : 2200) + (guidanceCount * 700);
    final highTokens = (high ? 7200 : 3900) + (guidanceCount * 1300);
    final minutes = (high ? 4 : 2) + guidanceCount;
    return GlassCard(
      tint: Theme.of(context).colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.schedule_outlined,
            title: 'Estimated run',
            subtitle: widget.prototypeMode
                ? 'Local preview; no API call is made.'
                : 'Estimate scales with research depth and selected modes.',
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatNumber(lowTokens)}–${_formatNumber(highTokens)} tokens',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Allow up to $minutes minutes after identification is confirmed.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('start-price-identification'),
            onPressed: _canStart ? _identify : null,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Review and identify item'),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentificationCard(PriceCheckIdentification result) {
    final stopped = result.gate != PriceCheckGate.clear;
    return GlassCard(
      tint: stopped ? Theme.of(context).colorScheme.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: stopped ? Icons.block : Icons.manage_search,
            title: stopped ? 'Cannot continue' : 'Confirm identification',
            subtitle: stopped
                ? 'No pricing or transaction guidance will be generated.'
                : 'Edit anything incorrect before market research.',
          ),
          const SizedBox(height: 16),
          if (stopped) ...[
            Text(result.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.stopReason!),
          ] else ...[
            TextField(
              key: const ValueKey('editable-identification'),
              controller: _identificationController,
              enabled: !_busy && !_identificationConfirmed,
              decoration: const InputDecoration(labelText: 'Identified item'),
            ),
          ],
          const SizedBox(height: 12),
          Text('Confidence: ${result.confidence}'),
          const SizedBox(height: 12),
          _EvidenceList(title: 'Observed in photos', items: result.observedFacts),
          _EvidenceList(title: 'User-supplied claims', items: result.userClaims),
          _EvidenceList(title: 'AI inferences', items: result.inferences),
          if (!stopped && !_identificationConfirmed) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('confirm-price-identification'),
              onPressed: _busy ? null : _confirmAndResearch,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm and research market'),
            ),
          ],
          if (_identificationConfirmed) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.verified_outlined, size: 18),
                SizedBox(width: 8),
                Text('Identification confirmed'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int value) {
    final text = value.toString();
    return text.length <= 3
        ? text
        : '${text.substring(0, text.length - 3)},${text.substring(text.length - 3)}';
  }
}

class _PrototypeStateCard extends StatelessWidget {
  const _PrototypeStateCard({required this.scenario, required this.onChanged});

  final PriceCheckMockScenario scenario;
  final ValueChanged<PriceCheckMockScenario> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      PriceCheckMockScenario.typical: 'Typical result',
      PriceCheckMockScenario.lowEvidence: 'Low evidence',
      PriceCheckMockScenario.restricted: 'Restricted item',
      PriceCheckMockScenario.specialist: 'Specialist valuation required',
      PriceCheckMockScenario.offline: 'Offline',
      PriceCheckMockScenario.recoverableError: 'Recoverable error',
    };
    return GlassCard(
      tint: Theme.of(context).colorScheme.tertiary,
      child: DropdownButtonFormField<PriceCheckMockScenario>(
        key: const ValueKey('price-mock-scenario'),
        initialValue: scenario,
        decoration: const InputDecoration(
          labelText: 'Prototype state preview',
          helperText: 'Review deterministic UI states before the backend exists.',
        ),
        items: [
          for (final value in PriceCheckMockScenario.values)
            DropdownMenuItem(value: value, child: Text(labels[value]!)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionalField extends StatelessWidget {
  const _OptionalField({required this.controller, required this.label, this.lines = 1});

  final TextEditingController controller;
  final String label;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      minLines: lines,
      maxLines: lines == 1 ? 2 : lines + 2,
    );
  }
}

class _EvidenceList extends StatelessWidget {
  const _EvidenceList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Theme.of(context).colorScheme.error,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: Theme.of(context).colorScheme.error,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Price Check needs an internet connection for every new run. '
              'Saved reports remain available through the Library.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketResultCard extends StatelessWidget {
  const _MarketResultCard({required this.result});

  final PriceCheckMarketResult result;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.insights_outlined,
            title: result.noReliableEstimate
                ? 'No reliable estimate'
                : 'Shared market result',
            subtitle: result.context,
          ),
          const SizedBox(height: 16),
          Text(result.range, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('${result.confidence} confidence — ${result.confidenceReason}'),
          const SizedBox(height: 16),
          Text('Strongest comparables', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final comparable in result.comparables)
            Card(
              child: ListTile(
                title: Text('${comparable.price} • ${comparable.title}'),
                subtitle: Text(
                  '${comparable.status} • ${comparable.condition}\n'
                  '${comparable.source} • ${comparable.date} • '
                  '${comparable.matchQuality} match',
                ),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 12),
          _EvidenceList(title: 'Value factors', items: result.valueFactors),
        ],
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.result});

  final PriceCheckGuidanceResult result;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: result.heading.startsWith('Buyer')
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(result.summary),
          const SizedBox(height: 12),
          for (final entry in result.sections.entries) ...[
            if (result.heading.startsWith('Seller') &&
                (entry.key == 'Draft title' ||
                    entry.key == 'Draft description'))
              TextFormField(
                initialValue: entry.value,
                minLines: entry.key == 'Draft description' ? 3 : 1,
                maxLines: entry.key == 'Draft description' ? 6 : 2,
                decoration: InputDecoration(
                  labelText: entry.key,
                  helperText: 'Editable before saving',
                ),
              )
            else ...[
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(entry.value),
            ],
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MarketChangesCard extends StatelessWidget {
  const _MarketChangesCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.compare_arrows,
            title: 'Market changes since the previous check',
            subtitle: 'Compared only after the new market analysis was complete.',
          ),
          const SizedBox(height: 12),
          Text(summary),
          const SizedBox(height: 8),
          const Text(
            'The prior analysis was not sent into identification, research, or '
            'Buyer/Seller guidance.',
          ),
        ],
      ),
    );
  }
}
