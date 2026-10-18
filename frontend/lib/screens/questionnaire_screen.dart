import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/analysis_input.dart';
import '../theme/app_theme.dart';
import 'processing_screen.dart';

//A single quiz question with answer options
class _QuizQuestion {
  final String title;
  final String subtitle;
  final List<_QuizOption> options;
  _QuizQuestion({
    required this.title,
    required this.subtitle,
    required this.options,
  });
}

class _QuizOption {
  final String label;
  final String hint;
  final String? imageAsset;
  final String? imageCaption;
  _QuizOption({
    required this.label,
    required this.hint,
    this.imageAsset,
    this.imageCaption,
  });
}

// Temporary six-color previews based on the approved mockup. Replace BOTH
// lists with the owner's final palettes; these never affect backend scoring.
const _brightPalette = [
  Color(0xFF12429E),
  Color(0xFFde0065),
  Color(0xFFcfcdff),
  Color(0xFF629b3d),
  Color(0xFFe65d4d),
  Color(0xFFFdebad),
];
const _mutedPalette = [
  Color(0xFF3c557d),
  Color(0xFFd1869b),
  Color(0xFFe8e5d2),
  Color(0xFF4f9e81),
  Color(0xFF4fbec5),
  Color(0xFF4a4041),
];

class QuestionnaireScreen extends StatefulWidget {
  final String imagePath;

  const QuestionnaireScreen({super.key, required this.imagePath});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _step = 0;
  String? _selected;
  final Map<int, String?> _answers = {0: null, 1: null, 2: null, 3: null};
  bool _photoReady = false;
  bool _photoLoading = true;
  bool _photoCheckStarted = false;
  Uint8List? _photoBytes;
  String? _photoError;
  bool _submitting = false;

  bool get _isColorQuestion => _step == _questions.length - 1;

  Future<void> _checkPhoto() async {
    _photoCheckStarted = true;
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

  //4 question
  final List<_QuizQuestion> _questions = [
    _QuizQuestion(
      title: 'Your wrist vein color',
      subtitle: 'Look at your inner wrist in natural light.',
      options: [
        _QuizOption(
          label: 'Blue / Purple',
          hint: 'Cool undertone',
          imageAsset: 'assets/blue.jpg',
          imageCaption: 'Blue / Purple',
        ),
        _QuizOption(
          label: 'Green',
          hint: 'Warm undertone',
          imageAsset: 'assets/green.jpg',
          imageCaption: 'Green',
        ),
        _QuizOption(
          label: 'A mix of both',
          hint: 'Neutral undertone',
          imageAsset: 'assets/mix_blue&green.jpg',
          imageCaption: 'A mix of both',
        ),
      ],
    ),
    _QuizQuestion(
      title: 'Gold or silver?',
      subtitle: 'Which one makes your face look brighter?',
      options: [
        _QuizOption(
          label: 'Gold',
          hint: 'Warm undertone',
          imageAsset: 'assets/gold.jpg',
          imageCaption: 'Gold',
        ),
        _QuizOption(
          label: 'Silver',
          hint: 'Cool undertone',
          imageAsset: 'assets/silver.jpg',
          imageCaption: 'Silver',
        ),
        _QuizOption(label: 'Both look fine', hint: 'Neutral undertone'),
      ],
    ),
    _QuizQuestion(
      title: 'How does your skin react to sun?',
      subtitle: 'Think about a typical day outdoors.',
      options: [
        _QuizOption(
          label: 'Tans easily, rarely burns',
          hint: 'Warm / Deep',
          imageAsset: 'assets/tan.jpg',
          imageCaption: 'Tans easily',
        ),
        _QuizOption(
          label: 'Burns easily, rarely tans',
          hint: 'Cool / Light',
          imageAsset: 'assets/burn.jpg',
          imageCaption: 'Burns easily',
        ),
        _QuizOption(label: 'A little of both', hint: 'Neutral'),
      ],
    ),
    _QuizQuestion(
      title: 'Which colors suit you best?',
      subtitle: 'Compare the colors beneath your photo.',
      options: [
        _QuizOption(label: 'Bright', hint: 'Bright & vivid'),
        _QuizOption(label: 'Muted', hint: 'Soft & muted'),
      ],
    ),
  ];

  void _next() {
    _advance(_selected);
  }

  void _skip() {
    if (_isColorQuestion || _submitting) return;
    _advance(null);
  }

  Future<void> _advance(String? answer) async {
    if (_submitting) return;
    if (_isColorQuestion && !AnalysisInput.colorPreferences.contains(answer)) {
      return;
    }
    _answers[_step] = answer;

    if (_step < _questions.length - 1) {
      setState(() {
        _step++;
        _selected = _answers[_step];
      });
      if (_isColorQuestion && !_photoCheckStarted) _checkPhoto();
    } else {
      setState(() => _submitting = true);
      try {
        final answers = Map<int, String?>.from(_answers);
        AnalysisInput.validateAnswers(answers);
        // Recheck the actual source before navigation, even if preview loaded.
        final currentBytes = await AnalysisInput.validatePhoto(
          widget.imagePath,
        );
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
  }

  void _back() {
    if (_submitting) return;
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _step--;
      _selected = _answers[_step];
    });
  }

  Widget _exampleImages(_QuizQuestion question) {
    final examples = question.options
        .where((option) => option.imageAsset != null)
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < examples.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label: 'Example: ${examples[i].label}',
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 76,
                        width: double.infinity,
                        child: Image.asset(
                          examples[i].imageAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            key: ValueKey('example-placeholder-$_step-$i'),
                            color: AppColors.cream,
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      examples[i].imageCaption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
    final q = _questions[_step];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
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
                          '${_step + 1}/${_questions.length}',
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
                        value: (_step + 1) / _questions.length,
                        backgroundColor: AppColors.charcoal.withOpacity(0.08),
                        color: AppColors.gold,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      q.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      q.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: AppColors.mid,
                      ),
                    ),
                    const SizedBox(height: 28),

                    if (_isColorQuestion) _userPhoto() else _exampleImages(q),
                    const SizedBox(height: 22),

                    // Options
                    ...q.options.map((opt) {
                      final isSelected = _selected == opt.label;
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
                                      _selected = opt.label;
                                      _answers[_step] = opt.label;
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
                                crossAxisAlignment: _isColorQuestion
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          opt.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(
                                          height: _isColorQuestion ? 8 : 2,
                                        ),
                                        if (_isColorQuestion)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                            child: _palette(opt.label),
                                          )
                                        else
                                          Text(
                                            opt.hint,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.mid,
                                            ),
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

                    // Continue box (top) and Skip box (bottom) — two clearly
                    // separate, equally-prominent boxes, with a caption under
                    // the skip box explaining the trade-off.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _selected != null &&
                                !_submitting &&
                                (!_isColorQuestion ||
                                    (_photoReady && !_photoLoading))
                            ? _next
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          _step == _questions.length - 1
                              ? 'Finish'
                              : 'Continue',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (!_isColorQuestion) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _skip,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: AppColors.mid.withOpacity(0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.charcoal,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Skipping won\'t break the analysis it just makes the result a bit less precise.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: AppColors.mid,
                          ),
                        ),
                      ),
                    ],
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
