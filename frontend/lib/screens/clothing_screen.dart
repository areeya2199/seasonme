import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/season_palette.dart';
import '../utils/color_utils.dart';

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

class _ClothingScreenState extends State<ClothingScreen> {
  File? _pickedImage;
  Color? _sampledColor;
  _LoadState _state = _LoadState.idle;
  String? _errorMessage;
  _OutfitMatch? _result;

  late final SeasonProfile _profile = SeasonPaletteData.getProfile(
    widget.season,
  );

  // Quick-tap alternative to taking a photo — colors already known to
  // belong to this season, for a fast manual check.
  late final List<SwatchItem> _quickSwatches = [
    ..._profile.topsPool.take(8),
    ..._profile.bottoms,
  ];

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
      });

      final color = await _extractDominantColor(file);
      final match = _matchAgainstSeason(color);
      if (!mounted) return;
      setState(() {
        _sampledColor = color;
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

  void _pickQuickSwatch(SwatchItem item) {
    setState(() {
      _pickedImage = null;
      _sampledColor = item.color;
      _result = _matchAgainstSeason(item.color);
      _state = _LoadState.done;
      _errorMessage = null;
    });
  }

  // ---- "Take a photo and detect the color": average the center of the
  // frame, where the garment usually fills the shot while background
  // tends to sit toward the edges. No extra package needed — dart:ui
  // decodes the image and we read raw RGBA bytes directly. ----
  Future<Color> _extractDominantColor(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return Colors.grey;

    final pixels = byteData.buffer.asUint8List();
    final w = image.width, h = image.height;
    final x0 = (w * 0.2).round(), x1 = (w * 0.8).round();
    final y0 = (h * 0.2).round(), y1 = (h * 0.8).round();

    int rSum = 0, gSum = 0, bSum = 0, count = 0;
    for (int y = y0; y < y1; y += 2) {
      for (int x = x0; x < x1; x += 2) {
        final i = (y * w + x) * 4;
        if (i + 3 >= pixels.length) continue;
        final a = pixels[i + 3];
        if (a < 200) continue;
        rSum += pixels[i];
        gSum += pixels[i + 1];
        bSum += pixels[i + 2];
        count++;
      }
    }
    if (count == 0) return Colors.grey;
    return Color.fromARGB(
      255,
      (rSum / count).round(),
      (gSum / count).round(),
      (bSum / count).round(),
    );
  }

  // ---- Compare only against THIS season's own palette. If the result
  // screen showed Winter, this checks against Winter only — and so on
  // for each of the 4 seasons. ----
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
              if (_state == _LoadState.done && _result != null)
                _buildResultCard(),

              const SizedBox(height: 24),
              const Text(
                'Or tap a swatch from your clothing palette',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickSwatches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final item = _quickSwatches[i];
                    final active = _sampledColor == item.color;
                    return GestureDetector(
                      onTap: () => _pickQuickSwatch(item),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? AppColors.charcoal : Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.charcoal.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
          'สีนี้ค่อนข้างห่างจากโทนของ ${_profile.displayName} ลองเทียบกับพาเลตด้านล่างแทน',
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
