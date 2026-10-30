# MediaPipe ใช้หาจุดบนใบหน้า เพื่อนำพิกัดไปเลือกพื้นที่แก้ม
import mediapipe as mp
# OpenCV ใช้แปลงรูปแบบสี สร้างพื้นที่ใน Mask และหาค่าเฉลี่ยสี
import cv2
# NumPy ใช้จัดข้อมูลภาพ พิกัด และ Mask เป็นอาร์เรย์
import numpy as np
# math เป็นไลบรารีมาตรฐาน Python ใช้คำนวณมุมสีและ Chroma
import math
# Path ใช้อ้างตำแหน่งไฟล์โมเดลจากตำแหน่งไฟล์นี้
from pathlib import Path


# หาไฟล์โมเดลใน backend/models โดยไม่ขึ้นกับโฟลเดอร์ที่ใช้รันโปรแกรม
model_path = str(Path(__file__).resolve().parent.parent / "models" / "face_landmarker.task")


# ตั้งชื่อย่อให้คลาสของ MediaPipe ที่ใช้สร้างและตั้งค่าตัวตรวจจับใบหน้า
BaseOptions = mp.tasks.BaseOptions
FaceLandmarker = mp.tasks.vision.FaceLandmarker
FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
VisionRunningMode = mp.tasks.vision.RunningMode


# กำหนดไฟล์โมเดลและใช้โหมด IMAGE สำหรับวิเคราะห์ภาพนิ่ง
options = FaceLandmarkerOptions(
    base_options=BaseOptions(
        model_asset_path=model_path
    ),
    running_mode=VisionRunningMode.IMAGE
)



# โหลดโมเดลและสร้างตัวตรวจจับครั้งเดียว แล้วใช้ซ้ำเมื่อเรียกวิเคราะห์ภาพ
landmarker = FaceLandmarker.create_from_options(options)

#จุดบนใบหน้า
# รายการ index ของจุดแก้มซ้ายตามที่โค้ดกำหนด ใช้ 10 จุดล้อมพื้นที่แก้ม
left_cheek = [
    36, 206, 207, 187, 123,
    116, 117, 118, 119, 100
]

# รายการ index ของจุดแก้มขวา ใช้ 10 จุดเพื่อสร้างพื้นที่อีกฝั่ง
right_cheek = [
    266, 426, 427, 411, 352,
    345, 346, 347, 348, 329
]

#คิดคะแนนจากคำตอบของแบบสอบถาม
def _calculate_questionnaire_scores(answers):
    # รับ answers เป็น dictionary รหัส "0"–"2" คือคำถามข้อ 1–3
    # คะแนนแต่ละตัวเลือกเรียงเป็น (Warm, Cool); ข้อ 4 ไม่รวมในตารางนี้
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

    # เริ่มคะแนนสะสมและจำนวนข้อที่ตอบ โดยยังไม่คิดน้ำหนักรวมกับภาพ
    warm_score = 0.0
    cool_score = 0.0
    answered_count = 0

    for key, answer_scores in score_map.items():
        answer = answers.get(key)
        # null จาก JSON เป็น None ใน Python: Skip ทั้งคะแนนและการนับข้อนี้
        if answer is None:
            continue
        # ดึงคะแนนตามตัวเลือก แล้วสะสมคะแนนของสองฝั่งและจำนวนข้อที่ตอบ
        warm_points, cool_points = answer_scores[answer]
        warm_score += warm_points
        cool_score += cool_points
        answered_count += 1
    
    if answered_count == 0:
        # ไม่มีคำตอบให้เฉลี่ย จึงตั้งค่ากึ่งกลางเพื่อหลีกเลี่ยงการหารด้วยศูนย์
        # น้ำหนักคำตอบจะเป็น 0 ทำให้ค่ากึ่งกลางนี้ไม่มีผลต่อคะแนนรวม
        warm_question = 0.5
        cool_question = 0.5
    else:
        # หาคะแนนเฉลี่ยจากจำนวนข้อที่ตอบจริง ไม่รวมข้อที่ Skip
        warm_question = warm_score / answered_count
        cool_question = cool_score / answered_count

    
    # ตอบข้อ 1–3 ครบให้น้ำหนักคำตอบ 30%; ตอบ 2/1/0 ข้อให้ 20%/10%/0%
    questionnaire_weight = 0.30 * (answered_count / 3)
    # น้ำหนักที่เหลือเป็นของภาพ เพื่อให้น้ำหนักสองส่วนรวมกันเท่ากับ 1
    image_weight = 1.0 - questionnaire_weight

    # ส่งคะแนนเฉลี่ย จำนวนข้อที่ตอบ และน้ำหนักกลับไปใช้ใน analyze_skin()
    return {
        "warm": warm_question,
        "cool": cool_question,
        "answered_count": answered_count,
        "questionnaire_weight": questionnaire_weight,
        "image_weight": image_weight,
    }

def _select_season(undertone, preference):
    # ใช้ Undertone ร่วมกับคำตอบข้อ 4 (Bright/Muted) เลือกหนึ่งในสี่ฤดู
    # เป็นกฎของโปรเจกต์ ไม่ได้ใช้ค่า Lightness หรือ Chroma เลือกฤดูในฟังก์ชันนี้
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

    # ถ้าค่าไม่ตรงกับคู่ที่รองรับ ให้แจ้งข้อผิดพลาดแทนการเดาฤดูให้
    raise ValueError("Season requires Warm/Cool and Bright/Muted")

#วิเคราะห์ภาพ
def analyze_skin(image, answers):
    # รับ image เป็นอาร์เรย์ภาพ BGR จาก OpenCV และ answers เป็น dictionary
    # resize
    # คำสั่ง resize ด้านล่างถูกคอมเมนต์ไว้ จึงไม่ได้ย่อหรือขยายภาพในขั้นนี้
    #imageresize = cv2.resize(image, (640, 680))
    
    # convert BGR to RGB ส่งภาพไปให้ mediapipe
    # เก็บภาพที่แปลงไว้ใน rgb_image ส่วน image เดิมยังเป็น BGR สำหรับคำนวณสี
    rgb_image = cv2.cvtColor(
        image,
        cv2.COLOR_BGR2RGB
    )

    # ห่ออาร์เรย์ RGB เป็นข้อมูลภาพของ MediaPipe โดยระบุรูปแบบสีเป็น SRGB
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



    # สร้าง Mask ช่องเดียว ขนาดเท่าภาพ โดยเริ่มทุกพิกเซลเป็น 0 (สีดำ)
    # uint8 เก็บค่า 0–255; Mask ใช้เลือกพื้นที่ ไม่ได้เปลี่ยนสีภาพต้นฉบับ
    mask = np.zeros(
        (height, width),
        dtype=np.uint8
    )
    # เติมพื้นที่แก้มซ้ายและขวาด้วย 255 (สีขาว) ลงใน Mask เดียวกัน
    cv2.fillPoly(mask,[left_points_np],255)
    cv2.fillPoly(mask,[right_points_np], 255)

    # BGR
    #หาค่าเฉลี่ยของสีใน image โดยเลือกเฉพาะพื้นที่ที่กำหนดใน mask
    # cv2.mean นับเฉพาะพิกเซลที่ Mask ไม่เป็น 0 จึงไม่เฉลี่ยพื้นดำรอบแก้ม
    # ใช้พิกเซลสองแก้มรวมกัน ไม่ได้เฉลี่ยแต่ละแก้มแล้วให้น้ำหนักข้างละ 50%
    mean_bgr = cv2.mean(image,mask=mask)
    # image ยังเป็น BGR จึงรับค่าตามลำดับ b, g, r; ค่าที่สี่ไม่ได้นำมาใช้
    b, g, r, _ = mean_bgr

    # HSV
    # แปลงภาพ BGR เป็น HSV (เฉดสี ความอิ่มสี และ Value) เพื่อเก็บข้อมูลประกอบ
    hsv_image = cv2.cvtColor(image,cv2.COLOR_BGR2HSV)

    # หาค่าเฉลี่ย HSV ด้วย Mask เดิม; hue ตรงนี้ไม่ใช่ Hue Angle จาก CIELAB
    mean_hsv = cv2.mean(hsv_image,mask=mask)
    hue, sat, val, _ = mean_hsv

    # LAB
    # แปลงพิกเซลภาพเป็น Lab ก่อน แล้วหาค่าเฉลี่ยเฉพาะพื้นที่แก้ม
    lab_image = cv2.cvtColor(image,cv2.COLOR_BGR2Lab)
    mean_lab = cv2.mean(lab_image,mask=mask)
    l, a, b_lab, _ = mean_lab


    # convert CIELAB
    # คืนสเกล Lab แบบ uint8 ของ OpenCV ให้เป็น L*, a*, b* ก่อนใช้สูตร
    # L* คือความสว่าง; a* เป็นแกนเขียว–แดง; b* เป็นแกนน้ำเงิน–เหลือง
    L_star = (l * 100) / 255
    a_star = a - 128
    b_star = b_lab - 128

    # Chroma
    # หาระยะจากจุดกำเนิดบนระนาบ a*, b* เพื่อบอกขนาดความอิ่มสีแบบ Chroma
    chroma = math.sqrt(a_star**2 + b_star**2)
    # Lightness Group
    # จัดกลุ่มความสว่างไว้เป็นข้อมูลประกอบ ไม่ได้ใช้กลุ่มนี้เลือกฤดู
    if L_star > 66:
        lightness_group = "High"
    elif L_star >= 45:
        lightness_group = "Medium"
    else:
        lightness_group = "Low"


    # Chroma Group
    # จัดกลุ่ม Chroma ไว้เป็นข้อมูลประกอบ ไม่ได้ใช้แทนคำตอบ Bright/Muted
    if chroma >= 45:
        chroma_group = "High"
    else:
        chroma_group = "Low"

    # Hue angle
    # หามุมจากค่าเฉลี่ย a*, b* ของแก้มรวมกัน โดยวัดจากแกน +a*
    # atan2 รับ (y, x) จึงใส่ b_star ก่อน a_star และคืนมุมเป็นเรเดียน
    # degrees แปลงมุมเป็นองศา; ไม่ได้นำมุมของแก้มสองข้างมาเฉลี่ยกัน
    hue_angle = math.degrees(
        math.atan2(
            b_star,
            a_star
        )
    )

    # ถ้ามุมติดลบ ให้บวก 360 เพื่อปรับให้อยู่ในช่วง 0 ถึงก่อน 360 องศา
    if hue_angle < 0:
        hue_angle += 360


    

    # คำนวณคะแนนเฉลี่ยคำตอบข้อ 1–3 พร้อมน้ำหนักที่ปรับตามจำนวนข้อที่ตอบ
    questionnaire = _calculate_questionnaire_scores(answers)

    # เกณฑ์ของระบบ: มุมมากกว่า 60 ให้ภาพโหวต Warm; ไม่เกิน 60 โหวต Cool
    # เป็นคะแนน 1/0 ของภาพก่อนรวมคำตอบ ไม่ใช่เปอร์เซ็นต์ความแม่นยำ
    if hue_angle > 60:
        image_warm = 1
        image_cool = 0
    else:
        image_warm = 0
        image_cool = 1



    # ดึงข้อมูลจาก helper มาใช้รวมคะแนนภาพกับคำตอบ
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

    # คะแนนรวมแต่ละฝั่ง = คะแนนภาพ × น้ำหนักภาพ + คะแนนคำตอบเฉลี่ย × น้ำหนักคำตอบ
    # สูตรปัจจุบันให้น้ำหนักภาพอย่างน้อย 70% และภาพโหวต 1/0
    # คำตอบข้อ 1–3 จึงเปลี่ยนคะแนนรวมได้ แต่ไม่สามารถพลิกผล Warm/Cool จากภาพ
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
    


    # เปรียบเทียบคะแนนรวมเพื่อเลือก Undertone; ถ้าเสมอ เงื่อนไขนี้เลือก Warm
    if warm_total >= cool_total:
        undertone = "Warm"
    else:
        undertone = "Cool"

    print("undertone =", undertone)
    


    # รหัส "3" คือคำถามข้อ 4 รับ Bright/Muted เพื่อใช้เลือกฤดูแยกจากคะแนนข้อ 1–3
    preference = answers.get("3")




    # นำ Undertone และคำตอบข้อ 4 ไปเลือก Spring/Summer/Autumn/Winter
    season = _select_season(undertone, preference)

    print("season =", season)

    # ส่งผลเป็น dictionary ให้ FastAPI แปลงเป็น JSON กลับไปแสดงในแอป
    # ปัดค่าที่รายงานหลังคำนวณเสร็จ; คะแนนรวมเป็นคะแนนตามสูตร ไม่ใช่ความแม่นยำ
    return {

        "undertone": undertone,

        "season": season,

        # warm_score/cool_score ในผลลัพธ์นี้คือคะแนนรวมแล้ว ไม่ใช่คะแนนคำตอบอย่างเดียว
        "warm_score": round(warm_total, 2),
        "cool_score": round(cool_total, 2),
        # Explicit aliases make it clear that these are the final combined
        # scores, rather than the questionnaire-only values below.
        "warm_total": round(warm_total, 2),
        "cool_total": round(cool_total, 2),

        # จำนวนข้อที่ตอบนับเฉพาะข้อ 1–3 และรายงานน้ำหนักของทั้งภาพกับคำตอบ
        "answered_count": answered_count,
        "questionnaire_weight": round(questionnaire_weight, 2),
        "image_weight": round(image_weight, 2),

        # คะแนนคำตอบเฉลี่ยก่อนคูณน้ำหนัก แยกจาก warm_total/cool_total
        "questionnaire": {
        "warm": round(warm_question, 2),
        "cool": round(cool_question, 2)
    },

        "hue_angle": round(
            hue_angle,
            2
        ),

        # นำค่าที่อ่านจาก BGR มาเรียงรายงานเป็น R, G, B
        "rgb": {
            "r": round(r,2),
            "g": round(g,2),
            "b": round(b,2)
        },

        # รายงาน HSV แบบที่คำนวณจากภาพ uint8: H ช่วง 0–179 และ S/V ช่วง 0–255
        "hsv": {
            "h": round(hue,2),
            "s": round(sat,2),
            "v": round(val,2)
        },

        # รายงาน CIELAB ที่คืนสเกลแล้ว พร้อม Chroma และกลุ่มข้อมูลประกอบ
        "lab": {
            "L": round(L_star,2),
            "a": round(a_star,2),
            "b": round(b_star,2),
            "chroma": round(chroma,2)
        },
        "lightness_group": lightness_group,
        "chroma_group": chroma_group

    }
