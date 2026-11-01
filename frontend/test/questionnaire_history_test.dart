import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/services/analysis_history.dart';
import 'package:frontend/utils/undertone_utils.dart';

// Exercise the actual history reader without live Firebase or modifying data.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> value;
  _Document(this.id, this.value);
  @override
  Map<String, dynamic> data() => value;
}

void main() {
  for (final combination in [
    ('Cool', 'Bright', SeasonKey.Winter),
    ('Cool', 'Muted', SeasonKey.Summer),
    ('Warm', 'Bright', SeasonKey.Spring),
    ('Warm', 'Muted', SeasonKey.Autumn),
  ]) {
    test(
      'history preserves ${combination.$1}/${combination.$2} result and answers',
      () {
        final stored = <String, dynamic>{
          'season': combination.$3.name,
          'undertone': combination.$1,
          'questionnaireAnswers': {'3': combination.$2},
          'warm_score': combination.$1 == 'Warm' ? 1 : 0,
          'cool_score': combination.$1 == 'Cool' ? 1 : 0,
          'warm_question': null,
          'cool_question': null,
          'schemaVersion': 2,
          'photo': {
            'storagePath': 'users/alice/analysisHistory/current/photo',
            'status': 'ready',
          },
        };
        final entry = AnalysisHistoryEntry.fromFirestore(
          _Document('current', stored),
          ownerUid: 'alice',
        );
        expect(entry.season, combination.$3);
        expect(UndertoneUtils.label(entry.analysis), combination.$1);
        expect(
          (entry.analysis['questionnaireAnswers'] as Map)['3'],
          combination.$2,
        );
        expect(entry.storagePath, 'users/alice/analysisHistory/current/photo');
        expect(entry.analysis, stored);
      },
    );
  }

  test('legacy Q1-Q4 scores and answers remain unchanged when read', () {
    final stored = <String, dynamic>{
      'season': 'Autumn',
      'undertone': 'Warm',
      'questionnaireAnswers': {
        '0': 'Green',
        '1': 'Gold',
        '2': 'Tans easily, rarely burns',
        '3': 'Muted',
      },
      'warm_question': 1.0,
      'cool_question': 0.0,
      'warm_score': 1.0,
      'cool_score': 0.0,
      'warm_total': 1.0,
      'cool_total': 0.0,
    };
    final originalAnswers = Map<String, dynamic>.from(
      stored['questionnaireAnswers'] as Map,
    );
    final entry = AnalysisHistoryEntry.fromFirestore(
      _Document('legacy-full', stored),
    );
    expect(entry.season, SeasonKey.Autumn);
    expect(UndertoneUtils.label(entry.analysis), 'Warm');
    expect(entry.analysis['questionnaireAnswers'], originalAnswers);
    expect(entry.analysis['warm_question'], 1.0);
    expect(entry.analysis, stored);
    expect(stored['questionnaireAnswers'], originalAnswers);
  });

  test(
    'legacy Q4 answers and absent answers never remap or reject saved seasons',
    () {
      for (final oldAnswer in [
        'Bright & vivid',
        'Soft & muted',
        'Deep & rich',
        null,
      ]) {
        final stored = <String, dynamic>{
          'season': 'Summer',
          'undertone': 'Warm',
          'questionnaireAnswers': {'3': oldAnswer},
        };
        final entry = AnalysisHistoryEntry.fromFirestore(
          _Document('legacy', stored),
        );
        expect(entry.season, SeasonKey.Summer);
        expect(UndertoneUtils.label(entry.analysis), 'Warm');
        expect((entry.analysis['questionnaireAnswers'] as Map)['3'], oldAnswer);
        expect(stored, {
          'season': 'Summer',
          'undertone': 'Warm',
          'questionnaireAnswers': {'3': oldAnswer},
        });
      }
      final noAnswers = AnalysisHistoryEntry.fromFirestore(
        _Document('older', {'season': 'Winter'}),
      );
      expect(noAnswers.season, SeasonKey.Winter);
      expect(noAnswers.analysis.containsKey('questionnaireAnswers'), isFalse);
    },
  );
}
