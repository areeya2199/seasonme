import 'dart:math';
import 'package:flutter/material.dart';
import 'season_palette.dart';

/// The four occasions the user can filter a season's palette by.
/// This file only *selects* colors that already exist in
/// SeasonPaletteData — it never invents new ones, so season_palette.dart
/// stays completely untouched as requested.
enum Occasion { work, temple, nature, celebration }

extension OccasionLabel on Occasion {
  String get label {
    switch (this) {
      case Occasion.work:
        return 'Work / Office';
      case Occasion.temple:
        return 'Temple / Religious';
      case Occasion.nature:
        return 'Nature / Travel';
      case Occasion.celebration:
        return 'Celebration / Party';
    }
  }

  String get subtitle {
    switch (this) {
      case Occasion.work:
        return 'Professional and trustworthy';
      case Occasion.temple:
        return 'Gentle and elegant';
      case Occasion.nature:
        return 'Vibrant and nature-friendly';
      case Occasion.celebration:
        return 'Vibrant and festive';
    }
  }

  IconData get icon {
    switch (this) {
      case Occasion.work:
        return Icons.work_outline;
      case Occasion.temple:
        return Icons.spa_outlined;
      case Occasion.nature:
        return Icons.park_outlined;
      case Occasion.celebration:
        return Icons.celebration_outlined;
    }
  }
}

class OccasionPaletteSelector {
  OccasionPaletteSelector._();

  /// How well a single color fits an occasion, 0..1, based on HSL.
  /// This is where the "color theory" constraints for each occasion live.
  static double _fitScore(Occasion occasion, Color color) {
    final hsl = HSLColor.fromColor(color);
    final s = hsl.saturation, l = hsl.lightness;

    switch (occasion) {
      case Occasion.work:
        // สุภาพ น่าเชื่อถือ: ความอิ่มตัวต่ำ-กลาง, ไม่มืดจัด ไม่สว่างจ้า
        final satFit = 1 - (s - 0.30).abs().clamp(0.0, 1.0);
        final lightFit = (l >= 0.18 && l <= 0.62) ? 1.0 : 0.3;
        return satFit * 0.5 + lightFit * 0.5;

      case Occasion.temple:
        // นุ่มนวล เรียบร้อย: อิ่มตัวต่ำ, สว่างกลาง-สูง (ครีม/พาสเทลนวล)
        final satFit = 1 - (s / 0.45).clamp(0.0, 1.0);
        final lightFit = l >= 0.45 ? 1.0 : (l / 0.45);
        return satFit * 0.6 + lightFit * 0.4;

      case Occasion.nature:
        // สดใสตัดกับธรรมชาติ ถ่ายรูปสวย: อิ่มตัวสูง ความสว่างกลาง
        final satFit = s;
        final lightFit = 1 - (l - 0.55).abs().clamp(0.0, 1.0);
        return satFit * 0.65 + lightFit * 0.35;

      case Occasion.celebration:
        // สดใสพาสเทล: สว่างสูง อิ่มตัวปานกลาง-สูง (พาสเทลที่ยังมีสีสัน)
        final lightFit = (l >= 0.60 && l <= 0.88) ? 1.0 : 0.3;
        final satFit = (s >= 0.25 && s <= 0.75) ? 1.0 : 0.4;
        return lightFit * 0.55 + satFit * 0.45;
    }
  }

  /// Picks [count] items from [pool] that best fit [occasion]. Takes a
  /// generous shortlist of the best-fitting candidates first (the color
  /// theory constraint), then randomizes within that shortlist (the
  /// "shuffle" affordance) so results vary without ever including a
  /// poor fit for the occasion.
  static List<SwatchItem> select(
    Occasion occasion,
    List<SwatchItem> pool,
    int count, {
    Random? random,
  }) {
    final r = random ?? Random();
    final scored = List.generate(
      pool.length,
      (i) => MapEntry(i, _fitScore(occasion, pool[i].color)),
    )..sort((a, b) => b.value.compareTo(a.value));

    final shortlistSize = min(pool.length, max(count * 3, count));
    final shortlist = scored.take(shortlistSize).toList()..shuffle(r);

    return shortlist.take(count).map((e) => pool[e.key]).toList();
  }
}
