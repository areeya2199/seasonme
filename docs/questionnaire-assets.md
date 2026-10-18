# SeasonMe Questionnaire: images and palettes

The Flutter screen follows the approved `color-quiz-mockup.html` design. Q1–Q3
currently show labeled image placeholders. No new photographs were bundled or
downloaded. Existing image-picking, camera, result and history behavior is retained.

## Add your example images later

1. Create `frontend/assets/questionnaire/` when your images are ready.
2. Add these exact, case-sensitive filenames (or update each option's `imageAsset`
   in `frontend/lib/screens/questionnaire_screen.dart` if you choose another name):

| Question | Answer | Filename |
| --- | --- | --- |
| Q1 | Blue / Purple | `q1_veins_blue_purple.jpg` |
| Q1 | Green | `q1_veins_green.jpg` |
| Q1 | A mix of both | `q1_veins_mixed.jpg` |
| Q2 | Gold | `q2_jewelry_gold.jpg` |
| Q2 | Silver | `q2_jewelry_silver.jpg` |
| Q3 | Tans easily, rarely burns | `q3_skin_tans.jpg` |
| Q3 | Burns easily, rarely tans | `q3_skin_burns.jpg` |

3. Under the existing `flutter: assets:` list in `frontend/pubspec.yaml`, add
   `- assets/questionnaire/` at the same indentation as the other asset entries.
   Keep every existing asset, font and dependency. Do not declare a nonexistent
   folder before you add the files. Run `flutter pub get` and restart the app.
4. The screen already uses `Image.asset(option.imageAsset, fit: BoxFit.cover)`.
   For example, the first option refers to
   `assets/questionnaire/q1_veins_blue_purple.jpg`. Missing/invalid examples fall
   back to placeholders. A `.png` file needs a matching `.png` path in the option.

Q2 uses just the Gold and Silver images side by side. The third answer, **Both
look fine**, remains selectable and refers to those same two examples; it does
not need a separate image.

Q3 likewise uses only the tanning and burning examples. **A little of both**
remains an answer for someone whose skin can both burn and tan depending on the
situation; no `q3_skin_both.jpg` is needed.

Use comparable crops and an aspect ratio close to square. Examples appear above
the answer cards, labeled for their matching answers. They are visual references
only: Q1–Q3 API answer strings and undertone scoring are unchanged.

## Q4 uses only the user's original photo

Gallery and Camera both pass their original file path into
`QuestionnaireScreen.imagePath`. On Q4, `AnalysisInput.validatePhoto` reads that
file, checks that it decodes, and returns its original encoded bytes. The preview
uses `Image.memory` with those bytes. Cropping affects display only.

Before Finish, the source is checked again and compared with the preview bytes;
a changed file cannot be analyzed without choosing the photo again.
Processing passes the same path to
ApiService, which validates the required answer and reads/validates the source
again. Multipart attaches those exact validated bytes with the original filename.
No resizing, re-encoding, EXIF rewriting or file overwrite is performed. Missing,
empty and corrupt photos show an error and cannot be submitted. No asset/sample
photo is used as a replacement.

## Replace the temporary palettes

In `frontend/lib/screens/questionnaire_screen.dart`, replace `_brightPalette`
and `_mutedPalette` with the owner's final colors, exactly six `Color(0xFFRRGGBB)`
entries per list. The initial five colors follow the mockup and the sixth entries
are temporary additions. The UI labels these as **Sample palettes** until final
colors are supplied. Remove/update that label when the final palettes are approved.

Both the six swatches under the photo and the corresponding answer-card swatches
use the same lists. All six change immediately on selection; the photo stays the
same. Initially six neutral slots are shown and neither answer is selected. A
preview is never counted as a user's answer. These lists are independent of
`season_palette.dart` and do not change Result, Clothing or Backend calculations.

## API contract and history compatibility

`POST /analyze` keeps Firebase Bearer authentication and multipart fields `file`
and `answers`. The latter is a JSON string with string keys `0`, `1`, `2`, `3`.
Q1–Q3 may be null; Q4 must be exactly `Bright` or `Muted`.

```json
{"0":null,"1":"Silver","2":null,"3":"Bright"}
```

Only season selection changes: Cool/Bright → Winter, Cool/Muted → Summer,
Warm/Bright → Spring, Warm/Muted → Autumn. Image analysis, undertone, score
weights, thresholds and response field names remain unchanged.

Existing history is not migrated or recalculated. Old Q4 strings/nulls remain
readable; new-request validation is not applied to stored documents. Storage
schema version, authentication, photo retry and Saved Outfits remain unchanged.

Update Flutter and Backend together: the old Backend rejects the new Q4 values,
and the new Backend rejects old/omitted Q4 values on new analysis requests.

## Manual check with the final images/colors

- Use Gallery and Camera on a device; confirm Q4 shows the selected/captured face.
- Toggle Bright/Muted; confirm six swatches change while the face stays fixed.
- Confirm Q1–Q3 Skip works and Q4 has no Skip or automatic answer.
- Test missing/unreadable source: Finish must not start analysis.
- Analyze, reopen History, and verify saved season/undertone/Q4/photo; retry a
  failed photo upload and check that no duplicate history record is created.
- Open an older history record and check Home/Profile/Clothing still use its
  saved season. Do not recompute old records using the new mapping.
