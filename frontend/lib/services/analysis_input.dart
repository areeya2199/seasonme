import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Input errors are kept separate from sign-in, network and server failures.
class AnalysisInputException implements Exception {
  final String message;
  const AnalysisInputException(this.message);

  @override
  String toString() => message;
}

class AnalysisInput {
  AnalysisInput._();

  static const colorPreferences = {'Bright', 'Muted'};

  static bool hasColorPreference(Map<int, String?> answers) =>
      colorPreferences.contains(answers[3]);

  static void validateAnswers(Map<int, String?> answers) {
    if (!hasColorPreference(answers)) {
      throw const AnalysisInputException(
        'Please choose Bright or Muted in question 4 before continuing.',
      );
    }
  }

  /// Read/decode only. Never resize, re-encode, rotate or overwrite the source.
  static Future<Uint8List> validatePhoto(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) {
      throw const AnalysisInputException(
        'No photo was provided. Please choose or take a photo again.',
      );
    }
    try {
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      return bytes;
    } catch (_) {
      throw const AnalysisInputException(
        'Unable to load your photo. Please go back and choose or take it again.',
      );
    }
  }
}
