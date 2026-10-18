# Analysis History / Firebase Storage

## Implementation batches

1. Added firebase_storage 12.4.10, compatible with the existing firebase_core
   3.15.2 lockfile. Only the three Storage packages were added to pubspec.lock.
   Flutter regenerated the macOS and Windows plugin registrations.
2. Added an authenticated image transport and a retryable HistorySaveTask.
   One task allocates one Firestore document ID; repeated or concurrent saves
   reuse that ID. Upload failures do not remove analysis metadata or local files.
3. Connected Result, Home and Profile. Existing result cards and previews remain;
   small progress/error/retry controls appear below the result card. Account
   changes discard pending photo results and clear the rendered history photo.
4. API_BASE_URL can be supplied with --dart-define. The emulator default remains
   http://10.0.2.2:8000. Python and Android network policy were not changed.

## New records only

Firestore: users/{uid}/analysisHistory/{historyId}

Existing analysis fields and analyzedAt are preserved. New fields:

```
schemaVersion: 2
photo:
  storagePath: users/{uid}/analysisHistory/{historyId}/photo
  status: pending | ready | failed | missing
  updatedAt: server timestamp
  errorCode: photo-save-incomplete  # only when completion failed
deletionStatus: pending            # only during requested cloud deletion
```

The Storage object has no extension. JPEG, PNG and WebP signatures determine its
MIME metadata; bytes are uploaded without re-encoding. Maximum size: 20 MiB.
No permanent download URL is stored. Reads use the authenticated Storage SDK.
Client-side owner/path checks supplement, and do not replace, Security Rules.

Analysis metadata is written before upload. A successful upload is marked ready
by updating the same record. If the final metadata update fails, retrying the
open result does not upload again. Reopening a pending/failed cloud record offers
Retry photo upload; this first checks whether its object already exists, then
uses the original device's durable local copy if necessary.

Legacy records remain readable through localImageKey. They are never uploaded or
rewritten by opening them. Missing legacy files cannot be reconstructed from
Firestore. No existing image migration or local cache purge is performed.

User-requested deletion of a new cloud record marks deletion pending, deletes
the Storage object (object-not-found is acceptable), then deletes the document.
Failure keeps the record available for another delete attempt. Local files are
retained. In-process operations for the same entry cannot save/retry/delete
simultaneously. Firestore and Storage are not a distributed transaction; concurrent
changes on different devices and interruption during deletion still need runtime
validation before production acceptance.

## Verification actually run

- flutter pub get --offline: passed.
- flutter test --no-pub: 80 tests passed, including existing upload/EXIF,
  questionnaire, Result and preview regression tests.
- Targeted analyzer on History/Storage/API services and changed tests: passed.
- Analyzer on the services and Result/Home/Profile: no compilation errors;
  22 existing warning/info diagnostics remain in the screen files (duplicate
  import, unused fields/parameter, deprecated APIs and prefer-final suggestions).
- git diff --check: passed.
- flutter build apk --debug --no-pub: passed. Output:
  frontend/build/app/outputs/flutter-apk/app-debug.apk. This build uses the
  default emulator analysis endpoint; it was not installed or launched.

The mock tests cover upload failure and retry, stable IDs, concurrent save calls,
metadata failure, owner/path guards, account changes during image loading,
legacy/new deserialization, UI progress/error/retry, and operation-lock recovery.
They do not validate deployed Security Rules or actual Firebase persistence.

## Live verification still required

Android client config names project seasonme-977e3 and bucket
seasonme-977e3.firebasestorage.app. Firebase CLI project discovery returned 401
after an elevated read attempt. Bucket existence, deployed Firestore/Storage Rules
and App Check enforcement remain unverified. No Rules were created or deployed;
no real Firebase test records or objects were written or deleted.

Before live testing, inspect the bucket and both deployed Rules with an account
that has project access. If Rules need changes or reject the additive schema,
prepare and review that change separately; do not weaken Rules to make tests pass.

## Emulator and phone acceptance procedure (not yet run)

1. Confirm the bucket and existing Rules permit the authenticated owner to access
   the new path and fields. Confirm read/write/list/delete is denied to another
   UID and signed-out clients. Client mock tests are not proof of this.
2. Use an analysis endpoint reachable from the phone. From frontend:

   ```powershell
   flutter run -d YOUR_PHONE_ID --dart-define=API_BASE_URL=https://YOUR_BACKEND_HOST
   ```

   Replace the placeholders. For a trusted local HTTP endpoint, inspect actual
   device network-policy errors before proposing a debug-only configuration.
   Do not disable cleartext restrictions globally without evidence.
3. Sign in with the same Firebase UID on emulator and phone. Create a new analysis
   on A, wait for its photo to finish saving, then reopen History on B. Repeat in
   the other direction. B must not need A's local file.
4. Close and reopen the apps. Stop FastAPI and verify an already-saved History
   photo still opens; History reads do not require the analysis API.
5. Interrupt a new photo upload. Confirm analysis metadata remains. Retry on the
   original device and verify the same document ID/path and a single history row.
   Also test reopening the failed record before retrying.
6. Open a legacy record on its original device and on another device. Preserve
   analysis display when its local photo is absent; no automatic upload occurs.
7. Change account during loading/upload and verify the old photo is not shown to
   the new account. Test requested deletion and retry after partial failure using
   disposable new test records only, with explicit live-test authorization.

Do not mark cross-device support accepted until these device checks pass.
