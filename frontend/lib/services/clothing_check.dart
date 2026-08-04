import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../data/season_palette.dart';

//Result of scanning a clothing photo for its dominant color.
class DominantColorResult {
  final Color color;
  final double hue;
  final double saturation;
  final double lightness;
  const DominantColorResult(
    this.color,
    this.hue,
    this.saturation,
    this.lightness,
  );
}

//comparing clothing colors
class OutfitMatchVerdict {
  final bool isGoodMatch;
  final String label; // 'Great Match' / 'Good Match' / 'Not Ideal'
  final String reason;
  final double score; // 0-1
  final SwatchItem? closestPaletteColor;

  const OutfitMatchVerdict({
    required this.isGoodMatch,
    required this.label,
    required this.reason,
    required this.score,
    this.closestPaletteColor,
  });
}

class ClothingColorService {
  ClothingColorService._();

  static Future<DominantColorResult> extractDominantColor(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read this image. Please try another photo.');
    }
    final resized = img.copyResize(decoded, width: 160);

    //24 hue bins of 15° each.
    final hueWeight = List<double>.filled(24, 0);
    final satSum = List<double>.filled(24, 0);
    final lightSum = List<double>.filled(24, 0);
    final counts = List<int>.filled(24, 0);

    for (int y = 0; y < resized.height; y += 2) {
      for (int x = 0; x < resized.width; x += 2) {
        final p = resized.getPixel(x, y);
        final c = Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt());
        final hsl = HSLColor.fromColor(c);

        // Skip near-black / near-white / near-gray — usually shadow,
        // highlight, or plain background rather than the garment's hue.
        if (hsl.lightness < 0.08 ||
            hsl.lightness > 0.94 ||
            hsl.saturation < 0.08) {
          continue;
        }

        final bin = (hsl.hue / 15).floor().clamp(0, 23);
        hueWeight[bin] += hsl.saturation;
        satSum[bin] += hsl.saturation;
        lightSum[bin] += hsl.lightness;
        counts[bin]++;
      }
    }

    int bestBin = 0;
    for (int i = 1; i < 24; i++) {
      if (hueWeight[i] > hueWeight[bestBin]) bestBin = i;
    }

    if (counts[bestBin] == 0) {
      // Whole image was near-neutral (white / black / gray garment).
      return const DominantColorResult(Color(0xFF9E9E9E), 0, 0.02, 0.55);
    }

    final avgHue = bestBin * 15 + 7.5;
    final avgSat = satSum[bestBin] / counts[bestBin];
    final avgLight = lightSum[bestBin] / counts[bestBin];
    final color = HSLColor.fromAHSL(1, avgHue, avgSat, avgLight).toColor();

    return DominantColorResult(color, avgHue, avgSat, avgLight);
  }

  static OutfitMatchVerdict evaluate(
    SeasonKey season,
    DominantColorResult detected,
  ) {
    final core = SeasonPaletteData.coreOf(season);

    double minHueDist = 999;
    for (final anchor in core.hueAnchors) {
      var d = (detected.hue - anchor).abs();
      if (d > 180) d = 360 - d;
      if (d < minHueDist) minHueDist = d;
    }
    final hueScore = (1 - (minHueDist / 60)).clamp(0.0, 1.0);

    final satMid = (core.satMin + core.satMax) / 2;
    final satScore = (1 - ((detected.saturation - satMid).abs() / 0.35)).clamp(
      0.0,
      1.0,
    );

    final lightMid = (core.lightMin + core.lightMax) / 2;
    final lightScore = (1 - ((detected.lightness - lightMid).abs() / 0.35))
        .clamp(0.0, 1.0);

    final isNeutral = detected.saturation < 0.15;
    final overall = isNeutral
        ? (0.25 * hueScore + 0.35 * satScore + 0.40 * lightScore)
        : (0.50 * hueScore + 0.25 * satScore + 0.25 * lightScore);

    String label;
    String reason;
    if (overall >= 0.7) {
      label = 'Great Match';
      reason =
          'This color sits right in your ${core.displayName} palette — the warmth and depth line up beautifully with your undertone.';
    } else if (overall >= 0.45) {
      label = 'Good Match';
      reason =
          "This is in the same tonal family as your palette. Lighting can shift the exact shade in a photo, but the overall temperature and depth work for you.";
    } else {
      label = 'Not Ideal';
      reason =
          'This shade leans toward the opposite temperature or intensity of your ${core.displayName} palette, which may wash you out.';
    }

    final closest = _closestClothingSwatch(season, detected.color);

    return OutfitMatchVerdict(
      isGoodMatch: overall >= 0.45,
      label: label,
      reason: reason,
      score: overall,
      closestPaletteColor: closest,
    );
  }

  static SwatchItem? _closestClothingSwatch(SeasonKey season, Color detected) {
    final profile = SeasonPaletteData.getProfile(season);
    SwatchItem? best;
    double bestDist = double.infinity;

    final clothingIterable = (profile as dynamic).clothing as Iterable?;
    if (clothingIterable == null) return null;
    for (final swatch in clothingIterable) {
      final dr = (swatch as dynamic).color.red - detected.red;
      final dg = (swatch as dynamic).color.green - detected.green;
      final db = (swatch as dynamic).color.blue - detected.blue;
      final dist = (dr * dr + dg * dg + db * db).toDouble();
      if (dist < bestDist) {
        bestDist = dist;
        best = swatch as SwatchItem;
      }
    }
    return best;
  }
}
