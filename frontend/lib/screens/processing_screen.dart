import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/season_palette.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

//Analyzing your Personal Color
class ProcessingScreen extends StatefulWidget {
  final String? imagePath;
  const ProcessingScreen({super.key, this.imagePath});

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

  int _currentStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (_currentStep >= _steps.length - 1) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(season: _mockAnalysisResult()),
            ),
          );
        });
        return;
      }
      setState(() => _currentStep++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SeasonKey _mockAnalysisResult() {
    return SeasonKey.values[Random().nextInt(SeasonKey.values.length)];
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
