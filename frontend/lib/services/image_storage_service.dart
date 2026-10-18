import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// The transport boundary is replaceable in tests; no Firebase app is needed.
abstract class ImageStorageGateway {
  Future<void> upload(String path, Uint8List bytes, String contentType);
  Future<Uint8List?> download(String path, int maxBytes);
  Future<void> delete(String path);
}

class FirebaseImageStorageGateway implements ImageStorageGateway {
  final FirebaseStorage storage;
  FirebaseImageStorageGateway(this.storage);

  @override
  Future<void> upload(String path, Uint8List bytes, String contentType) async {
    await storage
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: contentType));
  }

  @override
  Future<Uint8List?> download(String path, int maxBytes) =>
      storage.ref(path).getData(maxBytes);

  @override
  Future<void> delete(String path) async {
    try {
      await storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}

class ImageStorageService {
  static const maxImageBytes = 20 * 1024 * 1024;
  final ImageStorageGateway gateway;
  final String? Function() currentUid;

  ImageStorageService({required this.gateway, required this.currentUid});

  factory ImageStorageService.firebase() => ImageStorageService(
    gateway: FirebaseImageStorageGateway(FirebaseStorage.instance),
    currentUid: () => FirebaseAuth.instance.currentUser?.uid,
  );

  static String pathFor(String uid, String historyId) {
    final safe = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!safe.hasMatch(uid) || !safe.hasMatch(historyId)) {
      throw ArgumentError('Invalid analysis photo owner or history ID');
    }
    // No extension: the original encoded bytes and MIME type are preserved.
    return 'users/$uid/analysisHistory/$historyId/photo';
  }

  void _check(String uid, String historyId, String path) {
    if (currentUid() != uid) throw StateError('The signed-in account changed');
    if (path != pathFor(uid, historyId)) {
      throw ArgumentError('Photo does not belong to this history entry');
    }
  }

  static String contentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'image/jpeg';
    }
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= 8 &&
        List.generate(8, (i) => bytes[i] == png[i]).every((v) => v)) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw ArgumentError('Unsupported photo encoding; use JPEG, PNG or WebP');
  }

  Future<String> upload(String uid, String historyId, Uint8List bytes) async {
    final path = pathFor(uid, historyId);
    _check(uid, historyId, path);
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw ArgumentError('Invalid analysis photo size');
    }
    final type = contentType(bytes);
    await gateway.upload(path, bytes, type);
    _check(uid, historyId, path);
    return path;
  }

  Future<Uint8List> download(String uid, String historyId, String path) async {
    _check(uid, historyId, path);
    final bytes = await gateway.download(path, maxImageBytes);
    _check(uid, historyId, path);
    if (bytes == null || bytes.isEmpty || bytes.length > maxImageBytes) {
      throw StateError('Analysis photo is unavailable');
    }
    return bytes;
  }

  Future<void> delete(String uid, String historyId, String path) async {
    _check(uid, historyId, path);
    await gateway.delete(path);
    _check(uid, historyId, path);
  }

  // Saved outfits have their own strict namespace; History's API is unchanged.
  static String savedOutfitPathFor(String uid, String outfitId) {
    final safe = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!safe.hasMatch(uid) || !safe.hasMatch(outfitId)) {
      throw ArgumentError('Invalid outfit owner or ID');
    }
    return 'users/$uid/savedOutfits/$outfitId/photo';
  }

  void _checkOutfit(String uid, String id, String path) {
    if (currentUid() != uid) throw StateError('The signed-in account changed');
    if (path != savedOutfitPathFor(uid, id)) {
      throw ArgumentError('Photo does not belong to this saved outfit');
    }
  }

  Future<void> uploadOutfit(String uid, String id, Uint8List bytes) async {
    final path = savedOutfitPathFor(uid, id);
    _checkOutfit(uid, id, path);
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw ArgumentError('Use a photo between 1 byte and 20 MiB');
    }
    await gateway.upload(path, bytes, contentType(bytes));
    _checkOutfit(uid, id, path);
  }

  /// Only a missing object returns null; permissions/network errors propagate.
  Future<Uint8List?> findOutfitPhoto(String uid, String id, String path) async {
    _checkOutfit(uid, id, path);
    Uint8List? bytes;
    try {
      bytes = await gateway.download(path, maxImageBytes);
    } on FirebaseException catch (error) {
      _checkOutfit(uid, id, path);
      if (error.code == 'object-not-found') return null;
      rethrow;
    }
    _checkOutfit(uid, id, path);
    if (bytes == null) return null;
    if (bytes.isEmpty || bytes.length > maxImageBytes) {
      throw StateError('Saved photo is invalid');
    }
    contentType(bytes);
    return bytes;
  }

  Future<void> deleteOutfit(String uid, String id, String path) async {
    _checkOutfit(uid, id, path);
    await gateway.delete(path);
    _checkOutfit(uid, id, path);
  }
}
