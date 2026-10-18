import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/screens/clothing_screen.dart';
import 'package:frontend/screens/saved_outfits_screen.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/utils/color_utils.dart';
import 'package:image/image.dart' as img;

import 'saved_outfits_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OutfitTestEnvironment env;
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() => env = OutfitTestEnvironment());
  tearDown(() async {
    messenger.setMockMethodCallHandler(picker, null);
    await env.dispose();
  });

  Finder buttons(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );
  Finder noteButton() => find.byKey(const ValueKey('edit-outfit-note'));
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<Uint8List> openNoteDialog(
    WidgetTester tester, {
    bool openDialog = true,
  }) async {
    final color = SeasonPaletteData.getProfile(
      SeasonKey.Winter,
    ).topsPool.first.color;
    final picture = img.Image(width: 40, height: 40);
    img.fill(
      picture,
      color: img.ColorRgb8(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
      ),
    );
    final bytes = Uint8List.fromList(img.encodePng(picture));
    final directory = Directory.systemTemp.createTempSync('outfit-note-ui-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/garment.png')..writeAsBytesSync(bytes);
    messenger.setMockMethodCallHandler(picker, (_) async => file.path);
    await show(
      tester,
      ClothingScreen(season: SeasonKey.Winter, outfitService: env.service),
    );
    await tap(tester, find.text('Upload clothing photo'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose from gallery'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    if (openDialog) {
      await tap(tester, noteButton());
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Name / Note (Optional)'),
        ),
        findsOneWidget,
      );
    }
    return bytes;
  }

  for (final note in ['', '   ', 'a' * 100, '😀' * 100]) {
    testWidgets(
      'dialog saves ${note.trim().isEmpty ? 'blank' : note.runes.length.toString()}-character note without a required field',
      (tester) async {
        await openNoteDialog(tester);
        await tester.enterText(find.byType(TextField), note);
        await tap(tester, find.widgetWithText(FilledButton, 'Done'));
        expect(env.storage.uploads, 0);
        expect(env.documents.puts, 0);
        expect(find.text('Saved'), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('confirmed-outfit-note')))
              .data,
          note.trim().isEmpty ? 'No name or note added.' : note,
        );
        await tap(tester, buttons('Save Outfit'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Saved'), findsOneWidget);
        final raw = env.documents.docs.values.single;
        if (note.trim().isEmpty) {
          expect(raw.containsKey('note'), isFalse);
          expect(raw.values, isNot(contains('Saved Outfit')));
        } else {
          expect(raw['note'], note);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('separate note card wraps long notes at 320px scale $scale', (
      tester,
    ) async {
      await openNoteDialog(tester);
      await tester.enterText(find.byType(TextField), 'uniqlo ' * 14);
      await tap(tester, find.widgetWithText(FilledButton, 'Done'));
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Name / Note (Optional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, buttons('Save Outfit'));
      expect(find.text('Saved with outfit'), findsOneWidget);
      expect(tester.widget<TextButton>(noteButton()).onPressed, isNull);
      expect(tester.takeException(), isNull);
      // Exercise this component alone: the existing upload/result layouts
      // have independent small-screen overflows outside this UI change.
      final card = tester.widget<Container>(
        find.byKey(const ValueKey('outfit-note-card')),
      );
      await show(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(24), child: card),
          ),
        ),
        width: 320,
        scale: scale,
      );
      expect(find.text('uniqlo ' * 13 + 'uniqlo'), findsOneWidget);
      expect(find.text('Saved with outfit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Save Outfit works without ever opening the note dialog', (
    tester,
  ) async {
    await openNoteDialog(tester, openDialog: false);
    await tap(tester, buttons('Save Outfit'));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(env.documents.docs.values.single.containsKey('note'), isFalse);
  });

  testWidgets(
    'editing uses a draft; Cancel preserves confirmed note and Done can clear it',
    (tester) async {
      await openNoteDialog(tester);
      await tester.enterText(find.byType(TextField), 'Original note');
      await tap(tester, find.widgetWithText(FilledButton, 'Done'));
      await tap(tester, noteButton());
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Original note',
      );
      await tester.enterText(find.byType(TextField), 'Discard this edit');
      await tap(tester, find.text('Cancel'));
      expect(find.text('Original note'), findsOneWidget);
      expect(find.text('Discard this edit'), findsNothing);
      expect(env.storage.uploads, 0);
      expect(env.documents.puts, 0);
      await tap(tester, noteButton());
      await tester.enterText(find.byType(TextField), '   ');
      await tap(tester, find.widgetWithText(FilledButton, 'Done'));
      expect(find.text('No name or note added.'), findsOneWidget);
      await tap(tester, buttons('Save Outfit'));
      expect(env.documents.docs.values.single.containsKey('note'), isFalse);
    },
  );

  testWidgets('Cancel after editing still saves the original confirmed note', (
    tester,
  ) async {
    await openNoteDialog(tester);
    await tester.enterText(find.byType(TextField), 'Keep this');
    await tap(tester, find.widgetWithText(FilledButton, 'Done'));
    await tap(tester, noteButton());
    await tester.enterText(find.byType(TextField), 'Discard');
    await tap(tester, find.text('Cancel'));
    await tap(tester, buttons('Save Outfit'));
    expect(env.documents.docs.values.single['note'], 'Keep this');
  });

  for (final source in ['Choose from gallery', 'Take a photo']) {
    testWidgets(
      '$source cancellation keeps note; selecting a new photo clears it',
      (tester) async {
        final bytes = await openNoteDialog(tester);
        await tester.enterText(find.byType(TextField), 'Old photo note');
        await tap(tester, find.widgetWithText(FilledButton, 'Done'));
        messenger.setMockMethodCallHandler(picker, (_) async => null);
        await tap(tester, find.byType(Image).first);
        await tap(tester, find.text(source));
        expect(find.text('Old photo note'), findsOneWidget);
        final directory = Directory.systemTemp.createTempSync(
          'replacement-outfit-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/new.png')..writeAsBytesSync(bytes);
        messenger.setMockMethodCallHandler(picker, (_) async => file.path);
        await tap(tester, find.byType(Image).first);
        await tester.runAsync(() async {
          await tester.tap(find.text(source));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
        expect(find.text('Old photo note'), findsNothing);
        expect(find.text('No name or note added.'), findsOneWidget);
        expect(env.storage.uploads, 0);
        await tap(tester, buttons('Save Outfit'));
        expect(env.documents.docs.values.single.containsKey('note'), isFalse);
      },
    );
  }

  testWidgets('dialog limits 101 characters and Cancel writes nothing', (
    tester,
  ) async {
    await openNoteDialog(tester);
    await tester.enterText(find.byType(TextField), 'a' * 100);
    await tester.enterText(find.byType(TextField), 'a' * 101);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'a' * 100,
    );
    await tap(tester, find.text('Cancel'));
    expect(env.storage.uploads, 0);
    expect(env.documents.puts, 0);
    expect(env.documents.docs, isEmpty);
    await tap(tester, buttons('Save Outfit'));
    expect(find.text('Saved'), findsOneWidget);
    expect(env.documents.docs.values.single.containsKey('note'), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'account change while entering a note cannot save another owner data',
    (tester) async {
      await openNoteDialog(tester);
      await tester.enterText(find.byType(TextField), 'Original account note');
      env.switchTo('bob');
      await tester.pump();
      await tap(tester, find.widgetWithText(FilledButton, 'Done'));
      expect(env.documents.puts, 0);
      expect(env.storage.uploads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'duplicate save keeps the existing note and shows English message',
    (tester) async {
      final bytes = await openNoteDialog(tester);
      await env.service
          .createSaveTask(sampleMatch, bytes, note: 'Existing name')
          .save();
      await tester.enterText(
        find.byType(TextField),
        'Do not replace existing name',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'Done'));
      await tap(tester, buttons('Save Outfit'));
      expect(
        find.text(
          'This outfit is already saved. The existing name and note have been kept.',
        ),
        findsOneWidget,
      );
      expect(env.documents.docs.values.single['note'], 'Existing name');
      expect(env.documents.docs.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('name overlays the photo before Match at 320px scale $scale', (
      tester,
    ) async {
      final note = 'A long purple shirt name from Store A for the interview';
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto(), note: note)
          .save();
      await show(
        tester,
        SavedOutfitsScreen(access: env.service),
        width: 320,
        scale: scale,
      );
      final finder = find.byKey(ValueKey('outfit-name/${saved.id}'));
      final text = tester.widget<Text>(finder);
      expect(text.data, note);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.style!.color, Colors.white);
      expect(
        tester.getBottomLeft(finder).dy,
        lessThan(tester.getTopLeft(find.text('Excellent Match')).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'legacy cards show Saved Outfit on the photo without updating documents',
    (tester) async {
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      final writes = env.documents.puts;
      await show(tester, SavedOutfitsScreen(access: env.service));
      expect(find.text('Saved Outfit'), findsOneWidget);
      expect(env.documents.puts, writes);
      expect(env.documents.docs.values.single.containsKey('note'), isFalse);
    },
  );

  testWidgets(
    'real access returns empty; no mock controls, sample scores or preview UI',
    (tester) async {
      await show(tester, SavedOutfitsScreen(access: env.service));
      expect(find.text('Your outfits, kept close.'), findsOneWidget);
      expect(find.text('ดูรายการตัวอย่าง'), findsNothing);
      expect(find.textContaining('UI Preview'), findsNothing);
      expect(find.text('92%'), findsNothing);
    },
  );

  testWidgets(
    'list loading, failure, retry and missing photo are independent',
    (tester) async {
      final barrier = Completer<void>();
      env.documents.beforeList = () => barrier.future;
      await tester.pumpWidget(
        MaterialApp(home: SavedOutfitsScreen(access: env.service)),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      env.documents.failList = true;
      barrier.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      env.documents.beforeList = null;
      env.documents.failList = false;
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      env.storage.files.remove(saved.storagePath);
      await tap(tester, find.text('Retry'));
      expect(find.text('82%'), findsOneWidget);
      expect(find.text('Retry photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete cancellation, partial failure and retry do not claim early success',
    (tester) async {
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      await show(tester, SavedOutfitsScreen(access: env.service));
      await tap(tester, find.byTooltip('Remove saved outfit'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('82%'), findsOneWidget);
      env.documents.failFinishDelete = true;
      await tap(tester, find.byTooltip('Remove saved outfit'));
      await tap(tester, find.text('Remove'));
      expect(find.text('Retry delete'), findsOneWidget);
      expect(find.text('Saved outfit removed.'), findsNothing);
      env.documents.failFinishDelete = false;
      await tap(tester, find.text('Retry delete'));
      await tap(tester, find.text('OK'));
      await tap(tester, find.text('Remove'));
      expect(find.text('Your outfits, kept close.'), findsOneWidget);
      expect(env.storage.files, isEmpty);
      expect(env.documents.docs, isEmpty);
    },
  );

  testWidgets(
    'switch accounts clears old entries and ignores old listing futures',
    (tester) async {
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      await show(tester, SavedOutfitsScreen(access: env.service));
      expect(find.text('82%'), findsOneWidget);
      env.switchTo('bob');
      await tester.pumpAndSettle();
      expect(find.text('82%'), findsNothing);
      expect(find.byType(Image), findsNothing);
      env.switchTo(null);
      await tester.pumpAndSettle();
      expect(
        find.text('Please sign in to view Saved Outfits.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('two-column real data grid at 320px scale $scale', (
      tester,
    ) async {
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      await show(
        tester,
        SavedOutfitsScreen(access: env.service),
        width: 320,
        scale: scale,
      );
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      expect(find.text('Checked for Winter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final avoid in [false, true]) {
    testWidgets(
      'Clothing ${avoid ? 'Avoid disabled' : 'Save, Saving, Retry and Saved use real task outcomes'}',
      (tester) async {
        final pool = SeasonPaletteData.getProfile(SeasonKey.Winter);
        final swatches = [...pool.topsPool, ...pool.bottoms, ...pool.jewelry];
        Color color = swatches.first.color;
        if (avoid) {
          double furthest = -1;
          for (final r in [0, 128, 255]) {
            for (final g in [0, 128, 255]) {
              for (final b in [0, 128, 255]) {
                final c = Color.fromARGB(255, r, g, b);
                final d = swatches
                    .map((s) => ColorUtils.labDistance(c, s.color))
                    .reduce((a, b) => a < b ? a : b);
                if (d > furthest) {
                  furthest = d;
                  color = c;
                }
              }
            }
          }
          expect(
            matchLevelFromPercent(ColorUtils.distanceToPercent(furthest)),
            MatchLevel.poor,
          );
        }
        final picture = img.Image(width: 40, height: 40);
        img.fill(
          picture,
          color: img.ColorRgb8(
            (color.r * 255).round(),
            (color.g * 255).round(),
            (color.b * 255).round(),
          ),
        );
        final directory = Directory.systemTemp.createTempSync(
          'outfit-ui-test-',
        );
        // This test owns only this disposable directory.
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/garment.png')
          ..writeAsBytesSync(img.encodePng(picture));
        messenger.setMockMethodCallHandler(picker, (_) async => file.path);
        await show(
          tester,
          ClothingScreen(season: SeasonKey.Winter, outfitService: env.service),
        );
        await tap(tester, find.text('Upload clothing photo'));
        await tester.runAsync(() async {
          await tester.tap(find.text('Choose from gallery'));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pumpAndSettle();
        expect(buttons('Save Outfit'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(buttons('Save Outfit')).onPressed,
          avoid ? isNull : isNotNull,
        );
        if (!avoid) {
          final blocked = Completer<void>();
          env.documents.beforeGet = () => blocked.future;
          await tap(tester, noteButton());
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('Name / Note (Optional)'),
            ),
            findsOneWidget,
          );
          expect(env.storage.uploads, 0);
          expect(env.documents.docs, isEmpty);
          await tester.enterText(
            find.byType(TextField),
            'Purple shirt from Store A',
          );
          await tap(tester, find.text('Cancel'));
          expect(env.storage.uploads, 0);
          expect(env.documents.docs, isEmpty);
          await tap(tester, noteButton());
          await tester.enterText(
            find.byType(TextField),
            'Purple shirt from Store A',
          );
          await tap(tester, find.widgetWithText(FilledButton, 'Done'));
          expect(env.storage.uploads, 0);
          expect(env.documents.docs, isEmpty);
          await tester.ensureVisible(buttons('Save Outfit'));
          await tester.tap(buttons('Save Outfit'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Saving...'), findsOneWidget);
          expect(
            tester.widget<FilledButton>(buttons('Saving...')).onPressed,
            isNull,
          );
          env.documents.failPut = true;
          blocked.complete();
          await tester.pumpAndSettle();
          expect(find.text('Retry'), findsOneWidget);
          expect(find.text('Saved'), findsNothing);
          expect(env.storage.files.length, 1);
          expect(tester.widget<TextButton>(noteButton()).onPressed, isNull);
          env.documents.failPut = false;
          env.documents.beforeGet = null;
          await tap(tester, buttons('Retry'));
          expect(find.text('Saved'), findsOneWidget);
          expect(env.documents.docs.length, 1);
          expect(
            env.documents.docs.values.single['note'],
            'Purple shirt from Store A',
          );
          expect(find.byType(AlertDialog), findsNothing);
          expect(env.storage.uploads, 1);
          expect(
            tester.widget<FilledButton>(buttons('Saved')).onPressed,
            isNull,
          );
          env.switchTo('bob');
          await tester.pumpAndSettle();
          expect(find.text('Saved'), findsNothing);
          expect(find.byType(Image), findsNothing);
        } else {
          expect(env.documents.docs, isEmpty);
          expect(env.storage.uploads, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a delayed old-account list cannot appear after switching accounts',
    (tester) async {
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      final pending = Completer<void>();
      env.documents.beforeList = () => pending.future;
      await tester.pumpWidget(
        MaterialApp(home: SavedOutfitsScreen(access: env.service)),
      );
      await tester.pump();
      env.switchTo('bob');
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('82%'), findsNothing);
      expect(find.text('Your outfits, kept close.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
