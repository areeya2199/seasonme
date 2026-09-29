import mediapipe as mp
import cv2
import numpy as np
import math


model_path = "models/face_landmarker.task"


BaseOptions = mp.tasks.BaseOptions
FaceLandmarker = mp.tasks.vision.FaceLandmarker
FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode


options = FaceLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path=model_path
    ),
    running_mode=VisionRunningMode.IMAGE
)



landmarker = FaceLandmarker.create_from_options(options)


left_cheek = [
    36, 206, 207, 187, 123,
    116, 117, 118, 119, 100
]

right_cheek = [
    266, 426, 427, 411, 352,
    345, 346, 347, 348, 329
]


def _calculate_questionnaire_scores(answers):
    score_map = {
        "0": {
            "Green": (1.0, 0.0),
            "Blue / Purple": (0.0, 1.0),
            "A mix of both": (0.5, 0.5),
        },
        "1": {
            "Gold": (1.0, 0.0),
            "Silver": (0.0, 1.0),
            "Both look fine": (0.5, 0.5),
        },
        "2": {
            "Tans easily, rarely burns": (1.0, 0.0),
            "Burns easily, rarely tans": (0.0, 1.0),
            "A little of both": (0.5, 0.5),
        },
    }

    warm_score = 0.0
    cool_score = 0.0
    answered_count = 0

    for key, answer_scores in score_map.items():
        answer = answers.get(key)
        if answer is None:
            continue
        warm_points, cool_points = answer_scores[answer]
        warm_score += warm_points
        cool_score += cool_points
        answered_count += 1

    if answered_count == 0:
        warm_question = 0.5
        cool_question = 0.5
    else:
        warm_question = warm_score / answered_count
        cool_question = cool_score / answered_count

    questionnaire_weight = 0.30 * (answered_count / 3)
    image_weight = 1.0 - questionnaire_weight

    return {
        "warm": warm_question,
        "cool": cool_question,
        "answered_count": answered_count,
        "questionnaire_weight": questionnaire_weight,
        "image_weight": image_weight,
    }


def _select_season(undertone, preference, L_star, chroma):
    if undertone == "Warm":
        if preference == "Bright & vivid":
            return "Spring"
        if preference == "Deep & rich":
            return "Autumn"

        # Soft/muted and skipped preferences use image measurements.
        if L_star > 66 and chroma >= 45:
            return "Spring"
        return "Autumn"

    if preference == "Soft & muted":
        return "Summer"
    if preference == "Deep & rich":
        return "Winter"

    # Bright/vivid and skipped preferences use image measurements.
    if L_star > 66 and chroma < 45:
        return "Summer"
    return "Winter"


def analyze_skin(image, answers):
    

    # resize
    imageresize = cv2.resize(image, (640, 680))


    # BGR RGB
    rgb_image = cv2.cvtColor(
        imageresize,
        cv2.COLOR_BGR2RGB
    )


    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=rgb_image
    )


    result = landmarker.detect(mp_image)


    if not result.face_landmarks:
        return {
            "error": "No face detected"
        }


    landmarks = result.face_landmarks[0]


    height, width, _ = imageresize.shape


    left_points = []
    right_points = []


    # left cheek
    for index in left_cheek:

        point = landmarks[index]

        x = int(point.x * width)
        y = int(point.y * height)

        left_points.append((x, y))


    # right cheek
    for index in right_cheek:

        point = landmarks[index]

        x = int(point.x * width)
        y = int(point.y * height)

        right_points.append((x, y))


    left_points_np = np.array(left_points)
    right_points_np = np.array(right_points)


    # mask
    mask = np.zeros(
        (height, width),
        dtype=np.uint8
    )


    cv2.fillPoly(
        mask,
        [left_points_np],
        255
    )

    cv2.fillPoly(
        mask,
        [right_points_np],
        255
    )


    # BGR
    mean_bgr = cv2.mean(
        imageresize,
        mask=mask
    )

    b, g, r, _ = mean_bgr



    # HSV
    hsv_image = cv2.cvtColor(
        imageresize,
        cv2.COLOR_BGR2HSV
    )

    mean_hsv = cv2.mean(
        hsv_image,
        mask=mask
    )

    hue, sat, val, _ = mean_hsv
    



    # LAB
    lab_image = cv2.cvtColor(
        imageresize,
        cv2.COLOR_BGR2Lab
    )

    mean_lab = cv2.mean(
        lab_image,
        mask=mask
    )


    l, a, b_lab, _ = mean_lab


    # convert CIELAB
    L_star = (l * 100) / 255
    a_star = a - 128
    b_star = b_lab - 128

    # Chroma
    chroma = math.sqrt(a_star**2 + b_star**2)
    # Lightness Group
    if L_star > 66:
        lightness_group = "High"
    elif L_star >= 45:
        lightness_group = "Medium"
    else:
        lightness_group = "Low"


    # Chroma Group
    if chroma >= 45:
        chroma_group = "High"
    else:
        chroma_group = "Low"

    # Hue angle

    hue_angle = math.degrees(
        math.atan2(
            b_star,
            a_star
        )
    )


    if hue_angle < 0:
        hue_angle += 360


    

    questionnaire = _calculate_questionnaire_scores(answers)

    




    if hue_angle > 60:
        image_warm = 1
        image_cool = 0
    else:
        image_warm = 0
        image_cool = 1



    warm_question = questionnaire["warm"]
    cool_question = questionnaire["cool"]
    answered_count = questionnaire["answered_count"]
    questionnaire_weight = questionnaire["questionnaire_weight"]
    image_weight = questionnaire["image_weight"]

    print("warm_question =", warm_question)
    print("cool_question =", cool_question)

# ---------------- Weighted Fusion ----------------
# Image weight starts at 70%; questionnaire weight is at most 30% and
# decreases by 10 percentage points for each skipped Q1-Q3 answer.

    warm_total = (
        image_warm * image_weight
        + warm_question * questionnaire_weight
    )
    cool_total = (
        image_cool * image_weight
        + cool_question * questionnaire_weight
    )

    print("warm_total =", warm_total)
    print("cool_total =", cool_total)
    


    if warm_total >= cool_total:
        undertone = "Warm"
    else:
        undertone = "Cool"

    print("undertone =", undertone)
    


    preference = answers.get("3")




    season = _select_season(undertone, preference, L_star, chroma)
    # # Personal Color 
    # if undertone == "Warm":

    #     if L_star > 66 and chroma >= 45:
    #         season = "Spring"
    #     else:
    #         season = "Autumn"

    # else:  # Cool

    #     if L_star > 66 and chroma < 45:
    #         season = "Summer"
    #     else:
    #         season = "Winter"
    print("season =", season)

    return {

        "undertone": undertone,

        "season": season,

        "warm_score": round(warm_total, 2),
        "cool_score": round(cool_total, 2),
        # Explicit aliases make it clear that these are the final combined
        # scores, rather than the questionnaire-only values below.
        "warm_total": round(warm_total, 2),
        "cool_total": round(cool_total, 2),

        "answered_count": answered_count,
        "questionnaire_weight": round(questionnaire_weight, 2),
        "image_weight": round(image_weight, 2),

        "questionnaire": {
        "warm": round(warm_question, 2),
        "cool": round(cool_question, 2)
    },

        "hue_angle": round(
            hue_angle,
            2
        ),

        "rgb": {
            "r": round(r,2),
            "g": round(g,2),
            "b": round(b,2)
        },

        "hsv": {
            "h": round(hue,2),
            "s": round(sat,2),
            "v": round(val,2)
        },

        "lab": {
            "L": round(L_star,2),
            "a": round(a_star,2),
            "b": round(b_star,2),
            "chroma": round(chroma,2)
        },
        "lightness_group": lightness_group,
        "chroma_group": chroma_group

    }
