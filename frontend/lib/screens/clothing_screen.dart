import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/season_palette.dart';
import '../utils/color_utils.dart';

// Outfit Checker: the user photographs (or uploads) a piece of clothing,
// the app samples its color, and checks how close that color is to the
// SAME season the user got on the Result screen — Winter photos compare
// only to the Winter palette, Autumn to Autumn, and so on for all 4
// seasons, since `_profile` below is always built from `widget.season`.
// No manual color picking: the photo is the only input.
class ClothingScreen extends StatefulWidget {
  final SeasonKey season;
  const ClothingScreen({super.key, this.season = SeasonKey.Autumn});

  @override
  State<ClothingScreen> createState() => _ClothingScreenState();
}

enum _LoadState { idle, loading, done, error }

class _OutfitMatch {
  final int percent;
  final MatchLevel level;
  final SwatchItem closest;
  final String closestCategory;
  const _OutfitMatch(
    this.percent,
    this.level,
    this.closest,
    this.closestCategory,
  );
}

// Result of the on-device pixel analysis: the sampled color plus two rough
// texture/hue signals used only as a heuristic "does this even look like a
// photo of plain clothing" check — not a real image classifier.
class _ImageAnalysis {
  final Color color;
  final double textureVariance;
  final double greenShare;
  const _ImageAnalysis(this.color, this.textureVariance, this.greenShare);
}

class _ClothingScreenState extends State<ClothingScreen> {
  File? _pickedImage;
  Color? _sampledColor;
  bool _looksSuspicious = false;
  _LoadState _state = _LoadState.idle;
  String? _errorMessage;
  _OutfitMatch? _result;

  late final SeasonProfile _profile = SeasonPaletteData.getProfile(
    widget.season,
  );

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (xfile == null) return; // user cancelled

      final file = File(xfile.path);
      setState(() {
        _pickedImage = file;
        _state = _LoadState.loading;
        _errorMessage = null;
        _result = null;
        _sampledColor = null;
        _looksSuspicious = false;
      });

      final analysis = await _analyzeImage(file);
      final match = _matchAgainstSeason(analysis.color);
      if (!mounted) return;
      setState(() {
        _sampledColor = analysis.color;
        // Heuristic only: high pixel-to-pixel variance in the sampled area
        // (fur/foliage texture) or a strong green cast (grass/leaves/skin)
        // suggests this may not be a plain garment. This is a rough signal,
        // not a real "is this clothing" classifier.
        _looksSuspicious =
            analysis.textureVariance > 55 || analysis.greenShare > 0.35;
        _result = match;
        _state = _LoadState.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = 'อ่านสีจากภาพไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  // ---- "Take a photo and detect the color": average the center 60% of the
  // frame, where the garment usually fills the shot while background tends
  // to sit toward the edges. Also computes two rough signals (pixel
  // variance and green-hue share) used only for the soft "does this look
  // like clothing" warning below — this stays a heuristic, not true scene
  // classification, since there's no vision model running on-device here.
  Future<_ImageAnalysis> _analyzeImage(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return const _ImageAnalysis(Colors.grey, 0, 0);

    final pixels = byteData.buffer.asUint8List();
    final w = image.width, h = image.height;
    final x0 = (w * 0.2).round(), x1 = (w * 0.8).round();
    final y0 = (h * 0.2).round(), y1 = (h * 0.8).round();

    int rSum = 0, gSum = 0, bSum = 0, count = 0, greenCount = 0;
    final samples = <List<int>>[];
    for (int y = y0; y < y1; y += 2) {
      for (int x = x0; x < x1; x += 2) {
        final i = (y * w + x) * 4;
        if (i + 3 >= pixels.length) continue;
        final a = pixels[i + 3];
        if (a < 200) continue;
        final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        rSum += r;
        gSum += g;
        bSum += b;
        count++;
        samples.add([r, g, b]);
        final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
        if (hsl.hue >= 70 && hsl.hue <= 160 && hsl.saturation > 0.25) {
          greenCount++;
        }
      }
    }
    if (count == 0) return const _ImageAnalysis(Colors.grey, 0, 0);

    final avgR = rSum / count, avgG = gSum / count, avgB = bSum / count;
    double varSum = 0;
    for (final s in samples) {
      final dr = s[0] - avgR, dg = s[1] - avgG, db = s[2] - avgB;
      varSum += dr * dr + dg * dg + db * db;
    }
    final variance = sqrt(varSum / count);
    final greenShare = greenCount / count;

    return _ImageAnalysis(
      Color.fromARGB(255, avgR.round(), avgG.round(), avgB.round()),
      variance,
      greenShare,
    );
  }

  // ---- Compare only against THIS season's own palette. If the result
  // screen showed Winter, this checks against Winter only — and so on
  // for each of the 4 seasons. Picks whichever single color has the
  // smallest perceptual (Lab) distance — that's "closest" and "why". ----
  _OutfitMatch _matchAgainstSeason(Color color) {
    final candidates = <MapEntry<String, SwatchItem>>[
      for (final s in _profile.topsPool) MapEntry('เสื้อผ้า', s),
      for (final s in _profile.bottoms) MapEntry('เสื้อผ้า', s),
      for (final s in _profile.jewelry) MapEntry('เครื่องประดับ', s),
    ];

    double bestDist = double.infinity;
    late MapEntry<String, SwatchItem> best;
    for (final c in candidates) {
      final d = ColorUtils.labDistance(color, c.value.color);
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    final percent = ColorUtils.distanceToPercent(bestDist);
    return _OutfitMatch(
      percent,
      matchLevelFromPercent(percent),
      best.value,
      best.key,
    );
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.gold,
                ),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.gold,
                ),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Outfit Checker',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: AppColors.mid),
                  children: [
                    const TextSpan(text: 'Based on your season '),
                    TextSpan(
                      text: _profile.displayName,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showSourceSheet,
                child: _pickedImage == null
                    ? DottedContainer(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.mid,
                              size: 32,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Upload clothing photo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tap to take a photo or choose from gallery',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.mid,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Image.file(
                              _pickedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              if (_state == _LoadState.loading) _buildLoading(),
              if (_state == _LoadState.error) _buildError(),
              if (_state == _LoadState.done && _result != null) ...[
                if (_looksSuspicious) _buildSuspiciousBanner(),
                _buildResultCard(),
                const SizedBox(height: 10),
                _buildExplanationCard(),
              ],
              if (_state == _LoadState.idle) _buildIdleHint(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdleHint() {
    return Text(
      'ถ่ายหรืออัปโหลดรูปเสื้อผ้า แล้วแอปจะตรวจสีให้อัตโนมัติว่าเข้ากับซีซั่น ${_profile.displayName} ของคุณแค่ไหน',
      style: const TextStyle(fontSize: 12, color: AppColors.mid),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.gold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Reading the garment color…',
              style: TextStyle(fontSize: 12, color: AppColors.mid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Something went wrong.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspiciousBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8C57A).withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFB07A1E),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This photo has a lot of texture or a strong green tone — it might be a plant, animal or scenery shot rather than plain fabric. For a reliable check, photograph a flat, evenly-lit piece of clothing.',
              style: TextStyle(fontSize: 12, color: const Color(0xFF6B4E12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    final levelInfo = _levelInfo(result.level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _sampledColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.compare_arrows, size: 16, color: AppColors.mid),
              const SizedBox(width: 6),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: result.closest.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      levelInfo.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: levelInfo.color,
                      ),
                    ),
                    Text(
                      'ใกล้เคียง ${result.closest.name} มากที่สุด',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mid,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${result.percent}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: levelInfo.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: result.percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.cream,
              valueColor: AlwaysStoppedAnimation(levelInfo.color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            levelInfo.description,
            style: const TextStyle(fontSize: 12, color: AppColors.mid),
          ),
        ],
      ),
    );
  }

  // Explains WHERE the sampled color came from, and WHICH part of the
  // palette it was compared to and WHY that particular color was picked.
  Widget _buildExplanationCard() {
    final result = _result!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _explanationRow(
            Icons.crop_free,
            'Sampled from the middle ~60% of your photo, so edge/background pixels are ignored.',
          ),
          const SizedBox(height: 8),
          _explanationRow(
            Icons.category_outlined,
            'Compared against the "${result.closestCategory}" colors in your ${_profile.displayName} palette.',
          ),
          const SizedBox(height: 8),
          _explanationRow(
            Icons.emoji_objects_outlined,
            '"${result.closest.name}" was picked because it has the smallest color difference to your photo out of every color in that group.',
          ),
        ],
      ),
    );
  }

  Widget _explanationRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.charcoal,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  _LevelInfo _levelInfo(MatchLevel level) {
    switch (level) {
      case MatchLevel.excellent:
        return _LevelInfo(
          'เข้ากับซีซั่นมาก',
          const Color(0xFF3E9C6D),
          'สีนี้อยู่ในโทนของ ${_profile.displayName} พอดี ใส่ได้อย่างมั่นใจ',
        );
      case MatchLevel.good:
        return _LevelInfo(
          'พอใช้ได้',
          const Color(0xFFD9A441),
          'สีนี้ใกล้เคียงกับโทน ${_profile.displayName} อยู่บ้าง ลองจับคู่กับชิ้นที่เป็นกลางเพิ่มเติม',
        );
      case MatchLevel.poor:
        return _LevelInfo(
          'ควรเลี่ยง',
          const Color(0xFFC65B5B),
          'สีนี้ค่อนข้างห่างจากโทนของ ${_profile.displayName} ลองถ่ายชิ้นอื่นเทียบดูอีกครั้ง',
        );
    }
  }
}

class _LevelInfo {
  final String label;
  final Color color;
  final String description;
  const _LevelInfo(this.label, this.color, this.description);
}

//Simple dashed border
class DottedContainer extends StatelessWidget {
  final Widget child;
  const DottedContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        height: 140,
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.mid.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
