import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/season_palette.dart';
import '../services/api_service.dart';
import '../services/analysis_input.dart';
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

class _ProcessingScreenState extends State<ProcessingScreen> {
  String _analysisError =
      'Unable to get an analysis result from the server. Please try again.';

  bool _requestStarted = false;
  bool _hasLeftScreen = false;
  bool _navigationHandled = false;

  Future<Map<String, dynamic>?> _uploadImage() async {
    try {
      final imagePath = widget.imagePath;
      if (imagePath == null || imagePath.isEmpty) {
        _analysisError =
            'No photo was provided. Please choose a photo and try again.';
        return null;
      }
      return await ApiService().analyzeImage(imagePath, widget.answers);
    } on AnalysisInputException catch (e) {
      if (!mounted) return null;
      _analysisError = e.message;
    } on TimeoutException catch (e) {
      print(e);
      if (!mounted) return null;
      _analysisError =
          'Analysis timed out. Please try again when the server is available.';
    } on SocketException catch (e) {
      print(e);
      if (!mounted) return null;
      _analysisError =
          'Unable to connect to the analysis server. Please try again.';
    } on http.ClientException catch (e) {
      print(e);
      if (!mounted) return null;
      _analysisError =
          'Unable to connect to the analysis server. Please try again.';
    } on FileSystemException catch (e) {
      debugPrint('$e');
      if (!mounted) return null;
      _analysisError = 'Unable to read your photo. Please choose it again.';
    } on FormatException catch (e) {
      debugPrint('$e');
      if (!mounted) return null;
      _analysisError =
          'The server returned an invalid analysis response. Please try again.';
    } on StateError catch (e) {
      debugPrint('$e');
      if (!mounted) return null;
      _analysisError =
          'Unable to prepare the analysis request. Please check your sign-in and try again.';
    } catch (e) {
      print(e);
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_processImage());
  }

  Future<void> _processImage() async {
    if (_requestStarted || !mounted || _hasLeftScreen) return;
    _requestStarted = true;
    final loadingTime = Stopwatch()..start();

    final result = await _uploadImage();
    if (!mounted || _hasLeftScreen) return;

    // Even an immediate local failure must wait until the first build before
    // using the route, ScaffoldMessenger, or Navigator. The request starts above.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _hasLeftScreen || _navigationHandled) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final seasonName = result?['season'];
    final season = seasonName is String ? _convertSeason(seasonName) : null;
    if (result == null || result['error'] != null || season == null) {
      _navigationHandled = true;
      if (result != null) {
        _analysisError = switch (result['error']) {
          'No face detected' =>
            'No face was detected. Please try another photo.',
          'Invalid image' =>
            'The photo could not be processed. Please try another photo.',
          _ =>
            'The server did not return a supported season. Please try again.',
        };
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_analysisError)));
      Navigator.pop(context);
      return;
    }

    // Keep fast successful responses readable without delaying the API request.
    final remaining = const Duration(milliseconds: 2500) - loadingTime.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted || _hasLeftScreen || _navigationHandled) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _navigationHandled = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          season: season,
          analysis: result,
          questionnaireAnswers: widget.answers.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
          imagePath: widget.imagePath,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hasLeftScreen = true;
    super.dispose();
  }

  SeasonKey? _convertSeason(String season) {
    switch (season.trim().toLowerCase()) {
      case "spring":
        return SeasonKey.Spring;

      case "summer":
        return SeasonKey.Summer;

      case "autumn":
        return SeasonKey.Autumn;

      case "winter":
        return SeasonKey.Winter;

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _hasLeftScreen = true;
      },
      child: GradientScaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SizedBox(
            width: double.infinity,
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
                  'Sending your photo and\nwaiting for analysis...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
