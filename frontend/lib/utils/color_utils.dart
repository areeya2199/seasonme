import 'dart:math';
import 'package:flutter/material.dart';

/// Shared color-science helpers used across the app (result screen,
/// outfit checker, occasion palette selection). Centralizing this means
/// "what counts as a good match" is defined once, consistently.
class ColorUtils {
  ColorUtils._();

  // ---------------- CIE Lab (perceptual distance) ----------------
  // Used for "how similar are these two colors" — e.g. matching a
  // detected outfit color against a season palette.

  static List<double> rgbToLab(Color c) {
    double r = c.red / 255.0, g = c.green / 255.0, b = c.blue / 255.0;
    r = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4).toDouble() : r / 12.92;
    g = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4).toDouble() : g / 12.92;
    b = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4).toDouble() : b / 12.92;
    r *= 100;
    g *= 100;
    b *= 100;

    final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 95.047;
    final y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 100.0;
    final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 108.883;

    double f(double t) =>
        t > 0.008856 ? pow(t, 1 / 3).toDouble() : (7.787 * t) + 16 / 116;

    final fx = f(x), fy = f(y), fz = f(z);
    return [(116 * fy) - 16, 500 * (fx - fy), 200 * (fy - fz)];
  }

  static double labDistance(Color a, Color b) {
    final la = rgbToLab(a), lb = rgbToLab(b);
    final dl = la[0] - lb[0], da = la[1] - lb[1], db = la[2] - lb[2];
    return sqrt(dl * dl + da * da + db * db);
  }

  // ---------------- HSL helpers (color-wheel relationships) ----------------
  // Used for "do these two colors work together as an outfit pairing" —
  // this is a *different* question from "are they similar colors".

  static bool isNeutral(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.saturation < 0.14 ||
        hsl.lightness < 0.12 ||
        hsl.lightness > 0.93;
  }

  static double hueDiff(Color a, Color b) {
    final ha = HSLColor.fromColor(a).hue;
    final hb = HSLColor.fromColor(b).hue;
    double d = (ha - hb).abs();
    if (d > 180) d = 360 - d;
    return d;
  }

  /// Returns 0..1: how well two colors work together as an outfit pairing.
  /// - Neutrals (black/white/gray/very muted) pair with almost anything.
  /// - Analogous hues (close together on the wheel) read as a coordinated look.
  /// - Complementary hues (near-opposite) read as an intentional, bold contrast.
  /// - The 20°-100° "in-between" zone is where colors tend to visually clash,
  ///   so it scores low and is avoided rather than picked at random.
  static double harmonyScore(Color a, Color b) {
    if (isNeutral(a) || isNeutral(b)) return 0.95;

    final hd = hueDiff(a, b);
    double hueScore;
    if (hd <= 20) {
      hueScore = 0.85; // analogous / same family
    } else if (hd >= 150) {
      hueScore = 0.90; // complementary — bold, intentional contrast
    } else if (hd >= 100) {
      hueScore = 0.60; // triadic / split-complementary — usable
    } else {
      hueScore = 0.25; // the awkward clash zone
    }

    final hslA = HSLColor.fromColor(a), hslB = HSLColor.fromColor(b);
    final bothVeryVivid = hslA.saturation > 0.75 && hslB.saturation > 0.75;
    final penalty = bothVeryVivid ? 0.15 : 0.0;

    return (hueScore - penalty).clamp(0.0, 1.0);
  }

  /// Picks a harmonious match for [target] out of [pool]: scores every
  /// candidate with [harmonyScore], then does a *weighted* random pick
  /// among the top [topN] — so results stay tasteful (no clashing colors)
  /// but aren't the same single "closest" pick every single time.
  static int? pickHarmoniousIndex(
    Color target,
    List<Color> pool, {
    Random? random,
    int topN = 3,
  }) {
    if (pool.isEmpty) return null;
    final r = random ?? Random();
    final scored = List.generate(
      pool.length,
      (i) => MapEntry(i, harmonyScore(target, pool[i])),
    )..sort((a, b) => b.value.compareTo(a.value));

    final candidates = scored.take(min(topN, scored.length)).toList();
    final totalWeight = candidates.fold<double>(0, (s, e) => s + e.value);
    if (totalWeight <= 0) return candidates.first.key;

    double roll = r.nextDouble() * totalWeight;
    for (final c in candidates) {
      roll -= c.value;
      if (roll <= 0) return c.key;
    }
    return candidates.first.key;
  }

  // ---------------- Season-match percentage (outfit checker) ----------------

  /// Converts a Lab distance into a 0..100 "match percent" against a palette.
  /// Distances beyond ~70 are treated as essentially unrelated colors.
  static int distanceToPercent(double distance) {
    const maxMeaningfulDistance = 70.0;
    final pct = 100 * (1 - (distance / maxMeaningfulDistance)).clamp(0.0, 1.0);
    return pct.round();
  }
}

enum MatchLevel { excellent, good, poor }

MatchLevel matchLevelFromPercent(int percent) {
  if (percent >= 75) return MatchLevel.excellent;
  if (percent >= 45) return MatchLevel.good;
  return MatchLevel.poor;
}
