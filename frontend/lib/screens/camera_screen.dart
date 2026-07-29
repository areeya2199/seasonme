import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../theme/app_theme.dart';
import 'processing_screen.dart';

/// The different things we might need to tell the user while they line
/// their face up for the scan. Checked in priority order every frame:
/// lighting problems first, then "no face found", then position/distance,
/// and finally [ready] once everything looks good.
enum _Guidance {
  initializing,
  noFace,
  tooDark,
  tooBright,
  moveCloser,
  moveBack,
  moveLeft,
  moveRight,
  centerFace,
  ready,
}

/// Face Scan — live camera preview with a circular face guide. Tells the
/// user in real time if the lighting is too dark/too bright and if they
/// need to move to center their face in the frame, then enables capture
/// only once both lighting and framing look good (matches the reference
/// flow: /select -> /camera -> /processing -> /result).
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceDetector? _faceDetector;

  bool _isDetecting = false;
  bool _capturing = false;
  bool _permissionDenied = false;
  _Guidance _guidance = _Guidance.initializing;

  // Face guide circle takes up this fraction of the screen width, and is
  // vertically centered a little above screen-middle (where a selfie
  // camera naturally frames a face).
  static const double _circleFraction = 0.62;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', 'No camera found');
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _permissionDenied = false;
        _guidance = _Guidance.noFace;
      });
      await controller.startImageStream(_onFrame);
    } catch (_) {
      if (!mounted) return;
      setState(() => _permissionDenied = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector?.close();
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
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // -- Per-frame analysis --------------------------------------------

  Future<void> _onFrame(CameraImage image) async {
    if (_isDetecting || _capturing || _faceDetector == null) return;
    _isDetecting = true;
    try {
      final brightness = _estimateBrightness(image);
      _Guidance? lightIssue;
      if (brightness < 70) {
        lightIssue = _Guidance.tooDark;
      } else if (brightness > 205) {
        lightIssue = _Guidance.tooBright;
      }

      final inputImage = _toInputImage(image);
      _Guidance next;
      if (inputImage == null) {
        next = lightIssue ?? _Guidance.noFace;
      } else {
        final faces = await _faceDetector!.processImage(inputImage);
        if (lightIssue != null) {
          next = lightIssue;
        } else if (faces.isEmpty) {
          next = _Guidance.noFace;
        } else {
          next = _evaluateFacePosition(faces.first, image);
        }
      }

      if (mounted && next != _guidance) {
        setState(() => _guidance = next);
      }
    } catch (_) {
      // A single bad/partial frame shouldn't crash the live stream.
    } finally {
      _isDetecting = false;
    }
  }

  /// Cheap lighting proxy: average value of the luma (Y) plane, which is
  /// the first plane for both NV21 (Android) and BGRA8888 (iOS treated
  /// as raw bytes here) — good enough to flag "too dark" / "too bright"
  /// without a full YUV->RGB conversion every frame.
  double _estimateBrightness(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return 128;
    const sampleStride = 8; // sample every Nth byte for speed
    int sum = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += sampleStride) {
      sum += bytes[i];
      count++;
    }
    return count == 0 ? 128 : sum / count;
  }

  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;
    final sensorOrientation = controller.description.sensorOrientation;
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    if (Platform.isAndroid) {
      if (image.planes.length != 1) return null;
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // iOS: planes come as separate buffers — concatenate into one.
    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  _Guidance _evaluateFacePosition(Face face, CameraImage image) {
    final box = face.boundingBox;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    final dx = (box.left + box.width / 2 - imgW / 2) / imgW;
    final dy = (box.top + box.height / 2 - imgH / 2) / imgH;

    const centerTolerance = 0.12;
    if (dx.abs() > centerTolerance || dy.abs() > centerTolerance) {
      // The front-camera preview is mirrored, so a face left-of-center
      // in the raw sensor frame appears right-of-center on screen.
      if (dx.abs() >= dy.abs()) {
        return dx > 0 ? _Guidance.moveLeft : _Guidance.moveRight;
      }
      return _Guidance.centerFace;
    }

    final faceWidthFraction = box.width / imgW;
    if (faceWidthFraction < 0.32) return _Guidance.moveCloser;
    if (faceWidthFraction > 0.68) return _Guidance.moveBack;

    return _Guidance.ready;
  }

  // -- Capture ----------------------------------------------------------

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _guidance != _Guidance.ready || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      await controller.stopImageStream();
      final file = await controller.takePicture();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(imagePath: file.path),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
      final c = _controller;
      if (c != null && c.value.isInitialized && !c.value.isStreamingImages) {
        await c.startImageStream(_onFrame);
      }
    }
  }

  // -- UI -----------------------------------------------------------------

  String get _statusMessage {
    switch (_guidance) {
      case _Guidance.initializing:
        return 'Starting camera…';
      case _Guidance.noFace:
        return 'Your face here';
      case _Guidance.tooDark:
        return 'Lighting is too low — find a brighter spot';
      case _Guidance.tooBright:
        return 'Too bright — soften the light a little';
      case _Guidance.moveCloser:
        return 'Move closer';
      case _Guidance.moveBack:
        return 'Move back a little';
      case _Guidance.moveLeft:
        return 'Move slightly left';
      case _Guidance.moveRight:
        return 'Move slightly right';
      case _Guidance.centerFace:
        return 'Place your face inside the frame';
      case _Guidance.ready:
        return 'Perfect! Hold still';
    }
  }

  Color get _ringColor {
    switch (_guidance) {
      case _Guidance.ready:
        return AppColors.sage;
      case _Guidance.tooDark:
      case _Guidance.tooBright:
        return AppColors.gold;
      case _Guidance.initializing:
      case _Guidance.noFace:
        return Colors.white.withOpacity(0.7);
      default:
        return AppColors.blush;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Center(child: CameraPreview(_controller!))
          else
            Container(color: Colors.black),

          // Dark scrim with a circular window cut out around the face
          // guide, ringed in a color that reflects the current guidance.
          _FaceMaskOverlay(
            circleFraction: _circleFraction,
            ringColor: _ringColor,
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Spacer(),
                if (_permissionDenied)
                  _buildPermissionDenied()
                else ...[
                  _buildStatusPill(),
                  const SizedBox(height: 10),
                  const Text(
                    'Use natural lighting for best results',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 28),
                if (!_permissionDenied) _buildCaptureButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 18,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Face Scan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40), // balances the back button for centering
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final ready = _guidance == _Guidance.ready;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: ready
            ? AppColors.sage.withOpacity(0.9)
            : Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white70,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'We need camera access to scan your face.\nPlease enable it in your device settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: _initCamera,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    final ready = _guidance == _Guidance.ready && !_capturing;
    return GestureDetector(
      onTap: ready ? _capture : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: ready ? AppColors.sage : Colors.white24,
        ),
        child: _capturing
            ? const Padding(
                padding: EdgeInsets.all(22),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                Icons.camera_alt,
                color: ready ? Colors.white : Colors.white54,
                size: 28,
              ),
      ),
    );
  }
}

/// Paints a dark scrim over the whole preview with a circular window cut
/// out in the middle (the face guide), ringed in [ringColor].
class _FaceMaskOverlay extends StatelessWidget {
  final double circleFraction;
  final Color ringColor;

  const _FaceMaskOverlay({
    required this.circleFraction,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final diameter = size.width * circleFraction;
        return IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _FaceMaskPainter(diameter: diameter, ringColor: ringColor),
          ),
        );
      },
    );
  }
}

class _FaceMaskPainter extends CustomPainter {
  final double diameter;
  final Color ringColor;

  _FaceMaskPainter({required this.diameter, required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.44);
    final radius = diameter / 2;

    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final maskPath = Path.combine(
      PathOperation.difference,
      scrimPath,
      holePath,
    );

    canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.55));
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) {
    return oldDelegate.diameter != diameter ||
        oldDelegate.ringColor != ringColor;
  }
}
