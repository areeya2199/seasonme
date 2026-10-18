import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteObject,
  getBytes,
  getMetadata,
  listAll,
  ref,
  updateMetadata,
  uploadBytes,
} from 'firebase/storage';

// Fail closed: do not run against live Firebase, even if launched incorrectly.
const projectId = 'demo-seasonme-rules';
const bucket = `gs://${projectId}.firebasestorage.app`;
const path = 'users/alice/analysisHistory/entry1/photo';
const jpeg = new Uint8Array([255, 216, 255, 217]);
const maxBytes = 20 * 1024 * 1024;
let environment;

before(async () => {
  assert.equal(
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
    '127.0.0.1:9199',
    'Run npm run test:rules; a localhost Storage Emulator is required',
  );
  environment = await initializeTestEnvironment({
    projectId,
    storage: {
      host: '127.0.0.1',
      port: 9199,
      rules: await readFile(new URL('./storage.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  // Clear this exact demo bucket recursively; fixtures live under nested paths.
  await environment.withSecurityRulesDisabled(async (context) => {
    async function clear(prefix) {
      const { items, prefixes } = await listAll(prefix);
      await Promise.all(items.map((item) => deleteObject(item)));
      await Promise.all(prefixes.map(clear));
    }
    await clear(ref(context.storage(bucket)));
  });
});
after(async () => environment?.cleanup());

function object(uid = 'alice', objectPath = path) {
  const context = uid === null
    ? environment.unauthenticatedContext()
    : environment.authenticatedContext(uid);
  return ref(context.storage(bucket), objectPath);
}

async function seed(objectPath = path, contentType = 'image/jpeg') {
  await environment.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(bucket), objectPath), jpeg, { contentType });
  });
}

for (const contentType of ['image/jpeg', 'image/png', 'image/webp']) {
  test(`owner can create, read and replace ${contentType}`, async () => {
    const file = object();
    await assertSucceeds(uploadBytes(file, jpeg, { contentType }));
    assert.deepEqual(new Uint8Array(await assertSucceeds(getBytes(file))), jpeg);
    await assertSucceeds(uploadBytes(file, jpeg, { contentType }));
    assert.equal((await getMetadata(file)).contentType, contentType);
  });
}

for (const uid of ['bob', null]) {
  test(`${uid ?? 'signed-out client'} cannot create another owner's photo`, async () => {
    await assertFails(uploadBytes(object(uid), jpeg, { contentType: 'image/jpeg' }));
  });

  test(`${uid ?? 'signed-out client'} cannot read, overwrite, alter metadata or delete`, async () => {
    await seed();
    const file = object(uid);
    await assertFails(getBytes(file));
    await assertFails(getMetadata(file));
    await assertFails(uploadBytes(file, jpeg, { contentType: 'image/jpeg' }));
    await assertFails(updateMetadata(file, { contentType: 'image/png' }));
    await assertFails(deleteObject(file));
    await assertSucceeds(getBytes(object()));
  });
}

test('owner can delete without request.resource upload metadata', async () => {
  await seed();
  await assertSucceeds(deleteObject(object()));
});

test('owner can delete an existing invalid-format object', async () => {
  await seed(path, 'application/octet-stream');
  await assertSucceeds(deleteObject(object()));
});

test('exactly 20 MiB is accepted', async () => {
  await assertSucceeds(uploadBytes(object(), new Uint8Array(maxBytes), { contentType: 'image/jpeg' }));
});

test('over 20 MiB is denied on create and replacement', async () => {
  const oversized = new Uint8Array(maxBytes + 1);
  await assertFails(uploadBytes(object(), oversized, { contentType: 'image/jpeg' }));
  await seed();
  await assertFails(uploadBytes(object(), oversized, { contentType: 'image/jpeg' }));
  assert.deepEqual(new Uint8Array(await getBytes(object())), jpeg);
});

test('empty file is denied on create and replacement', async () => {
  await assertFails(uploadBytes(object(), new Uint8Array(), { contentType: 'image/png' }));
  await seed();
  await assertFails(uploadBytes(object(), new Uint8Array(), { contentType: 'image/png' }));
});

for (const contentType of ['application/octet-stream', 'text/html', 'image/svg+xml', 'image/gif']) {
  test(`${contentType} is denied on create, replacement and metadata update`, async () => {
    await assertFails(uploadBytes(object(), jpeg, { contentType }));
    await seed();
    await assertFails(uploadBytes(object(), jpeg, { contentType }));
    await assertFails(updateMetadata(object(), { contentType }));
  });
}

test('upload without an explicit supported MIME type is denied', async () => {
  await assertFails(uploadBytes(object(), jpeg));
});

test('owner cannot list the bucket, users, own folder or history folder', async () => {
  await seed();
  for (const prefix of ['', 'users', 'users/alice', 'users/alice/analysisHistory']) {
    await assertFails(listAll(object('alice', prefix)));
  }
});

test('other users and signed-out clients cannot list photos', async () => {
  await seed();
  for (const uid of ['bob', null]) {
    await assertFails(listAll(object(uid, 'users/alice/analysisHistory')));
  }
});

for (const objectPath of [
  'photo',
  'users/alice/profile/photo',
  'users/alice/analysisHistory/entry1/photo.jpg',
  'users/alice/analysisHistory/entry1/photo/extra',
  'users/alice/analysisHistory/bad.id/photo',
]) {
  test(`unapproved path is denied: ${objectPath}`, async () => {
    await assertFails(uploadBytes(object('alice', objectPath), jpeg, { contentType: 'image/jpeg' }));
    await seed(objectPath);
    await assertFails(getBytes(object('alice', objectPath)));
    await assertFails(deleteObject(object('alice', objectPath)));
  });
}
