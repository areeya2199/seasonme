import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/season_palette.dart';

class AnalysisHistoryEntry {
  final String id;
  final SeasonKey season;
  final DateTime analyzedAt;
  final Map<String, dynamic> analysis;
  final String? localImageKey;

  const AnalysisHistoryEntry({
    required this.id,
    required this.season,
    required this.analyzedAt,
    required this.analysis,
    this.localImageKey,
  });

  static AnalysisHistoryEntry fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final json = document.data();
    final timestamp = json['analyzedAt'];
    final localImageKey = json['localImageKey'];
    final seasonName = json['season'];
    final normalizedSeason = seasonName is String
        ? seasonName.trim().toLowerCase()
        : null;
    return AnalysisHistoryEntry(
      id: document.id,
      season: SeasonKey.values.firstWhere(
        (s) => s.name.toLowerCase() == normalizedSeason,
        orElse: () => throw FormatException(
          'Invalid season in analysis history entry ${document.id}',
        ),
      ),
      analyzedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      analysis: json,
      // A photo reference must belong to this history entry.
      localImageKey:
          localImageKey is String &&
              localImageKey.startsWith('analysis_${document.id}.')
          ? localImageKey
          : null,
    );
  }
}

class AnalysisHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get _user => FirebaseAuth.instance.currentUser;

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final user = _user;
    if (user == null) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('analysisHistory');
  }

  static Future<List<AnalysisHistoryEntry>> getAll() async {
    final uid = _user?.uid;
    final collection = _collection;
    if (collection == null || uid == null) {
      throw StateError('Sign in before loading analysis history');
    }

    final snapshot = await collection
        .orderBy('analyzedAt', descending: true)
        .get();
    _checkUser(uid);
    return snapshot.docs.map(AnalysisHistoryEntry.fromFirestore).toList();
  }

  // Only Home's outfit action needs server confirmation. Other history reads
  // keep Firestore's normal server/cache behavior.
  static Future<AnalysisHistoryEntry?> getLatestFromServer() async {
    final uid = _user?.uid;
    final collection = _collection;
    if (collection == null || uid == null) {
      throw StateError('Sign in before loading analysis history');
    }
    final snapshot = await collection
        .orderBy('analyzedAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    _checkUser(uid);
    return snapshot.docs.isEmpty
        ? null
        : AnalysisHistoryEntry.fromFirestore(snapshot.docs.first);
  }

  static void _checkUser(String uid) {
    if (_user?.uid != uid) {
      throw StateError('The signed-in account changed while loading history');
    }
  }

  static Future<void> addEntry({
    required SeasonKey season,
    required Map<String, dynamic> analysis,
    required Map<String, String?> questionnaireAnswers,
    String? imagePath,
  }) async {
    final collection = _collection;
    final user = _user;
    if (collection == null || user == null) return;

    final document = collection.doc();
    final analyzedAt = Timestamp.fromDate(DateTime.now());
    String? localImageKey;
    File? savedPhoto;
    if (imagePath != null && !kIsWeb) {
      try {
        final file = File(imagePath);
        // Keep saved photos within the in-memory history loading limit.
        if (await file.length() > _maxImageBytes) {
          throw StateError('Analysis photo is too large to store');
        }
        final extension =
            RegExp(
              r'\.([a-zA-Z0-9]{1,10})$',
            ).firstMatch(imagePath)?.group(1)?.toLowerCase() ??
            'img';
        final key = 'analysis_${document.id}.$extension';
        final destination = await _photoFile(user.uid, key);
        await destination.parent.create(recursive: true);
        savedPhoto = destination;
        await file.copy(destination.path);
        localImageKey = key;
      } catch (error) {
        debugPrint('Analysis photo copy failed: $error');
        if (savedPhoto != null) {
          await _deletePhotoIfPresent(savedPhoto);
          savedPhoto = null;
        }
        // The analysis is still saved when its photo cannot be copied.
      }
    }

    final questionnaire = Map<String, dynamic>.from(
      analysis['questionnaire'] as Map? ?? const {},
    );
    try {
      await document.set({
        'season': season.name,
        'undertone': analysis['undertone'],
        'questionnaireAnswers': questionnaireAnswers,
        'warm_score': analysis['warm_score'],
        'cool_score': analysis['cool_score'],
        'warm_question': questionnaire['warm'],
        'cool_question': questionnaire['cool'],
        'warm_total': analysis['warm_total'] ?? analysis['warm_score'],
        'cool_total': analysis['cool_total'] ?? analysis['cool_score'],
        'hue_angle': analysis['hue_angle'],
        'rgb': analysis['rgb'],
        'hsv': analysis['hsv'],
        'lab': analysis['lab'],
        'lightness_group': analysis['lightness_group'],
        'chroma_group': analysis['chroma_group'],
        'analyzedAt': analyzedAt,
        if (localImageKey != null) 'localImageKey': localImageKey,
      });
    } catch (error) {
      if (savedPhoto != null) {
        await _deletePhotoIfPresent(savedPhoto);
      }
      rethrow;
    }
  }

  static const int _maxImageBytes = 20 * 1024 * 1024;

  static Future<File> _photoFile(String uid, String localImageKey) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(uid) ||
        !RegExp(
          r'^analysis_[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,10}$',
        ).hasMatch(localImageKey)) {
      throw ArgumentError('Invalid local analysis photo reference');
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/analysis_photos/$uid/$localImageKey');
  }

  static Future<void> _deletePhotoIfPresent(File photo) async {
    try {
      if (await photo.exists()) await photo.delete();
    } catch (error) {
      debugPrint('Local analysis photo cleanup failed: $error');
    }
  }

  static Future<Uint8List?> loadPhoto(String localImageKey) async {
    if (kIsWeb) return null;
    try {
      final user = _user;
      if (user == null) return null;
      final photo = await _photoFile(user.uid, localImageKey);
      if (!await photo.exists() || await photo.length() > _maxImageBytes) {
        return null;
      }
      final bytes = await photo.readAsBytes();
      return _user?.uid == user.uid ? bytes : null;
    } catch (error) {
      debugPrint('Local analysis photo load failed: $error');
      return null;
    }
  }

  static Future<void> remove(String historyId) async {
    final collection = _collection;
    final user = _user;
    if (collection == null || user == null) return;
    final document = collection.doc(historyId);
    final snapshot = await document.get();
    final localImageKey = snapshot.data()?['localImageKey'];
    if (!kIsWeb && localImageKey is String) {
      if (!localImageKey.startsWith('analysis_$historyId.')) {
        throw StateError('Invalid local analysis photo reference');
      }
      final photo = await _photoFile(user.uid, localImageKey);
      if (await photo.exists()) await photo.delete();
    }
    await document.delete();
  }
}
