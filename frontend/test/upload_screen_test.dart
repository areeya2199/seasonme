import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/questionnaire_screen.dart';
import 'package:frontend/screens/upload_screen.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const picker = MethodChannel('plugins.flutter.io/image_picker');
  const detector = MethodChannel('google_mlkit_face_detector');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(picker, null);
    messenger.setMockMethodCallHandler(detector, null);
  });

  testWidgets('cancelled gallery selection leaves Continue disabled', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(picker, (_) async => null);
    messenger.setMockMethodCallHandler(detector, (_) async => null);
    await tester.pumpWidget(const MaterialApp(home: UploadPhotoScreen()));
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(find.byType(QuestionnaireScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery failure is reported without navigating', (tester) async {
    messenger.setMockMethodCallHandler(picker, (_) async {
      throw PlatformException(code: 'photo_access_denied');
    });
    messenger.setMockMethodCallHandler(detector, (_) async => null);
    await tester.pumpWidget(const MaterialApp(home: UploadPhotoScreen()));
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not choose a photo. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(QuestionnaireScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final orientation in [1, 3, 6, 8]) {
    testWidgets(
      'EXIF $orientation keeps original JPEG bytes and navigation path',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'seasonme-upload-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final image = img.Image(width: 120, height: 200);
        img.fill(image, color: img.ColorRgb8(128, 128, 128));
        img.fillRect(
          image,
          x1: 0,
          y1: 0,
          x2: 29,
          y2: 49,
          color: img.ColorRgb8(170, 120, 110),
        );
        image.exif.imageIfd.orientation = orientation;
        final bytes = img.encodeJpg(image);
        final file = File('${directory.path}/oriented.jpg')
          ..writeAsBytesSync(bytes);
        final decoded = img.decodeJpg(bytes)!;
        final encodedSize = img.JpegDecoder().startDecode(bytes)!;
        expect(encodedSize.width, 120);
        expect(encodedSize.height, 200);
        // This image package version already applies EXIF during JPEG decode.
        final upright = img.bakeOrientation(decoded);
        final rotated = orientation == 6 || orientation == 8;
        expect(upright.width, rotated ? 200 : 120);
        expect(upright.height, rotated ? 120 : 200);
        Map<dynamic, dynamic>? detectorInput;
        messenger.setMockMethodCallHandler(picker, (_) async => file.path);
        messenger.setMockMethodCallHandler(detector, (call) async {
          if (call.method != 'vision#startFaceDetector') return null;
          final arguments = call.arguments as Map;
          detectorInput = arguments['imageData'] as Map;
          expect((arguments['options'] as Map)['mode'], 'fast');
          final width = upright.width.toDouble();
          final centerY = upright.height * .42;
          return [
            {
              'rect': {
                'left': width * .275,
                'right': width * .725,
                'top': centerY - 30,
                'bottom': centerY + 30,
              },
              'landmarks': <String, dynamic>{},
            },
          ];
        });
        await tester.pumpWidget(const MaterialApp(home: UploadPhotoScreen()));
        await tester.runAsync(() async {
          await tester.tap(find.text('Choose from Gallery'));
          for (
            var attempt = 0;
            attempt < 100 && detectorInput == null;
            attempt++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pumpAndSettle();
        expect(detectorInput?['path'], file.path);
        expect(file.readAsBytesSync(), bytes);
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<QuestionnaireScreen>(find.byType(QuestionnaireScreen))
              .imagePath,
          file.path,
        );
        expect(file.readAsBytesSync(), bytes);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
