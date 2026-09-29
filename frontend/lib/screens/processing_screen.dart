import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/season_palette.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String? imagePath;
  final Map<int, String?> answers;

  const ProcessingScreen({
    super.key,
    required this.imagePath,
    required this.answers,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingStep {
  final IconData icon;
  final String label;
  const _ProcessingStep(this.icon, this.label);
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  static const List<_ProcessingStep> _steps = [
    _ProcessingStep(Icons.photo_camera_outlined, 'Photo received'),
    _ProcessingStep(
      Icons.face_retouching_natural_outlined,
      'Reading your undertone',
    ),
    _ProcessingStep(Icons.palette_outlined, 'Finding your season'),
  ];

  static const Color _doneGreen = Color(0xFF3E9C6D);

  Future<Map<String, dynamic>?> _uploadImage() async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("http://10.0.2.2:8000/analyze"),
      );

      request.files.add(
        await http.MultipartFile.fromPath("file", widget.imagePath!),
      );

      request.fields["answers"] = jsonEncode(
        widget.answers.map((key, value) => MapEntry(key.toString(), value)),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        print(body);

        return jsonDecode(body);
      }
    } catch (e) {
      print(e);
    }

    return null;
  }

  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_currentStep >= _steps.length - 1) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 700), () async {
          if (!mounted) return;

          final result = await _uploadImage();

          // The server might reply with 200 but no usable "season" (e.g. an
          // error payload). A hard `as String` cast on null throws
          // "type 'Null' is not a subtype of type 'String'", so check first.
          final seasonName = result?["season"];
          if (result == null || seasonName is! String) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Analysis failed — no season was returned. Please try again.',
                ),
              ),
            );
            Navigator.pop(context);
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                season: _convertSeason(seasonName),
                analysis: result,
                questionnaireAnswers: widget.answers.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
                imagePath: widget.imagePath,
              ),
            ),
          );
        });
        return;
      }
      setState(() => _currentStep++);
    });
    print(widget.imagePath);
    print(widget.answers);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SeasonKey _convertSeason(String season) {
    switch (season.toLowerCase()) {
      case "spring":
        return SeasonKey.Spring;

      case "summer":
        return SeasonKey.Summer;

      case "autumn":
        return SeasonKey.Autumn;

      case "winter":
        return SeasonKey.Winter;

      default:
        return SeasonKey.Summer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 84,
                    height: 84,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                  const Icon(
                    Icons.auto_awesome,
                    size: 28,
                    color: AppColors.charcoal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'A PALETTE IN THE MAKING',
              style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Finding your\nnatural harmony.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'We\'re bringing your photo\nand answers together.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.mid, height: 1.4),
            ),
            const SizedBox(height: 32),
            ..._steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isDone =
                  index < _currentStep ||
                  (index == _currentStep && _currentStep == _steps.length - 1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (isDone ? _doneGreen : AppColors.charcoal)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          step.icon,
                          size: 17,
                          color: isDone ? _doneGreen : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDone ? AppColors.charcoal : AppColors.mid,
                          ),
                        ),
                      ),
                      Icon(
                        isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isDone
                            ? _doneGreen
                            : AppColors.mid.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
