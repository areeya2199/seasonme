# Image-only undertone experiment

This experiment starts from `1b3d7e7` on `experiment/image-only`. Undertone now
uses the existing cheek-image pipeline alone. Q4 remains required and is used
only to select a season after undertone classification.

## API contract

`POST /analyze` still accepts multipart `file` (the original encoded photo) and
`answers` (a JSON string), with `Authorization: Bearer <Firebase ID token>`.

Before, answers could contain keys `0`, `1`, `2`, `3`, with Q1-Q3 optional:

```json
{"0": "Green", "1": "Silver", "2": null, "3": "Bright"}
```

Now the only supported payload is `{"3":"Bright"}` or `{"3":"Muted"}`.
The canonical Q4 key stays `3` even though the UI shows a single question.
Missing/invalid Q4, malformed JSON, non-object JSON and any extra answer key
(including Q1-Q3 with null values) return 422 before image processing. An old
client sending all four keys must continue using its original backend; the
experimental Flutter client and API must be used together.

The image path is unchanged: OpenCV decode, BGR-to-RGB for MediaPipe, the same
10 landmarks per cheek, the same combined polygon mask, BGR/HSV/Lab means,
OpenCV Lab scale conversion, and `degrees(atan2(b*, a*))` normalized to [0, 360).
The unrounded hue angle is **Warm if greater than 60 degrees; otherwise Cool**.
No threshold, landmark, color-space or season-mapping changes were made.

| Image undertone | Q4 | Season |
| --- | --- | --- |
| Cool | Bright | Winter |
| Cool | Muted | Summer |
| Warm | Bright | Spring |
| Warm | Muted | Autumn |

The response retains `undertone`, `season`, `hue_angle`, `rgb`, `hsv`, `lab`,
`lightness_group` and `chroma_group`. `warm_score`/`cool_score` are now binary
image votes (1/0); `warm_total`/`cool_total` remain aliases for the existing
history writer. These scores are not confidence or accuracy percentages.
`questionnaire`, `answered_count`, `questionnaire_weight` and `image_weight`
have been removed from the response and their calculations have been deleted.

Missing multipart fields return 422. Empty/corrupt images and OpenCV decoding
exceptions return the existing HTTP 200 `{"error":"Invalid image"}` contract;
no detected face returns HTTP 200 `{"error":"No face detected"}`. Flutter
already handles both error bodies without opening or saving a result.
Authentication and its 401/503 behavior remain unchanged.

## History compatibility and limits

The existing Firestore writer, collections, schema version (2), document field
names, Storage paths and rules are unchanged. New `questionnaireAnswers` maps
contain only key `3`. The existing writer handles the absent questionnaire
scores by saving `warm_question` and `cool_question` as null. Old documents keep
their original Q1-Q4 answers and scores; history displays saved undertone and
season without recomputing them. No migration or cloud-data changes are needed.

The original image vote had at least 70% weight and answers at most 30%, so valid
Q1-Q3 answers could not overturn the binary image vote. Removing fusion should
preserve undertone/season for the same image and Q4, while reported scores change.
This experiment does not calibrate lighting, makeup, white balance, mask quality
or the 60-degree threshold, and does not establish clinical/colorimetric accuracy.

Tests in `tests/test_questionnaire.py` cover Q4-only validation, the exact hue
boundary, all four seasons through multipart decoding and color analysis, Q4
independence, real MediaPipe face/no-face fixtures and image errors. Auth and
EXIF-orientation regressions remain in their existing suites. Flutter tests
cover the one-question UI, unchanged swatches/photo, Q4 validation and multipart,
and reading old/new history. Live Firebase tokens, cloud saves/reads and mobile
device camera flows still require manual verification; mocks cannot certify them.
The older deployment/test results below describe the pre-experiment baseline.

## Verification on 2026-11-01

- Backend: `python -B -m unittest discover -s tests -v` passed all 32 tests.
- Flutter: the questionnaire, API, questionnaire-history, upload, history-save
  and image-storage suites passed all 42 tests.
- Full Flutter suite: 112 passed, 43 failed. The same 43 failure names reproduce
  from an isolated Git archive of starting commit `1b3d7e7`: 19 in
  `preview_ui_test.dart`, 24 in `result_screen_test.dart`. The existing Result
  and Palette implementation and these two test files were not modified.
  This is not a fully passing Flutter regression suite.
- The Upload tests now wait for the Q4 photo to finish loading before deleting
  temporary files; otherwise Windows correctly rejects deleting an open file.
- Image-pipeline AST statements through hue computation match the starting
  commit. On `frontend/assets/person.png`, RGB/HSV/Lab, hue (53.06 degrees),
  Cool undertone and Winter/Summer match the pre-change results for both Q4
  choices and both fully answered/skipped legacy answer sets. New image votes
  are Warm=0, Cool=1; old fully answered fusion scores were 0.15/0.85.
- Scoped Dart analysis reports four inherited `withOpacity` deprecation infos
  in the preserved Q4 styling, with no errors or warnings.

The first sandboxed TestClient/formatter attempts stalled and were stopped;
verification then ran successfully outside that sandbox without installing or
upgrading dependencies. MediaPipe native inference notices and the existing
Starlette/httpx deprecation notice remain. No live Firebase data, real-user token,
device camera or deployment was exercised. These checks and the existing Flutter
failures remain follow-up work before a production merge.

# Local Firebase authentication

`GET /` remains public. `POST /analyze` requires a Firebase ID token in
`Authorization: Bearer <token>`. Missing, invalid and expired tokens return 401
before image decoding or analysis. Authentication does not modify analysis JSON.
Credential/configuration and certificate-fetch failures return 503 and never
allow analysis through.

## Credentials on Windows

Use a Firebase Admin service-account JSON for the same project as Flutter
(`seasonme-977e3`). Keep the file **outside this repository**, for example
`C:\Users\Gim\seasonme-secrets\firebase-admin.json`. Android's
`google-services.json` and iOS's `GoogleService-Info.plist` are client
configuration, not Admin credentials. Never embed an Admin private key in Flutter
or commit it to Git.

In the PowerShell session that starts the backend:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\Users\Gim\seasonme-secrets\firebase-admin.json'
$env:FIREBASE_PROJECT_ID = 'seasonme-977e3'
Set-Location C:\Users\Gim\seasonme\backend
# Reuse the existing local environment; Phase B does not install into it.
.\.venv\Scripts\python.exe -B -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The credentials variable is a **file path**, not JSON text. This change does not
generate or supply credentials. The local `.venv` was created with
`--system-site-packages` to reuse the working analysis dependencies without
changing the global Python environment. On a fresh machine create a virtualenv
and install `requirements.txt`. That original file is preserved, including its
two OpenCV packages. The separately tested Linux list is `requirements-render.txt`.

The Admin app initializes on the first authenticated request through Application
Default Credentials (ADC). A health check does not validate credential setup.
Firebase's `getIdToken()` refreshes expired client ID tokens; the backend still
validates each submitted token independently. Default SDK verification does not
perform an additional user revocation lookup on every request.

## Tests and manual verification

From `backend`, install test dependencies in an isolated environment and run:

```powershell
python -m pip install -r requirements-test.txt
python -B -m unittest discover -s tests -v
```

Automated auth tests mock the Admin SDK boundary and need no real credentials.
They send multipart HTTP requests through FastAPI and verify that auth failures
block image decoding and analysis, while successful JSON stays unchanged.

For a real local check, start the backend with the variables above, sign into
Flutter, and analyze a photo. Check that unauthenticated requests return 401,
signed-in requests succeed, and a signed-out app cannot upload. The existing API
URL must be reachable from your phone. Use a trusted local test network with the
existing HTTP URL; ID tokens are bearer credentials. Future internet-facing
operation requires HTTPS. Never log tokens or show them in screenshots/reports.

## Future Cloud setup

Keep this verification code. On Google-hosted runtimes use ADC with the runtime
service-account identity. Elsewhere mount credentials through the provider's
secret facility and set `GOOGLE_APPLICATION_CREDENTIALS` to the runtime file path.
Set `FIREBASE_PROJECT_ID` to the Flutter project. Never copy credentials into a
Docker image. This change does not deploy or configure any Cloud provider.

## Phase B: Linux preparation (2026-10-19)

The confirmed project is `seasonme-977e3`. Local and Render are separate backend
processes and URLs, but use the same Firebase project and user data. Flutter
accesses Firestore/Storage directly; changing the API URL does not select a
different Firebase project or create separate history collections.

`requirements-render.txt` preserves every version pin from `requirements.txt`
and removes only `opencv-python==5.0.0.93`. Linux pip resolution selects exactly
one OpenCV distribution: `opencv-contrib-python==5.0.0.93`, which is required by
`mediapipe==0.10.35`. Do not add a headless OpenCV package alongside it: pip would
still satisfy MediaPipe's named dependency with the non-headless distribution.
Dependencies not pinned by the original file (including Firebase's transitive
dependencies) are resolved by pip; the full tested resolution is retained in
the ignored local evidence directory. This is not a complete dependency lock.

The model path now resolves from `services/analysis.py`, independent of the
working directory. Image decoding, preprocessing, questionnaire scoring,
undertone and season selection are unchanged.

### Actual Linux results and system-library requirement

Tests used a fresh virtual environment at `/opt/seasonme-test` in a local Docker
container based on `python:3.12.1-slim-bookworm` (Linux x86-64, Debian Bookworm).
The existing Windows `.venv` was not modified or copied into the container.
Only source, model, tests and a repository image fixture were copied; no Firebase
credentials were supplied to the container.

Python installation and `pip check` passed. The unmodified slim image could not
import OpenCV (`libxcb.so.1` missing); `ldd` also showed missing GL and GLib
libraries. After adding these, MediaPipe model creation exposed missing GLES/EGL
libraries. These packages were installed **only in the disposable container**:

```sh
apt-get update
apt-get install -y --no-install-recommends libxcb1 libgl1 libglib2.0-0 libgles2 libegl1
```

With these native libraries, imports and model initialization passed even from
`/tmp` with `PYTHONPATH=/app/backend`. A real face fixture (`frontend/assets/person.png`,
683 by 677 pixels) passed inference with three answer sets: fully answered,
partly skipped, and Q1-Q3 all skipped. Every returned field matched the pre-change
baseline on Linux, and all three results also matched the Windows results.
An AST comparison confirmed the analysis code differed only in the path/import.
An actual Uvicorn subprocess also started with `$PORT=10000`; HTTP `/` returned
200 and a complete multipart `/analyze` request without a token returned 401.
The subprocess was stopped after testing and its port was not published outside
the container.

The existing backend suite passed 32 tests on Linux and 32 on Windows. Auth tests
mock Firebase token verification; they do not prove live Firebase credentials or
real user tokens work on Render. MediaPipe emitted native inference warnings and
Starlette emitted an existing `httpx` deprecation warning; neither failed tests.

This proves the tested Linux environment works, **not** that Render's native
runtime has all these libraries. No Dockerfile or Render configuration has been
added. Selecting a reproducible hosting runtime remains a separate approval gate;
a Dockerfile would be an additional file requiring approval. Render Free memory,
CPU, concurrent requests, large photos and cold-start behavior are not certified
by this fixture test. Python 3.12.1 records the test baseline, not a recommendation
to keep that old patch version in a public service without further validation.

### Flutter URL and timeout selection

From `frontend`, local Android Emulator development keeps the existing URL and
30-second default timeout:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a real phone, replace that URL with the notebook's reachable LAN IP and port
8000. Verify the phone's network access, firewall and HTTP policy before an exam.
Firebase still needs internet access even when FastAPI runs locally.

After a Render URL exists, the future APK command is:

```text
flutter build apk --release --dart-define=API_BASE_URL=https://<SERVICE>.onrender.com --dart-define=API_TIMEOUT_SECONDS=120
```

`API_TIMEOUT_SECONDS` is an integer compile-time setting; omit it for 30 seconds.
Use a positive value. The timeout still covers input preparation, token retrieval,
upload and response together. It does not cancel the underlying HTTP operation
or automatically retry a request. The 120-second value is a starting setting,
not a guarantee against a cold-start timeout.

Both settings are fixed when the app is built. An installed Render APK does not
switch to Local automatically. Keep a separately labelled local build or use
`flutter run` with the Local URL for demonstrations. Preserve APK copies outside
the build output directory so a later build does not overwrite the fallback.

The existing API tests passed five tests with the default configuration; the
API/questionnaire/history/photo regression selection passed 21 tests with
`API_TIMEOUT_SECONDS=120`. Disposable virtual-clock probes verified the actual
ApiService timeout boundary at 30 and 120 seconds without waiting in real time.
No UI, API URL default, Firebase flow or camera flow was changed.

### Future Render commands (not executed)

Use Root Directory `backend`, a tested Python version, and these candidate commands:

```sh
python -m pip install -r requirements-render.txt
python -m uvicorn main:app --host 0.0.0.0 --port "$PORT" --workers 1
```

The runtime must also provide the native libraries above. Use `/` for a public
health check, but test authenticated analysis separately. Do not use `--reload`
on Render. If approved later, store Admin JSON using a Render Secret File named
`firebase-admin.json` and set:

```text
GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-admin.json
FIREBASE_PROJECT_ID=seasonme-977e3
```

The first variable is a file path, not JSON text. Never place the file in Git,
Flutter assets, container source or an image layer. Phase B does not upload it.
Real-token checks, APK/device tests, live History/Storage tests and Render cold
starts remain for later phases. No commit, push, branch change or deployment is
authorized by completing Phase B.

Local test artifacts (resolution/install reports, baseline hashes, inference JSON
and temporary probes) are in root `.render-test/`, ignored by Git. Keep tracked
`.pyc` cleanup deferred; Phase B does not remove or untrack those files.

Official references:
- https://firebase.google.com/docs/auth/admin/verify-id-tokens
- https://firebase.google.com/docs/admin/setup
