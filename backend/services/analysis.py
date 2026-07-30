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


def analyze_skin(image):

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



    # undertone
    if hue_angle > 60:
        undertone = "Warm"
    else:
        undertone = "Cool"

    # Personal Color 
    if undertone == "Warm":

        if L_star > 66 and chroma >= 45:
            season = "Spring"
        else:
            season = "Autumn"

    else:  # Cool

        if L_star > 66 and chroma < 45:
            season = "Summer"
        else:
            season = "Winter"



    return {

        "undertone": undertone,

        "season": season,

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