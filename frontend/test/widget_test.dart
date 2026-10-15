import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/processing_screen.dart';
import 'package:frontend/screens/questionnaire_screen.dart';

class _PushedRouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushedRoute = route;
  }
}

void main() {
  late _PushedRouteObserver observer;

  Future<void> showQuestionnaire(WidgetTester tester, {double textScale = 1}) {
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
        home: const QuestionnaireScreen(imagePath: 'test.jpg'),
      ),
    );
  }

  Future<void> tapText(
    WidgetTester tester,
    String text, {
    bool pump = true,
  }) async {
    await tester.ensureVisible(find.text(text));
    // Apply the scroll offset before measuring the tap position.
    await tester.pump();
    expect(find.text(text).hitTestable(), findsOneWidget);
    await tester.tap(find.text(text));
    if (pump) await tester.pump();
  }

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

    await tapText(tester, 'Skip', pump: false);

    final processing = pushedProcessing(tester);
    expect(processing.answers, <int, String?>{
      0: null,
      1: 'Silver',
      2: null,
      3: null,
    });

    final encoded = jsonEncode(
      processing.answers.map((key, value) => MapEntry(key.toString(), value)),
    );
    expect(jsonDecode(encoded), <String, dynamic>{
      '0': null,
      '1': 'Silver',
      '2': null,
      '3': null,
    });

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

  testWidgets('can skip every questionnaire item', (WidgetTester tester) async {
    await showQuestionnaire(tester);

    for (var i = 0; i < 4; i++) {
      await tapText(tester, 'Skip', pump: i < 3);
    }

    final processing = pushedProcessing(tester);
    expect(processing.answers, <int, String?>{
      0: null,
      1: null,
      2: null,
      3: null,
    });

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

      for (var step = 0; step < 4; step++) {
        expect(find.text('${step + 1}/4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapText(tester, 'Skip', pump: step < 3);
      }

      expect(pushedProcessing(tester).answers, <int, String?>{
        0: null,
        1: null,
        2: null,
        3: null,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
