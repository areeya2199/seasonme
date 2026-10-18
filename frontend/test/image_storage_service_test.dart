import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/image_storage_service.dart';

class MemoryStorage implements ImageStorageGateway {
  final files = <String, Uint8List>{};
  String? mime;
  bool failUpload = false;
  void Function()? afterDownload;
  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    if (failUpload) throw StateError('offline');
    files[path] = bytes;
    mime = contentType;
  }

  @override
  Future<Uint8List?> download(String path, int maxBytes) async {
    afterDownload?.call();
    return files[path];
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }
}

void main() {
  late MemoryStorage gateway;
  late ImageStorageService service;
  String? uid;
  final photo = Uint8List.fromList([255, 216, 255, 1]);
  setUp(() {
    uid = 'alice';
    gateway = MemoryStorage();
    service = ImageStorageService(gateway: gateway, currentUid: () => uid);
  });
  test(
    'retry overwrites the same owner/history path and preserves MIME',
    () async {
      gateway.failUpload = true;
      await expectLater(
        service.upload('alice', 'entry1', photo),
        throwsStateError,
      );
      gateway.failUpload = false;
      final path = await service.upload('alice', 'entry1', photo);
      await service.upload('alice', 'entry1', photo);
      expect(gateway.files.length, 1);
      expect(gateway.mime, 'image/jpeg');
      expect(await service.download('alice', 'entry1', path), photo);
    },
  );
  test(
    'rejects other owners, other entries and traversal before transport',
    () async {
      await expectLater(
        service.upload('bob', 'entry1', photo),
        throwsStateError,
      );
      await expectLater(
        service.download(
          'alice',
          'entry1',
          ImageStorageService.pathFor('alice', 'entry2'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ImageStorageService.pathFor('alice', '../entry'),
        throwsArgumentError,
      );
      expect(gateway.files, isEmpty);
    },
  );
  test(
    'does not return bytes when the account changes during download',
    () async {
      final path = await service.upload('alice', 'entry1', photo);
      gateway.afterDownload = () => uid = 'bob';
      await expectLater(
        service.download('alice', 'entry1', path),
        throwsStateError,
      );
    },
  );
  test('rejects empty, oversized and unsupported uploads', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List(ImageStorageService.maxImageBytes + 1),
      Uint8List(8),
    ]) {
      await expectLater(
        service.upload('alice', 'entry1', bytes),
        throwsArgumentError,
      );
    }
    expect(gateway.files, isEmpty);
  });
}
