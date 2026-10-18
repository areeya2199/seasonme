import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/saved_outfit.dart';
import 'image_storage_service.dart';

/// All reads and writes in the Firebase adapter are server-confirmed.
abstract class SavedOutfitsGateway {
  Future<Map<String, Map<String, dynamic>>> list(String uid);
  Future<Map<String, dynamic>?> get(String uid, String id);

  /// Returns true only when this transaction creates the document.
  Future<bool> putReady(
    String uid,
    String id,
    Map<String, dynamic> data, {
    bool requireExisting = false,
  });
  Future<void> markDeleting(String uid, String id, String path);
  Future<void> finishDelete(String uid, String id, String path);
}

class FirebaseSavedOutfitsGateway implements SavedOutfitsGateway {
  final FirebaseFirestore firestore;
  FirebaseSavedOutfitsGateway(this.firestore);
  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      firestore.collection('users').doc(uid).collection('savedOutfits');

  @override
  Future<Map<String, Map<String, dynamic>>> list(String uid) async {
    // Fetch documents without orderBy so malformed records missing savedAt
    // can be reported, rather than silently excluded by the query.
    final result = await _collection(
      uid,
    ).get(const GetOptions(source: Source.server));
    return {for (final doc in result.docs) doc.id: doc.data()};
  }

  @override
  Future<Map<String, dynamic>?> get(String uid, String id) async =>
      (await _collection(
        uid,
      ).doc(id).get(const GetOptions(source: Source.server))).data();

  @override
  Future<bool> putReady(
    String uid,
    String id,
    Map<String, dynamic> data, {
    bool requireExisting = false,
  }) async {
    final doc = _collection(uid).doc(id);
    return firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(doc);
      if (existing.exists) {
        final entry = SavedOutfit.fromMap(uid, id, existing.data()!);
        if (entry.status != 'ready' ||
            entry.imageHash != data['imageHash'] ||
            entry.match.season.name != data['season']) {
          throw StateError('This outfit changed. Reopen Saved Outfits.');
        }
        // Keep the first confirmed result and timestamp on duplicate saves.
        return false;
      }
      if (requireExisting) {
        throw StateError(
          'This outfit was deleted while saving. Please select the photo again.',
        );
      }
      transaction.set(doc, {...data, 'savedAt': FieldValue.serverTimestamp()});
      return true;
    });
  }

  @override
  Future<void> markDeleting(String uid, String id, String path) async {
    final doc = _collection(uid).doc(id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      if (!existing.exists) return;
      if (existing.data()!['storagePath'] != path) {
        throw StateError('Invalid saved photo reference');
      }
      transaction.update(doc, {'status': 'deleting'});
    });
  }

  @override
  Future<void> finishDelete(String uid, String id, String path) async {
    final doc = _collection(uid).doc(id);
    await firestore.runTransaction((transaction) async {
      final existing = await transaction.get(doc);
      if (!existing.exists) return;
      if (existing.data()!['storagePath'] != path ||
          existing.data()!['status'] != 'deleting') {
        throw StateError('This outfit changed. Retry deletion.');
      }
      transaction.delete(doc);
    });
  }
}

abstract class SavedOutfitsAccess {
  String? get currentUid;
  Stream<String?> get accountChanges;
  Future<SavedOutfitList> list();
  Future<Uint8List> photo(SavedOutfit entry);
  Future<void> remove(SavedOutfit entry);
}

class SavedOutfitsService implements SavedOutfitsAccess {
  final SavedOutfitsGateway gateway;
  final ImageStorageService images;
  final String? Function() uidProvider;
  @override
  final Stream<String?> accountChanges;
  late final StreamSubscription<String?> _subscription;
  String? _observedUid;
  int _session = 0;
  final _busy = <String>{};
  final _saves = <String, Future<SavedOutfit>>{};
  static SavedOutfitsService? _firebase;

  SavedOutfitsService({
    required this.gateway,
    required this.images,
    required this.uidProvider,
    required this.accountChanges,
  }) {
    _observedUid = currentUid;
    _subscription = accountChanges.listen((uid) {
      if (uid != _observedUid) {
        _observedUid = uid;
        _session++;
      }
    });
  }

  factory SavedOutfitsService.firebase() => _firebase ??= SavedOutfitsService(
    gateway: FirebaseSavedOutfitsGateway(FirebaseFirestore.instance),
    images: ImageStorageService.firebase(),
    uidProvider: () => FirebaseAuth.instance.currentUser?.uid,
    accountChanges: FirebaseAuth.instance
        .authStateChanges()
        .map((u) => u?.uid)
        .asBroadcastStream(),
  );

  @override
  String? get currentUid => uidProvider();
  int get sessionVersion => _session;

  void _check(String uid, int session) {
    if (currentUid != uid || _session != session) {
      throw StateError('Your account changed. Please reopen this screen.');
    }
  }

  String _owner() {
    final uid = currentUid;
    if (uid == null) throw StateError('Please sign in to save outfits.');
    return uid;
  }

  OutfitSaveTask createSaveTask(
    OutfitMatchSnapshot match,
    Uint8List source, {
    String? note,
  }) {
    match.validate();
    final normalizedNote = SavedOutfit.normalizeNote(note);
    if (source.isEmpty || source.length > ImageStorageService.maxImageBytes) {
      throw ArgumentError('Use a photo between 1 byte and 20 MiB');
    }
    ImageStorageService.contentType(source);
    final uid = _owner();
    final bytes = Uint8List.fromList(source);
    final hash = sha256.convert(bytes).toString();
    final id = sha256
        .convert(utf8.encode('$hash|${match.season.name}|1'))
        .toString();
    return OutfitSaveTask._(
      this,
      uid,
      _session,
      id,
      hash,
      match,
      bytes,
      normalizedNote,
    );
  }

  Future<SavedOutfit> _save(OutfitSaveTask task) {
    _check(task.ownerUid, task.session);
    final key = '${task.ownerUid}/${task.id}';
    if (_saves.containsKey(key)) {
      task._wasAlreadySaved = true;
      return _saves[key]!;
    }
    if (!_busy.add(key)) {
      throw StateError('Wait for this outfit operation to finish.');
    }
    final future = _saveUnlocked(task).whenComplete(() {
      _busy.remove(key);
      _saves.remove(key);
    });
    _saves[key] = future;
    return future;
  }

  Future<SavedOutfit> _saveUnlocked(OutfitSaveTask task) async {
    void check() => _check(task.ownerUid, task.session);
    final uid = task.ownerUid, id = task.id;
    final path = ImageStorageService.savedOutfitPathFor(uid, id);
    check();
    final existing = await gateway.get(uid, id);
    check();
    if (existing == null && task._observedReady) {
      throw StateError(
        'This outfit was deleted. Please select the photo again.',
      );
    }
    if (existing != null &&
        SavedOutfit.fromMap(uid, id, existing).status != 'ready') {
      throw StateError(
        'Deletion is incomplete. Finish deleting this outfit first.',
      );
    }
    // Recheck on every retry: another screen/device may have deleted a
    // previously uploaded object after an ambiguous metadata failure.
    {
      final prior = await images.findOutfitPhoto(uid, id, path);
      check();
      if (prior == null) {
        await images.uploadOutfit(uid, id, task._bytes);
      } else if (sha256.convert(prior).toString() != task.imageHash) {
        throw StateError('Saved photo does not match this outfit.');
      }
      check();
    }
    // Never compensate by deleting the photo on a failed/ambiguous commit.
    // Retrying observes the server document and reuses this exact object.
    final created = await gateway.putReady(uid, id, {
      ...task.match.toMap(),
      'schemaVersion': 1,
      'matchAlgorithmVersion': 1,
      'imageHash': task.imageHash,
      'storagePath': path,
      'status': 'ready',
      if (task.note != null) 'note': task.note,
    }, requireExisting: existing != null);
    task._wasAlreadySaved = !created;
    check();
    final confirmed = await gateway.get(uid, id);
    check();
    if (confirmed == null) {
      throw StateError('Could not confirm the saved outfit. Retry.');
    }
    final entry = SavedOutfit.fromMap(uid, id, confirmed);
    if (entry.status != 'ready' || entry.imageHash != task.imageHash) {
      throw StateError('The outfit changed while saving. Please retry.');
    }
    task._observedReady = true;
    return entry;
  }

  @override
  Future<SavedOutfitList> list() async {
    final uid = _owner(), session = _session;
    final documents = await gateway.list(uid);
    _check(uid, session);
    final entries = <SavedOutfit>[];
    var invalid = 0;
    for (final doc in documents.entries) {
      try {
        entries.add(SavedOutfit.fromMap(uid, doc.key, doc.value));
      } on FormatException {
        invalid++;
      } on ArgumentError {
        invalid++;
      }
    }
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return SavedOutfitList(List.unmodifiable(entries), invalidCount: invalid);
  }

  @override
  Future<Uint8List> photo(SavedOutfit entry) async {
    final session = _session;
    _check(entry.ownerUid, session);
    final bytes = await images.findOutfitPhoto(
      entry.ownerUid,
      entry.id,
      entry.storagePath,
    );
    _check(entry.ownerUid, session);
    if (bytes == null) {
      throw StateError('Photo is missing. You can remove this outfit.');
    }
    if (sha256.convert(bytes).toString() != entry.imageHash) {
      throw StateError('Saved photo is invalid.');
    }
    return bytes;
  }

  @override
  Future<void> remove(SavedOutfit entry) async {
    final session = _session;
    void check() => _check(entry.ownerUid, session);
    check();
    if (entry.storagePath !=
        ImageStorageService.savedOutfitPathFor(entry.ownerUid, entry.id)) {
      throw ArgumentError('Invalid saved photo reference');
    }
    final key = '${entry.ownerUid}/${entry.id}';
    if (!_busy.add(key)) {
      throw StateError('Wait for this outfit operation to finish.');
    }
    try {
      await gateway.markDeleting(entry.ownerUid, entry.id, entry.storagePath);
      check();
      await images.deleteOutfit(entry.ownerUid, entry.id, entry.storagePath);
      check();
      await gateway.finishDelete(entry.ownerUid, entry.id, entry.storagePath);
      check();
      if (await gateway.get(entry.ownerUid, entry.id) != null) {
        throw StateError('Could not confirm deletion. Please retry.');
      }
      check();
    } finally {
      _busy.remove(key);
    }
  }

  @visibleForTesting
  Future<void> dispose() => _subscription.cancel();
}

class OutfitSaveTask {
  final SavedOutfitsService _service;
  final String ownerUid;
  final int session;
  final String id;
  final String imageHash;
  final OutfitMatchSnapshot match;
  final Uint8List _bytes;
  final String? note;
  bool _wasAlreadySaved = false;
  bool get wasAlreadySaved => _wasAlreadySaved;
  bool _observedReady = false;
  OutfitSaveTask._(
    this._service,
    this.ownerUid,
    this.session,
    this.id,
    this.imageHash,
    this.match,
    this._bytes,
    this.note,
  );
  Future<SavedOutfit> save() => Future.sync(() => _service._save(this));
}

String outfitErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthorized' =>
        'ไม่ได้รับสิทธิ์เข้าถึง Saved Outfits กรุณาตรวจ Rules หรือเข้าสู่ระบบอีกครั้ง',
      'unauthenticated' => 'กรุณาเข้าสู่ระบบอีกครั้ง',
      'unavailable' || 'network-request-failed' || 'retry-limit-exceeded' =>
        'เชื่อมต่อไม่ได้ กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่',
      'object-not-found' => 'ไม่พบรูปเสื้อผ้านี้ คุณยังลบรายการได้',
      _ => 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่',
    };
  }
  if (error is StateError ||
      error is ArgumentError ||
      error is FormatException) {
    return error.toString().replaceFirst(RegExp(r'^[^:]+: '), '');
  }
  return 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่';
}
