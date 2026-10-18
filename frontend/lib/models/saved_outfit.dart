import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/season_palette.dart';
import '../services/image_storage_service.dart';
import '../utils/color_utils.dart';

/// Immutable values from one Clothing analysis; never recomputed on retrieval.
class OutfitMatchSnapshot {
  final SeasonKey season;
  final int matchPercent;
  final MatchLevel matchLevel;
  final int sampledColorArgb;
  final String closestName;
  final int closestArgb;
  final String closestCategory;

  const OutfitMatchSnapshot({
    required this.season,
    required this.matchPercent,
    required this.matchLevel,
    required this.sampledColorArgb,
    required this.closestName,
    required this.closestArgb,
    required this.closestCategory,
  });

  void validate() {
    if (matchPercent < 45 ||
        matchPercent > 100 ||
        matchLevel == MatchLevel.poor ||
        matchLevelFromPercent(matchPercent) != matchLevel ||
        sampledColorArgb < 0 ||
        sampledColorArgb > 0xffffffff ||
        closestArgb < 0 ||
        closestArgb > 0xffffffff ||
        closestName.isEmpty ||
        closestName.length > 120 ||
        !['Clothing', 'Bottoms', 'Jewelry'].contains(closestCategory)) {
      throw const FormatException('Invalid outfit match result');
    }
  }

  Map<String, dynamic> toMap() {
    validate();
    return {
      'season': season.name,
      'matchPercent': matchPercent,
      'matchLevel': matchLevel.name,
      'sampledColorArgb': sampledColorArgb,
      'closestColor': {
        'name': closestName,
        'argb': closestArgb,
        'category': closestCategory,
      },
    };
  }
}

class SavedOutfit {
  static const maxNoteLength = 100;

  /// Count Unicode code points; Rules uses an equivalent RE2 length check.
  static String? normalizeNote(String? value) {
    final note = value?.trim();
    if (note == null || note.isEmpty) return null;
    if (note.runes.length > maxNoteLength) {
      throw const FormatException(
        'Name / Note must be 100 characters or fewer.',
      );
    }
    return note;
  }

  final String id;
  final String ownerUid;
  final OutfitMatchSnapshot match;
  final String imageHash;
  final String storagePath;
  final DateTime savedAt;
  final String status;
  final String? note;

  String get displayName => normalizeNote(note) ?? 'Saved Outfit';

  const SavedOutfit({
    required this.id,
    required this.ownerUid,
    required this.match,
    required this.imageHash,
    required this.storagePath,
    required this.savedAt,
    required this.status,
    this.note,
  });

  factory SavedOutfit.fromMap(
    String uid,
    String id,
    Map<String, dynamic> data,
  ) {
    final closest = data['closestColor'];
    if (data.containsKey('note') && data['note'] is! String) {
      throw FormatException('Invalid name / note in saved outfit $id');
    }
    final note = normalizeNote(data['note'] as String?);
    final season = SeasonKey.values.where((s) => s.name == data['season']);
    final level = MatchLevel.values.where((s) => s.name == data['matchLevel']);
    if (data['schemaVersion'] != 1 ||
        data['matchAlgorithmVersion'] != 1 ||
        data['storagePath'] !=
            ImageStorageService.savedOutfitPathFor(uid, id) ||
        data['imageHash'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['imageHash'] as String) ||
        data['savedAt'] is! Timestamp ||
        !['ready', 'deleting'].contains(data['status']) ||
        season.length != 1 ||
        level.length != 1 ||
        data['matchPercent'] is! int ||
        data['sampledColorArgb'] is! int ||
        closest is! Map ||
        closest['name'] is! String ||
        closest['argb'] is! int ||
        closest['category'] is! String) {
      throw FormatException('Invalid saved outfit $id');
    }
    final match = OutfitMatchSnapshot(
      season: season.single,
      matchPercent: data['matchPercent'] as int,
      matchLevel: level.single,
      sampledColorArgb: data['sampledColorArgb'] as int,
      closestName: closest['name'] as String,
      closestArgb: closest['argb'] as int,
      closestCategory: closest['category'] as String,
    )..validate();
    return SavedOutfit(
      id: id,
      ownerUid: uid,
      match: match,
      imageHash: data['imageHash'] as String,
      storagePath: data['storagePath'] as String,
      savedAt: (data['savedAt'] as Timestamp).toDate(),
      status: data['status'] as String,
      note: note,
    );
  }
}

class SavedOutfitList {
  final List<SavedOutfit> items;
  final int invalidCount;
  const SavedOutfitList(this.items, {this.invalidCount = 0});
}
