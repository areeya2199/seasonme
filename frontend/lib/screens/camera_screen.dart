import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show WriteBuffer;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/preview.dart';
import '../theme/app_theme.dart';
import 'questionnaire_screen.dart';
import 'processing_screen.dart';

import 'dart:typed_data';

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
  // Keep the existing guidance available without running ML Kit in basic mode.
  static const bool _basicCameraMode = bool.fromEnvironment(
    'BASIC_CAMERA_MODE',
    defaultValue: false,
  );
  CameraController? _controller;
  FaceDetector? _faceDetector;
  ModalRoute<dynamic>? _cameraRoute;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  bool _isDetecting = false;
  int _frameCount = 0;
  bool _loggedInputFormat = false;
  bool _capturing = false;
  bool _permissionDenied = false;
  bool _torchOn = false;
  bool _cameraBusy = false;
  bool _foreground = true;
  bool _routeAway = false;
  bool _disposed = false;
  int _generation = 0;
  String? _cameraError;
  // CameraX resources are shared even across consecutive CameraScreen routes.
  static Future<void> _operations = Future<void>.value();
  Future<void>? _detectionTask;
  _Guidance _guidance = _Guidance.initializing;

  bool get _canUseCamera =>
      mounted &&
      !_disposed &&
      _foreground &&
      !_routeAway &&
      (_cameraRoute?.isCurrent ?? true);

  bool get _cameraReady =>
      _canUseCamera &&
      !_cameraBusy &&
      _cameraError == null &&
      _controller != null &&
      _controller!.value.isInitialized &&
      !_controller!.value.isTakingPicture;

  bool get _canCapture =>
      !_capturing &&
      (kUiPreviewMode
          ? _guidance == _Guidance.ready
          : _cameraReady && (_basicCameraMode || _guidance == _Guidance.ready));

  // Every hardware operation, including lifecycle cleanup, uses this queue.
  // Recover the queue after errors while returning the error to its caller.
  Future<void> _serialize(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  void _reportCameraError(String step, Object error, StackTrace stack) {
    final detail = error is CameraException
        ? '${error.code}: ${error.description}'
        : error.toString();
    debugPrint('[SeasonMe camera] $step failed: $detail\n$stack');
    if (!mounted || _disposed) return;
    setState(() {
      _permissionDenied =
          error is CameraException && error.code == 'CameraAccessDenied';
      _cameraError = '$step failed: $detail';
    });
  }

  void _onControllerChanged() {
    final value = _controller?.value;
    if (value == null || !value.hasError || !mounted || _disposed) return;
    final message = value.errorDescription ?? 'Unknown camera error';
    if (_cameraError == message) return;
    debugPrint('[SeasonMe camera] controller error: $message');
    setState(() => _cameraError = message);
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (mounted && !_disposed) setState(() => _torchOn = false);
    if (controller == null) return;
    controller.removeListener(_onControllerChanged);
    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await _detectionTask;
    } finally {
      debugPrint('[SeasonMe camera] dispose ${controller.description.name}');
      await controller.dispose();
    }
  }

  Future<void> _startGuidance(
    CameraController controller,
    int generation,
  ) async {
    if (_basicCameraMode || !_canUseCamera || generation != _generation) return;
    if (!controller.value.isStreamingImages) {
      await controller.startImageStream((image) {
        if (!_isDetecting) {
          _detectionTask = _onFrame(image, controller, generation);
        }
      });
    }
  }

  //Face guide oval
  static const double _ovalWidthFraction = 0.55; // width
  static const double _ovalAspect = 0.85; // height

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kUiPreviewMode) {
      //preview mode
      _guidance = _Guidance.noFace;
      return;
    }
    if (!_basicCameraMode) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
      );
    }
    _initCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cameraRoute = ModalRoute.of(context);
  }

  Future<void> _initCamera({int? preferredIndex}) async {
    if (kUiPreviewMode || !_canUseCamera) return;
    final generation = ++_generation;
    setState(() {
      _cameraBusy = true;
      _cameraError = null;
      _permissionDenied = false;
      _guidance = _Guidance.initializing;
    });
    try {
      await _serialize(() async {
        if (!_canUseCamera || generation != _generation) return;
        // CameraX dispose releases shared resources: finish it BEFORE creating
        // the replacement, or disposing the old camera can unbind the new one.
        await _releaseCamera();
        if (!_canUseCamera || generation != _generation) return;
        final cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
        if (!_canUseCamera || generation != _generation) return;
        if (cameras.isEmpty) {
          throw CameraException('noCamera', 'No camera found');
        }
        _cameras = cameras;

        int index = preferredIndex ?? _cameraIndex;
        if (preferredIndex == null) {
          final frontIndex = cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          );
          index = frontIndex != -1 ? frontIndex : 0;
        }
        index = index.clamp(0, cameras.length - 1);
        _cameraIndex = index;

        final controller = CameraController(
          cameras[index],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: _basicCameraMode
              ? null
              : Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
        debugPrint(
          '[SeasonMe camera] initialize ${cameras[index].name} '
          '${cameras[index].lensDirection.name}, basic=$_basicCameraMode',
        );
        try {
          await controller.initialize();
          if (!_canUseCamera || generation != _generation) {
            await controller.dispose();
            return;
          }
          setState(() {
            _controller = controller;
            _cameraIndex = index;
            _permissionDenied = false;
            _torchOn = false;
            _guidance = _Guidance.noFace;
          });
          controller.addListener(_onControllerChanged);
          await _startGuidance(controller, generation);
          debugPrint(
            '[SeasonMe camera] initialized ${controller.description.name}, '
            'preview=${controller.value.previewSize}, '
            'stream=${controller.value.isStreamingImages}',
          );
          _onControllerChanged();
        } catch (_) {
          if (identical(_controller, controller)) {
            await _releaseCamera();
          } else {
            await controller.dispose();
          }
          rethrow;
        }
      });
    } catch (error, stack) {
      if (generation == _generation) {
        _reportCameraError('Initialize', error, stack);
      } else {
        debugPrint(
          '[SeasonMe camera] superseded initialize failed: $error\n$stack',
        );
      }
    } finally {
      if (mounted && !_disposed && generation == _generation) {
        setState(() => _cameraBusy = false);
      }
    }
  }

  Future<void> _flipCamera() async {
    if (kUiPreviewMode || !_cameraReady || _capturing) return;
    final direction =
        _cameras[_cameraIndex].lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final next = _cameras.indexWhere(
      (camera) => camera.lensDirection == direction,
    );
    if (next == -1) return;
    await _initCamera(preferredIndex: next);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (kUiPreviewMode || !_cameraReady || _capturing || controller == null) {
      return;
    }
    final generation = _generation;
    setState(() => _cameraBusy = true);
    try {
      await _serialize(() async {
        if (!_canUseCamera || generation != _generation) return;
        final next = _torchOn ? FlashMode.off : FlashMode.torch;
        await controller.setFlashMode(next);
        if (_canUseCamera && generation == _generation) {
          setState(() => _torchOn = !_torchOn);
        }
      });
    } catch (error, stack) {
      _reportCameraError('Flash', error, stack);
    } finally {
      if (mounted && !_disposed && generation == _generation) {
        setState(() => _cameraBusy = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    ++_generation;
    unawaited(
      _serialize(() async {
        try {
          await _releaseCamera();
        } finally {
          await _detectionTask;
          await _faceDetector?.close();
        }
      }).catchError((Object error, StackTrace stack) {
        debugPrint('[SeasonMe camera] final cleanup failed: $error\n$stack');
      }),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kUiPreviewMode) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (!_routeAway) _initCamera(preferredIndex: _cameraIndex);
    } else if (_foreground) {
      _foreground = false;
      ++_generation;
      setState(() => _cameraBusy = true);
      unawaited(
        _serialize(_releaseCamera).catchError((Object error, StackTrace stack) {
          _reportCameraError('Suspend', error, stack);
        }),
      );
    }
  }

  //Per frame analysis
  Future<void> _onFrame(
    CameraImage image,
    CameraController controller,
    int generation,
  ) async {
    if (_basicCameraMode ||
        !_canUseCamera ||
        _cameraBusy ||
        generation != _generation ||
        !identical(controller, _controller) ||
        _isDetecting ||
        _capturing ||
        _faceDetector == null) {
      return;
    }
    _isDetecting = true;
    try {
      final brightness = _estimateBrightness(image);
      _Guidance? lightIssue;
      if (brightness < 70) {
        lightIssue = _Guidance.tooDark;
      } else if (brightness > 205) {
        lightIssue = _Guidance.tooBright;
      }

      _frameCount++;
      if (_frameCount == 1 || _frameCount % 30 == 0) {
        debugPrint(
          '[SeasonMe camera] frame #$_frameCount: '
          '${image.width}x${image.height}, format=${image.format.raw}, '
          'planes=${image.planes.length}, brightness=${brightness.toStringAsFixed(1)}',
        );
      }

      final inputImage = _toInputImage(image, controller);
      _Guidance next;
      if (inputImage == null) {
        if (!_loggedInputFormat) {
          _loggedInputFormat = true;
          debugPrint(
            '[SeasonMe camera] Cannot convert camera frame to ML Kit InputImage. '
            'Check image format and plane count above.',
          );
        }
        next = lightIssue ?? _Guidance.noFace;
      } else {
        final faces = await _faceDetector!.processImage(inputImage);
        if (_frameCount == 1 || _frameCount % 15 == 0) {
          debugPrint('[SeasonMe camera] faces detected: ${faces.length}');
        }
        if (lightIssue != null) {
          next = lightIssue;
        } else if (faces.isEmpty) {
          next = _Guidance.noFace;
        } else {
          next = _evaluateFacePosition(faces.first, image, controller);
        }
      }

      if (_canUseCamera &&
          generation == _generation &&
          identical(controller, _controller) &&
          next != _guidance) {
        setState(() => _guidance = next);
      }
    } catch (error, stack) {
      debugPrint('[SeasonMe camera] face frame failed: $error\n$stack');
      if (mounted && !_disposed && generation == _generation) {
        setState(() => _guidance = _Guidance.noFace);
      }
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

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final sensorOrientation = controller.description.sensorOrientation;
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    if (Platform.isAndroid) {
      final width = image.width;
      final height = image.height;

      // Case 1: Android already provides a single NV21 plane.
      if (image.planes.length == 1) {
        final format = InputImageFormatValue.fromRawValue(image.format.raw);

        if (format != InputImageFormat.nv21) {
          debugPrint(
            '[SeasonMe camera] Unsupported single-plane format: '
            '${image.format.raw}',
          );
          return null;
        }

        final plane = image.planes.first;

        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      // Case 2: Android provides YUV_420_888 as three planes.
      if (image.planes.length == 3) {
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];

        final ySize = width * height;
        final nv21 = Uint8List(ySize + (ySize ~/ 2));

        // Copy the Y (brightness) plane, respecting row/pixel strides.
        for (int row = 0; row < height; row++) {
          for (int col = 0; col < width; col++) {
            final sourceIndex =
                row * yPlane.bytesPerRow + col * (yPlane.bytesPerPixel ?? 1);

            nv21[row * width + col] = yPlane.bytes[sourceIndex];
          }
        }

        // NV21 stores chroma in VU order.
        final chromaHeight = height ~/ 2;
        final chromaWidth = width ~/ 2;

        for (int row = 0; row < chromaHeight; row++) {
          for (int col = 0; col < chromaWidth; col++) {
            final uIndex =
                row * uPlane.bytesPerRow + col * (uPlane.bytesPerPixel ?? 1);

            final vIndex =
                row * vPlane.bytesPerRow + col * (vPlane.bytesPerPixel ?? 1);

            final targetIndex = ySize + row * width + col * 2;

            if (targetIndex + 1 < nv21.length) {
              nv21[targetIndex] = vPlane.bytes[vIndex];
              nv21[targetIndex + 1] = uPlane.bytes[uIndex];
            }
          }
        }

        return InputImage.fromBytes(
          bytes: nv21,
          metadata: InputImageMetadata(
            size: Size(width.toDouble(), height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: width,
          ),
        );
      }

      debugPrint(
        '[SeasonMe camera] Unsupported plane count: '
        '${image.planes.length}, format=${image.format.raw}',
      );
      return null;
    }

    // iOS and other platforms: preserve the existing conversion behavior.
    if (image.planes.isEmpty) return null;

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

  // ML Kit returns face coordinates in the image's upright orientation.
  // CameraImage dimensions may still be in sensor orientation, so swap the
  // dimensions when the sensor rotation is 90/270 degrees.
  _Guidance _evaluateFacePosition(
    Face face,
    CameraImage image,
    CameraController controller,
  ) {
    final box = face.boundingBox;
    final rotation = controller.description.sensorOrientation;
    final rotated = rotation == 90 || rotation == 270;
    final uprightWidth = (rotated ? image.height : image.width).toDouble();
    final uprightHeight = (rotated ? image.width : image.height).toDouble();

    if (uprightWidth <= 0 || uprightHeight <= 0) return _Guidance.noFace;

    final faceCenterX = box.left + box.width / 2;
    final faceCenterY = box.top + box.height / 2;

    // The oval is drawn slightly above the screen's vertical center (42%).
    // Use forgiving thresholds because the preview is cropped/scaled to fit.
    final dx = (faceCenterX - uprightWidth * 0.5) / uprightWidth;
    final targetY = uprightHeight * 0.42;
    final dy = (faceCenterY - targetY) / uprightHeight;

    const horizontalTolerance = 0.17;
    const verticalTolerance = 0.19;

    if (dx.abs() > horizontalTolerance) {
      // The front preview is mirrored, so invert the on-screen instruction.
      final isFront =
          controller.description.lensDirection == CameraLensDirection.front;
      if (isFront) {
        return dx > 0 ? _Guidance.moveRight : _Guidance.moveLeft;
      }
      return dx > 0 ? _Guidance.moveLeft : _Guidance.moveRight;
    }

    if (dy.abs() > verticalTolerance) return _Guidance.centerFace;

    final faceWidthFraction = box.width / uprightWidth;
    if (faceWidthFraction < 0.25) return _Guidance.moveCloser;
    if (faceWidthFraction > 0.72) return _Guidance.moveBack;

    return _Guidance.ready;
  }

  //Capture
  Future<void> _capture() async {
    if (!_canCapture) return;

    if (kUiPreviewMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProcessingScreen(imagePath: null, answers: {}),
        ),
      );
      return;
    }

    final controller = _controller;
    if (controller == null) return;
    final generation = _generation;
    String? imagePath;
    setState(() => _capturing = true);
    try {
      await _serialize(() async {
        if (!_canUseCamera ||
            generation != _generation ||
            !identical(controller, _controller)) {
          return;
        }
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await _detectionTask;
        if (!_canUseCamera || generation != _generation) return;
        debugPrint(
          '[SeasonMe camera] takePicture ${controller.description.name}',
        );
        final captured = await controller.takePicture();
        final file = File(captured.path);
        if (!await file.exists() || await file.length() == 0) {
          throw CameraException(
            'emptyCapture',
            'Captured image is missing or empty',
          );
        }
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        try {
          final frame = await codec.getNextFrame();
          try {
            debugPrint(
              '[SeasonMe camera] captured ${captured.path}, '
              'bytes=${await file.length()}, '
              'size=${frame.image.width}x${frame.image.height}',
            );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
        if (!_canUseCamera || generation != _generation) return;
        _routeAway = true;
        await _releaseCamera();
        // Do not navigate if the app was suspended during camera cleanup.
        if (!mounted ||
            _disposed ||
            !_foreground ||
            generation != _generation) {
          _routeAway = false;
          return;
        }
        imagePath = captured.path;
      });
      if (imagePath == null || !mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionnaireScreen(imagePath: imagePath!),
        ),
      );
    } catch (error, stack) {
      _routeAway = false;
      _reportCameraError('Capture', error, stack);
    } finally {
      final returningFromQuestionnaire = _routeAway;
      _routeAway = false;
      if (mounted && !_disposed) {
        setState(() => _capturing = false);
        if (_foreground &&
            (returningFromQuestionnaire ||
                (_controller == null && _cameraError == null))) {
          await _initCamera(preferredIndex: _cameraIndex);
        }
      }
    }
  }

  //UI
  String get _statusMessage {
    if (!kUiPreviewMode && _basicCameraMode) {
      return _cameraBusy ? 'Starting camera…' : 'Camera ready';
    }
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

  String get _pillMessage => _statusMessage;
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
        return Colors.white.withValues(alpha: 0.7);
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
          if (_canUseCamera &&
              _controller != null &&
              _controller!.value.isInitialized)
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
                if (_cameraError != null)
                  _buildCameraError()
                else ...[
                  _buildInstructionPill(),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 28),
                if (_cameraError == null) _buildBottomControls(),
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
    final ready = _basicCameraMode && !kUiPreviewMode
        ? _cameraReady
        : _guidance == _Guidance.ready;
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

  Widget _buildCameraError() {
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
          Text(
            _permissionDenied
                ? 'Camera access denied. Please enable it in device settings.\n$_cameraError'
                : _cameraError ?? 'Camera unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            onPressed: _cameraBusy || _capturing
                ? null
                : () => _initCamera(preferredIndex: _cameraIndex),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final ready = _canCapture;
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
    canvas.drawPath(
      maskPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

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
