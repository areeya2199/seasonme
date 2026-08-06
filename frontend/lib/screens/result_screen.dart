import 'dart:math';

import 'package:flutter/material.dart';
import '../data/season_palette.dart';
import '../services/analysis_history.dart';
import '../theme/app_theme.dart';
import 'clothing_screen.dart';
import 'select_screen.dart';

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
  static const int _topsGroupCount = 7;
  static const int _topsGroupSize = 9;

  bool _nightMode = false;
  int? _selectedTopIndex;
  int _topsGroupIndex = 0;

  late SeasonProfile _profile;
  late List<SwatchItem> _bottoms;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.recordToHistory) {
      AnalysisHistoryService.addEntry(widget.season);
    }
  }

  void _loadProfile() {
    _profile = SeasonPaletteData.getProfile(widget.season, night: _nightMode);
    _bottoms = SeasonPaletteData.pickRandom(_profile.bottoms, 9);
    _topsGroupIndex = Random().nextInt(_topsGroupCount);
    _selectedTopIndex = null;
  }

  //สุ่มจากกลุ่มของ tops ที่มีอยู่ใน profile โดยใช้ _topsGroupIndex
  List<SwatchItem> get _tops {
    final start = _topsGroupIndex * _topsGroupSize;
    return _profile.topsPool.sublist(start, start + _topsGroupSize);
  }

  void _shuffleTops() {
    setState(() {
      int next;
      do {
        next = Random().nextInt(_topsGroupCount);
      } while (next == _topsGroupIndex);
      _topsGroupIndex = next;
      _selectedTopIndex = null;
    });
  }

  void _setNightMode(bool value) {
    if (value == _nightMode) return;
    setState(() {
      _nightMode = value;
      _loadProfile();
    });
  }

  //จับคู่สี
  void _onTopTap(int index) {
    setState(() {
      _selectedTopIndex = _selectedTopIndex == index ? null : index;
    });
  }

  //คำนวณระยะห่างของสีในอวกาศ Lab เพื่อหาสีที่ใกล้เคียงที่สุด
  double _colorDistance(Color a, Color b) {
    final labA = _rgbToLab(a);
    final labB = _rgbToLab(b);
    final dl = labA[0] - labB[0];
    final da = labA[1] - labB[1];
    final db = labA[2] - labB[2];
    return sqrt(dl * dl + da * da + db * db);
  }

  List<double> _rgbToLab(Color c) {
    double r = c.red / 255.0, g = c.green / 255.0, b = c.blue / 255.0;
    r = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;
    r *= 100;
    g *= 100;
    b *= 100;

    final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 95.047;
    final y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 100.0;
    final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 108.883;

    double f(double t) =>
        t > 0.008856 ? pow(t, 1 / 3).toDouble() : (7.787 * t) + 16 / 116;

    final fx = f(x), fy = f(y), fz = f(z);
    return [(116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  int? _nearestIndex(Color target, List<SwatchItem> items) {
    if (items.isEmpty) return null;
    int bestIndex = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < items.length; i++) {
      final d = _colorDistance(target, items[i].color);
      if (d < bestDist) {
        bestDist = d;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _selectedTopIndex != null
        ? _tops[_selectedTopIndex!].color
        : null;

    final matchedBottoms = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _bottoms);
    final matchedHair = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _profile.hair);
    final matchedEyeMakeup = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _profile.eyeMakeup);
    final matchedBlush = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _profile.blush);
    final matchedLipstick = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _profile.lipstick);
    final matchedJewelry = selectedColor == null
        ? null
        : _nearestIndex(selectedColor, _profile.jewelry);

    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildResultHeader(),
            const SizedBox(height: 18),
            _buildDayNightToggle(),
            const SizedBox(height: 8),
            if (_selectedTopIndex != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Paired with the colors ringed in gold below ,tap another swatch to change, or tap it again to clear.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mid,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            _paletteSection(
              'Tops',
              _tops,
              big: true,
              selectable: true,
              sparkle: true,
              selectedIndex: _selectedTopIndex,
              onTapItem: _onTopTap,
              onShuffle: _shuffleTops,
            ),
            _paletteSection(
              'Bottoms',
              _bottoms,
              sparkle: true,
              matchedIndex: matchedBottoms,
            ),
            _paletteSection(
              'Recommended Hair Colors',
              _profile.hair,
              sparkle: true,
              matchedIndex: matchedHair,
            ),
            _paletteSection(
              'Eye Makeup',
              _profile.eyeMakeup,
              sparkle: true,
              matchedIndex: matchedEyeMakeup,
            ),
            _paletteSection(
              'Blush Palette',
              _profile.blush,
              sparkle: true,
              matchedIndex: matchedBlush,
            ),
            _paletteSection(
              'Lipstick Palette',
              _profile.lipstick,
              sparkle: true,
              matchedIndex: matchedLipstick,
            ),
            _paletteSection(
              'Jewelry',
              _profile.jewelry,
              sparkle: true,
              matchedIndex: matchedJewelry,
            ),

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
                  MaterialPageRoute(
                    builder: (_) => ClothingScreen(season: widget.season),
                  ),
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

  Widget _buildResultHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _circleIconButton(
                Icons.chevron_left,
                onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
              ),
              const Expanded(
                child: Text(
                  'Your Result',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              _circleIconButton(
                Icons.ios_share,
                small: true,
                onTap: () {
                  // TODO: implement share result.
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xfffee8f2),
                  Color(0xffffebe9),
                  Color(0xffffede0),
                  Color(0xfffbecee),
                  Color(0xfff4eafd),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Text(
                  'YOUR SEASON IS',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blush,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _profile.displayName,
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.circle, size: 9, color: AppColors.gold),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(
    IconData icon, {
    required VoidCallback onTap,
    bool small = false,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Container(
        padding: EdgeInsets.all(small ? 8 : 6),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: small ? 15 : 20, color: AppColors.charcoal),
      ),
    );
  }

  Widget _buildDayNightToggle() {
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? Color(0xff4c3935) : AppColors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? Colors.white : AppColors.mid,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.mid,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(
          'Day',
          Icons.wb_sunny_outlined,
          !_nightMode,
          () => _setNightMode(false),
        ),
        const SizedBox(width: 10),
        chip(
          'Night Mode',
          Icons.nightlight_round,
          _nightMode,
          () => _setNightMode(true),
        ),
      ],
    );
  }

  Widget _paletteSection(
    String title,
    List<SwatchItem> items, {
    bool big = false,
    bool sparkle = false,
    bool selectable = false,
    int? selectedIndex,
    int? matchedIndex,
    void Function(int index)? onTapItem,
    VoidCallback? onShuffle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              //icon sun moon
              if (sparkle) ...[
                Icon(
                  _nightMode ? Icons.nightlight_round : Icons.sunny,
                  size: 15,
                  color: _nightMode
                      ? const Color.fromARGB(255, 230, 220, 28)
                      : const Color.fromARGB(255, 239, 173, 20),
                ),
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
              if (onShuffle != null) ...[
                const SizedBox(width: 8),
                _ShuffleButton(onTap: onShuffle),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _SwatchTile(
                item: s,
                size: 100,
                selected: selectable && selectedIndex == i,
                matched: matchedIndex == i,
                onSelect: selectable && onTapItem != null
                    ? () => onTapItem(i)
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final SwatchItem item;
  final double size;
  final VoidCallback? onSelect;
  final bool selected;
  final bool matched;

  const _SwatchTile({
    required this.item,
    this.size = 100,
    this.onSelect,
    this.selected = false,
    this.matched = false,
  });

  String get _hex =>
      '#${item.color.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onSelect?.call();
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
                border: selected
                    ? Border.all(color: AppColors.charcoal, width: 3)
                    : matched
                    ? Border.all(color: AppColors.gold, width: 3)
                    : null,
                boxShadow: selected || matched
                    ? [
                        BoxShadow(
                          color:
                              (selected ? AppColors.charcoal : AppColors.gold)
                                  .withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : matched
                  ? const Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.link, size: 14, color: Colors.white),
                      ),
                    )
                  : null,
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
          ],
        ),
      ),
    );
  }
}

//ปุมShuffle tops
class _ShuffleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShuffleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.shuffle, size: 16, color: AppColors.charcoal),
      ),
    );
  }
}
