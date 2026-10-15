import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/occasion_palette.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/screens/beauty_preview.dart';
import 'package:frontend/screens/result_screen.dart';
import 'package:frontend/screens/wardrobe_preview.dart';
import 'package:frontend/theme/app_theme.dart';

const _assets = {
  'assets/preview_face_base.png': Size(400, 422),
  'assets/preview_face_blush.png': Size(400, 422),
  'assets/preview_face_earrings.png': Size(400, 422),
  'assets/preview_face_eyeshadow.png': Size(400, 422),
  'assets/preview_face_hair.png': Size(400, 422),
  'assets/preview_face_lips.png': Size(400, 422),
  'assets/preview_mannequin_base.png': Size(400, 770),
  'assets/preview_mannequin_shirt.png': Size(400, 770),
  'assets/preview_mannequin_skirt.png': Size(400, 770),
};

Map<String, Color?> _beautyColors(BeautyPreviewCard card) => {
  'hair': card.hair,
  'eye': card.eyeshadow,
  'blush': card.blush,
  'lipstick': card.lips,
  'jewelry': card.earrings,
};

Finder _compactWraps() => find.byWidgetPredicate((widget) {
  if (widget is! Wrap || widget.children.isEmpty) return false;
  final first = widget.children.first;
  return first is GestureDetector &&
      first.child is Container &&
      (first.child! as Container).constraints?.maxWidth == 34;
});

Finder _compactTile(int group, int index) => find
    .descendant(
      of: _compactWraps().at(group),
      matching: find.byType(GestureDetector),
    )
    .at(index);

Finder _beautyTiles() => find.byWidgetPredicate((widget) {
  return widget is GestureDetector &&
      widget.child is SizedBox &&
      (widget.child! as SizedBox).width == 64;
});

BoxDecoration _tileDecoration(WidgetTester tester, Finder finder) {
  final child = tester.widget<GestureDetector>(finder).child!;
  final box = child is Container
      ? child
      : ((child as SizedBox).child! as Column).children.first as Container;
  return box.decoration! as BoxDecoration;
}

List<Color> _compactColors(WidgetTester tester, int group) {
  final count = tester.widget<Wrap>(_compactWraps().at(group)).children.length;
  return List.generate(
    count,
    (index) => _tileDecoration(tester, _compactTile(group, index)).color!,
  );
}

List<Color> _beautySwatches(WidgetTester tester) => [
  for (var i = 0; i < _beautyTiles().evaluate().length; i++)
    _tileDecoration(tester, _beautyTiles().at(i)).color!,
];

List<Color> _selectedColors(WidgetTester tester, Iterable<Finder> tiles) => [
  for (final tile in tiles)
    if ((_tileDecoration(tester, tile).border! as Border).top.color ==
        AppColors.gold)
      _tileDecoration(tester, tile).color!,
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapBeauty(WidgetTester tester, int index) => _tap(
  tester,
  // The wrapper center can fall in the gap between the color and its label.
  find
      .descendant(
        of: _beautyTiles().at(index),
        matching: find.byType(Container),
      )
      .first,
);

Future<void> _showResult(
  WidgetTester tester,
  SeasonKey season, {
  Size size = const Size(430, 1000),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(const MaterialApp(home: Scaffold()));
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Scaffold));
    for (final path in _assets.keys) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ResultScreen(
        season: season,
        recordToHistory: false,
        analysis: const {'undertone': 'Cool'},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MannequinCard _mannequin(WidgetTester tester) =>
    tester.widget<MannequinCard>(find.byType(MannequinCard));

BeautyPreviewCard _beauty(WidgetTester tester) =>
    tester.widget<BeautyPreviewCard>(find.byType(BeautyPreviewCard));

Future<void> _occasion(WidgetTester tester, String label) async {
  await _tap(tester, find.byIcon(Icons.place_outlined));
  await _tap(tester, find.text(label));
}

void main() {
  testWidgets(
    'all nine bundled preview layers decode with matching dimensions',
    (tester) async {
      await tester.runAsync(() async {
        for (final entry in _assets.entries) {
          final data = await rootBundle.load(entry.key);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          final frame = await codec.getNextFrame();
          expect(
            frame.image.width,
            entry.value.width.toInt(),
            reason: entry.key,
          );
          expect(
            frame.image.height,
            entry.value.height.toInt(),
            reason: entry.key,
          );
          frame.image.dispose();
          codec.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview defaults and layer order match the peer implementation',
    (tester) async {
      await _showResult(tester, SeasonKey.Winter);
      expect(_mannequin(tester).shirtColor, isNull);
      expect(_mannequin(tester).pantsColor, isNull);
      final wardrobeImages = tester.widgetList<Image>(
        find.descendant(
          of: find.byType(MannequinCard),
          matching: find.byType(Image),
        ),
      );
      expect(
        wardrobeImages.map((image) => (image.image as AssetImage).assetName),
        [
          'assets/preview_mannequin_shirt.png',
          'assets/preview_mannequin_skirt.png',
          'assets/preview_mannequin_base.png',
        ],
      );
      await _tap(tester, find.text('Beauty & Jewelry'));
      expect(_beautyColors(_beauty(tester)).values, everyElement(isNull));
      final layers = tester.widgetList<Image>(
        find.descendant(
          of: find.byType(BeautyPreviewCard),
          matching: find.byType(Image, skipOffstage: false),
          skipOffstage: false,
        ),
      );
      expect(layers.map((image) => (image.image as AssetImage).assetName), [
        'assets/preview_face_base.png',
        'assets/preview_face_blush.png',
        'assets/preview_face_eyeshadow.png',
        'assets/preview_face_lips.png',
        'assets/preview_face_hair.png',
        'assets/preview_face_earrings.png',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final season in SeasonKey.values) {
    testWidgets('$season wardrobe colors persist across palette changes', (
      tester,
    ) async {
      await _showResult(tester, season);
      final shirt = _compactColors(tester, 0).first;
      await _tap(tester, _compactTile(0, 0));
      final pants = _mannequin(tester).pantsColor;
      expect(_mannequin(tester).shirtColor, shirt);
      expect(
        SeasonPaletteData.getProfile(season).bottoms.map((item) => item.color),
        contains(pants),
      );

      void expectPreserved() {
        expect(_mannequin(tester).shirtColor, shirt);
        expect(_mannequin(tester).pantsColor, pants);
      }

      await _tap(tester, find.byIcon(Icons.shuffle));
      expectPreserved();
      expect(_compactColors(tester, 0), isNot(contains(shirt)));
      expect(
        _selectedColors(tester, List.generate(9, (i) => _compactTile(0, i))),
        isEmpty,
      );
      for (final mode in ['Night Event', 'Day Event']) {
        await _tap(tester, find.text(mode));
        expectPreserved();
      }
      for (final occasion in Occasion.values) {
        await _occasion(tester, occasion.label);
        expectPreserved();
        await _tap(tester, find.byIcon(Icons.shuffle));
        expectPreserved();
      }
      await _tap(tester, find.byIcon(Icons.place_outlined));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(Occasion.celebration.label), findsOneWidget);
      expectPreserved();
      await _occasion(tester, 'Show All (Default)');
      expectPreserved();
      await _tap(tester, find.text('Beauty & Jewelry'));
      await _tap(tester, find.text('Wardrobe'));
      expectPreserved();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$season beauty categories persist independently', (
      tester,
    ) async {
      await _showResult(tester, season);
      await _tap(tester, find.text('Beauty & Jewelry'));
      final picked = <String, Color>{};
      for (final category in {
        'hair': 'Hair',
        'eye': 'Eyes',
        'blush': 'Blush',
        'lipstick': 'Lips',
        'jewelry': 'Jewelry',
      }.entries) {
        await _tap(tester, find.text(category.value));
        picked[category.key] = _beautySwatches(tester).first;
        await _tapBeauty(tester, 0);
      }
      expect(_beautyColors(_beauty(tester)), picked);
      await _tap(tester, find.text('Wardrobe'));
      await _tap(tester, _compactTile(0, 0));
      await _tap(tester, find.byIcon(Icons.shuffle));
      await _tap(tester, find.text('Beauty & Jewelry'));
      expect(_beautyColors(_beauty(tester)), picked);
      for (final mode in ['Night Event', 'Day Event']) {
        await _tap(tester, find.text(mode));
        expect(_beautyColors(_beauty(tester)), picked);
      }
      for (final occasion in Occasion.values) {
        await _occasion(tester, occasion.label);
        expect(_beautyColors(_beauty(tester)), picked);
      }
      await _occasion(tester, 'Show All (Default)');
      expect(_beautyColors(_beauty(tester)), picked);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wardrobe toggles and a new top recomputes the bottom', (
    tester,
  ) async {
    await _showResult(tester, SeasonKey.Winter);
    await _tap(tester, _compactTile(0, 0));
    await _tap(tester, _compactTile(0, 0));
    expect(_mannequin(tester).shirtColor, isNull);
    expect(_mannequin(tester).pantsColor, isNull);

    await _tap(tester, _compactTile(0, 0));
    final auto = _mannequin(tester).pantsColor;
    await _tap(
      tester,
      _compactTile(1, _compactColors(tester, 1).indexOf(auto!)),
    );
    expect(_mannequin(tester).pantsColor, isNull);
    expect(_mannequin(tester).shirtColor, isNotNull);

    const dayBlack = Color(0xFF0B0B0C);
    await _tap(
      tester,
      _compactTile(1, _compactColors(tester, 1).indexOf(dayBlack)),
    );
    expect(_mannequin(tester).pantsColor, dayBlack);
    await _tap(tester, find.text('Night Event'));
    expect(_mannequin(tester).pantsColor, dayBlack);
    final nightBottoms = SeasonPaletteData.getProfile(
      SeasonKey.Winter,
      night: true,
    ).bottoms.map((item) => item.color);
    expect(nightBottoms, isNot(contains(dayBlack)));
    final nextTop = _compactColors(
      tester,
      0,
    ).indexWhere((color) => color != _mannequin(tester).shirtColor);
    await _tap(tester, _compactTile(0, nextTop));
    expect(nightBottoms, contains(_mannequin(tester).pantsColor));
    expect(_mannequin(tester).pantsColor, isNot(dayBlack));
  });

  testWidgets('beauty same-color toggle only clears its own category', (
    tester,
  ) async {
    await _showResult(tester, SeasonKey.Winter);
    await _tap(tester, find.text('Beauty & Jewelry'));
    await _tapBeauty(tester, 0);
    await _tap(tester, find.text('Eyes'));
    final eye = _beautySwatches(tester).first;
    await _tapBeauty(tester, 0);
    await _tap(tester, find.text('Hair'));
    await _tapBeauty(tester, 0);
    expect(_beauty(tester).hair, isNull);
    expect(_beauty(tester).eyeshadow, eye);
  });

  testWidgets('Winter Day Silver stays selected when absent from Night hair', (
    tester,
  ) async {
    await _showResult(tester, SeasonKey.Winter);
    await _tap(tester, find.text('Beauty & Jewelry'));
    const silver = Color(0xFFC7CDD2);
    await _tapBeauty(tester, _beautySwatches(tester).indexOf(silver));
    await _tap(tester, find.text('Night Event'));
    expect(_beauty(tester).hair, silver);
    expect(_beautySwatches(tester), isNot(contains(silver)));
    expect(
      _selectedColors(
        tester,
        List.generate(
          _beautyTiles().evaluate().length,
          (i) => _beautyTiles().at(i),
        ),
      ),
      isEmpty,
    );
    await _tap(tester, find.text('Day Event'));
    expect(_beauty(tester).hair, silver);
    expect(
      _selectedColors(
        tester,
        List.generate(
          _beautyTiles().evaluate().length,
          (i) => _beautyTiles().at(i),
        ),
      ),
      [silver],
    );
  });

  testWidgets('same Result route retains colors and a new State starts empty', (
    tester,
  ) async {
    await _showResult(tester, SeasonKey.Winter);
    await _tap(tester, _compactTile(0, 0));
    final shirt = _mannequin(tester).shirtColor;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(_mannequin(tester).shirtColor, shirt);
    await _showResult(tester, SeasonKey.Winter);
    expect(_mannequin(tester).shirtColor, isNull);
    expect(_mannequin(tester).pantsColor, isNull);
    await _tap(tester, find.text('Beauty & Jewelry'));
    expect(_beautyColors(_beauty(tester)).values, everyElement(isNull));
  });

  for (final width in [320.0, 360.0, 430.0]) {
    final height = switch (width) {
      320.0 => 568.0,
      360.0 => 640.0,
      _ => 932.0,
    };
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'all seasons remain usable at width $width and scale $scale',
        (tester) async {
          for (final season in SeasonKey.values) {
            await _showResult(
              tester,
              season,
              size: Size(width, height),
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            await _tap(tester, _compactTile(0, 0));
            await _tap(tester, find.text('Beauty & Jewelry'));
            for (final label in ['Hair', 'Eyes', 'Blush', 'Lips', 'Jewelry']) {
              await _tap(tester, find.text(label));
              await _tapBeauty(tester, 0);
              expect(tester.takeException(), isNull);
            }
            await _tap(tester, find.text('Night Event'));
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
