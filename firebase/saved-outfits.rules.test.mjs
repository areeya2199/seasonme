import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject, listAll } from 'firebase/storage';

const projectId = 'demo-seasonme-rules';
const bucket = `gs://${projectId}.firebasestorage.app`;
const id = 'outfit1';
const path = `users/alice/savedOutfits/${id}/photo`;
const jpeg = new Uint8Array([255,216,255,217]);
let env;
before(async () => {
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
  assert.equal(process.env.FIREBASE_STORAGE_EMULATOR_HOST, '127.0.0.1:9199');
  env = await initializeTestEnvironment({projectId,
    firestore: {host:'127.0.0.1',port:8080,rules:await readFile(new URL('./firestore.rules',import.meta.url),'utf8')},
    storage: {host:'127.0.0.1',port:9199,rules:await readFile(new URL('./storage.rules',import.meta.url),'utf8')},
  });
});
beforeEach(async () => {await env.clearFirestore();});
after(async () => {await env?.cleanup();});
const context = uid => uid ? env.authenticatedContext(uid) : env.unauthenticatedContext();
const db = uid => context(uid).firestore();
const entry = (uid='alice',owner='alice') => doc(db(uid),`users/${owner}/savedOutfits/${id}`);
const object = (uid='alice',target=path) => ref(context(uid).storage(bucket),target);
function data(overrides={}) {
  return {schemaVersion:1,season:'Winter',matchPercent:82,matchLevel:'excellent',sampledColorArgb:4281545523,
    closestColor:{name:'Navy',argb:4281545523,category:'Clothing'},imageHash:'a'.repeat(64),
    matchAlgorithmVersion:1,storagePath:path,savedAt:serverTimestamp(),status:'ready',...overrides};
}
async function seed() {await setDoc(entry(),data());}

for (const [label,note] of [
  ['short','Purple shirt from Store A'], ['blank',''], ['100 ASCII','a'.repeat(100)],
  ['100 Thai','ก'.repeat(100)], ['100 emoji','😀'.repeat(100)],
  ['multiline','Purple shirt\nStore A'],
]) test(`optional note accepts ${label}; still permits deletion`,async()=>{
  await assertSucceeds(setDoc(entry(),data({note})));
  assert.equal((await getDoc(entry())).data().note,note);
  await assertSucceeds(updateDoc(entry(),{status:'deleting'}));
  await assertSucceeds(deleteDoc(entry()));
});
for (const [label,note] of [
  ['101 ASCII','a'.repeat(101)], ['101 Thai','ก'.repeat(101)], ['101 emoji','😀'.repeat(101)],
  ['null',null], ['number',100], ['boolean',true], ['list',[]], ['map',{}],
]) test(`optional note rejects ${label}`,async()=>{
  await assertFails(setDoc(entry(),data({note})));
});
test('note does not grant editing of existing records or other owners',async()=>{
  await assertSucceeds(setDoc(entry(),data({note:'Original'})));
  await assertFails(updateDoc(entry(),{note:'Changed'}));
  await assertFails(updateDoc(entry(),{note:'Changed',status:'deleting'}));
  await assertFails(updateDoc(entry('bob'),{note:'Changed'}));
  await assertFails(setDoc(doc(db('bob'),'users/alice/savedOutfits/new'),data({note:'Other owner'})));
  assert.equal((await getDoc(entry())).data().note,'Original');
});

test('A uploads photo, commits metadata, lists/reads/downloads and deletes both',async()=>{
  await assertSucceeds(uploadBytes(object(),jpeg,{contentType:'image/jpeg'}));
  await assertSucceeds(setDoc(entry(),data()));
  const list=await assertSucceeds(getDocs(collection(db('alice'),'users/alice/savedOutfits')));
  assert.equal(list.size,1);
  const saved=await assertSucceeds(getDoc(entry()));
  assert.equal(saved.data().season,'Winter');
  assert.deepEqual(new Uint8Array(await assertSucceeds(getBytes(object()))),jpeg);
  await assertFails(deleteDoc(entry())); // must leave a recoverable marker first
  await assertSucceeds(updateDoc(entry(),{status:'deleting'}));
  await assertSucceeds(deleteObject(object()));
  await assertSucceeds(deleteDoc(entry()));
  assert.equal((await getDoc(entry())).exists(),false);
});

for(const uid of ['bob',null]) {
  test(`${uid??'signed-out'} cannot read, list, create, update or delete A metadata`,async()=>{
    await seed();
    await assertFails(getDoc(entry(uid)));
    await assertFails(getDocs(collection(db(uid),'users/alice/savedOutfits')));
    await assertFails(setDoc(doc(db(uid),'users/alice/savedOutfits/new'),data()));
    await assertFails(updateDoc(entry(uid),{status:'deleting'}));
    await assertFails(deleteDoc(entry(uid)));
  });
  test(`${uid??'signed-out'} cannot download, upload, list or delete A photo`,async()=>{
    await uploadBytes(object(),jpeg,{contentType:'image/jpeg'});
    await assertFails(getBytes(object(uid)));
    await assertFails(uploadBytes(object(uid),jpeg,{contentType:'image/jpeg'}));
    await assertFails(deleteObject(object(uid)));
    await assertFails(listAll(ref(context(uid).storage(bucket),'users/alice/savedOutfits')));
  });
}

for(const [label,patch] of [
  ['unknown season',{season:'Unknown'}],['avoid',{matchPercent:44,matchLevel:'poor'}],
  ['wrong level',{matchPercent:74,matchLevel:'excellent'}],['score over 100',{matchPercent:101}],
  ['fractional score',{matchPercent:82.5}],['string color',{sampledColorArgb:'red'}],
  ['color overflow',{sampledColorArgb:4294967296}],['foreign path',{storagePath:'users/bob/savedOutfits/outfit1/photo'}],
  ['wrong ID path',{storagePath:'users/alice/savedOutfits/other/photo'}],['local key',{storagePath:'analysis_old.png'}],
  ['URL',{storagePath:'https://example.com/photo'}],['bad hash',{imageHash:'invalid'}],
  ['extra field',{localImageKey:'photo.png'}],['wrong version',{schemaVersion:2}],
  ['string timestamp',{savedAt:'today'}],['client timestamp',{savedAt:Timestamp.fromMillis(1)}],
  ['wrong status',{status:'uploading'}],['invalid closest map',{closestColor:{name:'Navy',argb:-1,category:'Clothing'}}],
])test(`schema denies ${label}`,async()=>{await assertFails(setDoc(entry(),data(patch)));});

test('good 45 and excellent 75 use original boundaries; match data is immutable',async()=>{
  await assertSucceeds(setDoc(entry(),data({matchPercent:45,matchLevel:'good'})));
  await assertFails(updateDoc(entry(),{season:'Summer'}));
  await assertFails(updateDoc(entry(),{matchPercent:46}));
  await assertSucceeds(updateDoc(entry(),{status:'deleting'}));
  await assertFails(updateDoc(entry(),{status:'ready'}));
  await assertSucceeds(deleteDoc(entry()));
  await assertSucceeds(setDoc(entry(),data({matchPercent:75,matchLevel:'excellent'})));
});

test('History baseline retains owner create/read/update/delete; others denied',async()=>{
  const history=doc(db('alice'),'users/alice/analysisHistory/history1');
  await assertSucceeds(setDoc(history,{season:'Winter'}));
  await assertSucceeds(getDoc(history));
  await assertSucceeds(updateDoc(history,{season:'Summer'}));
  await assertFails(getDoc(doc(db('bob'),history.path)));
  await assertFails(deleteDoc(doc(db(null),history.path)));
  await assertSucceeds(deleteDoc(history));
  await assertFails(setDoc(doc(db('alice'),'users/alice/other/id'),{open:true}));
});

test('metadata retry after upload and deletion retry with a missing photo',async()=>{
  await uploadBytes(object(),jpeg,{contentType:'image/jpeg'});
  await assertFails(setDoc(entry(),data({matchPercent:0})));
  assert.deepEqual(new Uint8Array(await getBytes(object())),jpeg);
  await assertSucceeds(setDoc(entry(),data()));
  await updateDoc(entry(),{status:'deleting'});
  await deleteObject(object());
  await assertSucceeds(getDoc(entry()));
  await assertSucceeds(deleteDoc(entry()));
});

test('orphan photo can be removed by its owner with no metadata',async()=>{
  await uploadBytes(object(),jpeg,{contentType:'image/jpeg'});
  assert.equal((await getDoc(entry())).exists(),false);
  await assertSucceeds(deleteObject(object()));
});

for(const mime of ['image/jpeg','image/png','image/webp'])test(`Saved Outfit accepts MIME ${mime}`,async()=>{
  await assertSucceeds(uploadBytes(object(),jpeg,{contentType:mime}));
});
for(const mime of ['text/plain','image/gif','application/octet-stream'])test(`Saved Outfit rejects MIME ${mime}`,async()=>{
  await assertFails(uploadBytes(object(),jpeg,{contentType:mime}));
});
test('Saved Outfit accepts 20 MiB and rejects empty and 20 MiB + 1',async()=>{
  await assertSucceeds(uploadBytes(object(),new Uint8Array(20*1024*1024),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(object(),new Uint8Array(0),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(object(),new Uint8Array(20*1024*1024+1),{contentType:'image/jpeg'}));
});
for(const target of ['users/alice/savedOutfits/bad.id/photo','users/alice/savedOutfits/outfit1/photo.jpg','users/alice/savedOutfits/outfit1/photo/extra'])test(`Saved Outfit denies unexpected path ${target}`,async()=>{
  await assertFails(uploadBytes(object('alice',target),jpeg,{contentType:'image/jpeg'}));
});
