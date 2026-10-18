# Storage Rules สำหรับ Analysis History

ไฟล์ชุดนี้ใช้เตรียมและทดสอบ Rules ในเครื่องเท่านั้น ไม่มีคำสั่ง deploy และไม่มี
`.firebaserc` ที่ผูกกับโปรเจกต์จริง ไม่เปลี่ยน Firestore Rules หรือโค้ดแอป

## ขอบเขต Rules

ไฟล์ `storage.rules` อนุญาตเฉพาะ object:

```
users/{uid}/analysisHistory/{historyId}/photo
```

- ต้องล็อกอิน และ UID ต้องตรงกับ `{uid}` จึงจะ get/create/update/delete ได้
- `historyId` ต้องมีเฉพาะตัวอักษร ตัวเลข `_` และ `-` ตามโค้ด Flutter ปัจจุบัน
- create/update ต้องมีขนาดมากกว่า 0 และไม่เกิน 20 MiB (20,971,520 bytes)
- MIME metadata ต้องเป็น `image/jpeg`, `image/png` หรือ `image/webp`
- delete แยกจากเงื่อนไข upload จึงไม่อ้าง `request.resource` ที่ไม่มีตอนลบ
- ไม่อนุญาต list แม้เป็นเจ้าของ เพราะแอปอ่าน path ที่ทราบจาก Firestore
- path อื่นทั้งหมดถูกปฏิเสธ รวม Saved Outfits และไฟล์ `photo.jpg`

ชื่อไฟล์ไม่มีนามสกุล ตรงกับ `ImageStorageService.pathFor()` และ SDK กำหนด
contentType ตาม bytes โดยไม่แปลงรูปก่อนอัปโหลด

Rules ตรวจ MIME metadata ไม่ได้ตรวจหรือ decode เนื้อไฟล์ว่าเป็นภาพจริง และไม่ได้
ตรวจว่า Firestore document มีอยู่ ไม่เรียก Firestore จาก Storage Rules
ขีดจำกัด 20 MiB เป็นต่อไฟล์ ไม่ใช่เพดานพื้นที่รวม จำนวนรูป หรือค่าใช้จ่าย
สิทธิ์ผู้ดูแลผ่าน IAM/Admin SDK ไม่ได้ถูกจำกัดด้วย client Security Rules เหล่านี้

## ทดสอบในเครื่อง

ใช้ Node 22, Java 21 และ Firebase CLI 14.25.1 ที่ติดตั้งอยู่บนเครื่องนี้
dependencies แยกจาก Flutter และ pin เวอร์ชันไว้ใน package-lock.json

จากโฟลเดอร์ `firebase`:

```powershell
npm ci --no-audit --no-fund
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm run test:rules
```

แก้ Java path ตามเครื่องหากใช้ JDK 21 ที่อื่น Emulator ครั้งแรกอาจต้องดาวน์โหลด
binary จาก Google โดย Firebase CLI; ไม่ต้องใช้ Admin key หรือ Firebase login

คำสั่งเริ่มเฉพาะ Storage Emulator บน loopback ใช้ project ID
`demo-seasonme-rules` และปิด Emulator เมื่อ tests จบ ไฟล์ test จะปฏิเสธการรัน
หาก `FIREBASE_STORAGE_EMULATOR_HOST` ไม่ใช่ `127.0.0.1:9199` fixtures และการ
ล้างข้อมูลทดสอบเกิดใน Emulator เท่านั้น ไม่ใช้ bucket `seasonme-977e3` จริง

ครอบคลุม 25 กรณี: เจ้าของอ่าน/เขียน/เขียนทับ/ลบ, บัญชีอื่น, ผู้ไม่ล็อกอิน,
list, path นอกขอบเขต, MIME ไม่รองรับ/ไม่ระบุ, ไฟล์ว่าง และขอบเขตขนาด
20 MiB กับ 20 MiB + 1 byte รวมถึงลบไฟล์ที่มี MIME ไม่ถูกต้องได้โดยเจ้าของ

ผลที่รันจริง: `npm run test:rules` ผ่าน 25/25 กรณี ไม่มี failed/skipped และ
Emulator ปิดสำเร็จหลัง tests จบ `node --check storage.rules.test.mjs` และ
`git diff --check -- firebase` ผ่าน ยังไม่ได้ Publish Rules หรือทดสอบแอปบน
Firebase จริงในรอบนี้

## ขั้นตอนสำหรับผู้ใช้ตรวจและ Publish เอง

1. ตรวจ project `seasonme-977e3` และ bucket
   `seasonme-977e3.firebasestorage.app` ใน Firebase Console
2. เก็บสำเนา Rules ปัจจุบันก่อนเปลี่ยน (ภาพที่ส่งมาปัจจุบันเป็น deny-all)
3. คัดลอก **เนื้อหาทั้งไฟล์ `storage.rules` เท่านั้น** ไปยัง Storage > Rules
   ไม่วาง JSON configuration หรือ test script ใน editor ของ Rules
4. ตรวจ diff และกด Publish ด้วยตนเองเมื่อต้องการเปิดสิทธิ์ตามขอบเขตนี้
5. ยืนยันชื่อ bucket และ Rules ที่ publish แล้ว ก่อนทดสอบแอปกับข้อมูลใหม่

การ Publish เปิดสิทธิ์ client ใน path ข้างต้นทันที แต่ไม่ได้อัปโหลด/ย้ายรูปเก่า
และไม่ทำให้ Firestore Rules อนุญาต schema ใหม่โดยอัตโนมัติ การทดสอบบน
โทรศัพท์จริงและการเปิดรูปข้ามอุปกรณ์ยังต้องทำแยกต่างหาก

เอกสารอ้างอิง:
- https://firebase.google.com/docs/storage/security/rules-conditions
- https://firebase.google.com/docs/rules/unit-tests
