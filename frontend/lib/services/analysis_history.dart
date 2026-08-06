import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/season_palette.dart';

class AnalysisHistoryEntry {
  final SeasonKey season;
  final DateTime analyzedAt;

  const AnalysisHistoryEntry({required this.season, required this.analyzedAt});

  Map<String, dynamic> toJson() => {
    'season': season.name,
    'analyzedAt': analyzedAt.toIso8601String(),
  };

  static AnalysisHistoryEntry fromJson(Map<String, dynamic> json) {
    return AnalysisHistoryEntry(
      season: SeasonKey.values.firstWhere(
        (s) => s.name == json['season'],
        orElse: () => SeasonKey.Autumn,
      ),
      analyzedAt:
          DateTime.tryParse(json['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AnalysisHistoryService {
  static const _key = 'analysis_history';

  static Future<List<AnalysisHistoryEntry>> getAll({
    bool seedDemoIfNeverUsed = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getStringList(_key);

    if (raw == null && seedDemoIfNeverUsed) {
      final now = DateTime.now();
      final demo = SeasonKey.values.asMap().entries.map((e) {
        return AnalysisHistoryEntry(
          season: e.value,
          // Stagger fake dates so they read naturally, newest first.
          analyzedAt: now.subtract(Duration(days: e.key * 6)),
        );
      }).toList();
      raw = demo.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_key, raw);
    }

    raw ??= [];
    return raw
        .map(
          (s) => AnalysisHistoryEntry.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  static Future<void> addEntry(SeasonKey season) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final entry = AnalysisHistoryEntry(
      season: season,
      analyzedAt: DateTime.now(),
    );
    raw.insert(0, jsonEncode(entry.toJson()));
    await prefs.setStringList(_key, raw);
  }

  // Removes the entry at [index] from the history
  static Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (index < 0 || index >= raw.length) return;
    raw.removeAt(index);
    await prefs.setStringList(_key, raw);
  }
}
