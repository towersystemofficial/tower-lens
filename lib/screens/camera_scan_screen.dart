import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  bool _isDetecting = false;
  bool _permissionDenied = false;
  bool _frozen = false;
  String _liveText = '';
  final TextEditingController _resultController = TextEditingController();

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
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
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
          setState(() => _liveText = result.text);
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
    if (_controller == null) return;
    await _controller!.stopImageStream();
    setState(() {
      _frozen = true;
      _resultController.text = _liveText.trim();
      _resultController.selection =
          TextSelection(baseOffset: 0, extentOffset: _resultController.text.length);
    });
  }

  Future<void> _rescan() async {
    if (_controller == null) return;
    setState(() {
      _frozen = false;
      _liveText = '';
    });
    await _controller!.startImageStream(_onFrame);
  }

  void _confirm() => Navigator.pop(context, _resultController.text);

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: TextField(
            controller: _resultController,
            autofocus: true,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Recognized text will appear here.',
            ),
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _liveText.trim().isEmpty ? null : _freeze,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Freeze'),
      ),
    );
  }
}