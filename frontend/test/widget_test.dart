import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/processing_screen.dart';
import 'package:frontend/screens/questionnaire_screen.dart';

void main() {
  Future<void> showQuestionnaire(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(home: QuestionnaireScreen(imagePath: 'test.jpg')),
    );
  }

  testWidgets('keeps skipped answers null and preserves all answer keys', (
    WidgetTester tester,
  ) async {
    await showQuestionnaire(tester);

    await tester.tap(find.text('Skip'));
    await tester.pump();

    await tester.tap(find.text('Silver'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final processing = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen),
    );
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

    await tester.tap(find.text('Skip'));
    await tester.pump();

    await tester.tap(find.text('Gold'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text('Silver'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('can skip every questionnaire item', (WidgetTester tester) async {
    await showQuestionnaire(tester);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));

    final processing = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen),
    );
    expect(processing.answers, <int, String?>{
      0: null,
      1: null,
      2: null,
      3: null,
    });

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
