from fastapi import FastAPI, UploadFile, File
import cv2
import numpy as np

from services.analysis import analyze_skin
from fastapi import Form
import json

app = FastAPI()



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
    answers = json.loads(answers)

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


    result = analyze_skin(image, answers)


    return result