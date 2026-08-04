import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/preview.dart';
import '../theme/app_theme.dart';
import 'processing_screen.dart';

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

//Face Scan , lighting check
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  bool _isDetecting = false;
  bool _capturing = false;
  bool _permissionDenied = false;
  bool _torchOn = false;
  _Guidance _guidance = _Guidance.initializing;

  //Face guide oval
  static const double _ovalWidthFraction = 0.55; // width
  static const double _ovalAspect = 0.86; // height

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kUiPreviewMode) {
      //preview mode
      _guidance = _Guidance.noFace;
      return;
    }
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    _initCamera();
  }

  Future<void> _initCamera({int? preferredIndex}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', 'No camera found');
      _cameras = cameras;

      int index = preferredIndex ?? _cameraIndex;
      if (preferredIndex == null) {
        final frontIndex = cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        index = frontIndex != -1 ? frontIndex : 0;
      }
      index = index.clamp(0, cameras.length - 1);

      final controller = CameraController(
        cameras[index],
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
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _cameraIndex = index;
        _permissionDenied = false;
        _torchOn = false;
        _guidance = _Guidance.noFace;
      });
      await controller.startImageStream(_onFrame);
    } catch (_) {
      if (!mounted) return;
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _flipCamera() async {
    if (kUiPreviewMode || _cameras.length < 2 || _capturing) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _controller?.stopImageStream();
    await _initCamera(preferredIndex: next);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (kUiPreviewMode ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    try {
      final next = _torchOn ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(next);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Some devices don't support torch mode — ignore the error.
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
    if (kUiPreviewMode) return;
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

  //Per frame analysis
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

  //too dark , too bright
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

    // iOS planes come as separate buffers oncatenate into one.
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

  //Capture
  Future<void> _capture() async {
    if (_guidance != _Guidance.ready || _capturing) return;

    if (kUiPreviewMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProcessingScreen(imagePath: null),
        ),
      );
      return;
    }

    final controller = _controller;
    if (controller == null) return;
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

  //Ui instruction
  String get _pillMessage {
    switch (_guidance) {
      case _Guidance.initializing:
        return 'Starting camera…';
      case _Guidance.noFace:
        return 'Move to the center';
      case _Guidance.tooDark:
        return 'Lighting is too low';
      case _Guidance.tooBright:
        return 'Too bright';
      case _Guidance.moveCloser:
        return 'Move closer';
      case _Guidance.moveBack:
        return 'Move back a little';
      case _Guidance.moveLeft:
        return 'Move slightly left';
      case _Guidance.moveRight:
        return 'Move slightly right';
      case _Guidance.centerFace:
        return 'Move to the center';
      case _Guidance.ready:
        return 'Perfect! Hold still';
    }
  }

  IconData get _pillIcon {
    switch (_guidance) {
      case _Guidance.ready:
        return Icons.check;
      case _Guidance.tooDark:
      case _Guidance.tooBright:
        return Icons.wb_sunny_outlined;
      default:
        return Icons.arrow_downward;
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
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2A2E), Color(0xFF151517)],
                ),
              ),
            ),

          // Dark scrim with an oval
          _FaceOvalOverlay(
            widthFraction: _ovalWidthFraction,
            aspect: _ovalAspect,
            ringColor: _ringColor,
            showPlaceholder:
                _guidance == _Guidance.noFace ||
                _guidance == _Guidance.initializing,
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const Spacer(),
                if (_permissionDenied)
                  _buildPermissionDenied()
                else ...[
                  _buildInstructionPill(),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 28),
                if (!_permissionDenied) _buildBottomControls(),
                if (kUiPreviewMode) _buildPreviewStateChips(),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(
            icon: Icons.chevron_left,
            onTap: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Face Scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _circleButton(
            icon: _torchOn ? Icons.flash_on : Icons.flash_off_outlined,
            onTap: _toggleTorch,
            highlighted: _torchOn,
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: highlighted ? AppColors.gold : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildInstructionPill() {
    final ready = _guidance == _Guidance.ready;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: ready ? AppColors.sage : Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _pillIcon,
            size: 14,
            color: ready ? Colors.white : AppColors.charcoal,
          ),
          const SizedBox(width: 8),
          Text(
            _pillMessage,
            style: TextStyle(
              color: ready ? Colors.white : AppColors.charcoal,
              fontSize: 12.5,
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
            onPressed: () => _initCamera(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final ready = _guidance == _Guidance.ready && !_capturing;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(icon: Icons.cameraswitch_outlined, onTap: _flipCamera),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: ready ? _capture : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: ready ? Colors.white : Colors.white24,
            ),
            child: _capturing
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      color: AppColors.charcoal,
                      strokeWidth: 2,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 28),
        // Decorative
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white12,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  //UI preview
  Widget _buildPreviewStateChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _Guidance.values.map((g) {
            final selected = g == _guidance;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  g.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.black : Colors.white,
                  ),
                ),
                selected: selected,
                selectedColor: Colors.white,
                backgroundColor: Colors.white24,
                onSelected: (_) => setState(() => _guidance = g),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FaceOvalOverlay extends StatelessWidget {
  final double widthFraction;
  final double aspect;
  final Color ringColor;
  final bool showPlaceholder;

  const _FaceOvalOverlay({
    required this.widthFraction,
    required this.aspect,
    required this.ringColor,
    required this.showPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final ovalWidth = size.width * widthFraction;
        final ovalHeight = ovalWidth / aspect;
        final center = Offset(size.width / 2, size.height * 0.42);

        return IgnorePointer(
          child: Stack(
            children: [
              CustomPaint(
                size: size,
                painter: _FaceOvalPainter(
                  center: center,
                  ovalSize: Size(ovalWidth, ovalHeight),
                  ringColor: ringColor,
                ),
              ),
              if (showPlaceholder)
                Positioned(
                  left: center.dx - ovalWidth / 2,
                  top: center.dy - ovalHeight / 2,
                  width: ovalWidth,
                  height: ovalHeight,
                  child: const Center(
                    child: Text(
                      'Your face here',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  final Offset center;
  final Size ovalSize;
  final Color ringColor;

  _FaceOvalPainter({
    required this.center,
    required this.ovalSize,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromCenter(
      center: center,
      width: ovalSize.width + 26,
      height: ovalSize.height + 26,
    );
    final innerRect = Rect.fromCenter(
      center: center,
      width: ovalSize.width,
      height: ovalSize.height,
    );

    // Scrim with the inner oval cut out.
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addOval(innerRect);
    final maskPath = Path.combine(
      PathOperation.difference,
      scrimPath,
      holePath,
    );
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.6));

    // Dashed outer oval.
    _drawDashedOval(canvas, outerRect, Colors.white54, 1.5, 6, 5);

    // Solid inner ring, colored by guidance state.
    canvas.drawOval(
      innerRect,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawDashedOval(
    Canvas canvas,
    Rect rect,
    Color color,
    double strokeWidth,
    double dashWidth,
    double gapWidth,
  ) {
    final path = Path()..addOval(rect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FaceOvalPainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.ovalSize != ovalSize ||
        oldDelegate.ringColor != ringColor;
  }
}
