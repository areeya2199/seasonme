# Camera/Upload and UI integration — 16 October 2026

## Scope and recovery points

- Original branch: `personal-color-logic`, unchanged at `aceb73f`.
- Integration branch: `codex/integrate-camera-preview-20261016-01`.
- Local working changes: all eight modified tracked files saved in snapshot commit `727ee95`.
- Snapshot branch: `codex/backup-local-20261016-01`.
- Incoming reference: `89d2938c977abfe1d3741a14dd2810ddd764df22`.
- Full repository backup: `C:\Users\Gim\seasonme-backup-20261016-integration-01`.
- Backup SHA-256 verification: 8,295 original regular files matched, including ignored files and `.git`.
- Windows did not allow recreating 13 symbolic links. Their destination content was copied and their original paths/targets recorded in `BACKUP_SYMLINKS.json` in the backup directory.
- The original 12 stash entries and their commit hashes were preserved. No reset, clean, stash deletion, force push, main-branch merge, or remote push was performed.

## Integration decisions

| Files | Incoming UI/features used | Local behavior retained | Resolution |
| --- | --- | --- | --- |
| `frontend/lib/screens/camera_screen.dart` | Android YUV three-plane conversion to NV21, sensor-oriented face dimensions, front-camera guidance, detection thresholds and diagnostics | Capture path, Questionnaire navigation, lifecycle serialization and error handling | Incoming changes merged without changing the existing capture/navigation functions |
| `frontend/lib/screens/upload_screen.dart` | Fast detector, EXIF-aware image inspection, mounted check, detection thresholds | Original selected file path and bytes, Questionnaire handoff, cancellation | Added an error message for gallery picker exceptions; image inspection does not rewrite the selected file |
| `frontend/lib/screens/home_screen.dart` | Outfit button background | History loading/Retry, route guard, refresh, server-confirmed latest Season, analysis Undertone | Only the incoming style change and whitespace change applied |
| `frontend/lib/screens/result_screen.dart` | Compact Beauty swatches, selected-color popup with name and HEX, `SwatchItem` callback | Analysis/answers/image inputs, History save/error handling, old-result no-save behavior, photo ownership, preview state and responsive layout | Resolved UI conflict hunks individually; retained responsive Day/Night and section headers; popup may grow vertically for larger text |
| `frontend/lib/services/api_service.dart` | No functional incoming API change needed | Existing URL, Firebase token, Bearer header, multipart fields, timeout and HTTP handling | Compared both versions; retained local API implementation because incoming version has no token and uses another machine's IP |
| `frontend/pubspec.yaml` | Both hair variants available as assets | Every existing dependency and asset | Removed conflict markers and duplicate hair declaration; added distinct local/remote variant paths |
| `frontend/assets/preview_face_hair*.png` | Remote hair layer is active | Local original retained as `preview_face_hair_local.png`; incoming original retained as `preview_face_hair_remote.png` | Inspected both images: incoming layer clears the ear/earring area, allowing separate recoloring |
| `frontend/lib/theme/season_card_colors.dart` | Incoming Summer gradient and Winter pill tint | Existing Season mapping | Incoming theme applied |
| `frontend/lib/screens/clothing_screen.dart` | Incoming English labels | Required Season argument and matching logic | Kept required Season while accepting text changes |

`beauty_preview.dart`, `wardrobe_preview.dart` and Login already contained the shared changes and did not need replacement. Incoming tracked Python 3.14 bytecode was retained as part of the merge; Python 3.12 source and locally saved bytecode were preserved. Bytecode is not used as the basis for source-code decisions.

## Protected logic

No changes from snapshot `727ee95` to:

- Backend `main.py`, `services/analysis.py`, `services/auth.py` and requirements.
- Questionnaire (including question 4), Processing and Profile.
- API service, Firebase Auth service and Analysis History service/schema.
- Undertone formatter, Season palette and Occasion palette.

Undertone continues to read only `analysis['undertone']`; invalid/missing values display a dash. Season continues to come from the Backend response or the selected History entry.

The existing Chroma badge describes the palette through `ColorUtils.chromaLabel`; this integration does not redefine it as the Backend `chroma_group`. History continues to store its existing fields rather than the complete response object. These existing design decisions were not changed as part of UI integration.

API contract remains `POST /analyze`, Firebase `Authorization: Bearer <ID token>`, multipart `file` and JSON-object `answers` with keys `"0"` through `"3"`, preserving null skipped answers. User confirmed Android Emulator and local Backend, so `http://10.0.2.2:8000` remains unchanged.

## Automated verification

```powershell
Set-Location C:\Users\Gim\seasonme\frontend
flutter analyze --no-pub
flutter test --no-pub

Set-Location C:\Users\Gim\seasonme\backend
.\.venv\Scripts\python.exe -B -m unittest discover -s tests -v
```

- Flutter: **64 tests passed**. Existing 57 tests preserved, finder adapted to the new Beauty swatches, one popup regression and six Upload regressions added.
- Backend: **28 tests passed**, including existing Auth and Questionnaire cases, plus actual JPEG decoding through multipart for EXIF orientations 1, 3, 6 and 8.
- Analyzer: **0 errors, 80 warning/info diagnostics**; pre-integration backup also reports 80. Warnings include existing unused/duplicate imports and deprecations. Analyzer exits nonzero because those diagnostics remain; it is not reported as clean.
- `flutter build apk --debug --no-pub`: successful.
- Dependencies unchanged; asset declarations checked for unique names and existing paths.
- Protected-source diff and conflict-marker checks performed.

Upload tests create real JPEG files on disk and check original bytes and Questionnaire path. Native picker/ML Kit boundaries are mocked in Flutter tests. Backend image tests use actual OpenCV decoding and mock Firebase verification and scoring; they do not claim native detection or real Firebase authentication coverage by themselves.

## Live Emulator verification

Device: existing `Pixel_5` AVD, package `com.example.seasonme`, updated with `adb install -r` to preserve app data. FastAPI was started locally with the existing credential file outside the repository; no token or credential was copied into source.

1. Existing Firebase session opened Home and loaded saved History.
2. Project sample `frontend/assets/person.png` was copied into the Emulator Gallery as `SeasonMeIntegration.png`.
3. Actual ML Kit accepted the selected sample and enabled Continue.
4. Questionnaire used Q1 Skip, Q2 Silver, Q3 Skip, Q4 Soft & muted.
5. Processing sent the actual request; Backend received `{"0": null, "1": "Silver", "2": null, "3": "Soft & muted"}` and returned HTTP 200 after Firebase token verification.
6. Actual scoring returned `Summer` / `Cool`; Result displayed both correctly.
7. Beauty popup displayed `Icy Blonde` and `#E3D8C2`.
8. Returning Home refreshed the latest entry to Summer/Cool dated October 16. Home's Outfit button opened Clothing with Summer after server confirmation.
9. Opening the saved Result retained Summer/Cool; local History photo count stayed at 17. One new sample-photo record was created by the successful analysis, and no History entries were deleted.
10. Camera initialized the front stream at 640x480, Android format 35 with three planes. ML Kit processed frames; background/resume reinitialized the stream and detected a face. The simulated camera reported low lighting, so successful capture under real lighting is still pending.

Read-only Firestore verification confirmed the new record contains Summer/Cool and the exact submitted answers. The active user's collection contained **10 documents before reopening the saved Result and 10 afterwards**: opening History did not create a duplicate.

## Remaining manual coverage

- Successful Camera capture with adequate lighting and actual face positioning, followed by the complete analysis flow.
- Front/back guidance across physical devices and sensor orientations, NV21 single-plane devices, camera permissions and repeated camera switching.
- Native ML Kit gallery behavior for a variety of real EXIF/mirrored photos, HEIC and multi-face images. The EXIF JPEG byte/decode tests do not cover all native formats.
- Real expired-token/credential outage, offline History Retry and switching accounts during in-flight requests. Automated boundary tests and preserved code cover parts of these, but not every live environment condition.

The integration stays on its own branch for review. Moving it into `personal-color-logic` or pushing any branch requires the user's subsequent approval.
