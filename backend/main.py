from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
import cv2
import numpy as np

from services.analysis import analyze_skin
from services.auth import require_firebase_user
import json

app = FastAPI()


ALLOWED_ANSWERS = {
    "3": {"Bright", "Muted"},
}


def parse_answers(raw_answers: str):
    try:
        parsed = json.loads(raw_answers)
    except json.JSONDecodeError as error:
        raise HTTPException(
            status_code=422,
            detail="answers must be valid JSON",
        ) from error

    if not isinstance(parsed, dict):
        raise HTTPException(
            status_code=422,
            detail="answers must be a JSON object",
        )

    unsupported_keys = set(parsed) - set(ALLOWED_ANSWERS)
    if unsupported_keys:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported answer keys: {sorted(unsupported_keys)}",
        )

    normalized = {}
    for key, allowed_values in ALLOWED_ANSWERS.items():
        value = parsed.get(key)
        if key == "3" and value is None:
            raise HTTPException(
                status_code=422,
                detail="Q4 (answer key 3) is required: choose Bright or Muted",
            )
        if value is not None and not isinstance(value, str):
            raise HTTPException(
                status_code=422,
                detail=f"Answer {key} must be a string",
            )
        if value is not None and value not in allowed_values:
            raise HTTPException(
                status_code=422,
                detail=f"Invalid value for answer {key}",
            )
        normalized[key] = value

    return normalized



@app.get("/")
def home():

    return {
        "message": "Skin Analysis API"
    }




@app.post("/analyze", dependencies=[Depends(require_firebase_user)])
async def analyze(
    file: UploadFile = File(...),
    answers: str = Form(...)
):
    answers = parse_answers(answers)
    contents = await file.read()
    if not contents:
        return {"error": "Invalid image"}
    np_image = np.frombuffer(
        contents,
        np.uint8
    )
    try:
        image = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
    except cv2.error:
        return {"error": "Invalid image"}
    if image is None:
        return {
            "error": "Invalid image"
        }
    result = analyze_skin(image, answers["3"])



    return result