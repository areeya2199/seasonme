import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/analysis_input.dart';
import 'package:frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File photo;
  late List<int> originalBytes;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('seasonme-api-photo-');
    final image = img.Image(width: 20, height: 30);
    image.exif.imageIfd.orientation = 6;
    originalBytes = img.encodeJpg(image);
    photo = File('${directory.path}/gallery.jpg')
      ..writeAsBytesSync(originalBytes);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  for (final source in ['gallery', 'camera']) {
    test(
      '$source photo bytes, auth and canonical answers reach multipart unchanged',
      () async {
        final sourcePhoto = File('${directory.path}/$source.jpg')
          ..writeAsBytesSync(originalBytes);
        final answers = <int, String?>{
          0: null,
          1: 'Silver',
          2: null,
          3: 'Bright',
        };
        var requests = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.path, '/analyze');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(request.bodyBytes);
          expect(body, contains('name="file"'));
          expect(body, contains('filename="$source.jpg"'));
          expect(body, contains(latin1.decode(originalBytes)));
          expect(body, contains('name="answers"'));
          expect(
            body,
            contains(
              jsonEncode({'0': null, '1': 'Silver', '2': null, '3': 'Bright'}),
            ),
          );
          return http.Response(
            jsonEncode({'season': 'Winter', 'undertone': 'Cool'}),
            200,
          );
        });
        addTearDown(client.close);
        final api = ApiService(
          client: client,
          idTokenProvider: () async => 'test-token',
        );
        final pending = api.analyzeImage(sourcePhoto.path, answers);
        answers[3] =
            'Muted'; // Mutating the UI map cannot change an in-flight request.
        expect(await pending, {'season': 'Winter', 'undertone': 'Cool'});
        expect(requests, 1);
        expect(sourcePhoto.readAsBytesSync(), originalBytes);
      },
    );
  }

  test('missing/invalid Q4 is rejected before auth or transport', () async {
    final client = MockClient((_) async => throw StateError('Must not send'));
    addTearDown(client.close);
    final api = ApiService(
      client: client,
      idTokenProvider: () async => throw StateError('Must not authenticate'),
    );
    for (final value in [
      null,
      '',
      'Bright & vivid',
      'Soft & muted',
      'Deep & rich',
      'bright',
    ]) {
      await expectLater(
        api.analyzeImage(photo.path, {3: value}),
        throwsA(isA<AnalysisInputException>()),
      );
    }
  });

  test('missing, empty and corrupt sources cannot be sent', () async {
    final corrupt = File('${directory.path}/corrupt.jpg')
      ..writeAsStringSync('not a photo');
    final client = MockClient((_) async => throw StateError('Must not send'));
    addTearDown(client.close);
    final api = ApiService(
      client: client,
      idTokenProvider: () async => throw StateError('Must not authenticate'),
    );
    for (final path in ['', '${directory.path}/missing.jpg', corrupt.path]) {
      await expectLater(
        api.analyzeImage(path, {3: 'Muted'}),
        throwsA(isA<AnalysisInputException>()),
      );
    }
    await expectLater(
      AnalysisInput.validatePhoto(null),
      throwsA(isA<AnalysisInputException>()),
    );
  });

  test(
    '422 reports invalid answers; other HTTP failures keep existing behavior',
    () async {
      for (final status in [422, 401, 503]) {
        final client = MockClient(
          (_) async => http.Response('{"detail":"rejected"}', status),
        );
        addTearDown(client.close);
        final api = ApiService(
          client: client,
          idTokenProvider: () async => 'test-token',
        );
        final response = api.analyzeImage(photo.path, {3: 'Muted'});
        if (status == 422) {
          await expectLater(response, throwsA(isA<AnalysisInputException>()));
        } else {
          expect(await response, isNull);
        }
      }
      expect(photo.readAsBytesSync(), originalBytes);
    },
  );
}
