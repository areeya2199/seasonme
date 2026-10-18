import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/history_save_task.dart';

void main() {
  test('a rejected operation lock can be retried after release', () async {
    var locked = true;
    final task = HistorySaveTask(
      id: 'same',
      checkOwner: () {},
      onStart: () {
        if (locked) throw StateError('busy');
      },
      saveAnalysis: () async {},
      uploadPhoto: () async {},
      markReady: () async {},
      markFailed: () async {},
    );
    await expectLater(task.save(), throwsStateError);
    locked = false;
    expect(await task.save(), isTrue);
  });
  test('operation guard is released after failure and completion', () async {
    var locked = false;
    var fail = true;
    final task = HistorySaveTask(
      id: 'same',
      checkOwner: () {},
      onStart: () {
        expect(locked, isFalse);
        locked = true;
      },
      onFinish: () => locked = false,
      saveAnalysis: () async {
        if (fail) throw StateError('offline');
      },
      uploadPhoto: () async {},
      markReady: () async {},
      markFailed: () async {},
    );
    await expectLater(task.save(), throwsStateError);
    expect(locked, isFalse);
    fail = false;
    expect(await task.save(), isTrue);
    expect(locked, isFalse);
  });
  test(
    'failed photo preserves analysis; retry does not save another result',
    () async {
      var writes = 0, uploads = 0;
      var fail = true;
      var status = '';
      final task = HistorySaveTask(
        id: 'stable-id',
        checkOwner: () {},
        saveAnalysis: () async {
          writes++;
          status = 'pending';
        },
        uploadPhoto: () async {
          uploads++;
          if (fail) throw StateError('offline');
        },
        markReady: () async {
          status = 'ready';
        },
        markFailed: () async {
          status = 'failed';
        },
      );
      expect(await task.save(), isFalse);
      expect(writes, 1);
      expect(status, 'failed');
      fail = false;
      expect(await task.save(), isTrue);
      expect(await task.save(), isTrue);
      expect(writes, 1);
      expect(uploads, 2);
      expect(status, 'ready');
    },
  );
  test('concurrent saves share one operation', () async {
    final gate = Completer<void>();
    var writes = 0, uploads = 0;
    final task = HistorySaveTask(
      id: 'same',
      checkOwner: () {},
      saveAnalysis: () async {
        writes++;
        await gate.future;
      },
      uploadPhoto: () async {
        uploads++;
      },
      markReady: () async {},
      markFailed: () async {},
    );
    final a = task.save();
    final b = task.save();
    gate.complete();
    expect(await Future.wait([a, b]), [true, true]);
    expect(writes, 1);
    expect(uploads, 1);
  });
  test('metadata failure prevents upload and retry keeps the ID', () async {
    var fail = true, uploads = 0;
    final task = HistorySaveTask(
      id: 'original',
      checkOwner: () {},
      saveAnalysis: () async {
        if (fail) throw StateError('denied');
      },
      uploadPhoto: () async {
        uploads++;
      },
      markReady: () async {},
      markFailed: () async {},
    );
    await expectLater(task.save(), throwsStateError);
    expect(uploads, 0);
    fail = false;
    expect(await task.save(), isTrue);
    expect(task.id, 'original');
  });
  test('metadata completion failure does not upload the photo again', () async {
    var uploads = 0, updates = 0;
    final task = HistorySaveTask(
      id: 'same',
      checkOwner: () {},
      saveAnalysis: () async {},
      uploadPhoto: () async {
        uploads++;
      },
      markReady: () async {
        if (updates++ == 0) throw StateError('offline');
      },
      markFailed: () async {},
    );
    expect(await task.save(), isFalse);
    expect(await task.save(), isTrue);
    expect(uploads, 1);
  });
  test('account change after metadata blocks upload', () async {
    var sameOwner = true, uploads = 0;
    final task = HistorySaveTask(
      id: 'same',
      checkOwner: () {
        if (!sameOwner) throw StateError('changed');
      },
      saveAnalysis: () async {
        sameOwner = false;
      },
      uploadPhoto: () async {
        uploads++;
      },
      markReady: () async {},
      markFailed: () async {},
    );
    await expectLater(task.save(), throwsStateError);
    expect(uploads, 0);
  });
}
