import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../data/season_palette.dart';
import '../utils/color_utils.dart';
import '../widgets/outfit_save_button.dart';
import '../models/saved_outfit.dart';
import '../services/saved_outfits_service.dart';

// Outfit Checker: the user photographs (or uploads) a piece of clothing,
// the app samples its color, and checks how close that color is to the
// SAME season the user got on the Result screen — Winter photos compare
// only to the Winter palette, Autumn to Autumn, and so on for all 4
// seasons, since `_profile` below is always built from `widget.season`.
// No manual color picking: the photo is the only input.
class ClothingScreen extends StatefulWidget {
  final SeasonKey season;
  final SavedOutfitsService? outfitService;
  const ClothingScreen({super.key, required this.season, this.outfitService});

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
  final bool hasPixels;
  const _ImageAnalysis(
    this.color,
    this.textureVariance,
    this.greenShare, {
    this.hasPixels = true,
  });
}

class _ClothingScreenState extends State<ClothingScreen> {
  File? _pickedImage;
  Color? _sampledColor;
  bool _looksSuspicious = false;
  _LoadState _state = _LoadState.idle;
  String? _errorMessage;
  _OutfitMatch? _result;
  OutfitSaveState _saveState = OutfitSaveState.idle;
  OutfitSaveTask? _saveTask;
  SavedOutfitsService? _outfitService;
  StreamSubscription<String?>? _outfitAuth;
  Uint8List? _pickedBytes;
  String? _outfitOwner;
  String? _saveError;
  bool _accountChanged = false;
  bool _hasPixels = false;
  bool _picking = false;
  int _imageRequest = 0;
  bool _noteDialogOpen = false;
  String? _confirmedNote;

  late final SeasonProfile _profile = SeasonPaletteData.getProfile(
    widget.season,
  );

  @override
  void initState() {
    super.initState();
    // Observe the account from screen entry, including while the gallery is
    // open. Pure UI tests may render the screen without initializing Firebase.
    if (widget.outfitService != null || Firebase.apps.isNotEmpty) {
      _connectOutfitService();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_picking || _saveState == OutfitSaveState.saving) return;
    _picking = true;
    var request = _imageRequest;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (!mounted || xfile == null) return;
      request = ++_imageRequest;
      _connectOutfitService();
      if (_accountChanged) return;

      final file = File(xfile.path);
      setState(() {
        _pickedImage = file;
        _state = _LoadState.loading;
        _errorMessage = null;
        _result = null;
        _sampledColor = null;
        _looksSuspicious = false;
        _pickedBytes = null;
        _saveState = OutfitSaveState.idle;
        _saveTask = null;
        _confirmedNote = null;
        _saveError = null;
        _hasPixels = false;
      });

      final bytes = await file.readAsBytes();
      final analysis = await _analyzeImage(bytes);
      final match = _matchAgainstSeason(analysis.color);
      if (!mounted || request != _imageRequest) return;
      setState(() {
        _sampledColor = analysis.color;
        _pickedBytes = bytes;
        _hasPixels = analysis.hasPixels;
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
      if (!mounted || request != _imageRequest) return;
      setState(() {
        _state = _LoadState.error;
        _errorMessage = 'Failed to read the photo. Please try again.';
      });
    } finally {
      _picking = false;
    }
  }

  void _connectOutfitService() {
    if (_outfitService != null) return;
    final service = widget.outfitService ?? SavedOutfitsService.firebase();
    _outfitService = service;
    _outfitOwner = service.currentUid;
    _outfitAuth = service.accountChanges.listen((uid) {
      if (!mounted || uid == _outfitOwner) return;
      ++_imageRequest;
      setState(() {
        _accountChanged = true;
        _pickedImage = null;
        _pickedBytes = null;
        _result = null;
        _sampledColor = null;
        _saveTask = null;
        _confirmedNote = null;
        _saveState = OutfitSaveState.idle;
        _state = _LoadState.idle;
        _saveError = 'บัญชีเปลี่ยนแล้ว กรุณาเปิด Outfit Checker ใหม่';
      });
    });
  }

  @override
  void dispose() {
    _outfitAuth?.cancel();
    super.dispose();
  }

  Future<void> _editNote() async {
    if (_noteDialogOpen ||
        _saveTask != null ||
        _saveState == OutfitSaveState.saving ||
        _saveState == OutfitSaveState.saved ||
        _accountChanged ||
        _picking ||
        !_hasPixels) {
      return;
    }
    final request = _imageRequest;
    setState(() => _noteDialogOpen = true);
    String? response;
    try {
      response = await showDialog<String>(
        context: context,
        builder: (_) => _OutfitNoteDialog(initialNote: _confirmedNote),
      );
    } finally {
      if (mounted) setState(() => _noteDialogOpen = false);
    }
    // Cancel discards only this draft. Ignore dialogs from an old photo/account.
    if (!mounted ||
        response == null ||
        request != _imageRequest ||
        _accountChanged) {
      return;
    }
    setState(() => _confirmedNote = SavedOutfit.normalizeNote(response));
  }

  Future<void> _saveOutfit() async {
    if (_noteDialogOpen ||
        _saveState == OutfitSaveState.saving ||
        _saveState == OutfitSaveState.saved ||
        _accountChanged ||
        _picking ||
        !_hasPixels ||
        _pickedBytes == null ||
        _result == null ||
        _result!.level == MatchLevel.poor) {
      return;
    }
    final request = _imageRequest;
    setState(() {
      _saveState = OutfitSaveState.saving;
      _saveError = null;
    });
    try {
      _connectOutfitService();
      final service = _outfitService!;
      if (service.currentUid == null || service.currentUid != _outfitOwner) {
        throw StateError('กรุณาเข้าสู่ระบบและเปิด Outfit Checker ใหม่');
      }
      final result = _result!;
      _saveTask ??= service.createSaveTask(
        OutfitMatchSnapshot(
          season: widget.season,
          matchPercent: result.percent,
          matchLevel: result.level,
          sampledColorArgb: _sampledColor!.toARGB32(),
          closestName: result.closest.name,
          closestArgb: result.closest.color.toARGB32(),
          closestCategory: result.closestCategory,
        ),
        _pickedBytes!,
        note: _confirmedNote,
      );
      await _saveTask!.save();
      if (!mounted || request != _imageRequest || _accountChanged) return;
      setState(() => _saveState = OutfitSaveState.saved);
      if (_saveTask!.wasAlreadySaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This outfit is already saved. The existing name and note have been kept.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted || request != _imageRequest || _accountChanged) return;
      setState(() {
        _saveState = OutfitSaveState.failed;
        _saveError = outfitErrorMessage(error);
      });
    }
  }

  // ---- "Take a photo and detect the color": average the center 60% of the
  // frame, where the garment usually fills the shot while background tends
  // to sit toward the edges. Also computes two rough signals (pixel
  // variance and green-hue share) used only for the soft "does this look
  // like clothing" warning below — this stays a heuristic, not true scene
  // classification, since there's no vision model running on-device here.
  Future<_ImageAnalysis> _analyzeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return const _ImageAnalysis(Colors.grey, 0, 0, hasPixels: false);
    }

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
    if (count == 0) {
      return const _ImageAnalysis(Colors.grey, 0, 0, hasPixels: false);
    }

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
      for (final s in _profile.topsPool) MapEntry('Clothing', s),
      for (final s in _profile.bottoms) MapEntry('Bottoms', s),
      for (final s in _profile.jewelry) MapEntry('Jewelry', s),
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
                  fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_accountChanged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _saveError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),

              GestureDetector(
                onTap: _accountChanged || _saveState == OutfitSaveState.saving
                    ? null
                    : _showSourceSheet,
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tap to take a photo or choose from gallery',
                              style: TextStyle(
                                fontSize: 12,
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
                            if (_pickedBytes != null)
                              Image.memory(
                                _pickedBytes!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              )
                            else
                              const SizedBox(
                                height: 200,
                                width: double.infinity,
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
                const SizedBox(height: 14),
                _buildSaveOutfit(),
                const SizedBox(height: 14),
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

  Widget _buildSaveOutfit() {
    final canSave =
        !_accountChanged &&
        _hasPixels &&
        _state == _LoadState.done &&
        _pickedImage != null &&
        _result != null &&
        _result!.level != MatchLevel.poor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('outfit-note-card'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4D4CC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.edit_note,
                    size: 18,
                    color: Color(0xFF81736D),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Name / Note (Optional)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF81736D)),
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    fit: FlexFit.tight,
                    child: TextButton(
                      key: const ValueKey('edit-outfit-note'),
                      onPressed:
                          canSave &&
                              !_noteDialogOpen &&
                              !_picking &&
                              _saveTask == null &&
                              _saveState != OutfitSaveState.saving &&
                              _saveState != OutfitSaveState.saved
                          ? _editNote
                          : null,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(left: 12),
                        foregroundColor: const Color(0xFFA97C32),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(
                        _saveState == OutfitSaveState.saved
                            ? 'Saved with outfit'
                            : _confirmedNote == null
                            ? 'Add'
                            : 'Edit',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                _confirmedNote ?? 'No name or note added.',
                key: const ValueKey('confirmed-outfit-note'),
                style: TextStyle(
                  fontSize: _confirmedNote == null ? 12 : 16,
                  color: const Color(0xFF665B54),
                ),
              ),
            ],
          ),
        ),
        if (_saveState == OutfitSaveState.failed && _saveTask != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Retry will use the name / note from your first save attempt.',
              style: TextStyle(fontSize: 12, color: Color(0xFF665B54)),
            ),
          ),
        if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _saveError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA43E37)),
            ),
          ),
        OutfitSaveButton(
          state: _saveState,
          onPressed: canSave && !_noteDialogOpen ? _saveOutfit : null,
        ),
      ],
    );
  }

  Widget _buildIdleHint() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For Accurate Results',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.mid,
          ),
        ),

        const SizedBox(height: 20),

        _buildHintItem(
          'Photos other than clothing may not provide the results you are looking for.',
        ),
      ],
    );
  }

  Widget _buildHintItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.warning_rounded,
          color: ui.Color.fromARGB(255, 255, 213, 61),
          size: 20,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: AppColors.mid,
            ),
          ),
        ),
      ],
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
              'This photo has a lot of texture or a strong green tone, it might be a plant, animal or scenery shot rather than plain fabric. For a reliable check, photograph a flat, evenly-lit piece of clothing.',
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
                      'Closest to ${result.closest.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
          'Excellent Match',
          const Color(0xFF3E9C6D),
          'This color is a perfect match for your ${_profile.displayName} season.',
        );
      case MatchLevel.good:
        return _LevelInfo(
          'Good Match',
          const Color(0xFFD9A441),
          'This color is somewhat similar to your ${_profile.displayName} season. Try pairing it with more neutral pieces.',
        );
      case MatchLevel.poor:
        return _LevelInfo(
          'Avoid',
          const Color(0xFFC65B5B),
          'This color is quite different from your ${_profile.displayName} season. Try taking another photo of a different piece.',
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
class _OutfitNoteDialog extends StatefulWidget {
  final String? initialNote;
  const _OutfitNoteDialog({this.initialNote});

  @override
  State<_OutfitNoteDialog> createState() => _OutfitNoteDialogState();
}

class _OutfitNoteDialogState extends State<_OutfitNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Name / Note'),
      scrollable: true,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a name or note to help you remember this outfit.'),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 3,
              maxLength: SavedOutfit.maxNoteLength,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      newValue.text.runes.length <= SavedOutfit.maxNoteLength
                      ? newValue
                      : oldValue,
                ),
              ],
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => Text(
                    '${_controller.text.runes.length}/${SavedOutfit.maxNoteLength}',
                  ),
              decoration: const InputDecoration(
                labelText: 'Name / Note (Optional)',
                hintText: 'e.g. Purple shirt from Store A',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('You can save without adding a name or note.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

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
