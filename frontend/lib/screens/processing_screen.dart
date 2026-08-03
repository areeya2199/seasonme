import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/season_palette.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

//Analyzing your Personal Color
class ProcessingScreen extends StatefulWidget {
  final String imagePath;
  // final String season;
  final Map<int, String> answers;

  const ProcessingScreen({
    super.key,
    required this.imagePath,
    // required this.season,
    required this.answers,
  });
   

  
  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  static const List<String> _steps = [
    'Reading your skin undertone',
    'Measuring hair & eye contrast',
    'Matching your season',
    'Curating your palette',
  ];
  Future<Map<String, dynamic>?> _uploadImage() async {
  try {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("http://10.0.2.2:8000/analyze"),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        widget.imagePath,
      ),
    );

    request.fields["answers"] = jsonEncode(
      widget.answers.map(
        (key, value) => MapEntry(key.toString(), value),
  ),
);

    var response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
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

  if (result == null) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ResultScreen(
        season: _convertSeason(result["season"]),
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

  /// TODO: replace with the real result from the color-analysis backend
  /// (upload widget.imagePath + questionnaire answers, get a SeasonKey
  /// back). Picking randomly here only stands in until that API exists.
  // SeasonKey _mockAnalysisResult() {
  //   return SeasonKey.values[Random().nextInt(SeasonKey.values.length)];
  // }

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
                    Icons.palette_outlined,
                    size: 30,
                    color: AppColors.charcoal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Analyzing your\nPersonal Color…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Lora',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 32),
            ..._steps.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isDone = index < _currentStep;
              final isActive = index == _currentStep;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle
                          : isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: isDone || isActive
                          ? AppColors.gold
                          : AppColors.mid.withOpacity(0.4),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isDone || isActive
                            ? AppColors.charcoal
                            : AppColors.mid.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
