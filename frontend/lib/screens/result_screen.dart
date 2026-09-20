import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../data/season_palette.dart';
import '../data/occasion_palette.dart';
import '../utils/color_utils.dart';
import '../services/analysis_history.dart';
import '../theme/app_theme.dart';
import 'clothing_screen.dart';
import 'select_screen.dart';

class ResultScreen extends StatefulWidget {
  final SeasonKey season;
  final bool recordToHistory;
  final Map<String, dynamic>? analysis;
  final Map<String, String?>? questionnaireAnswers;

  const ResultScreen({
    super.key,
    required this.season,
    this.recordToHistory = true,
    this.analysis,
    this.questionnaireAnswers,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  static const int _topsGroupCount = 7;
  static const int _topsGroupSize = 9;
  static const int _occasionItemCount = 5;

  // Order the sections appear on screen — also the order the floating
  // "trail" bars stack in as the user scrolls past each one.
  static const List<String> _sectionOrder = [
    'tops',
    'bottoms',
    'hair',
    'eye',
    'blush',
    'lipstick',
    'jewelry',
  ];
  // How many of the most-recently-passed sections stay docked as
  // floating bars — keeps the trail from eventually covering the screen.
  static const int _maxTrailBars = 4;

  bool _nightMode = false;
  Occasion? _occasion;
  int? _selectedTopIndex;
  int _topsGroupIndex = 0;

  late SeasonProfile _profile;

  late List<SwatchItem> _tops;
  late List<SwatchItem> _bottoms;
  late List<SwatchItem> _hair;
  late List<SwatchItem> _eyeMakeup;
  late List<SwatchItem> _blush;
  late List<SwatchItem> _lipstick;
  late List<SwatchItem> _jewelry;

  // Harmony-matched indices, computed once per tap (not on every build)
  // so the "controlled randomness" doesn't reshuffle every frame.
  int? _matchedBottoms;
  int? _matchedHair;
  int? _matchedEye;
  int? _matchedBlush;
  int? _matchedLipstick;
  int? _matchedJewelry;

  // ---- scroll-following mini palette trail ----
  final GlobalKey _stackKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {
    for (final id in _sectionOrder) id: GlobalKey(),
  };
  List<String> _passedSections = [];

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
    _scrollController.addListener(_recomputePassedSections);
    _scheduleRecompute();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_recomputePassedSections);
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleRecompute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recomputePassedSections();
    });
  }

  void _recomputePassedSections() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.attached) return;

    final passed = <String>[];
    for (final id in _sectionOrder) {
      final ctx = _sectionKeys[id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final topLeft = box.localToGlobal(Offset.zero, ancestor: stackBox);
      final bottom = topLeft.dy + box.size.height;
      if (bottom < 4) {
        passed.add(id);
      }
    }
    if (!_listEquals(passed, _passedSections)) {
      setState(() => _passedSections = passed);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _loadProfile() {
    _profile = SeasonPaletteData.getProfile(widget.season, night: _nightMode);
    _selectedTopIndex = null;
    _passedSections = [];
    _clearMatches();

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
    _scheduleRecompute();
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
      _clearMatches();
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
    _scheduleRecompute();
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

  void _onTopTap(int index) {
    setState(() {
      if (_selectedTopIndex == index) {
        _selectedTopIndex = null;
        _clearMatches();
      } else {
        _selectedTopIndex = index;
        final color = _tops[index].color;
        final rnd = Random();
        _matchedBottoms = ColorUtils.pickHarmoniousIndex(
          color,
          _bottoms.map((e) => e.color).toList(),
          random: rnd,
        );
        _matchedHair = ColorUtils.pickHarmoniousIndex(
          color,
          _hair.map((e) => e.color).toList(),
          random: rnd,
        );
        _matchedEye = ColorUtils.pickHarmoniousIndex(
          color,
          _eyeMakeup.map((e) => e.color).toList(),
          random: rnd,
        );
        _matchedBlush = ColorUtils.pickHarmoniousIndex(
          color,
          _blush.map((e) => e.color).toList(),
          random: rnd,
        );
        _matchedLipstick = ColorUtils.pickHarmoniousIndex(
          color,
          _lipstick.map((e) => e.color).toList(),
          random: rnd,
        );
        _matchedJewelry = ColorUtils.pickHarmoniousIndex(
          color,
          _jewelry.map((e) => e.color).toList(),
          random: rnd,
        );
      }
    });
    // Sections collapse to a single swatch (or back to a full grid),
    // which changes their height — re-measure the trail after that layout settles.
    _scheduleRecompute();
  }

  void _clearMatches() {
    _matchedBottoms = null;
    _matchedHair = null;
    _matchedEye = null;
    _matchedBlush = null;
    _matchedLipstick = null;
    _matchedJewelry = null;
  }

  // ---- helpers shared by the inline sections and the floating trail ----

  String _sectionTitle(String id) {
    switch (id) {
      case 'tops':
        return 'Tops';
      case 'bottoms':
        return 'Bottoms';
      case 'hair':
        return 'Hair';
      case 'eye':
        return 'Eye Makeup';
      case 'blush':
        return 'Blush';
      case 'lipstick':
        return 'Lipstick';
      case 'jewelry':
        return 'Jewelry';
    }
    return '';
  }

  List<SwatchItem> _sectionItems(String id) {
    switch (id) {
      case 'tops':
        return _tops;
      case 'bottoms':
        return _bottoms;
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

  // For 'tops' this is just the user's tapped swatch; for every other
  // section it's the harmony-matched swatch computed in _onTopTap.
  int? _matchedIndexFor(String id) {
    switch (id) {
      case 'tops':
        return _selectedTopIndex;
      case 'bottoms':
        return _matchedBottoms;
      case 'hair':
        return _matchedHair;
      case 'eye':
        return _matchedEye;
      case 'blush':
        return _matchedBlush;
      case 'lipstick':
        return _matchedLipstick;
      case 'jewelry':
        return _matchedJewelry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Stack(
        key: _stackKey,
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildResultHeader(),
                const SizedBox(height: 18),
                _buildDayNightToggle(),
                if (_occasion != null) _buildOccasionBanner(),
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

                KeyedSubtree(
                  key: _sectionKeys['tops'],
                  child: _paletteSection(
                    'tops',
                    'Tops',
                    _tops,
                    big: true,
                    selectable: true,
                    sparkle: true,
                    selectedIndex: _selectedTopIndex,
                    onTapItem: _onTopTap,
                    onShuffle: _shuffleTops,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['bottoms'],
                  child: _paletteSection(
                    'bottoms',
                    'Bottoms',
                    _bottoms,
                    sparkle: true,
                    matchedIndex: _matchedBottoms,
                    matchOnlyMode: true,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['hair'],
                  child: _paletteSection(
                    'hair',
                    'Recommended Hair Colors',
                    _hair,
                    sparkle: true,
                    matchedIndex: _matchedHair,
                    matchOnlyMode: true,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['eye'],
                  child: _paletteSection(
                    'eye',
                    'Eye Makeup',
                    _eyeMakeup,
                    sparkle: true,
                    matchedIndex: _matchedEye,
                    matchOnlyMode: true,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['blush'],
                  child: _paletteSection(
                    'blush',
                    'Blush Palette',
                    _blush,
                    sparkle: true,
                    matchedIndex: _matchedBlush,
                    matchOnlyMode: true,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['lipstick'],
                  child: _paletteSection(
                    'lipstick',
                    'Lipstick Palette',
                    _lipstick,
                    sparkle: true,
                    matchedIndex: _matchedLipstick,
                    matchOnlyMode: true,
                  ),
                ),
                KeyedSubtree(
                  key: _sectionKeys['jewelry'],
                  child: _paletteSection(
                    'jewelry',
                    'Jewelry',
                    _jewelry,
                    sparkle: true,
                    matchedIndex: _matchedJewelry,
                    matchOnlyMode: true,
                  ),
                ),

                const SizedBox(height: 8),
                // Check an Outfit + Analyze Again — unchanged, per spec.
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
          _buildFloatingTrail(),
        ],
      ),
    );
  }

  // ---- floating "trail" of mini palette bars ----

  Widget _buildFloatingTrail() {
    if (_passedSections.isEmpty) return const SizedBox.shrink();
    final visible = _passedSections.length > _maxTrailBars
        ? _passedSections.sublist(_passedSections.length - _maxTrailBars)
        : _passedSections;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: visible.map(_miniBar).toList(),
      ),
    );
  }

  Widget _miniBar(String id) {
    final allItems = _sectionItems(id);
    final matchedIdx = _matchedIndexFor(id);
    final showMatchOnly = _selectedTopIndex != null && matchedIdx != null;
    final items = showMatchOnly ? [allItems[matchedIdx!]] : allItems;

    return Container(
      key: ValueKey('trail_$id'),
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.97),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              _sectionTitle(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: items
                  .take(9)
                  .map(
                    (s) => Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  //header
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
                _occasion == null ? Icons.tune : _occasion!.icon,
                small: true,
                onTap: _showOccasionPicker,
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
    //ปุ่มวงกลม
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

  Widget _buildOccasionBanner() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(_occasion!.icon, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Color palette for ${_occasion!.label} • ${_occasion!.subtitle}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _occasion = null;
                _loadProfile();
              }),
              child: const Icon(Icons.close, size: 16, color: AppColors.mid),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paletteSection(
    String id,
    String title,
    List<SwatchItem> items, {
    bool big = false,
    bool sparkle = false,
    bool selectable = false,
    int? selectedIndex,
    int? matchedIndex,
    void Function(int index)? onTapItem,
    VoidCallback? onShuffle,
    bool matchOnlyMode = false,
  }) {
    // When a top is selected and this section has a harmony match,
    // collapse the whole row down to just that one matched swatch.
    final showMatchOnly = matchOnlyMode && matchedIndex != null;
    final displayItems = showMatchOnly ? [items[matchedIndex!]] : items;
    final effectiveMatchedIndex = showMatchOnly ? 0 : matchedIndex;

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
              if (showMatchOnly) ...[
                const SizedBox(width: 6),
                Text(
                  '• matched',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                  ),
                ),
              ],
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
            children: displayItems.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _SwatchTile(
                item: s,
                size: 100,
                selected: selectable && selectedIndex == i,
                matched: effectiveMatchedIndex == i,
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

// Sentinel used to tell "sheet dismissed without a choice" apart from
// "user explicitly picked 'show all' (null)".
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
      //แสดงสีและชื่อของ swatch
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
