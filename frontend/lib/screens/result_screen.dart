import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../data/season_palette.dart';
import '../data/occasion_palette.dart';
import '../utils/color_utils.dart';
import '../services/analysis_history.dart';
import '../theme/app_theme.dart';
import 'clothing_screen.dart';
import 'select_screen.dart';

// Same warm brown gradient used on the Home screen's "personal color" card.
const List<Color> _personalColorGradient = [
  Color(0xFF6B4E36),
  Color(0xFF8A6A47),
];

class ResultScreen extends StatefulWidget {
  final SeasonKey season;
  final bool recordToHistory;
  final Map<String, dynamic>? analysis;
  final Map<String, String?>? questionnaireAnswers;
  // The photo the user just took/uploaded for this analysis. Only set right
  // after processing — revisiting a past result from Home/Profile/History
  // has no photo on hand, so this stays null there and the photo block
  // simply doesn't render.
  final String? imagePath;

  const ResultScreen({
    super.key,
    required this.season,
    this.recordToHistory = true,
    this.analysis,
    this.questionnaireAnswers,
    this.imagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const int _topsGroupCount = 7;
  static const int _topsGroupSize = 9;
  static const int _occasionItemCount = 5;

  bool _nightMode = false;
  Occasion? _occasion;

  // 0 = Wardrobe, 1 = Beauty & Jewelry
  int _mainTab = 0;
  // which category is shown in the Beauty & Jewelry tab
  String _beautyCategory = 'hair';

  int? _selectedTopIndex;
  int? _matchedBottomIndex; // auto harmony pick, from the selected top
  int? _selectedBottomIndex; // manual override, wins over the auto pick

  int _topsGroupIndex = 0;

  late SeasonProfile _profile;
  late List<SwatchItem> _tops;
  late List<SwatchItem> _bottoms;
  late List<SwatchItem> _hair;
  late List<SwatchItem> _eyeMakeup;
  late List<SwatchItem> _blush;
  late List<SwatchItem> _lipstick;
  late List<SwatchItem> _jewelry;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.recordToHistory && widget.analysis != null) {
      AnalysisHistoryService.addEntry(
        season: widget.season,
        analysis: widget.analysis!,
        questionnaireAnswers: widget.questionnaireAnswers ?? const {},
      );
    }
  }

  void _loadProfile() {
    _profile = SeasonPaletteData.getProfile(widget.season, night: _nightMode);
    _selectedTopIndex = null;
    _matchedBottomIndex = null;
    _selectedBottomIndex = null;

    if (_occasion == null) {
      _bottoms = SeasonPaletteData.pickRandom(_profile.bottoms, 9);
      _hair = _profile.hair;
      _eyeMakeup = _profile.eyeMakeup;
      _blush = _profile.blush;
      _lipstick = _profile.lipstick;
      _jewelry = _profile.jewelry;
      _topsGroupIndex = Random().nextInt(_topsGroupCount);
      _tops = _topsFromGroup();
    } else {
      _refreshOccasionPools();
    }
  }

  List<SwatchItem> _topsFromGroup() {
    final start = _topsGroupIndex * _topsGroupSize;
    return _profile.topsPool.sublist(start, start + _topsGroupSize);
  }

  void _refreshOccasionPools() {
    final occ = _occasion!;
    _tops = OccasionPaletteSelector.select(
      occ,
      _profile.topsPool,
      _occasionItemCount,
    );
    _bottoms = OccasionPaletteSelector.select(
      occ,
      _profile.bottoms,
      _occasionItemCount,
    );
    _hair = OccasionPaletteSelector.select(
      occ,
      _profile.hair,
      _occasionItemCount,
    );
    _eyeMakeup = OccasionPaletteSelector.select(
      occ,
      _profile.eyeMakeup,
      _occasionItemCount,
    );
    _blush = OccasionPaletteSelector.select(
      occ,
      _profile.blush,
      _occasionItemCount,
    );
    _lipstick = OccasionPaletteSelector.select(
      occ,
      _profile.lipstick,
      _occasionItemCount,
    );
    _jewelry = OccasionPaletteSelector.select(
      occ,
      _profile.jewelry,
      _occasionItemCount,
    );
  }

  void _shuffleTops() {
    setState(() {
      _selectedTopIndex = null;
      _matchedBottomIndex = null;
      _selectedBottomIndex = null;
      if (_occasion == null) {
        int next;
        do {
          next = Random().nextInt(_topsGroupCount);
        } while (next == _topsGroupIndex && _topsGroupCount > 1);
        _topsGroupIndex = next;
        _tops = _topsFromGroup();
      } else {
        _tops = OccasionPaletteSelector.select(
          _occasion!,
          _profile.topsPool,
          _occasionItemCount,
        );
      }
    });
  }

  void _setNightMode(bool value) {
    if (value == _nightMode) return;
    setState(() {
      _nightMode = value;
      _loadProfile();
    });
  }

  Future<void> _showOccasionPicker() async {
    final chosen = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _OccasionSheet(current: _occasion),
    );
    if (chosen == _unchanged) return;
    setState(() {
      _occasion = chosen as Occasion?;
      _loadProfile();
    });
  }

  // Tapping a Top: sets the shirt color and auto-picks a harmonious pair of
  // pants (color-theory match), clearing any earlier manual pants pick.
  void _onTopTap(int index) {
    setState(() {
      if (_selectedTopIndex == index) {
        _selectedTopIndex = null;
        _matchedBottomIndex = null;
        _selectedBottomIndex = null;
        return;
      }
      _selectedTopIndex = index;
      _selectedBottomIndex = null;
      final color = _tops[index].color;
      _matchedBottomIndex = ColorUtils.pickHarmoniousIndex(
        color,
        _bottoms.map((e) => e.color).toList(),
        random: Random(),
      );
    });
  }

  // Tapping a Bottom directly overrides whatever the auto-match picked.
  void _onBottomTap(int index) {
    setState(() {
      _selectedBottomIndex = _selectedBottomIndex == index ? null : index;
    });
  }

  Color? get _shirtColor =>
      _selectedTopIndex != null ? _tops[_selectedTopIndex!].color : null;

  Color? get _pantsColor {
    if (_selectedBottomIndex != null)
      return _bottoms[_selectedBottomIndex!].color;
    if (_matchedBottomIndex != null)
      return _bottoms[_matchedBottomIndex!].color;
    return null;
  }

  int? get _activeBottomIndex => _selectedBottomIndex ?? _matchedBottomIndex;

  String _dayNightBlurb() => _nightMode
      ? 'Rich, vivid combinations for evening.'
      : 'Light, fresh combinations for daytime.';

  List<SwatchItem> _beautyItems(String cat) {
    switch (cat) {
      case 'hair':
        return _hair;
      case 'eye':
        return _eyeMakeup;
      case 'blush':
        return _blush;
      case 'lipstick':
        return _lipstick;
      case 'jewelry':
        return _jewelry;
    }
    return const [];
  }

  String _beautyChipLabel(String cat) {
    switch (cat) {
      case 'hair':
        return 'Hair';
      case 'eye':
        return 'Eyes';
      case 'blush':
        return 'Blush';
      case 'lipstick':
        return 'Lips';
      case 'jewelry':
        return 'Jewelry';
    }
    return '';
  }

  String _beautySectionTitle(String cat) {
    switch (cat) {
      case 'hair':
        return 'Recommended Hair Colors';
      case 'eye':
        return 'Eye Makeup';
      case 'blush':
        return 'Blush Palette';
      case 'lipstick':
        return 'Lipstick Palette';
      case 'jewelry':
        return 'Jewelry';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final chroma = ColorUtils.chromaLabel(
      _profile.topsPool.map((s) => s.color).toList(),
    );

    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildTopBar(),
            const SizedBox(height: 16),
            _buildPersonalColorCard(chroma),
            if (widget.imagePath != null) ...[
              const SizedBox(height: 16),
              _buildUserPhoto(),
            ],
            const SizedBox(height: 16),
            _buildDayNightToggle(),
            const SizedBox(height: 12),
            _buildOccasionPill(),
            const SizedBox(height: 16),
            _buildMainTabs(),
            const SizedBox(height: 18),
            _mainTab == 0 ? _buildWardrobeTab() : _buildBeautyTab(),
            const SizedBox(height: 20),

            // Check an Outfit — compares against THIS season only.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6DFFA),
                  foregroundColor: const Color(0xFF5B3E9C),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClothingScreen(season: widget.season),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text(
                  'Check an Outfit',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectScreen()),
                ),
                child: const Text(
                  'Analyze Again',
                  style: TextStyle(
                    color: AppColors.mid,
                    fontWeight: FontWeight.w600,
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

  Widget _buildTopBar() {
    return Row(
      children: [
        _circleIconButton(
          Icons.chevron_left,
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        const Expanded(
          child: Text(
            'My Colors',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        _circleIconButton(Icons.tune, small: true, onTap: _showOccasionPicker),
      ],
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

  Widget _buildPersonalColorCard(String chroma) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _personalColorGradient,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PERSONAL COLOR',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _profile.displayName,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 34,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _profile.description,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFEADFD0)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pillTag(_profile.core.warm ? 'Warm' : 'Cool'),
              const SizedBox(width: 8),
              _pillTag(chroma),
            ],
          ),
        ],
      ),
    );
  }

  // Fixed width/height frame, centered — BoxFit.cover means the photo
  // always fills this exact frame regardless of the source photo's own
  // dimensions or orientation (portrait, landscape, square all look the
  // same size here; excess is cropped rather than the frame resizing).
  static const double _photoWidth = 200;
  static const double _photoHeight = 240;

  Widget _buildUserPhoto() {
    final path = widget.imagePath!;
    final fallback = Container(
      color: AppColors.cream,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.mid,
      ),
    );
    // On Flutter web the picked "path" is a blob URL and Image.file is not
    // supported, so use Image.network there.
    final image = kIsWeb
        ? Image.network(
            path,
            width: _photoWidth,
            height: _photoHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.file(
            File(path),
            width: _photoWidth,
            height: _photoHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
    return Center(
      child: Container(
        width: _photoWidth,
        height: _photoHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(20), child: image),
      ),
    );
  }

  Widget _pillTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
              color: active ? const Color(0xff4c3935) : AppColors.white,
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

  Widget _buildOccasionPill() {
    return GestureDetector(
      onTap: _showOccasionPicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 16, color: AppColors.mid),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _occasion?.label ?? 'All occasions',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.mid),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTabs() {
    Widget tab(String label, int index) {
      final active = _mainTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mainTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xff4c3935) : AppColors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.mid,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Wardrobe', 0),
        const SizedBox(width: 10),
        tab('Beauty & Jewelry', 1),
      ],
    );
  }

  // ---------------- Wardrobe: Tops + Bottoms + live mannequin ----------------

  Widget _buildWardrobeTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeaderRow('Tops', onShuffle: _shuffleTops),
              const SizedBox(height: 2),
              Text(
                _dayNightBlurb(),
                style: const TextStyle(fontSize: 11.5, color: AppColors.mid),
              ),
              const SizedBox(height: 10),
              _compactSwatchWrap(
                _tops,
                selectedIndex: _selectedTopIndex,
                onTap: _onTopTap,
              ),
              const SizedBox(height: 22),
              _sectionHeaderRow('Bottoms'),
              const SizedBox(height: 2),
              Text(
                _dayNightBlurb(),
                style: const TextStyle(fontSize: 11.5, color: AppColors.mid),
              ),
              const SizedBox(height: 10),
              _compactSwatchWrap(
                _bottoms,
                selectedIndex: _activeBottomIndex,
                onTap: _onBottomTap,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _MannequinCard(shirtColor: _shirtColor, pantsColor: _pantsColor),
      ],
    );
  }

  Widget _sectionHeaderRow(String title, {VoidCallback? onShuffle}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        if (onShuffle != null) ...[
          const SizedBox(width: 8),
          _ShuffleButton(onTap: onShuffle),
        ],
      ],
    );
  }

  Widget _compactSwatchWrap(
    List<SwatchItem> items, {
    int? selectedIndex,
    required void Function(int index) onTap,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        final active = selectedIndex == i;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active ? AppColors.gold : Colors.white,
                width: active ? 2.5 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.4),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------- Beauty & Jewelry ----------------

  Widget _buildBeautyTab() {
    const categories = ['hair', 'eye', 'blush', 'lipstick', 'jewelry'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final active = _beautyCategory == c;
            return GestureDetector(
              onTap: () => setState(() => _beautyCategory = c),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? const Color(0xff4c3935) : AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _beautyChipLabel(c),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.mid,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Text(
          _beautySectionTitle(_beautyCategory),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _dayNightBlurb(),
          style: const TextStyle(fontSize: 11.5, color: AppColors.mid),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _beautyItems(
            _beautyCategory,
          ).map((s) => _SwatchTile(item: s)).toList(),
        ),
      ],
    );
  }
}

const Object _unchanged = Object();

class _OccasionSheet extends StatelessWidget {
  final Occasion? current;
  const _OccasionSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    Widget tile(
      String label,
      String? subtitle,
      IconData icon,
      Occasion? value,
    ) {
      final active = current == value;
      return ListTile(
        leading: Icon(icon, color: active ? AppColors.gold : AppColors.mid),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: AppColors.mid),
              )
            : null,
        trailing: active
            ? const Icon(Icons.check, color: AppColors.gold)
            : null,
        onTap: () => Navigator.pop(context, value),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _unchanged);
        return false;
      },
      child: Container(
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
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose Occasion',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              tile('Show All (Default)', null, Icons.palette_outlined, null),
              const Divider(height: 1),
              for (final occ in Occasion.values)
                tile(occ.label, occ.subtitle, occ.icon, occ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple, functional torso+legs figure. Grey until a top / bottom is chosen.
class _MannequinCard extends StatelessWidget {
  final Color? shirtColor;
  final Color? pantsColor;
  const _MannequinCard({this.shirtColor, this.pantsColor});

  @override
  Widget build(BuildContext context) {
    final shirt = shirtColor ?? AppColors.mid.withOpacity(0.18);
    final pants = pantsColor ?? AppColors.charcoal.withOpacity(0.16);
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8C9A0),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 78,
            height: 60,
            decoration: BoxDecoration(
              color: shirt,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
                bottom: Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 58,
            height: 66,
            decoration: BoxDecoration(
              color: pants,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Preview',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.mid,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  final SwatchItem item;
  final double size;
  const _SwatchTile({required this.item, this.size = 90});

  String get _hex =>
      '#${item.color.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
              style: const TextStyle(fontSize: 9.5, color: AppColors.mid),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShuffleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
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
        child: const Icon(Icons.shuffle, size: 15, color: AppColors.charcoal),
      ),
    );
  }
}
