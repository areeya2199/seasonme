import 'package:flutter/material.dart';
import '../data/season_palette.dart';
import '../services/analysis_history.dart';
import '../theme/app_theme.dart';
import 'clothing_screen.dart';
import 'select_screen.dart';

/// Result — "Your Result / <Season>" + palette sections, driven by the
/// real per-season data in season_palette.dart.
///
/// Pass [recordToHistory]: false when just re-opening a past result from
/// Home's Analysis History (tapping a history card) — otherwise every
/// re-view would add a duplicate entry. It defaults to true because a
/// freshly-completed analysis (coming from ProcessingScreen) should be
/// saved.
class ResultScreen extends StatefulWidget {
  final SeasonKey season;
  final bool recordToHistory;

  const ResultScreen({
    super.key,
    required this.season,
    this.recordToHistory = true,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final SeasonProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = SeasonPaletteData.getProfile(widget.season);
    if (widget.recordToHistory) {
      AnalysisHistoryService.addEntry(widget.season);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GradientBackButton(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.ios_share,
                      size: 16,
                      color: AppColors.charcoal,
                    ),
                  ),
                  onPressed: () {
                    // TODO: implement share result.
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'YOUR SEASON IS',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _profile.displayName,
              style: const TextStyle(
                fontFamily: 'Lora',
                fontSize: 32,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    _profile.undertone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _profile.description,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.mid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            _paletteSection(
              'Your Color Palette',
              _profile.yourColorPalette,
              big: true,
            ),
            _paletteSection(
              'Recommended Hair Colors',
              _profile.hair,
              sparkle: true,
            ),
            _paletteSection('Eye Makeup', _profile.eyeMakeup, sparkle: true),
            _paletteSection('Blush Palette', _profile.blush, sparkle: true),
            _paletteSection(
              'Lipstick Palette',
              _profile.lipstick,
              sparkle: true,
            ),
            _paletteSection('Jewelry', _profile.jewelry, sparkle: true),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide.none,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClothingScreen()),
                ),
                icon: const Icon(Icons.checkroom_outlined, size: 18),
                label: const Text('Check an Outfit'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.blush, AppColors.gold],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectScreen()),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Analyze Again'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _paletteSection(
    String title,
    List<SwatchItem> items, {
    bool big = false,
    bool sparkle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (sparkle) ...[
                const Icon(Icons.auto_awesome, size: 15, color: AppColors.gold),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: items
                .map((s) => _SwatchTile(item: s, size: 100))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final SwatchItem item;
  final double size;
  const _SwatchTile({required this.item, this.size = 100});

  String get _hex =>
      '#${item.color.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Copy hex to clipboard
        // Clipboard.setData(ClipboardData(text: _hex));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_hex copied'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: size,
              height: size * 0.62,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            Text(
              _hex,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.mid,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
