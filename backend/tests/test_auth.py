import json
import unittest
from unittest.mock import patch, sentinel

from fastapi.testclient import TestClient
from firebase_admin import auth
from google.auth.exceptions import DefaultCredentialsError
import numpy as np

from main import app
from services.auth import _get_firebase_app


class AuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        self.firebase_app = patch(
            "services.auth._get_firebase_app", return_value=sentinel.firebase_app
        ).start()
        self.verify = patch("services.auth.auth.verify_id_token").start()
        self.decode = patch(
            "main.cv2.imdecode", return_value=np.zeros((1, 1, 3), dtype=np.uint8)
        ).start()
        self.analysis_result = {
            "season": "Summer", "undertone": "Cool",
            "warm_score": 0.15, "cool_score": 0.85,
            "warm_total": 0.15, "cool_total": 0.85,
            "answered_count": 3, "questionnaire_weight": 0.3,
            "image_weight": 0.7, "questionnaire": {"warm": 0.5, "cool": 0.5},
            "hue_angle": 50.0, "rgb": {"r": 190, "g": 150, "b": 140},
            "hsv": {"h": 10, "s": 60, "v": 190},
            "lab": {"L": 70, "a": 12, "b": 14, "chroma": 18.44},
            "lightness_group": "High", "chroma_group": "Low",
        }
        self.analysis = patch(
            "main.analyze_skin", return_value=self.analysis_result
        ).start()
        self.addCleanup(patch.stopall)

    def post_analysis(self, authorization=None):
        headers = {} if authorization is None else {"Authorization": authorization}
        return self.client.post(
            "/analyze",
            headers=headers,
            files={"file": ("face.jpg", b"image-bytes", "image/jpeg")},
            data={"answers": json.dumps({"1": "Silver"})},
        )

    def assert_blocked(self, response, status=401):
        self.assertEqual(response.status_code, status)
        if status == 401:
            self.assertEqual(response.headers["www-authenticate"], "Bearer")
        self.decode.assert_not_called()
        self.analysis.assert_not_called()

    def test_missing_token_is_unauthorized(self):
        self.assert_blocked(self.post_analysis())
        self.firebase_app.assert_not_called()
        self.verify.assert_not_called()

    def test_malformed_authorization_is_unauthorized(self):
        for header in ("Basic abc", "Bearer", "Bearer ", "not-a-scheme"):
            with self.subTest(header=header):
                self.assert_blocked(self.post_analysis(header))
        self.firebase_app.assert_not_called()
        self.verify.assert_not_called()

    def test_invalid_token_is_unauthorized(self):
        self.verify.side_effect = auth.InvalidIdTokenError("Invalid token")
        self.assert_blocked(self.post_analysis("Bearer invalid-token"))
        self.verify.assert_called_once_with("invalid-token", app=sentinel.firebase_app)

    def test_expired_token_is_unauthorized(self):
        self.verify.side_effect = auth.ExpiredIdTokenError("Expired token", None)
        self.assert_blocked(self.post_analysis("Bearer expired-token"))

    def test_wrong_project_token_is_unauthorized(self):
        self.verify.side_effect = auth.InvalidIdTokenError("Incorrect audience")
        self.assert_blocked(self.post_analysis("Bearer wrong-project-token"))

    def test_valid_token_preserves_analysis_json_and_answers(self):
        self.verify.return_value = {"uid": "test-user"}
        response = self.post_analysis("Bearer valid-token")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), self.analysis_result)
        self.verify.assert_called_once_with("valid-token", app=sentinel.firebase_app)
        self.decode.assert_called_once()
        self.analysis.assert_called_once()
        self.assertEqual(
            self.analysis.call_args.args[1],
            {"0": None, "1": "Silver", "2": None, "3": None},
        )

    def test_valid_token_still_enforces_answer_validation(self):
        self.verify.return_value = {"uid": "test-user"}
        response = self.client.post(
            "/analyze", headers={"Authorization": "Bearer valid-token"},
            files={"file": ("face.jpg", b"image-bytes", "image/jpeg")},
            data={"answers": "not-json"},
        )
        self.assert_blocked(response, status=422)
        self.verify.assert_called_once()

    def test_missing_credentials_fail_closed(self):
        self.firebase_app.side_effect = DefaultCredentialsError("No credentials")
        self.assert_blocked(self.post_analysis("Bearer test-token"), status=503)
        self.verify.assert_not_called()

    def test_lazy_credential_failure_during_verification_fails_closed(self):
        self.verify.side_effect = DefaultCredentialsError("No credentials")
        self.assert_blocked(self.post_analysis("Bearer test-token"), status=503)

    def test_certificate_fetch_failure_fails_closed(self):
        self.verify.side_effect = auth.CertificateFetchError("Unavailable", None)
        self.assert_blocked(self.post_analysis("Bearer test-token"), status=503)

    def test_health_check_is_public_without_credentials(self):
        self.firebase_app.side_effect = DefaultCredentialsError("No credentials")
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"message": "Skin Analysis API"})
        self.firebase_app.assert_not_called()
        self.verify.assert_not_called()
        self.analysis.assert_not_called()


class FirebaseInitializationTests(unittest.TestCase):
    def test_existing_app_is_reused(self):
        with (
            patch("services.auth.firebase_admin.get_app", return_value=sentinel.app),
            patch("services.auth.firebase_admin.initialize_app") as initialize,
        ):
            self.assertIs(_get_firebase_app(), sentinel.app)
            initialize.assert_not_called()

    def test_adc_initialization_uses_configured_project(self):
        with (
            patch.dict("os.environ", {"FIREBASE_PROJECT_ID": "test-project"}),
            patch("services.auth.firebase_admin.get_app", side_effect=ValueError),
            patch("services.auth.firebase_admin.initialize_app", return_value=sentinel.app)
            as initialize,
        ):
            self.assertIs(_get_firebase_app(), sentinel.app)
            initialize.assert_called_once_with(
                options={"projectId": "test-project"}, name="seasonme-api"
            )


if __name__ == "__main__":
    unittest.main()
