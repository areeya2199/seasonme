from fastapi import FastAPI, UploadFile, File, Form, HTTPException
import cv2
import numpy as np

from services.analysis import analyze_skin
import json

app = FastAPI()


ALLOWED_ANSWERS = {
    "0": {"Blue / Purple", "Green", "A mix of both"},
    "1": {"Gold", "Silver", "Both look fine"},
    "2": {
        "Tans easily, rarely burns",
        "Burns easily, rarely tans",
        "A little of both",
    },
    "3": {"Bright & vivid", "Soft & muted", "Deep & rich"},
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
        if value is not None and not isinstance(value, str):
            raise HTTPException(
                status_code=422,
                detail=f"Answer {key} must be a string or null",
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




@app.post("/analyze")
async def analyze(
    file: UploadFile = File(...),
    answers: str = Form(...)
):
    answers = parse_answers(answers)

    print(answers)

    contents = await file.read()


    np_image = np.frombuffer(
        contents,
        np.uint8
    )


    image = cv2.imdecode(
        np_image,
        cv2.IMREAD_COLOR
    )


    if image is None:

        return {
            "error": "Invalid image"
        }


    print("ANSWER:", answers)
    
    result = analyze_skin(image, answers)


    return result
