import asyncio
import json
import unittest
from unittest.mock import patch

from fastapi import HTTPException
import numpy as np

from main import analyze, parse_answers
from services.analysis import (
    _calculate_questionnaire_scores,
    _select_season,
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

    def test_skip_q4_uses_image_fallback(self):
        self.assertEqual(_select_season("Warm", None, 70, 50), "Spring")
        self.assertEqual(_select_season("Warm", None, 60, 50), "Autumn")
        self.assertEqual(_select_season("Cool", None, 70, 40), "Summer")
        self.assertEqual(_select_season("Cool", None, 60, 40), "Winter")

    def test_skip_every_question(self):
        answers = {"0": None, "1": None, "2": None, "3": None}
        result = _calculate_questionnaire_scores(answers)

        self.assertEqual(result["answered_count"], 0)
        self.assertEqual(_select_season("Warm", answers["3"], 60, 30), "Autumn")


class QuestionnaireValidationTests(unittest.TestCase):
    def test_invalid_answer_is_rejected(self):
        with self.assertRaises(HTTPException) as context:
            parse_answers(json.dumps({"1": "Bronze"}))

        self.assertEqual(context.exception.status_code, 422)

    def test_missing_keys_are_normalized_to_null(self):
        result = parse_answers(json.dumps({"0": "Green"}))

        self.assertEqual(result, {
            "0": "Green",
            "1": None,
            "2": None,
            "3": None,
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
            "3": "Soft & muted",
        })
        expected_answers = {
            "0": None,
            "1": "Silver",
            "2": None,
            "3": "Soft & muted",
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


if __name__ == "__main__":
    unittest.main()
