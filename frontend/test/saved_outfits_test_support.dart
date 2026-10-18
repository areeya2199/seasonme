import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/models/saved_outfit.dart';
import 'package:frontend/services/image_storage_service.dart';
import 'package:frontend/services/saved_outfits_service.dart';
import 'package:frontend/utils/color_utils.dart';
import 'package:image/image.dart' as img;

const sampleMatch = OutfitMatchSnapshot(
  season: SeasonKey.Winter,
  matchPercent: 82,
  matchLevel: MatchLevel.excellent,
  sampledColorArgb: 0xff30455f,
  closestName: 'Navy',
  closestArgb: 0xff30455f,
  closestCategory: 'Clothing',
);

Uint8List samplePhoto() => Uint8List.fromList(
  img.encodePng(img.Image(width: 4, height: 4)..setPixelRgb(0, 0, 48, 69, 95)),
);

class OutfitMemoryStorage implements ImageStorageGateway {
  final files = <String, Uint8List>{};
  int uploads = 0;
  int downloads = 0;
  int deletes = 0;
  bool failUpload = false;
  bool failDownload = false;
  bool failDelete = false;
  void Function()? afterUpload;
  void Function()? afterDownload;
  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    uploads++;
    if (failUpload) throw StateError('upload failed');
    files[path] = Uint8List.fromList(bytes);
    afterUpload?.call();
  }

  @override
  Future<Uint8List?> download(String path, int maxBytes) async {
    downloads++;
    if (failDownload) throw StateError('download failed');
    final bytes = files[path];
    afterDownload?.call();
    return bytes;
  }

  @override
  Future<void> delete(String path) async {
    deletes++;
    if (failDelete) throw StateError('delete failed');
    files.remove(path);
  }
}

class OutfitMemoryDocuments implements SavedOutfitsGateway {
  final docs = <String, Map<String, dynamic>>{};
  int puts = 0;
  int lists = 0;
  bool failPut = false;
  bool failAfterPut = false;
  bool failList = false;
  bool failFinishDelete = false;
  bool failAfterFinishDelete = false;
  void Function()? afterMarkDeleting;
  Future<void> Function()? beforeGet;
  Future<void> Function()? beforeList;
  @override
  Future<Map<String, Map<String, dynamic>>> list(String uid) async {
    lists++;
    await beforeList?.call();
    if (failList) throw StateError('list failed');
    return {
      for (final e in docs.entries)
        if (e.key.startsWith('$uid/'))
          e.key.substring(uid.length + 1): Map.of(e.value),
    };
  }

  @override
  Future<Map<String, dynamic>?> get(String uid, String id) async {
    await beforeGet?.call();
    return docs['$uid/$id'] == null ? null : Map.of(docs['$uid/$id']!);
  }

  @override
  Future<bool> putReady(
    String uid,
    String id,
    Map<String, dynamic> data, {
    bool requireExisting = false,
  }) async {
    puts++;
    if (failPut) throw StateError('metadata failed');
    final old = docs['$uid/$id'];
    if (old == null && requireExisting) {
      throw StateError('deleted while saving');
    }
    if (old != null && old['status'] != 'ready') {
      throw StateError('deleting');
    }
    docs.putIfAbsent(
      '$uid/$id',
      () => {
        ...data,
        'savedAt': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
      },
    );
    if (failAfterPut) throw StateError('commit outcome unknown');
    return old == null;
  }

  @override
  Future<void> markDeleting(String uid, String id, String path) async {
    final old = docs['$uid/$id'];
    if (old == null) return;
    if (old['storagePath'] != path) throw StateError('invalid path');
    old['status'] = 'deleting';
    afterMarkDeleting?.call();
  }

  @override
  Future<void> finishDelete(String uid, String id, String path) async {
    if (failFinishDelete) throw StateError('metadata delete failed');
    final old = docs['$uid/$id'];
    if (old != null &&
        (old['status'] != 'deleting' || old['storagePath'] != path)) {
      throw StateError('invalid deletion');
    }
    docs.remove('$uid/$id');
    if (failAfterFinishDelete) throw StateError('delete outcome unknown');
  }
}

class OutfitTestEnvironment {
  String? uid = 'alice';
  final accounts = StreamController<String?>.broadcast(sync: true);
  final storage = OutfitMemoryStorage();
  final documents = OutfitMemoryDocuments();
  late final images = ImageStorageService(
    gateway: storage,
    currentUid: () => uid,
  );
  late final service = SavedOutfitsService(
    gateway: documents,
    images: images,
    uidProvider: () => uid,
    accountChanges: accounts.stream,
  );
  void switchTo(String? value) {
    uid = value;
    accounts.add(value);
  }

  Future<void> dispose() async {
    await service.dispose();
    await accounts.close();
  }
}
