import 'package:flutter/material.dart';
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
  _QuizOption({required this.label, required this.hint});
}

//Questionnaire — multi-step quiz, mirrors "Your wrist vein color" step
class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _step = 0;
  String? _selected;

  //4 question
  final List<_QuizQuestion> _questions = [
    _QuizQuestion(
      title: 'Your wrist vein color',
      subtitle: 'Look at your inner wrist in natural light.',
      options: [
        _QuizOption(label: 'Blue / Purple', hint: 'Cool undertone'),
        _QuizOption(label: 'Green', hint: 'Warm undertone'),
        _QuizOption(label: 'A mix of both', hint: 'Neutral undertone'),
      ],
    ),
    _QuizQuestion(
      title: 'Gold or silver?',
      subtitle: 'Which one makes your face look brighter?',
      options: [
        _QuizOption(label: 'Gold', hint: 'Warm undertone'),
        _QuizOption(label: 'Silver', hint: 'Cool undertone'),
        _QuizOption(label: 'Both look fine', hint: 'Neutral undertone'),
      ],
    ),
    _QuizQuestion(
      title: 'How does your skin react to sun?',
      subtitle: 'Think about a typical day outdoors.',
      options: [
        _QuizOption(label: 'Tans easily, rarely burns', hint: 'Warm / Deep'),
        _QuizOption(label: 'Burns easily, rarely tans', hint: 'Cool / Light'),
        _QuizOption(label: 'A little of both', hint: 'Neutral'),
      ],
    ),
    _QuizQuestion(
      title: 'Which colors feel most "you"?',
      subtitle: 'Pick the vibe you gravitate toward.',
      options: [
        _QuizOption(label: 'Bright & vivid', hint: 'High chroma'),
        _QuizOption(label: 'Soft & muted', hint: 'Low chroma'),
        _QuizOption(label: 'Deep & rich', hint: 'Dark value'),
      ],
    ),
  ];

  void _next() {
    if (_step < _questions.length - 1) {
      setState(() {
        _step++;
        _selected = null;
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProcessingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_step];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress
              Row(
                children: [
                  const Text(
                    'Color Quiz',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_step + 1}/${_questions.length}',
                    style: const TextStyle(fontSize: 13, color: AppColors.mid),
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
                style: const TextStyle(fontSize: 13, color: AppColors.mid),
              ),
              const SizedBox(height: 28),

              // Options
              ...q.options.map((opt) {
                final isSelected = _selected == opt.label;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = opt.label),
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
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
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
                );
              }),

              const Spacer(),

              //Continue + Skip
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected != null ? _next : null,
                  child: Text(
                    _step == _questions.length - 1 ? 'Finish' : 'Continue',
                    style: TextStyle(color: AppColors.cream),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProcessingScreen()),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.mid),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
