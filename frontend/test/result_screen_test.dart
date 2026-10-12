import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/screens/result_screen.dart';
import 'package:frontend/services/analysis_history.dart';
import 'package:frontend/theme/season_card_colors.dart';
import 'package:frontend/utils/color_utils.dart';
import 'package:frontend/utils/undertone_utils.dart';
import 'package:image/image.dart' as img;

// Firestore snapshots are faked only at the deserialization boundary in tests.
// ignore: subtype_of_sealed_class
class _HistoryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic> _data;

  _HistoryDocument(this.id, this._data);

  @override
  Map<String, dynamic> data() => _data;
}

void main() {
  late Directory photoDirectory;
  late File photo;

  setUpAll(() {
    photoDirectory = Directory.systemTemp.createTempSync('seasonme_result_');
    photo = File('${photoDirectory.path}/photo.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));
  });

  tearDownAll(() => photoDirectory.deleteSync(recursive: true));

  test('undertone formats only recognized analysis values', () {
    for (final value in ['Warm', ' warm ', 'WARM UNDERTONE']) {
      final analysis = <String, dynamic>{'undertone': value};
      expect(UndertoneUtils.label(analysis), 'Warm');
      expect(
        UndertoneUtils.label(analysis, withSuffix: true),
        'Warm undertone',
      );
    }
    for (final value in ['Cool', ' cool ', 'Cool undertone']) {
      final analysis = <String, dynamic>{'undertone': value};
      expect(UndertoneUtils.label(analysis), 'Cool');
      expect(
        UndertoneUtils.label(analysis, withSuffix: true),
        'Cool undertone',
      );
    }
    for (final analysis in <Map<String, dynamic>?>[
      null,
      {},
      {'undertone': null},
      {'undertone': ''},
      {'undertone': '   '},
      {'undertone': 42},
      {'undertone': false},
      {'undertone': []},
      {'undertone': 'Neutral'},
      {'season': 'Spring', 'warm_total': 1, 'cool_total': 0},
    ]) {
      expect(UndertoneUtils.label(analysis), '—');
      expect(UndertoneUtils.label(analysis, withSuffix: true), '—');
    }
  });

  test('history only accepts the photo key belonging to its entry', () {
    AnalysisHistoryEntry entry(Object? key) {
      return AnalysisHistoryEntry.fromFirestore(
        _HistoryDocument('entry1', {'season': 'Winter', 'localImageKey': key}),
      );
    }

    expect(entry('analysis_entry1.png').localImageKey, 'analysis_entry1.png');
    expect(entry('analysis_entry2.png').localImageKey, isNull);
    expect(entry(null).localImageKey, isNull);
    expect(entry(42).localImageKey, isNull);
  });

  Future<void> showResult(
    WidgetTester tester,
    SeasonKey season, {
    String? imagePath,
    Map<String, dynamic>? analysis,
    double width = 430,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ResultScreen(
          season: season,
          recordToHistory: false,
          imagePath: imagePath,
          analysis: analysis,
        ),
      ),
    );
  }

  Finder personalCard(SeasonKey season) {
    return find.byWidgetPredicate((widget) {
      if (widget is! Container) return false;
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return false;
      final gradient = decoration.gradient;
      return gradient is LinearGradient &&
          listEquals(gradient.colors, seasonCardGradient(season));
    });
  }

  void expectCardColors(
    WidgetTester tester,
    SeasonKey season, {
    String undertone = '—',
    bool night = false,
  }) {
    final card = personalCard(season);
    expect(card, findsOneWidget);
    final colors = seasonCardText(season);
    final profile = SeasonPaletteData.getProfile(season, night: night);
    for (final value in [
      ('YOUR SEASON IS', colors.label),
      (profile.displayName, colors.title),
      (profile.description, colors.body),
      (undertone == '—' ? '—' : '$undertone undertone', colors.pillText),
    ]) {
      final text = tester.widget<Text>(
        find.descendant(of: card, matching: find.text(value.$1)),
      );
      expect(text.style?.color, value.$2);
    }
    final tags = find.descendant(of: card, matching: find.byType(Wrap));
    final tagTexts = tester.widgetList<Text>(
      find.descendant(of: tags, matching: find.byType(Text)),
    );
    expect(tagTexts, hasLength(2));
    expect(
      tagTexts.every((text) => text.style?.color == colors.pillText),
      isTrue,
    );
    final tagBoxes = tester.widgetList<Container>(
      find.descendant(of: tags, matching: find.byType(Container)),
    );
    expect(
      tagBoxes.every(
        (box) => (box.decoration as BoxDecoration).color == colors.pillBg,
      ),
      isTrue,
    );
  }

  for (final undertone in ['Warm', 'Cool']) {
    testWidgets(
      'analysis $undertone overrides the season label in both modes',
      (tester) async {
        // Deliberately disagree with the palette to detect season inference.
        final season = undertone == 'Warm'
            ? SeasonKey.Winter
            : SeasonKey.Spring;
        await showResult(tester, season, analysis: {'undertone': undertone});
        for (final night in [false, true, false]) {
          if (night) {
            await tester.tap(find.text('Night Event'));
          } else {
            await tester.tap(find.text('Day Event'));
          }
          await tester.pump();
          expectCardColors(tester, season, undertone: undertone, night: night);
          final card = personalCard(season);
          final profile = SeasonPaletteData.getProfile(season, night: night);
          expect(
            find.descendant(
              of: card,
              matching: find.text(
                ColorUtils.chromaLabel(
                  profile.topsPool.map((swatch) => swatch.color).toList(),
                ),
              ),
            ),
            findsOneWidget,
          );
          expect(
            tester.widget<ResultScreen>(find.byType(ResultScreen)).season,
            season,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  for (final value in [null, '', 42, 'Neutral']) {
    testWidgets('invalid analysis undertone $value displays a dash', (
      tester,
    ) async {
      await showResult(
        tester,
        SeasonKey.Spring,
        analysis: {'undertone': value},
      );
      expectCardColors(tester, SeasonKey.Spring);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opening different history entries uses each selected analysis', (
    tester,
  ) async {
    final entries = [
      AnalysisHistoryEntry.fromFirestore(
        _HistoryDocument('latest', {'season': 'Winter', 'undertone': 'Cool'}),
      ),
      AnalysisHistoryEntry.fromFirestore(
        _HistoryDocument('older', {'season': 'Winter', 'undertone': 'Warm'}),
      ),
      AnalysisHistoryEntry.fromFirestore(
        _HistoryDocument('legacy', {'season': 'Winter'}),
      ),
    ];
    for (final index in [0, 1, 2, 0]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final selected = entries[index];
      await showResult(tester, selected.season, analysis: selected.analysis);
      expectCardColors(
        tester,
        selected.season,
        undertone: ['Cool', 'Warm', '—'][index],
      );
      final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
      expect(screen.analysis, same(selected.analysis));
      expect(screen.recordToHistory, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  for (final season in SeasonKey.values) {
    testWidgets('$season keeps its text and tags without a photo', (
      tester,
    ) async {
      await showResult(tester, season);
      expectCardColors(tester, season);
      expect(
        find.descendant(of: personalCard(season), matching: find.byType(Image)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    for (final layout in [
      ('wide', 430.0, 1.0, false),
      ('narrow', 320.0, 1.0, true),
      ('large text', 430.0, 1.5, true),
    ]) {
      testWidgets('$season photo stays in card with ${layout.$1}', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await showResult(tester, season, imagePath: photo.path);
          // Exercise the actual Result card separately from unrelated controls
          // elsewhere on the screen, preserving its outer/inner padding.
          final card = tester.widget<Container>(personalCard(season));
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(layout.$3)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: SizedBox(width: layout.$2 - 40, child: card),
                  ),
                ),
              ),
            ),
          );
          await precacheImage(
            FileImage(photo),
            tester.element(personalCard(season)),
          );
        });
        await tester.pumpAndSettle();
        expectCardColors(tester, season);
        final image = find.descendant(
          of: personalCard(season),
          matching: find.byType(Image),
        );
        expect(image, findsOneWidget);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
        expect(tester.getSize(image), const Size(110, 140));
        final label = find.text('YOUR SEASON IS');
        final imagePosition = tester.getTopLeft(image);
        final labelPosition = tester.getTopLeft(label);
        if (layout.$4) {
          expect(labelPosition.dy, greaterThan(imagePosition.dy + 140));
        } else {
          expect(labelPosition.dx, greaterThan(imagePosition.dx + 110));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('missing local photo shows fallback without crashing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await showResult(
        tester,
        SeasonKey.Winter,
        imagePath: '${photoDirectory.path}/missing.png',
      );
      await precacheImage(
        FileImage(File('${photoDirectory.path}/missing.png')),
        tester.element(find.byType(ResultScreen)),
        onError: (_, _) {},
      );
    });
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expectCardColors(tester, SeasonKey.Winter);
    expect(tester.takeException(), isNull);
  });
}
