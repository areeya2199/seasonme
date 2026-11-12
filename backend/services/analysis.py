import mediapipe as mp
import cv2
import numpy as np
import math
from pathlib import Path


model_path = str(Path(__file__).resolve().parent.parent / "models" / "face_landmarker.task")



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

#จุดบนใบหน้า
left_cheek = [
    36, 206, 207, 187, 123,
    116, 117, 118, 119, 100
]


right_cheek = [
    266, 426, 427, 411, 352,
    345, 346, 347, 348, 329
]

def _classify_undertone(hue_angle):
    if hue_angle > 60:
        return "Warm"
    else:
        return "Cool"


def _select_season(undertone, preference):
   
    if undertone == "Cool":
        if preference == "Bright":
            return "Winter"
        elif preference == "Muted":
            return "Summer"

    elif undertone == "Warm":
        if preference == "Bright":
            return "Spring"
        elif preference == "Muted":
            return "Autumn"

   
    raise ValueError("Season requires Warm/Cool and Bright/Muted")

#วิเคราะห์ภาพ
def analyze_skin(image, preference):

    # convert BGR to RGB ส่งภาพไปให้ mediapipe
    # เก็บภาพที่แปลงไว้ใน rgb_image ส่วน image เดิมยังเป็น BGR สำหรับคำนวณสี
    rgb_image = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2RGB
    )


    mp_image = mp.Image(
        image_format=mp.ImageFormat.SRGB,
        data=rgb_image
    )

    # ส่งภาพให้โมเดลหาพิกัดจุดบนใบหน้า ผลอยู่ใน result.face_landmarks
    result = landmarker.detect(mp_image)

    #ตรวจสอบว่ามีใบหน้า
    if not result.face_landmarks:
        return {
            "error": "No face detected"
        }


    # เลือกชุดจุดของใบหน้าแรกที่ผลตรวจจับส่งกลับมา
    landmarks = result.face_landmarks[0]


    # อ่านความสูงและความกว้าง เพื่อใช้เปลี่ยนพิกัดจุดใบหน้าเป็นพิกเซล
    height, width, _ = image.shape


    # เก็บตำแหน่งพิกเซลที่จะใช้เป็นขอบพื้นที่แก้มแต่ละฝั่ง
    left_points = []
    right_points = []


    # left cheek เก็บพิกัดของจุดบนแก้มซ้าย
    for index in left_cheek:

        point = landmarks[index]

        # พิกัดจาก MediaPipe เป็นสัดส่วนภาพ จึงคูณขนาดภาพแล้วแปลงเป็นจำนวนเต็ม
        x = int(point.x * width)
        y = int(point.y * height)

        left_points.append((x, y))


    # right cheek เก็บพิกัดของจุดบนแก้มขวา
    for index in right_cheek:

        point = landmarks[index]

        # แปลงจุดแก้มขวาเป็นพิกเซลด้วยวิธีเดียวกับแก้มซ้าย
        x = int(point.x * width)
        y = int(point.y * height)

        right_points.append((x, y))


    # เปลี่ยนรายการพิกัดเป็นอาร์เรย์ NumPy เพื่อส่งให้ OpenCV เติมพื้นที่
    left_points_np = np.array(left_points)
    right_points_np = np.array(right_points)
    


    
    mask = np.zeros(
        (height, width),
        dtype=np.uint8
    )
    # เติมพื้นที่แก้มซ้ายและขวาด้วย 255 (สีขาว) ลงใน Mask เดียวกัน
    cv2.fillPoly(mask,[left_points_np],255)
    cv2.fillPoly(mask,[right_points_np], 255)

    # BGR
    #หาค่าเฉลี่ยของสีใน image โดยเลือกเฉพาะพื้นที่ที่กำหนดใน mask
   
    mean_bgr = cv2.mean(image,mask=mask)
    # image ยังเป็น BGR จึงรับค่าตามลำดับ b, g, r; ค่าที่สี่ไม่ได้นำมาใช้
    b, g, r, _ = mean_bgr

    # HSV
   
    hsv_image = cv2.cvtColor(image,cv2.COLOR_BGR2HSV)

  
    mean_hsv = cv2.mean(hsv_image,mask=mask)
    hue, sat, val, _ = mean_hsv

    # LAB
    # แปลงพิกเซลภาพเป็น Lab ก่อน แล้วหาค่าเฉลี่ยเฉพาะพื้นที่แก้ม
    lab_image = cv2.cvtColor(image,cv2.COLOR_BGR2Lab)
    mean_lab = cv2.mean(lab_image,mask=mask)
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
    


    

    undertone = _classify_undertone(hue_angle)
    image_warm = int(undertone == "Warm")
    image_cool = int(undertone == "Cool")

    
    season = _select_season(undertone, preference)

    return {
        "undertone": undertone,
        "season": season,
        
        "warm_score": image_warm,
        "cool_score": image_cool,
        "warm_total": image_warm,
        "cool_total": image_cool,

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
