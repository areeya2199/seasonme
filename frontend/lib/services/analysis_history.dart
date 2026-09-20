import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/season_palette.dart';

class AnalysisHistoryEntry {
  final String id;
  final SeasonKey season;
  final DateTime analyzedAt;
  final Map<String, dynamic> analysis;

  const AnalysisHistoryEntry({
    required this.id,
    required this.season,
    required this.analyzedAt,
    required this.analysis,
  });

  static AnalysisHistoryEntry fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final json = document.data();
    final timestamp = json['analyzedAt'];
    return AnalysisHistoryEntry(
      id: document.id,
      season: SeasonKey.values.firstWhere(
        (s) => s.name == json['season'],
        orElse: () => SeasonKey.Autumn,
      ),
      analyzedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      analysis: json,
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
    final collection = _collection;
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('analyzedAt', descending: true)
        .get();
    return snapshot.docs.map(AnalysisHistoryEntry.fromFirestore).toList();
  }

  static Future<void> addEntry({
    required SeasonKey season,
    required Map<String, dynamic> analysis,
    required Map<String, String?> questionnaireAnswers,
  }) async {
    final collection = _collection;
    if (collection == null) return;

    final questionnaire = Map<String, dynamic>.from(
      analysis['questionnaire'] as Map? ?? const {},
    );
    await collection.add({
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
      'analyzedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  static Future<void> remove(String historyId) async {
    final collection = _collection;
    if (collection == null) return;
    await collection.doc(historyId).delete();
  }
}
