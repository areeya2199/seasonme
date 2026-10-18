import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/season_palette.dart';
import 'history_save_task.dart';
import 'image_storage_service.dart';

/// Authenticated photo reads, replaceable for offline UI tests.
abstract class HistoryPhotoAccess {
  String? get currentUid;
  Stream<String?> get accountChanges;
  Future<Uint8List?> load(AnalysisHistoryEntry entry);
  Future<bool> retry(AnalysisHistoryEntry entry);
}

class FirebaseHistoryPhotoAccess implements HistoryPhotoAccess {
  @override
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;
  @override
  Stream<String?> get accountChanges =>
      FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  @override
  Future<Uint8List?> load(AnalysisHistoryEntry entry) =>
      AnalysisHistoryService.loadEntryPhoto(entry);
  @override
  Future<bool> retry(AnalysisHistoryEntry entry) =>
      AnalysisHistoryService.retryPhoto(entry);
}

class AnalysisHistoryEntry {
  final String id;
  final SeasonKey season;
  final DateTime analyzedAt;
  final Map<String, dynamic> analysis;
  final String? localImageKey;
  final String? storagePath;
  final String? photoStatus;
  final String? ownerUid;

  const AnalysisHistoryEntry({
    required this.id,
    required this.season,
    required this.analyzedAt,
    required this.analysis,
    this.localImageKey,
    this.storagePath,
    this.photoStatus,
    this.ownerUid,
  });

  static AnalysisHistoryEntry fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    String? ownerUid,
  }) {
    final json = document.data();
    final timestamp = json['analyzedAt'];
    final localImageKey = json['localImageKey'];
    final seasonName = json['season'];
    final photo = json['photo'];
    final rawPath = photo is Map ? photo['storagePath'] : null;
    final storagePath =
        ownerUid != null &&
            rawPath == ImageStorageService.pathFor(ownerUid, document.id)
        ? rawPath as String
        : null;
    final normalizedSeason = seasonName is String
        ? seasonName.trim().toLowerCase()
        : null;
    return AnalysisHistoryEntry(
      id: document.id,
      season: SeasonKey.values.firstWhere(
        (s) => s.name.toLowerCase() == normalizedSeason,
        orElse: () => throw FormatException(
          'Invalid season in analysis history entry ${document.id}',
        ),
      ),
      analyzedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      analysis: json,
      ownerUid: ownerUid,
      storagePath: storagePath,
      photoStatus: photo is Map && photo['status'] is String
          ? photo['status'] as String
          : null,
      // A photo reference must belong to this history entry.
      localImageKey:
          localImageKey is String &&
              localImageKey.startsWith('analysis_${document.id}.')
          ? localImageKey
          : null,
    );
  }
}

class AnalysisHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, Future<bool>> _photoRetries = {};
  static final Set<String> _busyEntries = {};

  static void _acquire(String uid, String id) {
    _checkUser(uid);
    if (!_busyEntries.add('$uid/$id')) {
      throw StateError('Wait for the current history operation to finish');
    }
  }

  static User? get _user => FirebaseAuth.instance.currentUser;

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final user = _user;
    if (user == null) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('analysisHistory');
  }

  static Future<List<AnalysisHistoryEntry>> getAll() async {
    final uid = _user?.uid;
    final collection = _collection;
    if (collection == null || uid == null) {
      throw StateError('Sign in before loading analysis history');
    }

    final snapshot = await collection
        .orderBy('analyzedAt', descending: true)
        .get();
    _checkUser(uid);
    return snapshot.docs
        .map((doc) => AnalysisHistoryEntry.fromFirestore(doc, ownerUid: uid))
        .toList();
  }

  // Only Home's outfit action needs server confirmation. Other history reads
  // keep Firestore's normal server/cache behavior.
  static Future<AnalysisHistoryEntry?> getLatestFromServer() async {
    final uid = _user?.uid;
    final collection = _collection;
    if (collection == null || uid == null) {
      throw StateError('Sign in before loading analysis history');
    }
    final snapshot = await collection
        .orderBy('analyzedAt', descending: true)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    _checkUser(uid);
    return snapshot.docs.isEmpty
        ? null
        : AnalysisHistoryEntry.fromFirestore(
            snapshot.docs.first,
            ownerUid: uid,
          );
  }

  static void _checkUser(String uid) {
    if (_user?.uid != uid) {
      throw StateError('The signed-in account changed while loading history');
    }
  }

  static HistorySaveTask createSaveTask({
    required SeasonKey season,
    required Map<String, dynamic> analysis,
    required Map<String, String?> questionnaireAnswers,
    String? imagePath,
  }) {
    final collection = _collection;
    final user = _user;
    if (collection == null || user == null) {
      throw StateError('Sign in before saving analysis history');
    }

    final document = collection.doc();
    final analyzedAt = Timestamp.fromDate(DateTime.now());
    final extension =
        RegExp(
          r'\.([a-zA-Z0-9]{1,10})$',
        ).firstMatch(imagePath ?? '')?.group(1)?.toLowerCase() ??
        'img';
    final localImageKey = imagePath == null
        ? null
        : 'analysis_${document.id}.$extension';
    final path = ImageStorageService.pathFor(user.uid, document.id);

    final questionnaire = Map<String, dynamic>.from(
      analysis['questionnaire'] as Map? ?? const {},
    );
    return HistorySaveTask(
      id: document.id,
      onStart: () => _acquire(user.uid, document.id),
      onFinish: () => _busyEntries.remove('${user.uid}/${document.id}'),
      checkOwner: () => _checkUser(user.uid),
      saveAnalysis: () async {
        // Keep a durable retry source, but never discard the result if copying fails.
        if (imagePath != null && localImageKey != null && !kIsWeb) {
          try {
            final source = File(imagePath);
            if (await source.length() > _maxImageBytes) {
              throw StateError('Photo too large');
            }
            final destination = await _photoFile(user.uid, localImageKey);
            _checkUser(user.uid);
            await destination.parent.create(recursive: true);
            await source.copy(destination.path);
          } catch (_) {
            // The original path can still be retried while this result is open.
          }
        }
        _checkUser(user.uid);
        await document.set({
          'season': season.name,
          'undertone': analysis['undertone'],
          'questionnaireAnswers': questionnaireAnswers,
          'warm_score': analysis['warm_score'],
          'cool_score': analysis['cool_score'],
          'warm_question': questionnaire['warm'],
          'cool_question': questionnaire['cool'],
          'warm_total': analysis['warm_total'] ?? analysis['warm_score'],
          'cool_total': analysis['cool_total'] ?? analysis['cool_score'],
          'hue_angle': analysis['hue_angle'],
          'rgb': analysis['rgb'],
          'hsv': analysis['hsv'],
          'lab': analysis['lab'],
          'lightness_group': analysis['lightness_group'],
          'chroma_group': analysis['chroma_group'],
          'analyzedAt': analyzedAt,
          if (localImageKey != null) 'localImageKey': localImageKey,
          'schemaVersion': 2,
          'photo': {
            'storagePath': path,
            'status': imagePath == null ? 'missing' : 'pending',
            'updatedAt': FieldValue.serverTimestamp(),
          },
        });
      },
      uploadPhoto: () async {
        if (imagePath == null) return;
        Uint8List? bytes;
        if (localImageKey != null) bytes = await loadPhoto(localImageKey);
        _checkUser(user.uid);
        if (bytes == null) {
          final source = File(imagePath);
          if (await source.length() > _maxImageBytes) {
            throw StateError('Photo too large');
          }
          bytes = await source.readAsBytes();
        }
        _checkUser(user.uid);
        await ImageStorageService.firebase().upload(
          user.uid,
          document.id,
          bytes,
        );
      },
      markReady: () async {
        _checkUser(user.uid);
        await document.update({
          'photo.status': imagePath == null ? 'missing' : 'ready',
          'photo.updatedAt': FieldValue.serverTimestamp(),
          'photo.errorCode': FieldValue.delete(),
        });
      },
      markFailed: () async {
        _checkUser(user.uid);
        await document.update({
          'photo.status': 'failed',
          'photo.errorCode': 'photo-save-incomplete',
          'photo.updatedAt': FieldValue.serverTimestamp(),
        });
      },
    );
  }

  static const int _maxImageBytes = 20 * 1024 * 1024;

  static Future<File> _photoFile(String uid, String localImageKey) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(uid) ||
        !RegExp(
          r'^analysis_[a-zA-Z0-9_-]+\.[a-zA-Z0-9]{1,10}$',
        ).hasMatch(localImageKey)) {
      throw ArgumentError('Invalid local analysis photo reference');
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/analysis_photos/$uid/$localImageKey');
  }

  static Future<Uint8List?> loadPhoto(String localImageKey) async {
    if (kIsWeb) return null;
    try {
      final user = _user;
      if (user == null) return null;
      final photo = await _photoFile(user.uid, localImageKey);
      if (!await photo.exists() || await photo.length() > _maxImageBytes) {
        return null;
      }
      final bytes = await photo.readAsBytes();
      return _user?.uid == user.uid ? bytes : null;
    } catch (error) {
      debugPrint('Local analysis photo load failed: $error');
      return null;
    }
  }

  static Future<void> remove(String historyId) async {
    final uid = _user?.uid;
    if (uid == null) throw StateError('Sign in before deleting history');
    _acquire(uid, historyId);
    try {
      await _remove(historyId);
    } finally {
      _busyEntries.remove('$uid/$historyId');
    }
  }

  static Future<void> _remove(String historyId) async {
    final collection = _collection;
    final user = _user;
    if (collection == null || user == null) {
      throw StateError('Sign in before deleting history');
    }
    if (_photoRetries.containsKey('${user.uid}/$historyId')) {
      throw StateError('Wait for the photo retry to finish');
    }
    final document = collection.doc(historyId);
    final snapshot = await document.get();
    _checkUser(user.uid);
    final data = snapshot.data();
    final photoData = data?['photo'];
    if (data?['schemaVersion'] == 2 &&
        photoData is Map &&
        photoData['storagePath'] is String) {
      await document.update({'deletionStatus': 'pending'});
      _checkUser(user.uid);
      await ImageStorageService.firebase().delete(
        user.uid,
        historyId,
        photoData['storagePath'] as String,
      );
      _checkUser(user.uid);
    }
    final localImageKey = snapshot.data()?['localImageKey'];
    if (!kIsWeb && localImageKey is String) {
      if (!localImageKey.startsWith('analysis_$historyId.')) {
        throw StateError('Invalid local analysis photo reference');
      }
      // Preserve local files until cloud and metadata deletion both succeed.
    }
    _checkUser(user.uid);
    await document.delete();
  }

  /// Reads cloud first; a local fallback does not mark a failed upload as ready.
  static Future<Uint8List?> loadEntryPhoto(AnalysisHistoryEntry entry) async {
    final uid = _user?.uid;
    if (uid == null || entry.ownerUid != uid) {
      throw StateError('Account changed');
    }
    if (entry.storagePath != null) {
      try {
        final bytes = await ImageStorageService.firebase().download(
          uid,
          entry.id,
          entry.storagePath!,
        );
        _checkUser(uid);
        return bytes;
      } catch (_) {
        _checkUser(uid);
        final local = entry.localImageKey == null
            ? null
            : await loadPhoto(entry.localImageKey!);
        _checkUser(uid);
        if (local != null) return local;
        rethrow;
      }
    }
    final local = entry.localImageKey == null
        ? null
        : await loadPhoto(entry.localImageKey!);
    _checkUser(uid);
    return local;
  }

  static Future<bool> retryPhoto(AnalysisHistoryEntry entry) {
    final uid = _user?.uid;
    if (uid == null || entry.ownerUid != uid) {
      throw StateError('Account changed');
    }
    final key = '$uid/${entry.id}';
    return _photoRetries.putIfAbsent(
      key,
      () =>
          _retryPhoto(entry, uid).whenComplete(() => _photoRetries.remove(key)),
    );
  }

  static Future<bool> _retryPhoto(
    AnalysisHistoryEntry entry,
    String uid,
  ) async {
    _acquire(uid, entry.id);
    try {
      return await _retryPhotoUnlocked(entry, uid);
    } finally {
      _busyEntries.remove('$uid/${entry.id}');
    }
  }

  static Future<bool> _retryPhotoUnlocked(
    AnalysisHistoryEntry entry,
    String uid,
  ) async {
    final document = _firestore
        .collection('users')
        .doc(uid)
        .collection('analysisHistory')
        .doc(entry.id);
    final snapshot = await document.get(
      const GetOptions(source: Source.server),
    );
    _checkUser(uid);
    final data = snapshot.data();
    // Retrying is deliberately limited to newly-created cloud records.
    if (data?['schemaVersion'] != 2 || data?['deletionStatus'] == 'pending') {
      throw StateError('This entry is not eligible for photo upload retry');
    }
    final path = ImageStorageService.pathFor(uid, entry.id);
    final photo = data?['photo'];
    if (photo is! Map || photo['storagePath'] != path) {
      throw StateError('Invalid photo reference');
    }
    final storage = ImageStorageService.firebase();
    try {
      // Recover an upload that succeeded before its Firestore update failed.
      await storage.download(uid, entry.id, path);
    } catch (_) {
      _checkUser(uid);
      final key = data?['localImageKey'];
      if (key is! String || !key.startsWith('analysis_${entry.id}.')) {
        throw StateError('No retry source on this device');
      }
      final bytes = await loadPhoto(key);
      _checkUser(uid);
      if (bytes == null) throw StateError('No retry source on this device');
      await storage.upload(uid, entry.id, bytes);
    }
    _checkUser(uid);
    await document.update({
      'photo.status': 'ready',
      'photo.updatedAt': FieldValue.serverTimestamp(),
      'photo.errorCode': FieldValue.delete(),
    });
    _checkUser(uid);
    return true;
  }
}
