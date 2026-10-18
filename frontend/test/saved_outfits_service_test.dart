import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/season_palette.dart';
import 'package:frontend/models/saved_outfit.dart';
import 'package:frontend/services/image_storage_service.dart';
import 'package:frontend/utils/color_utils.dart';

import 'saved_outfits_test_support.dart';

void main() {
  late OutfitTestEnvironment env;
  setUp(() => env = OutfitTestEnvironment());
  tearDown(() => env.dispose());

  test(
    'concurrent tasks with different notes keep the first confirmed name',
    () async {
      final first = env.service.createSaveTask(
        sampleMatch,
        samplePhoto(),
        note: 'First name',
      );
      final second = env.service.createSaveTask(
        sampleMatch,
        samplePhoto(),
        note: 'Second name',
      );
      final results = await Future.wait([first.save(), second.save()]);
      expect(results.map((entry) => entry.note), everyElement('First name'));
      expect(first.wasAlreadySaved, isFalse);
      expect(second.wasAlreadySaved, isTrue);
      expect(env.documents.docs.length, 1);
    },
  );

  test(
    'optional note is normalized, round-trips and never changes duplicate ID',
    () async {
      final task = env.service.createSaveTask(
        sampleMatch,
        samplePhoto(),
        note: '  Purple shirt from Store A  ',
      );
      final first = await task.save();
      expect(first.note, 'Purple shirt from Store A');
      expect(task.wasAlreadySaved, isFalse);
      final duplicate = env.service.createSaveTask(
        sampleMatch,
        samplePhoto(),
        note: 'Different note',
      );
      final again = await duplicate.save();
      expect(duplicate.id, task.id);
      expect(duplicate.wasAlreadySaved, isTrue);
      expect(again.note, first.note);
      expect(again.savedAt, first.savedAt);
      expect(env.documents.docs.length, 1);
      expect((await env.service.list()).items.single.displayName, first.note);
    },
  );

  test(
    'blank notes and legacy documents use fallback without writing it',
    () async {
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto(), note: '  ')
          .save();
      expect(saved.note, isNull);
      expect(saved.displayName, 'Saved Outfit');
      expect(env.documents.docs.values.single.containsKey('note'), isFalse);
      final duplicate = await env.service
          .createSaveTask(
            sampleMatch,
            samplePhoto(),
            note: 'Do not overwrite legacy',
          )
          .save();
      expect(duplicate.displayName, 'Saved Outfit');
      expect(env.documents.docs.values.single.containsKey('note'), isFalse);
    },
  );

  test(
    '100 Unicode characters accepted and 101 rejected before storage',
    () async {
      for (final character in ['a', 'ก', '😀']) {
        final note = List.filled(100, character).join();
        expect(SavedOutfit.normalizeNote(note), note);
        expect(
          () => env.service.createSaveTask(
            sampleMatch,
            samplePhoto(),
            note: note + character,
          ),
          throwsFormatException,
        );
      }
      expect(env.storage.uploads, 0);
      final note = 'a' * 100;
      expect(
        (await env.service
                .createSaveTask(sampleMatch, samplePhoto(), note: note)
                .save())
            .note,
        note,
      );
    },
  );

  for (final ambiguous in [false, true]) {
    test(
      'retry keeps note after ${ambiguous ? 'ambiguous commit' : 'metadata failure'}',
      () async {
        final task = env.service.createSaveTask(
          sampleMatch,
          samplePhoto(),
          note: 'Interview shirt',
        );
        env.documents.failPut = !ambiguous;
        env.documents.failAfterPut = ambiguous;
        await expectLater(task.save(), throwsStateError);
        env.documents.failPut = false;
        env.documents.failAfterPut = false;
        final saved = await task.save();
        expect(saved.note, 'Interview shirt');
        expect(env.storage.uploads, 1);
        expect(env.documents.docs.length, 1);
      },
    );
  }

  test(
    'malformed optional notes are rejected without changing old schema',
    () async {
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      final raw = env.documents.docs.values.single;
      for (final bad in [null, 1, true, [], 'a' * 101]) {
        expect(
          () => SavedOutfit.fromMap('alice', saved.id, {...raw, 'note': bad}),
          throwsFormatException,
        );
      }
      expect(raw['schemaVersion'], 1);
      expect(
        SavedOutfit.fromMap('alice', saved.id, raw).displayName,
        'Saved Outfit',
      );
    },
  );

  test(
    'save, concurrent double tap and a fresh task reuse one ID/path',
    () async {
      final task = env.service.createSaveTask(sampleMatch, samplePhoto());
      final results = await Future.wait([task.save(), task.save()]);
      expect(results[0].id, results[1].id);
      final again = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      expect(again.id, task.id);
      expect(env.documents.docs.length, 1);
      expect(env.storage.files.length, 1);
      expect(env.storage.uploads, 1);
      expect(again.savedAt, results[0].savedAt);
    },
  );

  test(
    'upload failure retries same task without metadata or extra objects',
    () async {
      final task = env.service.createSaveTask(sampleMatch, samplePhoto());
      env.storage.failUpload = true;
      await expectLater(task.save(), throwsStateError);
      expect(env.documents.docs, isEmpty);
      env.storage.failUpload = false;
      expect((await task.save()).id, task.id);
      expect(env.documents.docs.length, 1);
    },
  );

  for (final ambiguous in [false, true]) {
    test(
      'metadata ${ambiguous ? 'ambiguous commit' : 'failure'} preserves uploaded photo and retry recovers',
      () async {
        final task = env.service.createSaveTask(sampleMatch, samplePhoto());
        env.documents.failPut = !ambiguous;
        env.documents.failAfterPut = ambiguous;
        await expectLater(task.save(), throwsStateError);
        expect(env.storage.files.length, 1);
        expect(env.storage.deletes, 0);
        expect(env.documents.docs.length, ambiguous ? 1 : 0);
        env.documents.failPut = false;
        env.documents.failAfterPut = false;
        await task.save();
        expect(env.documents.docs.length, 1);
        expect(env.storage.uploads, 1);
      },
    );
  }

  test('server confirmation failure never returns saved until retry', () async {
    final task = env.service.createSaveTask(sampleMatch, samplePhoto());
    var reads = 0;
    env.documents.beforeGet = () async {
      if (++reads == 2) throw StateError('offline confirmation');
    };
    await expectLater(task.save(), throwsStateError);
    expect(env.documents.docs.length, 1);
    env.documents.beforeGet = null;
    await task.save();
    expect(env.storage.uploads, 1);
  });

  test(
    'new view loads server metadata and authenticated bytes, no local file',
    () async {
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      final list = await env.service.list();
      expect(list.items.single.match.season, SeasonKey.Winter);
      expect(list.items.single.match.matchPercent, 82);
      expect(await env.service.photo(saved), samplePhoto());
      expect(saved.storagePath, 'users/alice/savedOutfits/${saved.id}/photo');
      env.documents.docs['alice/bad'] = {'season': 'invalid'};
      final malformed = await env.service.list();
      expect(malformed.items.length, 1);
      expect(malformed.invalidCount, 1);
    },
  );

  test('photo missing/corrupt/network error does not invent a photo', () async {
    final saved = await env.service
        .createSaveTask(sampleMatch, samplePhoto())
        .save();
    env.storage.failDownload = true;
    await expectLater(env.service.photo(saved), throwsStateError);
    env.storage.failDownload = false;
    env.storage.files.remove(saved.storagePath);
    await expectLater(env.service.photo(saved), throwsStateError);
  });

  for (final phase in ['storage', 'metadata', 'ambiguous']) {
    test(
      'delete failure in $phase retains recoverable state; retry finishes',
      () async {
        final saved = await env.service
            .createSaveTask(sampleMatch, samplePhoto())
            .save();
        env.storage.failDelete = phase == 'storage';
        env.documents.failFinishDelete = phase == 'metadata';
        env.documents.failAfterFinishDelete = phase == 'ambiguous';
        await expectLater(env.service.remove(saved), throwsStateError);
        if (phase != 'ambiguous') {
          expect((await env.service.list()).items.single.status, 'deleting');
        }
        env.storage.failDelete = false;
        env.documents.failFinishDelete = false;
        env.documents.failAfterFinishDelete = false;
        await env.service.remove(saved);
        expect(env.storage.files, isEmpty);
        expect((await env.service.list()).items, isEmpty);
      },
    );
  }

  for (final side in ['photo', 'metadata']) {
    test('delete succeeds when $side is already missing', () async {
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      if (side == 'photo') {
        env.storage.files.clear();
      } else {
        env.documents.docs.clear();
      }
      await env.service.remove(saved);
      expect(env.storage.files, isEmpty);
      expect(env.documents.docs, isEmpty);
    });
  }

  test('other UID cannot read photo/delete/continue old task', () async {
    final task = env.service.createSaveTask(sampleMatch, samplePhoto());
    final saved = await task.save();
    env.switchTo('bob');
    await expectLater(env.service.photo(saved), throwsStateError);
    await expectLater(env.service.remove(saved), throwsStateError);
    await expectLater(task.save(), throwsStateError);
    expect((await env.service.list()).items, isEmpty);
    expect(env.storage.files.length, 1);
  });

  test('account changes during upload: no metadata is written', () async {
    final task = env.service.createSaveTask(sampleMatch, samplePhoto());
    env.storage.afterUpload = () => env.switchTo('bob');
    await expectLater(task.save(), throwsStateError);
    expect(env.documents.docs, isEmpty);
    expect(env.storage.deletes, 0); // do not clean up under a different account
  });

  test('logout and same UID login still invalidates an old task', () async {
    final task = env.service.createSaveTask(sampleMatch, samplePhoto());
    env.switchTo(null);
    env.switchTo('alice');
    await expectLater(task.save(), throwsStateError);
  });

  test('account switch during listing/photo rejects stale results', () async {
    final saved = await env.service
        .createSaveTask(sampleMatch, samplePhoto())
        .save();
    env.documents.beforeList = () async => env.switchTo('bob');
    await expectLater(env.service.list(), throwsStateError);
    env.switchTo('alice');
    env.documents.beforeList = null;
    env.storage.afterDownload = () => env.switchTo('bob');
    await expectLater(env.service.photo(saved), throwsStateError);
  });

  test(
    'save blocks delete on same entry while an operation is in flight',
    () async {
      final task = env.service.createSaveTask(sampleMatch, samplePhoto());
      final saved = await task.save();
      final wait = Completer<void>();
      env.documents.beforeGet = () => wait.future;
      final operation = task.save();
      await expectLater(env.service.remove(saved), throwsStateError);
      wait.complete();
      await operation;
    },
  );

  test(
    'deleting entry cannot be resurrected by retry; deleted bytes reupload on explicit fresh save',
    () async {
      final task = env.service.createSaveTask(sampleMatch, samplePhoto());
      final saved = await task.save();
      env.documents.failFinishDelete = true;
      await expectLater(env.service.remove(saved), throwsStateError);
      await expectLater(task.save(), throwsStateError);
      env.documents.failFinishDelete = false;
      await env.service.remove(saved);
      await expectLater(task.save(), throwsStateError);
      await env.service.createSaveTask(sampleMatch, samplePhoto()).save();
      expect(env.storage.uploads, 2);
    },
  );

  test(
    'account switch after deletion marker prevents Storage deletion',
    () async {
      final saved = await env.service
          .createSaveTask(sampleMatch, samplePhoto())
          .save();
      env.documents.afterMarkDeleting = () => env.switchTo('bob');
      await expectLater(env.service.remove(saved), throwsStateError);
      expect(env.storage.deletes, 0);
      expect(env.documents.docs['alice/${saved.id}']!['status'], 'deleting');
      env.documents.afterMarkDeleting = null;
      env.switchTo('alice');
      await env.service.remove(saved);
      expect(env.documents.docs, isEmpty);
    },
  );

  test(
    'signed out, Avoid, invalid score, unsupported and oversized bytes rejected',
    () async {
      const avoid = OutfitMatchSnapshot(
        season: SeasonKey.Winter,
        matchPercent: 20,
        matchLevel: MatchLevel.poor,
        sampledColorArgb: 0,
        closestName: 'x',
        closestArgb: 0,
        closestCategory: 'Clothing',
      );
      expect(
        () => env.service.createSaveTask(avoid, samplePhoto()),
        throwsFormatException,
      );
      expect(
        () => env.service.createSaveTask(sampleMatch, Uint8List(4)),
        throwsArgumentError,
      );
      expect(
        () => env.service.createSaveTask(
          sampleMatch,
          Uint8List(ImageStorageService.maxImageBytes + 1),
        ),
        throwsArgumentError,
      );
      env.switchTo(null);
      expect(
        () => env.service.createSaveTask(sampleMatch, samplePhoto()),
        throwsStateError,
      );
    },
  );

  test('different bytes or season are not merged merely by color', () {
    final first = env.service.createSaveTask(sampleMatch, samplePhoto());
    final bytes = Uint8List.fromList([...samplePhoto(), 1]);
    expect(env.service.createSaveTask(sampleMatch, bytes).id, isNot(first.id));
    const summer = OutfitMatchSnapshot(
      season: SeasonKey.Summer,
      matchPercent: 82,
      matchLevel: MatchLevel.excellent,
      sampledColorArgb: 0xff30455f,
      closestName: 'Navy',
      closestArgb: 0xff30455f,
      closestCategory: 'Clothing',
    );
    expect(
      env.service.createSaveTask(summer, samplePhoto()).id,
      isNot(first.id),
    );
  });

  test('invalid owner path is rejected before Storage transport', () async {
    final saved = await env.service
        .createSaveTask(sampleMatch, samplePhoto())
        .save();
    final calls = env.storage.downloads;
    await expectLater(
      env.images.findOutfitPhoto(
        'alice',
        saved.id,
        'users/bob/savedOutfits/${saved.id}/photo',
      ),
      throwsArgumentError,
    );
    expect(env.storage.downloads, calls);
  });
}
