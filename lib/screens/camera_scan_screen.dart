import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:markdown_editor_live/markdown_editor_live.dart'
    show MarkdownEditingController;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/text_ai_service.dart';
import '../widgets/markdown_editor.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({
    super.key,
    required this.textAiService,
    required this.usesRealAi,
    this.requireHighFidelity = false,
  });

  final TextAiService textAiService;
  final bool usesRealAi;
  final bool requireHighFidelity;

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  static const _privacyAcknowledgedPreference =
      'high_fidelity_ocr_privacy_acknowledged';

  CameraController? _controller;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  bool _isDetecting = false;
  bool _permissionDenied = false;
  String? _setupError;
  bool _frozen = false;
  bool _highFidelity = false;
  bool _isChangingMode = false;
  bool _isProcessingFreeze = false;
  String _liveText = '';
  String _processingMessage = '';
  final List<String> _previousCaptures = [];
  final MarkdownEditingController _resultController =
      MarkdownEditingController();

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _permissionDenied = true);
      return;
    }
    if (widget.requireHighFidelity) {
      if (!widget.usesRealAi ||
          widget.textAiService is! HighFidelityOcrService) {
        setState(() {
          _setupError =
              'Watchlist scanning requires a configured Anthropic API key '
              'because High-Fidelity OCR is always enabled.';
        });
        return;
      }
      if (!await _acknowledgeHighFidelityPrivacy()) {
        if (mounted) {
          setState(() {
            _setupError =
                'Accept the High-Fidelity privacy notice to scan a Watchlist label.';
          });
        }
        return;
      }
      _highFidelity = true;
      await _initializeCamera(ResolutionPreset.max);
      return;
    }
    await _initializeCamera(ResolutionPreset.medium);
  }

  Future<void> _initializeCamera(ResolutionPreset resolution) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final controller = CameraController(
      cameras.first,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
    await controller.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isDetecting || _frozen || _controller == null) return;
    _isDetecting = true;
    try {
      final inputImage = _toInputImage(image, _controller!.description);
      if (inputImage != null) {
        final result = await _recognizer.processImage(inputImage);
        if (mounted && !_frozen) {
          setState(() {
            final currentText = _liveText.trim();
            if (currentText.isNotEmpty) {
              _previousCaptures.add(currentText);
              if (_previousCaptures.length > 5) {
                _previousCaptures.removeAt(0);
              }
            }
            _liveText = result.text;
          });
        }
      }
    } catch (_) {
      // Drop a bad frame rather than crash the live preview.
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final builder = BytesBuilder();
    for (final plane in image.planes) {
      builder.add(plane.bytes);
    }
    final bytes = builder.toBytes();
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.nv21;
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Future<void> _freeze() async {
    if (_controller == null || _isProcessingFreeze) return;
    final frozenText = _liveText.trim();
    final earlierCaptures = List<String>.unmodifiable(_previousCaptures);
    setState(() {
      _isProcessingFreeze = true;
      _processingMessage =
          _highFidelity ? 'Capturing image…' : 'Freezing text…';
    });
    try {
      await _controller!.stopImageStream();
    } on CameraException {
      if (!mounted) return;
      setState(() {
        _isProcessingFreeze = false;
        _processingMessage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The camera could not freeze this scan.')),
      );
      return;
    }

    var result = frozenText;
    String? failureMessage;
    if (_highFidelity) {
      XFile? photo;
      try {
        photo = await _controller!.takePicture();
        if (mounted) {
          setState(() => _processingMessage =
              'Claude is reconstructing the scanned text…');
        }
        final highFidelityService =
            widget.textAiService as HighFidelityOcrService;
        result = await highFidelityService.reconstructScannedText(
          frozenOcrText: frozenText,
          previousOcrCaptures: earlierCaptures,
          imageBytes: await photo.readAsBytes(),
          imageMediaType: 'image/jpeg',
        );
      } on CameraException {
        failureMessage =
            'The photo could not be captured. Using the local OCR result.';
      } on TextAiServiceException catch (error) {
        failureMessage = '${error.message} Using the local OCR result.';
      } catch (_) {
        failureMessage =
            'High-Fidelity Mode could not finish. Using the local OCR result.';
      } finally {
        if (photo != null) {
          try {
            await File(photo.path).delete();
          } catch (_) {
            // The camera plugin or operating system may already remove it.
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _frozen = true;
      _isProcessingFreeze = false;
      _processingMessage = '';
      _resultController.value = TextEditingValue(
        text: result,
        selection: TextSelection(baseOffset: 0, extentOffset: result.length),
      );
    });
    if (failureMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  }

  Future<void> _rescan() async {
    if (_controller == null) return;
    setState(() {
      _frozen = false;
      _liveText = '';
      _previousCaptures.clear();
    });
    await _controller!.startImageStream(_onFrame);
  }

  Future<void> _setHighFidelity(bool enabled) async {
    if (_isChangingMode || enabled == _highFidelity) return;
    if (enabled &&
        (!widget.usesRealAi ||
            widget.textAiService is! HighFidelityOcrService)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'High-Fidelity Mode requires a configured Anthropic API key.',
          ),
        ),
      );
      return;
    }
    if (enabled && !await _acknowledgeHighFidelityPrivacy()) return;

    setState(() => _isChangingMode = true);
    final oldController = _controller;
    try {
      if (oldController?.value.isStreamingImages ?? false) {
        await oldController!.stopImageStream();
      }
      await oldController?.dispose();
      if (mounted) setState(() => _controller = null);
      await _initializeCamera(
        enabled ? ResolutionPreset.max : ResolutionPreset.medium,
      );
      if (!mounted) return;
      setState(() {
        _highFidelity = enabled;
        _liveText = '';
        _previousCaptures.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller = null;
        _highFidelity = false;
      });
      try {
        await _initializeCamera(ResolutionPreset.medium);
      } catch (_) {
        // The loading state remains visible if the camera cannot recover.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'High-Fidelity camera setup failed. Returned to normal mode.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isChangingMode = false);
    }
  }

  Future<bool> _acknowledgeHighFidelityPrivacy() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_privacyAcknowledgedPreference) ?? false) {
      return true;
    }
    if (!mounted) return false;
    final acknowledged = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('High-Fidelity Mode'),
            content: const Text(
              'This mode sends the scanned image and recent on-device OCR '
              'readings to Claude. It uses API tokens. Normal mode keeps OCR '
              'entirely on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('I understand'),
              ),
            ],
          ),
        ) ??
        false;
    if (acknowledged) {
      await preferences.setBool(_privacyAcknowledgedPreference, true);
    }
    return acknowledged;
  }

  void _confirm() => Navigator.pop(context, _resultController.sourceText);

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_setupError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan text')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_setupError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (_permissionDenied) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan text')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Camera permission was denied. Enable it in your phone\'s '
              'app settings to scan text.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_frozen) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review scanned text'),
          actions: [
            IconButton(icon: const Icon(Icons.replay), tooltip: 'Rescan', onPressed: _rescan),
            IconButton(icon: const Icon(Icons.check), tooltip: 'Use this text', onPressed: _confirm),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownEditor(
            controller: _resultController,
            autofocus: true,
            expands: true,
            hintText: 'Recognized text will appear here.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan text')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              color: Colors.black87,
              child: widget.requireHighFidelity
                  ? const ListTile(
                      leading: Icon(Icons.verified_user_outlined,
                          color: Colors.white),
                      title: Text(
                        'High-Fidelity Mode required',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Watchlist scans always use the most accurate OCR path',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : SwitchListTile(
                      value: _highFidelity,
                      onChanged: _isChangingMode || _isProcessingFreeze
                          ? null
                          : _setHighFidelity,
                      title: const Text(
                        'High-Fidelity Mode',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'Uses API tokens',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  _liveText.isEmpty ? 'Point the camera at text…' : _liveText,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          if (_isProcessingFreeze || _isChangingMode)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _isChangingMode
                          ? 'Changing camera mode…'
                          : _processingMessage,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _liveText.trim().isEmpty || _isProcessingFreeze
            ? null
            : _freeze,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Freeze'),
      ),
    );
  }
}
