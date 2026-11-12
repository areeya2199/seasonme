import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/analysis_input.dart';
import '../theme/app_theme.dart';
import 'processing_screen.dart';

// Temporary six-color previews based on the approved mockup. Replace BOTH
// lists with the owner's final palettes; these never affect backend scoring.
const _brightPalette = [
  Color(0xFFfcfffe),
  Color(0xFF8afcff),
  Color(0xFFff9dbd),
  Color(0xFF4f9fff),
  Color(0xFFe316eb),
  Color(0xFF680bb3),
];
const _mutedPalette = [
  Color(0xFFFFFFFF),
  Color(0xFFFDEFF4),
  Color(0xFFF7C8D8),
  Color(0xFFCDE7F0),
  Color(0xFF85CFC5),
  Color(0xFF5B6C8F),
];

class QuestionnaireScreen extends StatefulWidget {
  final String imagePath;

  const QuestionnaireScreen({super.key, required this.imagePath});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  String? _selected;
  bool _photoReady = false;
  bool _photoLoading = true;
  Uint8List? _photoBytes;
  String? _photoError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _checkPhoto();
  }

  Future<void> _checkPhoto() async {
    try {
      final bytes = await AnalysisInput.validatePhoto(widget.imagePath);
      if (!mounted) return;
      setState(() {
        _photoReady = true;
        _photoBytes = bytes;
        _photoLoading = false;
        _photoError = null;
      });
    } on AnalysisInputException catch (error) {
      if (!mounted) return;
      setState(() {
        _photoReady = false;
        _photoLoading = false;
        _photoError = error.message;
      });
    }
  }

  Future<void> _next() async {
    if (_submitting ||
        !_photoReady ||
        _photoLoading ||
        !AnalysisInput.colorPreferences.contains(_selected)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      // Preserve Q4's canonical key even though it is the only question.
      final answers = <int, String?>{3: _selected};
      AnalysisInput.validateAnswers(answers);
      // Recheck the actual source before navigation, even if preview loaded.
      final currentBytes = await AnalysisInput.validatePhoto(widget.imagePath);
      if (!listEquals(currentBytes, _photoBytes)) {
        throw const AnalysisInputException(
          'Your photo changed. Please go back and choose or take it again.',
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProcessingScreen(imagePath: widget.imagePath, answers: answers),
        ),
      );
    } on AnalysisInputException catch (error) {
      if (!mounted) return;
      setState(() {
        _photoReady = false;
        _photoBytes = null;
        _photoError = error.message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<Color> _paletteFor(String? answer) => switch (answer) {
    'Bright' => _brightPalette,
    'Muted' => _mutedPalette,
    _ => List<Color>.filled(6, AppColors.charcoal.withValues(alpha: 0.08)),
  };

  Widget _palette(String? answer, {bool preview = false}) {
    return Semantics(
      label: answer == null ? 'Choose a palette' : '$answer palette, 6 colors',
      liveRegion: preview,
      child: SizedBox(
        height: preview ? 58 : 29,
        child: Row(
          children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                child: ColoredBox(
                  key: preview ? ValueKey('photo-swatch-$i') : null,
                  color: _paletteFor(answer)[i],
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoFailure(String message) => Container(
    key: const ValueKey('questionnaire-photo-error'),
    padding: const EdgeInsets.all(24),
    alignment: Alignment.center,
    child: Semantics(
      liveRegion: true,
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  Widget _userPhoto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: ColoredBox(
            color: AppColors.white,
            child: Column(
              children: [
                SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: _photoLoading
                      ? const Center(child: Text('Loading your photo…'))
                      : !_photoReady
                      ? _photoFailure(
                          _photoError ?? 'Unable to load your photo.',
                        )
                      : Image.memory(
                          _photoBytes!,
                          key: const ValueKey('questionnaire-user-photo'),
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.36),
                          semanticLabel:
                              'Your photo for personal color analysis',
                          errorBuilder: (_, _, _) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || !_photoReady) return;
                              setState(() {
                                _photoReady = false;
                                _photoError =
                                    'Unable to load your photo. Please choose it again.';
                              });
                            });
                            return _photoFailure(
                              'Unable to load your photo. Please choose it again.',
                            );
                          },
                        ),
                ),
                _palette(_selected, preview: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sample palettes',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.mid),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Preserve the bottom spacing on tall screens and allow the
            // existing content to scroll when it exceeds the viewport.
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Color Quiz',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.charcoal,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '1/1',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mid,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 1,
                        backgroundColor: AppColors.charcoal.withOpacity(0.08),
                        color: AppColors.gold,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Which colors suit you best?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compare the colors beneath your photo.',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppColors.mid,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _userPhoto(),
                    const SizedBox(height: 22),

                    // Options
                    ...const ['Bright', 'Muted'].map((option) {
                      final isSelected = _selected == option;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          button: true,
                          selected: isSelected,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _submitting
                                ? null
                                : () {
                                    setState(() {
                                      _selected = option;
                                    });
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.gold.withOpacity(0.12)
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.charcoal.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          child: _palette(option),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.gold,
                                      size: 20,
                                    )
                                  else
                                    Icon(
                                      Icons.circle_outlined,
                                      color: AppColors.mid.withOpacity(0.3),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _selected != null &&
                                !_submitting &&
                                (_photoReady && !_photoLoading)
                            ? _next
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'Finish',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
