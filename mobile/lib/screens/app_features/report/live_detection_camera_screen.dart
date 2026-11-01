import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../services/app_services.dart';

/// A simple camera-first flow. The completed photo is returned to the report
/// screen for incident classification.
class LiveDetectionCameraScreen extends StatefulWidget {
  const LiveDetectionCameraScreen({super.key});

  @override
  State<LiveDetectionCameraScreen> createState() =>
      _LiveDetectionCameraScreenState();
}

class _LiveDetectionCameraScreenState extends State<LiveDetectionCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _captureBusy = false;
  bool _closing = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed && !_closing) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _cameraError = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
            'NoCamera', 'No camera was found on this device.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final oldController = _controller;
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await oldController?.dispose();
      await controller.initialize();
      if (!mounted || _closing) {
        await controller.dispose();
        return;
      }
      setState(() => _initializing = false);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = error.code == 'CameraAccessDenied'
            ? 'Camera permission was denied. Allow camera access in your phone settings.'
            : 'The camera could not start: ${error.description ?? error.code}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'The camera could not start. Please try again.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (_captureBusy ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    setState(() => _captureBusy = true);
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      _closing = true;
      Navigator.of(context).pop(ReportPhoto(
        bytes: bytes,
        filename: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _captureBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not capture the photo. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _cameraError != null
            ? _buildError()
            : _initializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _buildCamera(),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_rounded,
              color: Colors.white, size: 54),
          const SizedBox(height: 18),
          Text(
            _cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _initializeCamera,
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(controller)),
        Positioned(
          left: 12,
          right: 12,
          top: 10,
          child: Row(
            children: [
              Material(
                color: Colors.black.withValues(alpha: 0.62),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed:
                      _captureBusy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Text(
                    'Take a clear incident photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 52),
            ],
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.78,
            height: MediaQuery.sizeOf(context).width * 0.78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.78),
                width: 2,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            decoration: BoxDecoration(
              color: const Color(0xE6111827),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _captureBusy ? null : _capturePhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF111827),
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                    ),
                    icon: _captureBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111827),
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _captureBusy ? 'Capturing…' : 'Capture photo',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
