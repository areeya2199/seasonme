import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/season_palette.dart';
import '../data/occasion_palette.dart';
import '../utils/color_utils.dart';
import '../utils/undertone_utils.dart';
import '../services/analysis_history.dart';
import '../services/history_save_task.dart';
import '../theme/app_theme.dart';
import 'clothing_screen.dart';
import 'select_screen.dart';
import '../theme/season_card_colors.dart';
import 'wardrobe_preview.dart';
import 'beauty_preview.dart';

class ResultScreen extends StatefulWidget {
  final SeasonKey season;
  final bool recordToHistory;
  final Map<String, dynamic>? analysis;
  final Map<String, String?>? questionnaireAnswers;
  // Local photo used immediately after processing; history uses localImageKey.
  final String? imagePath;
  final String? localImageKey;
  final AnalysisHistoryEntry? historyEntry;
  final HistoryPhotoAccess? historyPhotoAccess;

  const ResultScreen({
    super.key,
    required this.season,
    this.recordToHistory = true,
    this.analysis,
    this.questionnaireAnswers,
    this.imagePath,
    this.localImageKey,
    this.historyEntry,
    this.historyPhotoAccess,
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

  // Colors the user picked for the two previews. They are kept while this
  // screen is open (switching Wardrobe <-> Beauty & Jewelry does not clear
  // them) and start empty again every time the screen is opened.
  Color? _shirtColor;
  Color? _pantsColor;
  final Map<String, Color> _beautyPicks = {};
  // Name + hex of the swatch that was just tapped.
  SwatchItem? _beautyInfo;

  int _topsGroupIndex = 0;

  late SeasonProfile _profile;
  late List<SwatchItem> _tops;
  late List<SwatchItem> _bottoms;
  late List<SwatchItem> _hair;
  late List<SwatchItem> _eyeMakeup;
  late List<SwatchItem> _blush;
  late List<SwatchItem> _lipstick;
  late List<SwatchItem> _jewelry;
  Uint8List? _historyPhoto;
  Future<void>? _historySave;
  HistorySaveTask? _saveTask;
  StreamSubscription<String?>? _authSubscription;
  late final HistoryPhotoAccess _photoAccess =
      widget.historyPhotoAccess ?? FirebaseHistoryPhotoAccess();
  bool _savingHistory = false;
  bool _loadingPhoto = false;
  bool _saveNeedsRetry = false;
  bool _uploadNeedsRetry = false;
  bool _accountChanged = false;
  String? _saveMessage;
  String? _photoMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    final entry = widget.historyEntry;
    if (entry != null || (widget.recordToHistory && widget.analysis != null)) {
      final owner = entry?.ownerUid ?? FirebaseAuth.instance.currentUser?.uid;
      _accountChanged = owner != _photoAccess.currentUid;
      if (_accountChanged) {
        _photoMessage = 'Your account changed. Please reopen history.';
      }
      _authSubscription = _photoAccess.accountChanges.listen((uid) {
        if (!mounted || uid == owner) return;
        setState(() {
          _accountChanged = true;
          _historyPhoto = null;
          _photoMessage = 'Your account changed. Please reopen history.';
          _saveMessage = null;
          _saveNeedsRetry = false;
          _uploadNeedsRetry = false;
        });
      });
    }
    if (widget.recordToHistory && widget.analysis != null) {
      _historySave = _saveAnalysis();
    }
    _uploadNeedsRetry =
        entry?.photoStatus == 'pending' || entry?.photoStatus == 'failed';
    if (widget.imagePath == null &&
        (entry != null || widget.localImageKey != null)) {
      _loadHistoryPhoto();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _saveAnalysis() async {
    if (_savingHistory || _accountChanged) return;
    setState(() {
      _savingHistory = true;
      _saveNeedsRetry = false;
      _saveMessage = null;
    });
    try {
      _saveTask ??= AnalysisHistoryService.createSaveTask(
        season: widget.season,
        analysis: widget.analysis!,
        questionnaireAnswers: widget.questionnaireAnswers ?? const {},
        imagePath: widget.imagePath,
      );
      final ready = await _saveTask!.save();
      if (!mounted || _accountChanged) return;
      setState(() {
        _saveNeedsRetry = !ready;
        _saveMessage = ready
            ? null
            : 'Analysis saved. The photo could not be saved yet.';
      });
    } catch (_) {
      if (!mounted || _accountChanged) return;
      setState(() {
        _saveNeedsRetry = true;
        _saveMessage = 'Could not finish saving history. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _savingHistory = false);
    }
  }

  Future<void> _loadHistoryPhoto() async {
    if (_loadingPhoto || _accountChanged) return;
    setState(() {
      _loadingPhoto = true;
      _photoMessage = null;
    });
    try {
      final entry = widget.historyEntry;
      final bytes = entry != null
          ? await _photoAccess.load(entry)
          : widget.localImageKey == null
          ? null
          : await AnalysisHistoryService.loadPhoto(widget.localImageKey!);
      if (!mounted || _accountChanged) return;
      setState(() {
        _historyPhoto = bytes;
        _photoMessage = bytes == null
            ? 'No photo is available on this device.'
            : null;
      });
    } catch (_) {
      if (mounted && !_accountChanged) {
        setState(
          () =>
              _photoMessage = 'Could not load the history photo. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _retryUpload() async {
    final entry = widget.historyEntry;
    if (entry == null || _loadingPhoto || _accountChanged) return;
    setState(() {
      _loadingPhoto = true;
      _photoMessage = null;
    });
    try {
      final ready = await _photoAccess.retry(entry);
      if (!mounted || _accountChanged) return;
      setState(() => _uploadNeedsRetry = !ready);
    } catch (_) {
      if (mounted && !_accountChanged) {
        setState(
          () => _photoMessage =
              'Photo retry failed. Try on the original device with an internet connection.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
    if (mounted && !_accountChanged && !_uploadNeedsRetry) {
      await _loadHistoryPhoto();
    }
  }

  Widget _buildHistoryStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_saveMessage != null)
          Text(
            _saveMessage!,
            style: const TextStyle(fontSize: 12, color: AppColors.mid),
          ),
        if (_photoMessage != null)
          Text(
            _photoMessage!,
            style: const TextStyle(fontSize: 12, color: AppColors.mid),
          ),
        if (_uploadNeedsRetry && !_accountChanged)
          const Text(
            'Analysis saved. Photo upload is incomplete.',
            style: TextStyle(fontSize: 12, color: AppColors.mid),
          ),
        if (_saveNeedsRetry && !_accountChanged)
          TextButton(
            onPressed: _savingHistory
                ? null
                : () {
                    _historySave = _saveAnalysis();
                  },
            child: const Text('Retry saving'),
          ),
        if (_uploadNeedsRetry && !_accountChanged)
          TextButton(
            onPressed: _loadingPhoto ? null : _retryUpload,
            child: const Text('Retry photo upload'),
          ),
        if (_photoMessage != null && !_accountChanged)
          TextButton(
            onPressed: _loadingPhoto ? null : _loadHistoryPhoto,
            child: const Text('Retry loading photo'),
          ),
      ],
    );
  }

  void _loadProfile() {
    _profile = SeasonPaletteData.getProfile(widget.season, night: _nightMode);

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
  // pants (color-theory match). Tapping the same top again clears both.
  void _onTopTap(int index) {
    setState(() {
      final color = _tops[index].color;
      if (_shirtColor == color) {
        _shirtColor = null;
        _pantsColor = null;
        return;
      }
      _shirtColor = color;
      final match = ColorUtils.pickHarmoniousIndex(
        color,
        _bottoms.map((e) => e.color).toList(),
        random: Random(),
      );
      _pantsColor = match == null ? null : _bottoms[match].color;
    });
  }

  // Tapping a Bottom directly overrides whatever the auto-match picked.
  void _onBottomTap(int index) {
    setState(() {
      final color = _bottoms[index].color;
      _pantsColor = _pantsColor == color ? null : color;
    });
  }

  // Tapping a Beauty swatch sets that category's color on the preview;
  // tapping it again clears it. Other categories are never touched.
  void _onBeautyTap(String category, SwatchItem item) {
    setState(() {
      if (_beautyPicks[category] == item.color) {
        _beautyPicks.remove(category);
        _beautyInfo = null;
      } else {
        _beautyPicks[category] = item.color;
        _beautyInfo = item;
      }
    });
  }

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
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildTopBar(),
            const SizedBox(height: 16),
            _buildPersonalColorCard(),
            _buildHistoryStatus(),
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
                  backgroundColor: const Color(0xff4c3935),
                  foregroundColor: AppColors.white,
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
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text(
                  'Check an Outfit',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
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
          onTap: () async {
            await _historySave;
            if (!mounted) return;
            Navigator.popUntil(context, (r) => r.isFirst);
          },
        ),
        const Expanded(
          child: Text(
            'My Palette',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lora',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
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

  // ไม่ต้องรับหรือส่ง chroma แล้ว เพราะการ์ดแสดงเฉพาะ undertone จากผลวิเคราะห์
  Widget _buildPersonalColorCard() {
    final details = _buildPersonalColorDetails();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: seasonCardGradient(widget.season),
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child:
          _accountChanged ||
              (widget.imagePath == null &&
                  _historyPhoto == null &&
                  !_loadingPhoto)
          ? details
          : LayoutBuilder(
              builder: (context, constraints) {
                final stackPhoto =
                    constraints.maxWidth < 270 ||
                    MediaQuery.textScalerOf(context).scale(14) > 16.8;
                if (stackPhoto) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserPhoto(),
                      const SizedBox(height: 20),
                      details,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildUserPhoto(),
                    const SizedBox(width: 16),
                    Expanded(child: details),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPersonalColorDetails() {
    // สีตัวหนังสือในการ์ดซีซั่น (แก้ได้ที่ season_card_colors.dart)
    final cardText = seasonCardText(widget.season);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SEASON IS',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.4,
            fontWeight: FontWeight.normal,
            color: cardText.label,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _profile.displayName,
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 34,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w800,
            color: cardText.title,
          ),
        ),
        const SizedBox(height: 6),
        // อ่าน undertone จากผลวิเคราะห์ และแสดงใต้ชื่อฤดู
        _pillTag(
          UndertoneUtils.label(widget.analysis, withSuffix: true),
          cardText,
        ),
        const SizedBox(height: 12),
        Text(
          _profile.description,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: cardText.body,
          ),
        ),
      ],
    );
  }

  // Fixed width/height frame, centered — BoxFit.cover means the photo
  // always fills this exact frame regardless of the source photo's own
  // dimensions or orientation (portrait, landscape, square all look the
  // same size here; excess is cropped rather than the frame resizing).
  static const double _photoWidth = 110;
  static const double _photoHeight = 140;

  Widget _buildUserPhoto() {
    if (_accountChanged) return const SizedBox.shrink();
    final path = widget.imagePath;
    final bytes = _historyPhoto;
    if (path == null && bytes == null) {
      if (!_loadingPhoto) return const SizedBox.shrink();
      return Container(
        width: _photoWidth,
        height: _photoHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
            semanticsLabel: 'Loading history photo',
          ),
        ),
      );
    }
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
    final image = path == null
        ? Image.memory(
            bytes!,
            width: _photoWidth,
            height: _photoHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : kIsWeb
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

  Widget _pillTag(String text, SeasonCardText cardText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cardText.pillBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cardText.pillText,
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
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: active ? Colors.white : AppColors.mid,
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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
          'Day Event',
          Icons.wb_sunny_outlined,
          !_nightMode,
          () => _setNightMode(false),
        ),
        const SizedBox(width: 10),
        chip(
          'Night Event',
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
      crossAxisAlignment: CrossAxisAlignment.center,
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
                style: const TextStyle(fontSize: 12, color: AppColors.mid),
              ),
              const SizedBox(height: 10),
              _compactSwatchWrap(
                _tops,
                selectedColor: _shirtColor,
                onTap: _onTopTap,
              ),
              const SizedBox(height: 22),
              _sectionHeaderRow('Bottoms'),
              const SizedBox(height: 2),
              Text(
                _dayNightBlurb(),
                style: const TextStyle(fontSize: 12, color: AppColors.mid),
              ),
              const SizedBox(height: 10),
              _compactSwatchWrap(
                _bottoms,
                selectedColor: _pantsColor,
                onTap: _onBottomTap,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        MannequinCard(shirtColor: _shirtColor, pantsColor: _pantsColor),
      ],
    );
  }

  Widget _sectionHeaderRow(String title, {VoidCallback? onShuffle}) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.charcoal,
          ),
        ),
        if (onShuffle != null) ...[_ShuffleButton(onTap: onShuffle)],
      ],
    );
  }

  Widget _compactSwatchWrap(
    List<SwatchItem> items, {
    Color? selectedColor,
    required void Function(int index) onTap,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        final active = selectedColor != null && s.color == selectedColor;
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

  // ---------------- Beauty & Jewelry: palette + live preview ----------------

  static const List<String> _beautyCategories = [
    'hair',
    'eye',
    'blush',
    'lipstick',
    'jewelry',
  ];

  Widget _buildBeautyTab() {
    final picked = _beautyPicks[_beautyCategory];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // All five category buttons stay on one row (they shrink to fit).
        Row(
          children: [
            for (int i = 0; i < _beautyCategories.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _beautyChip(_beautyCategories[i])),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _beautySectionTitle(_beautyCategory),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dayNightBlurb(),
                    style: const TextStyle(fontSize: 12, color: AppColors.mid),
                  ),
                  const SizedBox(height: 10),
                  _compactSwatchWrap(
                    _beautyItems(_beautyCategory),
                    selectedColor: picked,
                    onTap: (i) => _onBeautyTap(
                      _beautyCategory,
                      _beautyItems(_beautyCategory)[i],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _beautyInfoPopup(),
                ],
              ),
            ),
            const SizedBox(width: 14),
            BeautyPreviewCard(
              hair: _beautyPicks['hair'],
              eyeshadow: _beautyPicks['eye'],
              blush: _beautyPicks['blush'],
              lips: _beautyPicks['lipstick'],
              earrings: _beautyPicks['jewelry'],
            ),
          ],
        ),
      ],
    );
  }

  // Small popup under the palette: name + hex of the tapped color.
  // It reserves its own space, so nothing moves and nothing is covered.
  Widget _beautyInfoPopup() {
    final item = _beautyInfo;
    final hex = item == null
        ? ''
        : '#${item.color.value.toRadixString(16).substring(2).toUpperCase()}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: item == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: item?.color ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item?.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          hex,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.mid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _beautyChip(String c) {
    final active = _beautyCategory == c;
    return GestureDetector(
      onTap: () {
        setState(() {
          _beautyCategory = c;
          _beautyInfo = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xff4c3935) : AppColors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _beautyChipLabel(c),
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : AppColors.mid,
            ),
          ),
        ),
      ),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 16,

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
