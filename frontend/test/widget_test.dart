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

  Future<void> openColorQuestion(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tapText(tester, 'Skip');
    }
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

  testWidgets('keeps skipped answers null and preserves all answer keys', (
    WidgetTester tester,
  ) async {
    await showQuestionnaire(tester);

    await tapText(tester, 'Skip');

    await tapText(tester, 'Silver');
    await tapText(tester, 'Continue');

    await tapText(tester, 'Skip');

    await waitForPhoto(tester);
    await tapText(tester, 'Bright');
    await finishWithoutMountingProcessing(tester);

    final processing = pushedProcessing(tester);
    expect(processing.answers, <int, String?>{
      0: null,
      1: 'Silver',
      2: null,
      3: 'Bright',
    });

    final encoded = jsonEncode(
      processing.answers.map((key, value) => MapEntry(key.toString(), value)),
    );
    expect(jsonDecode(encoded), <String, dynamic>{
      '0': null,
      '1': 'Silver',
      '2': null,
      '3': 'Bright',
    });
    expect(processing.imagePath, photo.path);
    expect(photo.readAsBytesSync(), originalBytes);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restores and changes answers when navigating back', (
    WidgetTester tester,
  ) async {
    await showQuestionnaire(tester);

    await tapText(tester, 'Skip');

    await tapText(tester, 'Gold');
    await tapText(tester, 'Continue');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tapText(tester, 'Skip');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tapText(tester, 'Silver');
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('can skip Q1-Q3 but Q4 requires an explicit choice', (
    WidgetTester tester,
  ) async {
    await showQuestionnaire(tester);

    await openColorQuestion(tester);
    await waitForPhoto(tester);
    expect(find.text('Skip'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tapText(tester, 'Muted');
    await finishWithoutMountingProcessing(tester);

    final processing = pushedProcessing(tester);
    expect(processing.answers, <int, String?>{
      0: null,
      1: null,
      2: null,
      3: 'Muted',
    });

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Q2 and Q3 use two images and keep their third answer choices', (
    tester,
  ) async {
    await showQuestionnaire(tester);
    for (var step = 0; step < 3; step++) {
      await tester.pumpAndSettle();
      final imageCount = step == 0 ? 3 : 2;
      for (var option = 0; option < imageCount; option++) {
        expect(
          find.byKey(ValueKey('example-placeholder-$step-$option')),
          findsOneWidget,
        );
      }
      if (step == 1) {
        expect(
          find.byKey(const ValueKey('example-placeholder-1-2')),
          findsNothing,
        );
        expect(find.text('Both look fine'), findsOneWidget);
      }
      if (step == 2) {
        expect(
          find.byKey(const ValueKey('example-placeholder-2-2')),
          findsNothing,
        );
        expect(find.text('A little of both'), findsOneWidget);
      }
      await tapText(tester, 'Skip');
    }
    await waitForPhoto(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'all six colors change together while source photo and bytes stay unchanged',
    (tester) async {
      await showQuestionnaire(tester);
      await openColorQuestion(tester);
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

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tapText(tester, 'Skip');
      expect(photoColors(tester), muted);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
      await openColorQuestion(tester);
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
    await openColorQuestion(tester);
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
    await openColorQuestion(tester);
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

      for (var step = 0; step < 3; step++) {
        expect(find.text('${step + 1}/4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Skip');
      }
      expect(find.text('4/4'), findsOneWidget);
      await waitForPhoto(tester);
      await tapText(tester, 'Muted');
      await finishWithoutMountingProcessing(tester);

      expect(pushedProcessing(tester).answers, <int, String?>{
        0: null,
        1: null,
        2: null,
        3: 'Muted',
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
