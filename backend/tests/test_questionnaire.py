import asyncio
import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import HTTPException
from fastapi.testclient import TestClient
import numpy as np

from main import app, analyze, parse_answers
from services.auth import require_firebase_user
from services.analysis import (
    _calculate_questionnaire_scores,
    _select_season,
    analyze_skin,
    left_cheek,
    right_cheek,
)


class QuestionnaireScoringTests(unittest.TestCase):
    def test_all_undertone_questions_answered(self):
        result = _calculate_questionnaire_scores({
            "0": "Green",
            "1": "Silver",
            "2": "A little of both",
        })

        self.assertEqual(result["answered_count"], 3)
        self.assertAlmostEqual(result["warm"], 0.5)
        self.assertAlmostEqual(result["cool"], 0.5)
        self.assertAlmostEqual(result["questionnaire_weight"], 0.30)
        self.assertAlmostEqual(result["image_weight"], 0.70)

    def test_skip_q1(self):
        result = _calculate_questionnaire_scores({
            "0": None,
            "1": "Gold",
            "2": "A little of both",
        })

        self.assertEqual(result["answered_count"], 2)
        self.assertAlmostEqual(result["warm"], 0.75)
        self.assertAlmostEqual(result["cool"], 0.25)
        self.assertAlmostEqual(result["questionnaire_weight"], 0.20)
        self.assertAlmostEqual(result["image_weight"], 0.80)

    def test_skip_q2(self):
        result = _calculate_questionnaire_scores({
            "0": "Blue / Purple",
            "1": None,
            "2": "A little of both",
        })

        self.assertEqual(result["answered_count"], 2)
        self.assertAlmostEqual(result["warm"], 0.25)
        self.assertAlmostEqual(result["cool"], 0.75)

    def test_skip_q1_and_q2(self):
        result = _calculate_questionnaire_scores({
            "0": None,
            "1": None,
            "2": "Tans easily, rarely burns",
        })

        self.assertEqual(result["answered_count"], 1)
        self.assertAlmostEqual(result["warm"], 1.0)
        self.assertAlmostEqual(result["cool"], 0.0)
        self.assertAlmostEqual(result["questionnaire_weight"], 0.10)
        self.assertAlmostEqual(result["image_weight"], 0.90)

    def test_skip_all_undertone_questions(self):
        result = _calculate_questionnaire_scores({
            "0": None,
            "1": None,
            "2": None,
        })

        self.assertEqual(result["answered_count"], 0)
        self.assertAlmostEqual(result["warm"], 0.5)
        self.assertAlmostEqual(result["cool"], 0.5)
        self.assertAlmostEqual(result["questionnaire_weight"], 0.0)
        self.assertAlmostEqual(result["image_weight"], 1.0)

    def test_skip_undertone_questions_with_required_q4(self):
        answers = {"0": None, "1": None, "2": None, "3": "Muted"}
        result = _calculate_questionnaire_scores(answers)

        self.assertEqual(result["answered_count"], 0)
        self.assertEqual(_select_season("Warm", answers["3"]), "Autumn")


class SeasonSelectionTests(unittest.TestCase):
    def test_four_season_combinations(self):
        for undertone, preference, expected in [
            ("Cool", "Bright", "Winter"),
            ("Cool", "Muted", "Summer"),
            ("Warm", "Bright", "Spring"),
            ("Warm", "Muted", "Autumn"),
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

    def test_q4_changes_only_season_in_full_analysis(self):
        # Keep real image/color/scoring code; replace only face detection with
        # fixed cheek polygons so this regression does not depend on a photo.
        landmarks = [SimpleNamespace(x=0.5, y=0.5) for _ in range(478)]
        for indices in (left_cheek, right_cheek):
            for offset, index in enumerate(indices):
                angle = offset * 2 * np.pi / len(indices)
                landmarks[index] = SimpleNamespace(
                    x=0.5 + 0.2 * np.cos(angle),
                    y=0.5 + 0.2 * np.sin(angle),
                )
        detector = SimpleNamespace(
            detect=lambda _: SimpleNamespace(face_landmarks=[landmarks]),
        )
        for bgr, undertone in [((120, 170, 190), "Warm"), ((100, 100, 200), "Cool")]:
            for answered in range(4):
                answers = {"0": None, "1": None, "2": None}
                for key, value in list({
                    "0": "Green", "1": "Silver", "2": "A little of both",
                }.items())[:answered]:
                    answers[key] = value
                image = np.full((64, 64, 3), bgr, dtype=np.uint8)
                original = image.copy()
                with self.subTest(undertone=undertone, answered=answered), patch(
                    "services.analysis.landmarker", detector,
                ):
                    bright = analyze_skin(image, {**answers, "3": "Bright"})
                    muted = analyze_skin(image, {**answers, "3": "Muted"})
                    self.assertEqual(bright["undertone"], undertone)
                    self.assertEqual(bright["season"], _select_season(undertone, "Bright"))
                    self.assertEqual(muted["season"], _select_season(undertone, "Muted"))
                    self.assertEqual(
                        {k: v for k, v in bright.items() if k != "season"},
                        {k: v for k, v in muted.items() if k != "season"},
                    )
                    self.assertEqual(bright["answered_count"], answered)
                    self.assertAlmostEqual(bright["questionnaire_weight"], answered * 0.1)
                    self.assertAlmostEqual(bright["image_weight"], 1 - answered * 0.1)
                    np.testing.assert_array_equal(image, original)


class QuestionnaireValidationTests(unittest.TestCase):
    def test_invalid_answer_is_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers(json.dumps({"1": "Bronze"}))

        self.assertEqual(context.exception.status_code, 422)

    def test_missing_keys_are_normalized_to_null(self):
        result = parse_answers(json.dumps({"0": "Green", "3": "Bright"}))

        self.assertEqual(result, {
            "0": "Green",
            "1": None,
            "2": None,
            "3": "Bright",
        })

    def test_q4_is_required_and_accepts_only_canonical_values(self):
        payloads = [{}, *({"3": value} for value in [
            None, "", "bright", "muted", "Bright & vivid", "Soft & muted",
            "Deep & rich", 1, True, [], {},
        ])]
        for payload in payloads:
            with self.subTest(payload=payload), self.assertRaises(HTTPException) as context:
                parse_answers(json.dumps(payload))
            self.assertEqual(context.exception.status_code, 422)
        for value in ("Bright", "Muted"):
            self.assertEqual(parse_answers(json.dumps({"3": value})), {
                "0": None, "1": None, "2": None, "3": value,
            })

    def test_malformed_answers_are_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers("{not-json")

        self.assertEqual(context.exception.status_code, 422)

    def test_non_object_answers_are_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers(json.dumps(["Green", None, None, None]))

        self.assertEqual(context.exception.status_code, 422)

    def test_non_string_answer_is_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers(json.dumps({"0": 1}))

        self.assertEqual(context.exception.status_code, 422)

    def test_unsupported_key_is_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers(json.dumps({"4": None}))

        self.assertEqual(context.exception.status_code, 422)


class AnalyzeEndpointTests(unittest.TestCase):
    def test_null_answers_reach_analysis_as_normalized_values(self):
        class FakeUploadFile:
            async def read(self):
                return b"image-bytes"

        payload = json.dumps({
            "0": None,
            "1": "Silver",
            "2": None,
            "3": "Muted",
        })
        expected_answers = {
            "0": None,
            "1": "Silver",
            "2": None,
            "3": "Muted",
        }

        with (
            patch(
                "main.cv2.imdecode",
                return_value=np.zeros((1, 1, 3), dtype=np.uint8),
            ),
            patch(
                "main.analyze_skin",
                return_value={"season": "Summer", "undertone": "Cool"},
            ) as analyze_skin,
        ):
            result = asyncio.run(analyze(FakeUploadFile(), payload))

        self.assertEqual(result["season"], "Summer")
        self.assertEqual(analyze_skin.call_args.args[1], expected_answers)

    def test_http_rejects_missing_q4_before_decoding_or_analysis(self):
        app.dependency_overrides[require_firebase_user] = lambda: {"uid": "test-user"}
        try:
            with TestClient(app) as client, patch("main.cv2.imdecode") as decode, patch(
                "main.analyze_skin",
            ) as analysis:
                for payload in ({}, {"3": None}, {"3": "Deep & rich"}):
                    response = client.post(
                        "/analyze", files={"file": ("face.jpg", b"photo", "image/jpeg")},
                        data={"answers": json.dumps(payload)},
                    )
                    self.assertEqual(response.status_code, 422)
                decode.assert_not_called()
                analysis.assert_not_called()
        finally:
            app.dependency_overrides.pop(require_firebase_user, None)


if __name__ == "__main__":
    unittest.main()
