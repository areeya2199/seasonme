import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../theme/app_theme.dart';
import 'questionnaire_screen.dart';
import '../data/season_palette.dart';
import 'processing_screen.dart';

enum _Guidance {
  none,
  analyzing,
  noFace,
  tooDark,
  tooBright,
  offCenter,
  tooSmall,
  tooLarge,
  ready,
}

//Upload Photo
class UploadPhotoScreen extends StatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  State<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends State<UploadPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  FaceDetector? _faceDetector;

  String? _imagePath;
  _Guidance _guidance = _Guidance.none;

  @override
  void initState() {
    super.initState();
    // Match the live camera detector's performance mode.
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
  }

  @override
  void dispose() {
    _faceDetector?.close();
    super.dispose();
  }

  //pick
  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xfile == null || !mounted) return;
    setState(() {
      _imagePath = xfile.path;
      _guidance = _Guidance.analyzing;
    });
    await _analyzeImage(xfile.path);
  }

  Future<void> _analyzeImage(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || _faceDetector == null) {
        if (mounted) setState(() => _guidance = _Guidance.noFace);
        return;
      }

      // Respect EXIF orientation so coordinates and brightness use the
      // same upright image orientation as ML Kit.
      final upright = img.bakeOrientation(decoded);
      final brightness = _estimateBrightness(upright);
      _Guidance? lightIssue;
      if (brightness < 70) {
        lightIssue = _Guidance.tooDark;
      } else if (brightness > 205) {
        lightIssue = _Guidance.tooBright;
      }

      final faces = await _faceDetector!.processImage(
        InputImage.fromFilePath(path),
      );

      _Guidance next;
      if (lightIssue != null) {
        next = lightIssue;
      } else if (faces.isEmpty) {
        next = _Guidance.noFace;
      } else {
        next = _evaluateFace(
          faces.first,
          upright.width.toDouble(),
          upright.height.toDouble(),
        );
      }

      if (mounted) setState(() => _guidance = next);
    } catch (error, stack) {
      debugPrint('[SeasonMe upload] image analysis failed: $error\n$stack');
      if (mounted) setState(() => _guidance = _Guidance.noFace);
    }
  }

  // Use the same brightness thresholds as CameraScreen.
  // The gallery image is RGB, so estimate luma from sampled pixels.
  double _estimateBrightness(img.Image image) {
    final stepX = (image.width / 60).clamp(1, image.width).round();
    final stepY = (image.height / 60).clamp(1, image.height).round();
    int sum = 0;
    int count = 0;
    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        final luma = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sum += luma.round();
        count++;
      }
    }
    return count == 0 ? 128 : sum / count;
  }

  // Match CameraScreen's horizontal/vertical positioning and face-size limits.
  _Guidance _evaluateFace(Face face, double imgW, double imgH) {
    final box = face.boundingBox;
    final dx = (box.left + box.width / 2 - imgW * 0.5) / imgW;
    final dy = (box.top + box.height / 2 - imgH * 0.42) / imgH;

    const horizontalTolerance = 0.17;
    const verticalTolerance = 0.19;

    if (dx.abs() > horizontalTolerance) {
      return _Guidance.offCenter;
    }
    if (dy.abs() > verticalTolerance) {
      return _Guidance.offCenter;
    }

    final faceWidthFraction = box.width / imgW;
    if (faceWidthFraction < 0.25) return _Guidance.tooSmall;
    if (faceWidthFraction > 0.72) return _Guidance.tooLarge;

    return _Guidance.ready;
  }

  SeasonKey _convertSeason(String season) {
    switch (season.toLowerCase()) {
      case "spring":
        return SeasonKey.Spring;
      case "summer":
        return SeasonKey.Summer;
      case "autumn":
        return SeasonKey.Autumn;
      case "winter":
        return SeasonKey.Winter;
      default:
        return SeasonKey.Summer;
    }
  }

  Future<void> _continue() async {
    if (!_ready || _imagePath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionnaireScreen(imagePath: _imagePath!),
      ),
    );
  }

  // UI
  String get _statusMessage {
    switch (_guidance) {
      case _Guidance.none:
        return 'Choose a clear, front ,facing photo';
      case _Guidance.analyzing:
        return 'Checking your photo…';
      case _Guidance.noFace:
        return "We couldn't find a face ,try another photo";
      case _Guidance.tooDark:
        return 'This photo looks too dark ,try a brighter one';
      case _Guidance.tooBright:
        return 'This photo looks overexposed ,try softer light';
      case _Guidance.offCenter:
        return 'Your face isn\'t centered ,choose a more centered photo';
      case _Guidance.tooSmall:
        return 'Your face is too small ,try a closer shot';
      case _Guidance.tooLarge:
        return 'Too close / cropped ,try a photo with more space around your face';
      case _Guidance.ready:
        return 'Perfect! This photo looks great';
    }
  }

  Color get _ringColor {
    switch (_guidance) {
      case _Guidance.ready:
        return AppColors.sage;
      case _Guidance.tooDark:
      case _Guidance.tooBright:
        return AppColors.gold;
      case _Guidance.none:
      case _Guidance.analyzing:
        return AppColors.mid.withOpacity(0.3);
      default:
        return AppColors.blush;
    }
  }

  bool get _ready => _guidance == _Guidance.ready;
  bool get _isAnalyzing => _guidance == _Guidance.analyzing;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Row(
              children: [
                GradientBackButton(onPressed: () => Navigator.pop(context)),
                const Expanded(
                  child: Text(
                    'Upload Photo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 20),
            _buildPreviewCircle(),
            const SizedBox(height: 20),
            _buildStatusPill(),
            const SizedBox(height: 8),
            const Text(
              'Use a recent, well-lit photo with your face centered',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: AppColors.mid,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  side: BorderSide.none,
                ),
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  _imagePath == null
                      ? 'Choose from Gallery'
                      : 'Choose Another Photo',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _ready ? () => _continue() : null,
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCircle() {
    const size = 220.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _ringColor, width: 3),
        color: AppColors.white,
      ),
      child: ClipOval(
        child: _imagePath == null
            ? const Icon(Icons.person_outline, size: 72, color: AppColors.mid)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imagePath!), fit: BoxFit.cover),
                  if (_isAnalyzing)
                    Container(
                      color: Colors.black.withOpacity(0.35),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusPill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _ready ? AppColors.sage.withOpacity(0.18) : AppColors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _ready ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: _ready ? AppColors.sage : AppColors.mid,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ready ? AppColors.sage : AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
