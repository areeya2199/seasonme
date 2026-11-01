import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/processing_screen.dart';
import 'package:frontend/screens/questionnaire_screen.dart';
import 'package:frontend/services/analysis_input.dart';
import 'package:image/image.dart' as img;

class _PushedRouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
  }
}

void main() {
  late _PushedRouteObserver observer;
  late Directory directory;
  late File photo;
  late List<int> originalBytes;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('seasonme-questionnaire-');
    originalBytes = img.encodePng(img.Image(width: 20, height: 30));
    photo = File('${directory.path}/photo.png')
      ..writeAsBytesSync(originalBytes);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> showQuestionnaire(
    WidgetTester tester, {
    double textScale = 1,
    String? imagePath,
  }) {
    observer = _PushedRouteObserver();
    return tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: QuestionnaireScreen(imagePath: imagePath ?? photo.path),
      ),
    );
  }

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool pump = true,
  }) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    // Apply the scroll offset before measuring the tap position.
    await tester.pump();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    if (pump) await tester.pump();
  }

  Future<void> waitForPhoto(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
      if (find.text('Loading your photo…').evaluate().isEmpty) {
        return;
      }
    }
    fail('Photo validation did not finish');
  }

  Future<void> finishWithoutMountingProcessing(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Finish'));
    await tester.pump();
    final previous = observer.lastPushedRoute;
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish'));
      for (
        var i = 0;
        i < 100 && identical(previous, observer.lastPushedRoute);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(identical(previous, observer.lastPushedRoute), isFalse);
  }

  List<Color> photoColors(WidgetTester tester) => [
    for (var i = 0; i < 6; i++)
      tester.widget<ColoredBox>(find.byKey(ValueKey('photo-swatch-$i'))).color,
  ];

  ProcessingScreen pushedProcessing(WidgetTester tester) {
    final route = observer.lastPushedRoute;
    expect(route, isA<MaterialPageRoute<dynamic>>());
    // Check the navigation payload before mounting Processing, whose startup
    // invokes Auth/API dependencies outside these questionnaire tests.
    final screen = (route as MaterialPageRoute<dynamic>).builder(
      tester.element(find.byType(QuestionnaireScreen)),
    );
    expect(screen, isA<ProcessingScreen>());
    return screen as ProcessingScreen;
  }

  for (final preference in ['Bright', 'Muted']) {
    testWidgets('only Q4 $preference and the original photo reach Processing', (
      WidgetTester tester,
    ) async {
      await showQuestionnaire(tester);
      await waitForPhoto(tester);
      await tapText(tester, preference);
      await finishWithoutMountingProcessing(tester);

      final processing = pushedProcessing(tester);
      expect(processing.answers, <int, String?>{3: preference});
      final encoded = jsonEncode(
        processing.answers.map((key, value) => MapEntry(key.toString(), value)),
      );
      expect(jsonDecode(encoded), <String, dynamic>{'3': preference});
      expect(processing.imagePath, photo.path);
      expect(photo.readAsBytesSync(), originalBytes);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Q4 loads immediately and requires an explicit choice', (
    tester,
  ) async {
    await showQuestionnaire(tester);
    expect(find.text('Which colors suit you best?'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    for (final removed in [
      'Your wrist vein color',
      'Gold or silver?',
      'How does your skin react to sun?',
      'Skip',
      'Continue',
      'Blue / Purple',
      'Green',
      'Gold',
      'Silver',
      'Tans easily, rarely burns',
      'Burns easily, rarely tans',
    ]) {
      expect(find.text(removed), findsNothing);
    }
    await waitForPhoto(tester);
    expect(
      find.byKey(const ValueKey('questionnaire-user-photo')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tapText(tester, 'Muted');
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Back returns to the photo screen without earlier quiz steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QuestionnaireScreen(imagePath: photo.path),
                ),
              ),
              child: const Text('Choose photo'),
            ),
          ),
        ),
      ),
    );
    await tapText(tester, 'Choose photo');
    await tester.pumpAndSettle();
    await waitForPhoto(tester);
    await tapText(tester, 'Bright');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.byType(QuestionnaireScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'all six colors change together while source photo and bytes stay unchanged',
    (tester) async {
      await showQuestionnaire(tester);
      await waitForPhoto(tester);
      final photoFinder = find.byKey(
        const ValueKey('questionnaire-user-photo'),
      );
      final source = tester.widget<Image>(photoFinder).image as MemoryImage;
      expect(source.bytes, originalBytes);
      final initial = photoColors(tester);
      await tapText(tester, 'Bright');
      final bright = photoColors(tester);
      await tapText(tester, 'Muted');
      final muted = photoColors(tester);
      for (var i = 0; i < 6; i++) {
        expect(bright[i], isNot(initial[i]));
        expect(bright[i], isNot(muted[i]));
      }
      expect(tester.widget<Image>(photoFinder).image, source);
      expect(photo.readAsBytesSync(), originalBytes);

      await tapText(tester, 'Bright');
      expect(photoColors(tester), bright);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final badPhoto in ['empty', 'missing', 'corrupt']) {
    testWidgets('$badPhoto photo blocks Finish without a sample image', (
      tester,
    ) async {
      final badPath = switch (badPhoto) {
        'empty' => '',
        'missing' => '${directory.path}/missing.jpg',
        _ => (File(
          '${directory.path}/invalid.jpg',
        )..writeAsStringSync('not an image')).path,
      };
      await showQuestionnaire(tester, imagePath: badPath);
      await waitForPhoto(tester);
      await tapText(tester, 'Bright');
      expect(
        find.byKey(const ValueKey('questionnaire-photo-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('questionnaire-user-photo')),
        findsNothing,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.text('Skip'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('source removed after preview cannot navigate to Processing', (
    tester,
  ) async {
    await showQuestionnaire(tester);
    await waitForPhoto(tester);
    await tapText(tester, 'Bright');
    photo.deleteSync();
    final previous = observer.lastPushedRoute;
    await tester.ensureVisible(find.text('Finish'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish'));
      await expectLater(
        AnalysisInput.validatePhoto(photo.path),
        throwsA(isA<AnalysisInputException>()),
      );
    });
    await tester.pump();
    expect(observer.lastPushedRoute, previous);
    expect(
      find.byKey(const ValueKey('questionnaire-photo-error')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a different photo at the same path cannot be analyzed unseen', (
    tester,
  ) async {
    await showQuestionnaire(tester);
    await waitForPhoto(tester);
    await tapText(tester, 'Muted');
    final previous = observer.lastPushedRoute;
    photo.writeAsBytesSync(img.encodePng(img.Image(width: 21, height: 31)));
    await tester.ensureVisible(find.text('Finish'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Finish'));
      await AnalysisInput.validatePhoto(photo.path);
    });
    await tester.pump();
    expect(observer.lastPushedRoute, previous);
    expect(
      find.text(
        'Your photo changed. Please go back and choose or take it again.',
      ),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('questionnaire-user-photo')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final layout in [
    ('compact Android viewport', const Size(360, 640), 1.0),
    ('small viewport with enlarged text', const Size(320, 568), 1.5),
  ]) {
    testWidgets('questionnaire remains usable on ${layout.$1}', (tester) async {
      tester.view.physicalSize = layout.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showQuestionnaire(tester, textScale: layout.$3);

      expect(find.text('1/1'), findsOneWidget);
      await waitForPhoto(tester);
      await tapText(tester, 'Muted');
      await finishWithoutMountingProcessing(tester);

      expect(pushedProcessing(tester).answers, <int, String?>{3: 'Muted'});
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
