"""Exercise actual JPEG decoding and multipart answers without changing scoring."""

import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch, sentinel

import cv2
from fastapi.testclient import TestClient
import numpy as np

from main import app


class UploadImageOrientationTests(unittest.TestCase):
    def test_original_exif_jpegs_reach_analysis_upright_with_answers(self):
        raw = np.full((200, 120, 3), 128, dtype=np.uint8)
        raw[:50, :30] = (110, 120, 170)
        encoded, jpeg = cv2.imencode(".jpg", raw)
        self.assertTrue(encoded)
        original = jpeg.tobytes()
        decoded = cv2.imdecode(jpeg, cv2.IMREAD_COLOR)
        answers = {"0": None, "1": "Silver", "2": None, "3": "Muted"}

        with (
            tempfile.TemporaryDirectory(prefix="seasonme-upload-") as directory,
            patch("services.auth._get_firebase_app", return_value=sentinel.app),
            patch("services.auth.auth.verify_id_token", return_value={"uid": "test-user"}),
            TestClient(app) as client,
        ):
            for orientation, rotation in [
                (1, None),
                (3, cv2.ROTATE_180),
                (6, cv2.ROTATE_90_CLOCKWISE),
                (8, cv2.ROTATE_90_COUNTERCLOCKWISE),
            ]:
                with self.subTest(orientation=orientation):
                    tiff = b"II" + struct.pack("<HIH", 42, 8, 1)
                    tiff += struct.pack("<HHI", 0x0112, 3, 1)
                    tiff += struct.pack("<H", orientation) + b"\0\0" + struct.pack("<I", 0)
                    exif = b"Exif\0\0" + tiff
                    contents = original[:2] + b"\xff\xe1" + struct.pack(">H", len(exif) + 2) + exif + original[2:]
                    file = Path(directory) / f"orientation-{orientation}.jpg"
                    file.write_bytes(contents)
                    expected = decoded if rotation is None else cv2.rotate(decoded, rotation)

                    def analyze_image(image, received_answers):
                        np.testing.assert_array_equal(image, expected)
                        self.assertEqual(received_answers, answers)
                        return {"season": "Summer", "undertone": "Cool"}

                    with patch("main.analyze_skin", side_effect=analyze_image) as analyze:
                        response = client.post(
                            "/analyze",
                            headers={"Authorization": "Bearer test-token"},
                            files={"file": (file.name, file.read_bytes(), "image/jpeg")},
                            data={"answers": json.dumps(answers)},
                        )
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(response.json(), {"season": "Summer", "undertone": "Cool"})
                    analyze.assert_called_once()
                    self.assertEqual(file.read_bytes(), contents)
