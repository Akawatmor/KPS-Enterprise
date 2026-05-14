# Requirement Change / Demo Delta Strategy — Phase 2 Final

> สถานะปัจจุบัน: **Requirement change เดิมเรื่อง frontend quality gate ดำเนินการเสร็จแล้ว** และกลายเป็นส่วนหนึ่งของ baseline ใน `.woodpecker/main-push.yml` ไปแล้ว

เอกสารนี้จึงมี 2 หน้าที่พร้อมกัน

1. อธิบาย requirement change เดิมที่ทำสำเร็จแล้วอย่างชัดเจน
2. ช่วยทีมตัดสินใจว่าในวันเดโมควร “โชว์อะไร” และถ้าจำเป็นต้องมี live change ควรเลือกอะไรแทน

---

## 1. Requirement Change เดิมที่เลือกคืออะไร

Requirement change เดิมคือ

**เพิ่ม Frontend Quality Gate ใน Woodpecker Pipeline** ให้ frontend ต้องผ่าน

1. `npm run type-check`
2. `npm test -- --passWithNoTests --coverage`

ก่อนที่ pipeline จะเดินต่อไปสู่ build/push path ของ web image

เหตุผลที่เลือกหัวข้อนี้ตั้งแต่แรก เพราะมันตรงกับเกณฑ์ **small, safe, observable**

1. **Small**: เปลี่ยนเฉพาะ pipeline logic ไม่แตะ architecture หลัก
2. **Safe**: ไม่แตะ secret จริง, database หรือ infra ที่เสี่ยง
3. **Observable**: พิสูจน์ผลได้ทันทีจาก Woodpecker graph และ logs

---

## 2. ตอนนี้ change นี้อยู่ตรงไหนในระบบจริง

ใน Phase 2 Final change นี้ไม่ใช่แผนแล้ว แต่เป็น baseline ที่ active อยู่จริงใน `.woodpecker/main-push.yml`

ตำแหน่งใน pipeline คือ

1. Stage 0: `secret-scan`, `dockerfile-lint`, `k8s-lint`, `opa-policy`
2. Stage 1: `quality-backend`, `quality-frontend`
3. Stage 2: `integration-test`
4. Stage 3-10: build/push, sign/scan, DB ops, canary, verify, notify

ดังนั้นเวลาพูดหน้าห้อง ต้องพูดว่า

> “Frontend quality gate เป็นหนึ่งใน delivered improvements ที่ทำเสร็จแล้วและอยู่ใน baseline ปัจจุบัน”

ไม่ควรพูดว่า

> “วันนี้เราจะเพิ่ม frontend quality gate”

---

## 3. หลักฐานที่ใช้ยืนยันว่า requirement change นี้เสร็จจริง

### 3.1 หลักฐานใน source code

ใน `src/phase2-final/frontend/package.json` มี script ที่ pipeline เรียกใช้อยู่จริง

```json
{
  "scripts": {
    "type-check": "tsc --noEmit",
    "test": "jest",
    "test:ci": "jest --ci --coverage"
  }
}
```

### 3.2 หลักฐานใน pipeline

`quality-frontend` ใน `.woodpecker/main-push.yml` ทำงานดังนี้

1. `npm ci`
2. `npm run type-check`
3. `npm test -- --passWithNoTests --coverage`

### 3.3 หลักฐานใน UI/behavior tests

ใน `src/phase2-final/frontend/__tests__/page.test.tsx` มีชุดทดสอบพฤติกรรมที่เกี่ยวกับหน้า Big Calendar จริง เช่น

1. render layout และ header
2. navigation ระหว่างเดือน
3. day panel interactions
4. การแสดง task และสถิติ

ดังนั้น change นี้ไม่ได้เป็นเพียงการเพิ่ม step เปล่า ๆ แต่เป็นการย้าย quality control ของ frontend เข้าสู่ delivery path จริง

---

## 4. ในวันเดโมควรใช้เอกสารนี้อย่างไร

### 4.1 สิ่งที่ควรเปิดให้ดู

1. `.woodpecker/main-push.yml` ตรง Stage 1
2. `frontend/package.json`
3. Woodpecker run ล่าสุดที่มี `quality-frontend`

### 4.2 สิ่งที่ควรพูด

> “นี่คือหนึ่งใน requirement change ที่ทีมเลือกและทำเสร็จแล้ว เพราะมันยกระดับความน่าเชื่อถือของ pipeline ฝั่ง UI โดยไม่เพิ่ม blast radius สูง”

> “ดังนั้นใน Phase 2 Final สิ่งที่ควรโชว์ไม่ใช่การเพิ่มมันซ้ำ แต่โชว์ว่ามัน active อยู่จริงและทำหน้าที่เป็น gate ให้ delivery path อย่างไร”

### 4.3 สิ่งที่ไม่ควรพูด

1. อย่าพูดว่า frontend gate ยังเป็น gap
2. อย่าพูดว่า pipeline ตรวจ backend เป็นหลักเท่านั้น
3. อย่าพูดว่าเดโมวันนี้จะทำ change นี้แบบสดอีกครั้ง

---

## 5. ถ้าต้องมี live change ในวันเดโมจริง ควรเลือกอะไรแทน

เพราะ requirement change เดิมกลายเป็น baseline ไปแล้ว ถ้า reviewer ขอให้ “เปลี่ยนอะไรสักอย่าง” ควรเลือก delta ใหม่ที่ยังเล็ก ปลอดภัย และเห็นผลได้ โดยเรียงความเหมาะสมดังนี้

| ตัวเลือก | ไฟล์ที่แตะ | สิ่งที่เห็นบนจอ | เหตุผล |
|---|---|---|---|
| Frontend microcopy / release label | `src/phase2-final/frontend/...` | UI เปลี่ยนหลัง pipeline | safe และ user-facing ชัด |
| Email wording / CTA link | `.woodpecker/main-push.yml` | notification path เปลี่ยน | ไม่แตะ runtime data path |
| Documentation clarity | `document/phase2/report.md` หรือ `delivers.md` | reviewer เห็น reasoning ชัดขึ้น | ไม่มี runtime risk |

หลักสำคัญคือ

1. ต้องเป็น delta ใหม่จาก baseline ปัจจุบัน
2. rollback ง่าย
3. พิสูจน์ผลได้จริงจาก UI, pipeline, หรือเอกสารที่ใช้ประกอบการ review

---

## 6. Acceptance Criteria ของ requirement change เดิม

Requirement change เดิมถือว่า “สำเร็จแล้ว” เพราะครบตามเกณฑ์ต่อไปนี้

1. pipeline มี `quality-frontend` จริง
2. step นี้รัน type-check และ frontend tests จริง
3. web path จะไม่ผ่าน quality stage ถ้ามีปัญหาฝั่ง UI
4. ทีมสามารถชี้ evidence จาก Woodpecker UI และ source code ได้
5. requirement change นี้ถูกผนวกเป็นส่วนหนึ่งของ baseline Phase 2 Final แล้ว

---

## 7. ความเสี่ยงคงเหลือและสิ่งที่ควรต่อยอด

แม้ requirement change เดิมจะเสร็จแล้ว แต่ยังมี next steps ที่ควรพูดต่ออย่างซื่อสัตย์ เช่น

1. เพิ่ม frontend lint หรือ E2E เพื่อครอบคลุม behavior มากขึ้น
2. ทำ synthetic CRUD checks หลัง deploy ให้ลึกกว่า `/healthz`
3. เพิ่ม signature verification ก่อน promote เพื่อปิดลูป supply chain ให้ครบ
4. เพิ่ม restore drill ของ backup เพื่อให้ data safety พิสูจน์ได้จริง

---

## 8. สรุป

เอกสาร requirement change ของ Phase 2 Final ควรถูกมองเป็น **หลักฐานของการปรับปรุงที่ทำเสร็จแล้ว** ไม่ใช่รายการสิ่งที่จะทำในเดโมอีกครั้ง สิ่งที่ทีมควรทำในวันนำเสนอคือเปิดให้เห็นว่า `quality-frontend` อยู่ใน baseline จริง, ทำงานจริง, และช่วยยกระดับความน่าเชื่อถือของ delivery path อย่างไร จากนั้นถ้าจำเป็นต้องมี live change เพิ่ม ให้เลือก delta ใหม่ที่ไม่ทับกับของที่ทำเสร็จแล้ว