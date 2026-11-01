import json
import math
from pathlib import Path
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import cv2
from fastapi import HTTPException
from fastapi.testclient import TestClient
import numpy as np

from main import app, parse_answers
from services.auth import require_firebase_user
from services.analysis import (
    _classify_undertone,
    _select_season,
    analyze_skin,
    left_cheek,
    right_cheek,
)


def cheek_detector():
    landmarks = [SimpleNamespace(x=0.5, y=0.5) for _ in range(478)]
    for center, indices in ((0.3, left_cheek), (0.7, right_cheek)):
        for offset, index in enumerate(indices):
            angle = offset * 2 * np.pi / len(indices)
            landmarks[index] = SimpleNamespace(
                x=center + 0.1 * np.cos(angle),
                y=0.5 + 0.2 * np.sin(angle),
            )
    return SimpleNamespace(detect=lambda _: SimpleNamespace(face_landmarks=[landmarks]))


class ImageOnlyAnalysisTests(unittest.TestCase):
    def test_original_hue_threshold_including_exact_boundary(self):
        for angle, expected in [
            (0, "Cool"), (math.nextafter(60, 0), "Cool"), (60, "Cool"),
            (math.nextafter(60, 360), "Warm"), (90, "Warm"), (359, "Warm"),
        ]:
            with self.subTest(angle=angle):
                self.assertEqual(_classify_undertone(angle), expected)

    def test_q4_changes_only_season_in_full_analysis(self):
        for bgr, undertone in [((120, 170, 190), "Warm"), ((100, 100, 200), "Cool")]:
            image = np.full((64, 64, 3), bgr, dtype=np.uint8)
            original = image.copy()
            with self.subTest(undertone=undertone), patch(
                "services.analysis.landmarker", cheek_detector(),
            ):
                bright = analyze_skin(image, "Bright")
                muted = analyze_skin(image, "Muted")
            self.assertEqual(bright["undertone"], undertone)
            self.assertEqual(bright["season"], _select_season(undertone, "Bright"))
            self.assertEqual(muted["season"], _select_season(undertone, "Muted"))
            self.assertEqual(
                {k: v for k, v in bright.items() if k != "season"},
                {k: v for k, v in muted.items() if k != "season"},
            )
            self.assertEqual(bright["warm_score"], int(undertone == "Warm"))
            self.assertEqual(bright["cool_score"], int(undertone == "Cool"))
            self.assertEqual(bright["warm_total"], bright["warm_score"])
            self.assertEqual(bright["cool_total"], bright["cool_score"])
            self.assertTrue({
                "questionnaire", "answered_count", "questionnaire_weight", "image_weight",
            }.isdisjoint(bright))
            np.testing.assert_array_equal(image, original)

    def test_real_mediapipe_face_fixture_and_q4(self):
        image_path = Path(__file__).resolve().parents[2] / "frontend/assets/person.png"
        image = cv2.imread(str(image_path))
        self.assertIsNotNone(image)
        bright = analyze_skin(image, "Bright")
        muted = analyze_skin(image, "Muted")
        self.assertEqual(bright["undertone"], "Cool")
        self.assertEqual(bright["season"], "Winter")
        self.assertEqual(muted["season"], "Summer")
        self.assertEqual(bright["hue_angle"], muted["hue_angle"])
        self.assertEqual(bright["lab"], muted["lab"])

    def test_real_mediapipe_blank_image_has_no_face(self):
        self.assertEqual(
            analyze_skin(np.zeros((64, 64, 3), dtype=np.uint8), "Bright"),
            {"error": "No face detected"},
        )

    def test_missing_q4_never_selects_a_season(self):
        with patch("services.analysis.landmarker", cheek_detector()):
            with self.assertRaises(ValueError):
                analyze_skin(np.full((64, 64, 3), 128, dtype=np.uint8), None)


class SeasonSelectionTests(unittest.TestCase):
    def test_four_season_combinations(self):
        for undertone, preference, expected in [
            ("Cool", "Bright", "Winter"), ("Cool", "Muted", "Summer"),
            ("Warm", "Bright", "Spring"), ("Warm", "Muted", "Autumn"),
        ]:
            with self.subTest(undertone=undertone, preference=preference):
                self.assertEqual(_select_season(undertone, preference), expected)

    def test_invalid_inputs_have_no_fallback_season(self):
        for undertone, preference in [
            ("Warm", None), ("Cool", "Deep & rich"), ("Neutral", "Bright"),
        ]:
            with self.subTest(undertone=undertone, preference=preference):
                with self.assertRaises(ValueError):
                    _select_season(undertone, preference)


class QuestionnaireValidationTests(unittest.TestCase):
    def test_only_q4_is_required_and_preserves_key_3(self):
        for value in ("Bright", "Muted"):
            self.assertEqual(parse_answers(json.dumps({"3": value})), {"3": value})

    def test_q4_accepts_only_canonical_values(self):
        for payload in [{}, *({"3": value} for value in [
            None, "", "bright", "muted", "Bright & vivid", "Soft & muted",
            "Deep & rich", 1, True, [], {},
        ])]:
            with self.subTest(payload=payload), self.assertRaises(HTTPException) as context:
                parse_answers(json.dumps(payload))
            self.assertEqual(context.exception.status_code, 422)

    def test_removed_questions_are_rejected_even_when_null(self):
        for key in ("0", "1", "2", "4"):
            for value in (None, "Green"):
                with self.subTest(key=key, value=value), self.assertRaises(HTTPException) as context:
                    parse_answers(json.dumps({"3": "Bright", key: value}))
                self.assertEqual(context.exception.status_code, 422)

    def test_malformed_or_non_object_answers_are_rejected(self):
        for raw in ("{not-json", "null", "[]", '"Bright"', "42"):
            with self.subTest(raw=raw), self.assertRaises(HTTPException) as context:
                parse_answers(raw)
            self.assertEqual(context.exception.status_code, 422)


class AnalyzeEndpointTests(unittest.TestCase):
    def setUp(self):
        app.dependency_overrides[require_firebase_user] = lambda: {"uid": "test-user"}
        self.addCleanup(app.dependency_overrides.pop, require_firebase_user, None)
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def post_image(self, contents=b"photo", answers=None):
        return self.client.post(
            "/analyze", files={"file": ("face.png", contents, "image/png")},
            data={"answers": json.dumps({"3": "Bright"} if answers is None else answers)},
        )

    def test_only_q4_value_reaches_analysis(self):
        image = np.zeros((64, 64, 3), dtype=np.uint8)
        with patch("main.cv2.imdecode", return_value=image), patch(
            "main.analyze_skin", return_value={"season": "Summer", "undertone": "Cool"},
        ) as analysis:
            response = self.post_image(answers={"3": "Muted"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"season": "Summer", "undertone": "Cool"})
        self.assertIs(analysis.call_args.args[0], image)
        self.assertEqual(analysis.call_args.args[1], "Muted")

    def test_http_rejects_missing_invalid_q4_and_removed_keys_before_decoding(self):
        with patch("main.cv2.imdecode") as decode, patch("main.analyze_skin") as analysis:
            for payload in ({}, {"3": None}, {"3": "Deep & rich"}, *(
                {"3": "Bright", key: None} for key in ("0", "1", "2")
            )):
                with self.subTest(payload=payload):
                    self.assertEqual(self.post_image(answers=payload).status_code, 422)
            decode.assert_not_called()
            analysis.assert_not_called()

    def test_missing_image_or_answers_is_422(self):
        with patch("main.analyze_skin") as analysis:
            self.assertEqual(self.client.post(
                "/analyze", data={"answers": json.dumps({"3": "Bright"})},
            ).status_code, 422)
            self.assertEqual(self.client.post(
                "/analyze", files={"file": ("face.png", b"photo", "image/png")},
            ).status_code, 422)
            analysis.assert_not_called()

    def test_empty_corrupt_and_truncated_images_keep_error_contract(self):
        with patch("main.analyze_skin") as analysis:
            for contents in (b"", b"not an image", bytes.fromhex("89504e470d0a1a0a")):
                with self.subTest(contents=contents):
                    response = self.post_image(contents)
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(response.json(), {"error": "Invalid image"})
            analysis.assert_not_called()

    def test_opencv_decode_exception_is_an_invalid_image(self):
        with patch("main.cv2.imdecode", side_effect=cv2.error("decode failed")), patch(
            "main.analyze_skin",
        ) as analysis:
            response = self.post_image()
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), {"error": "Invalid image"})
            analysis.assert_not_called()

    def test_http_no_face_preserves_error_contract(self):
        _, encoded = cv2.imencode(".png", np.zeros((64, 64, 3), dtype=np.uint8))
        response = self.post_image(encoded.tobytes())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"error": "No face detected"})

    def test_decode_color_pipeline_and_season_mapping_over_multipart(self):
        for bgr, preference, undertone, season in [
            ((120, 170, 190), "Bright", "Warm", "Spring"),
            ((120, 170, 190), "Muted", "Warm", "Autumn"),
            ((100, 100, 200), "Bright", "Cool", "Winter"),
            ((100, 100, 200), "Muted", "Cool", "Summer"),
        ]:
            _, encoded = cv2.imencode(".png", np.full((64, 64, 3), bgr, dtype=np.uint8))
            with self.subTest(season=season), patch(
                "services.analysis.landmarker", cheek_detector(),
            ):
                response = self.post_image(encoded.tobytes(), {"3": preference})
            self.assertEqual(response.status_code, 200)
            result = response.json()
            self.assertEqual(result["undertone"], undertone)
            self.assertEqual(result["season"], season)
            self.assertEqual(result["rgb"], dict(zip(("b", "g", "r"), bgr)))


if __name__ == "__main__":
    unittest.main()
