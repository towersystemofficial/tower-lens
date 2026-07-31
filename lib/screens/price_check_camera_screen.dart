import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PriceCheckCameraScreen extends StatefulWidget {
  const PriceCheckCameraScreen({super.key});

  @override
  State<PriceCheckCameraScreen> createState() =>
      _PriceCheckCameraScreenState();
}

class _PriceCheckCameraScreenState extends State<PriceCheckCameraScreen> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) setState(() => _error = 'Camera permission is required.');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = 'No camera is available.');
        return;
      }
      final rearCamera = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final controller = CameraController(
        rearCamera.isEmpty ? cameras.first : rearCamera.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.description ?? 'The camera could not open.',
        );
      }
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.pop(context, photo.path);
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = error.description ?? 'The photo could not be captured.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Take item photo')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: CameraPreview(controller)),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 32,
                      child: SafeArea(
                        top: false,
                        child: FilledButton.icon(
                          onPressed: _capturing ? null : _capture,
                          icon: const Icon(Icons.camera_alt),
                          label: Text(
                            _capturing ? 'Capturing…' : 'Take photo',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
