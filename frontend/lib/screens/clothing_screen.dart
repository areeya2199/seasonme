import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/season_palette.dart';
import '../services/clothing_check.dart';

//หน้านี้ยังไม่เสร็จสมบูรณ์
class ClothingScreen extends StatefulWidget {
  final SeasonKey season;
  const ClothingScreen({super.key, this.season = SeasonKey.Autumn});

  @override
  State<ClothingScreen> createState() => _ClothingScreenState();
}

enum _LoadState { idle, loading, done, error }

class _ClothingScreenState extends State<ClothingScreen> {
  File? _pickedImage;
  DominantColorResult? _detected;
  OutfitMatchVerdict? _verdict;
  _LoadState _state = _LoadState.idle;
  String? _errorMessage;

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
        _verdict = null;
        _detected = null;
      });

      final detected = await ClothingColorService.extractDominantColor(file);
      final verdict = ClothingColorService.evaluate(widget.season, detected);

      if (!mounted) return;
      setState(() {
        _detected = detected;
        _verdict = verdict;
        _state = _LoadState.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage =
            'Could not analyze this photo. Please try a clearer, well-lit picture of the garment.';
      });
    }
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

              // Upload area — tappable, opens camera/gallery sheet.
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
              const SizedBox(height: 24),

              if (_state == _LoadState.loading) _buildLoading(),
              if (_state == _LoadState.error) _buildError(),
              if (_state == _LoadState.done &&
                  _detected != null &&
                  _verdict != null)
                _buildResultCard(_detected!, _verdict!),

              const SizedBox(height: 12),
              const Text(
                'Or tap a swatch from your clothing palette',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaletteQuickTest(),

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

  Widget _buildResultCard(
    DominantColorResult detected,
    OutfitMatchVerdict verdict,
  ) {
    final statusColor = verdict.isGoodMatch ? AppColors.sage : Colors.redAccent;
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: detected.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.charcoal.withOpacity(0.08),
                    width: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected garment color',
                      style: TextStyle(fontSize: 11, color: AppColors.mid),
                    ),
                    Text(
                      '#${detected.color.value.toRadixString(16).substring(2).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verdict.isGoodMatch ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Text(
                  verdict.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${(verdict.score * 100).round()}% fit',
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            verdict.reason,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mid,
              height: 1.5,
            ),
          ),
          if (verdict.closestPaletteColor != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: verdict.closestPaletteColor!.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Closest in your palette: ${verdict.closestPaletteColor!.name}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaletteQuickTest() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _profile.tops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final swatch = _profile.tops[i];
          return GestureDetector(
            onTap: () {
              final hsl = HSLColor.fromColor(swatch.color);
              final detected = DominantColorResult(
                swatch.color,
                hsl.hue,
                hsl.saturation,
                hsl.lightness,
              );
              final verdict = ClothingColorService.evaluate(
                widget.season,
                detected,
              );
              setState(() {
                _pickedImage = null;
                _detected = detected;
                _verdict = verdict;
                _state = _LoadState.done;
              });
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: swatch.color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
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
