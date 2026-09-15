import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'processing_screen.dart';

/// A single multiple-choice question in the color questionnaire.
class _Question {
  final String prompt;
  final List<String> options;
  const _Question(this.prompt, this.options);
}

/// Questionnaire — a few quick style questions (vein color, jewelry
/// preference, etc.) that help nudge the season analysis, shown after
/// the user picks/uploads a photo. Fully skippable: the analysis still
/// works from the photo alone if the user doesn't want to answer.
class QuestionnaireScreen extends StatefulWidget {
  final String? imagePath;
  const QuestionnaireScreen({super.key, this.imagePath});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  static const List<_Question> _questions = [
    _Question('เส้นเลือดใต้ข้อมือคุณออกโทนสีอะไร?', [
      'ฟ้า / ม่วง',
      'เขียว',
      'ก้ำกึ่ง ทั้งสองสี',
    ]),
    _Question('เครื่องประดับสีไหนทำให้ดูสดใสขึ้น?', [
      'เงิน / ไวท์โกลด์',
      'ทอง',
      'ทั้งสองแบบพอๆ กัน',
    ]),
    _Question('ผิวคุณเป็นแบบไหนเวลาโดนแดด?', [
      'ไหม้แดง ไม่ค่อยคล้ำ',
      'คล้ำง่าย ไม่ค่อยแดง',
      'ทั้งไหม้ทั้งคล้ำ',
    ]),
    _Question('คนมักชมว่าคุณใส่สีกลุ่มไหนแล้วดูดี?', [
      'โทนอุ่น (ส้ม/น้ำตาล/ทอง)',
      'โทนเย็น (ฟ้า/ม่วง/ชมพูเย็น)',
      'ไม่แน่ใจ',
    ]),
  ];

  // question index -> selected option index
  final Map<int, int> _answers = {};

  void _selectAnswer(int questionIndex, int optionIndex) {
    setState(() => _answers[questionIndex] = optionIndex);
  }

  void _goToProcessing() {
    // TODO: once the backend accepts questionnaire hints, pass
    // `_answers` through here alongside the photo so ProcessingScreen /
    // the analysis API can use them as a tiebreaker signal.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(
          imagePath: widget.imagePath,
          answers: {
            for (final entry in _answers.entries)
              entry.key: _questions[entry.key].options[entry.value],
          },
        ),
      ),
    );
  }

  void _skip() => _goToProcessing();

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                GradientBackButton(onPressed: () => Navigator.pop(context)),
                const Expanded(
                  child: Text(
                    'A Few Quick Questions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.mid,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'ตอบหรือข้ามก็ได้ — ช่วยให้ผลวิเคราะห์แม่นขึ้นนิดหน่อย แต่ไม่ตอบก็วิเคราะห์จากรูปได้ตามปกติ',
              style: TextStyle(fontSize: 12, color: AppColors.mid, height: 1.5),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, qIndex) {
                  final q = _questions[qIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.prompt,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...q.options.asMap().entries.map((entry) {
                        final oIndex = entry.key;
                        final label = entry.value;
                        final selected = _answers[qIndex] == oIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _selectAnswer(qIndex, oIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.gold.withOpacity(0.18)
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.gold
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    size: 18,
                                    color: selected
                                        ? AppColors.gold
                                        : AppColors.mid,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToProcessing,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
