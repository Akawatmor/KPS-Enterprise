# Requirement Change / Change Request สำหรับ Phase 2 (Woodpecker)

## 1. หัวข้อที่เลือก

**เพิ่ม Frontend Quality Gate ใน Woodpecker Pipeline** โดยบังคับให้ frontend ต้องผ่าน

1. `npm run type-check`
2. `npm run test:ci`

ก่อนถึงขั้น `build-push-web`

## 2. เหตุผลที่เลือกหัวข้อนี้

หัวข้อนี้ตรงตามเงื่อนไขของ requirement change ที่โจทย์กำหนดอย่างชัดเจน คือ **small, safe, observable**

### 2.1 Small

เป็นการเปลี่ยนแปลงเล็ก เพราะไม่ต้องเปลี่ยน architecture หลักของระบบ ไม่ต้องเพิ่ม VM ไม่ต้องแก้ Kubernetes resource จำนวนมาก และไม่กระทบ data path ของ production โดยตรง

สิ่งที่เพิ่มมีเพียง

1. เพิ่ม pipeline step ใหม่ 1 step
2. เพิ่ม dependency ให้ `build-push-web` รอ step นี้ผ่านก่อน
3. ใช้สคริปต์ที่มีอยู่แล้วใน `frontend/package.json`

### 2.2 Safe

การเปลี่ยนแปลงนี้ปลอดภัย เพราะ

1. ไม่ลบ resource
2. ไม่แตะ production credential จริง
3. ไม่ต้องรัน `terraform destroy`
4. ไม่เพิ่มค่าใช้จ่ายโครงสร้างพื้นฐานอย่างมีนัยสำคัญ
5. หาก step ใหม่มีปัญหา สามารถ revert pipeline change กลับได้ทันที

### 2.3 Observable

ผลของการเปลี่ยนแปลงเห็นได้ชัดผ่าน Woodpecker UI และ pipeline log ทันที

1. ถ้า frontend มี type error หรือ test fail จะเห็น pipeline หยุดที่ step ใหม่
2. ถ้าทุกอย่างผ่าน จะเห็นว่า pipeline ดำเนินต่อไปจน build, push และ deploy สำเร็จ
3. ทีมสามารถสาธิตความเปลี่ยนแปลงนี้ได้ภายในเวลาไม่นาน เพราะใช้การ push code เพียง 1 ครั้ง

## 3. สถานะปัจจุบันของระบบที่เกี่ยวข้องกับ change นี้

ใน Phase 2 ปัจจุบัน pipeline หลักของ Woodpecker มี flow โดยย่อดังนี้

1. `test-backend`
2. `build-push-core`
3. `build-push-web`
4. `deploy-k3s`
5. `notify-email`

จุดที่น่าสังเกตคือ frontend ใน repo มีความพร้อมสำหรับ quality gate อยู่แล้ว แต่ยัง **ไม่ได้ถูกบังคับใน pipeline**

### 3.1 หลักฐานจาก source code

ใน `src/phase2-final/frontend/package.json` มี script อยู่แล้ว

```json
{
	"scripts": {
		"type-check": "tsc --noEmit",
		"test": "jest",
		"test:ci": "jest --ci --coverage"
	}
}
```

และใน `src/phase2-final/frontend/__tests__/page.test.tsx` มีชุดทดสอบพฤติกรรมของหน้า Big Calendar จริง เช่น

1. ตรวจว่า render header ได้
2. ตรวจว่าแสดง weekday ครบ
3. ตรวจ navigation เปลี่ยนเดือน
4. ตรวจ panel เปิดเมื่อคลิกวัน
5. ตรวจการแสดง task และสถิติ

ดังนั้นความเสี่ยงปัจจุบันคือ

> frontend อาจมี regression เชิง type หรือเชิงพฤติกรรม แต่ยัง build image และ deploy ได้ เพราะ pipeline ปัจจุบันตรวจเฉพาะ backend เป็นหลัก

## 4. ปัญหาหรือความเสี่ยงที่ change นี้ต้องการแก้

### 4.1 ปัญหาเชิงคุณภาพ

เมื่อ pipeline บังคับแค่ backend test ทีมจะยังมี blind spot ฝั่ง frontend เช่น

1. TypeScript error ที่หลุดมาจากการ refactor component
2. UI behavior สำคัญพัง เช่น calendar navigation, stats bar, panel interaction
3. API contract ระหว่าง frontend กับ backend เปลี่ยนแล้ว frontend ไม่รองรับ

### 4.2 ผลกระทบถ้าไม่แก้

1. pipeline อาจขึ้นสีเขียวแม้ frontend มีปัญหา
2. image ใหม่อาจถูก deploy แล้วแต่ผู้ใช้ใช้งานจริงไม่ได้ตามคาด
3. ความเชื่อมั่นต่อ pipeline ลดลง เพราะ pipeline ไม่ครอบคลุมความเสี่ยงหลักของระบบฝั่ง UI

## 5. รายละเอียดของ change request ที่เสนอ

### 5.1 ข้อเสนอหลัก

เพิ่ม step ใหม่ชื่อ เช่น `test-frontend` ใน Woodpecker pipeline โดยให้รันก่อน `build-push-web`

ตัวอย่างแนวคิดของ step

```yaml
- name: test-frontend
	image: node:22-bookworm-slim
	commands:
		- cd src/phase2-final/frontend
		- npm ci
		- npm run type-check
		- npm run test:ci
```

และปรับ dependency ของ `build-push-web` ให้ขึ้นกับ `test-frontend`

```yaml
- name: build-push-web
	depends_on:
		- test-frontend
```

### 5.2 สิ่งที่ change นี้ “ไม่” ทำ

เพื่อให้ยังคงเล็กและปลอดภัย Change นี้จะไม่ทำสิ่งต่อไปนี้

1. ไม่เปลี่ยน architecture ของระบบ
2. ไม่เปลี่ยน database
3. ไม่แก้ secret จริงใน production
4. ไม่เพิ่มค่าใช้จ่าย infrastructure ใหม่
5. ไม่เปลี่ยนวิธี deploy หรือ ingress ของระบบ

## 6. เหตุผลเชิงวิศวกรรมว่าทำไมจึงเหมาะกับ Phase 2

### 6.1 เชื่อมกับเป้าหมายของ Woodpecker CI/CD โดยตรง

Woodpecker มีหน้าที่เป็น quality gate ก่อน deploy อยู่แล้ว การเพิ่ม frontend gate จึงสอดคล้องกับแนวคิดเดิมของ Phase 2 โดยไม่ทำให้ workflow ซับซ้อนผิดธรรมชาติ

### 6.2 ใช้ประโยชน์จากสิ่งที่มีอยู่แล้วใน repo

เนื่องจาก frontend มี `type-check` และ `Jest` test อยู่แล้ว การเพิ่ม requirement นี้ไม่ใช่การสร้างงานใหม่ทั้งหมด แต่เป็นการเอาของที่มีอยู่แล้วมาเชื่อมเข้ากับ pipeline ให้เกิดคุณค่าจริง

### 6.3 เหมาะกับเวลาทำงานจำกัด

Change นี้สามารถสาธิตให้เห็นผลได้ภายในเวลาไม่นาน เช่น

1. เพิ่ม step
2. push commit
3. เห็น pipeline ผ่านหรือ fail ได้ทันที

จึงเหมาะกับ requirement change ที่โจทย์ต้องการให้ “เล็ก ปลอดภัย และเห็นผลผ่าน pipeline ได้”

## 7. ผลที่คาดหวังหลังเปลี่ยน

| ด้าน | ก่อนเปลี่ยน | หลังเปลี่ยน |
|---|---|---|
| Quality gate | ตรวจ backend เป็นหลัก | ตรวจทั้ง backend และ frontend |
| ความเสี่ยง UI regression | ยังมีช่องว่าง | ลดลงอย่างชัดเจน |
| ความน่าเชื่อถือของ pipeline | ดีระดับหนึ่ง | ดีขึ้น เพราะครอบคลุมเส้นทางหลักของผู้ใช้ |
| การสาธิตผลลัพธ์ | เห็นแค่ backend gate | เห็น failure/success ฝั่ง UI ผ่าน Woodpecker ได้ชัด |

## 8. วิธีทดสอบและสังเกตผลของ change นี้

### 8.1 กรณีผ่าน (Happy Path)

1. เพิ่ม step `test-frontend`
2. push commit ที่ไม่ทำให้ frontend พัง เช่น เปลี่ยนข้อความเล็กน้อยใน UI
3. สังเกตว่า Woodpecker รัน `type-check` และ `test:ci` ผ่าน
4. pipeline ดำเนินต่อไปจน build/push/deploy สำเร็จ

**สิ่งที่เห็นได้ชัด:** ใน Woodpecker UI จะมี step ใหม่และสถานะเป็น success

### 8.2 กรณีไม่ผ่าน (Failure Path)

1. สร้างการเปลี่ยนแปลงเล็ก ๆ ที่ทำให้ TypeScript error หรือ Jest fail
2. push commit
3. สังเกตว่า pipeline หยุดที่ `test-frontend`
4. `build-push-web` และ `deploy-k3s` จะไม่ถูกเรียก

**สิ่งที่เห็นได้ชัด:** ระบบป้องกันไม่ให้ frontend ที่มีปัญหาถูก deploy และผลลัพธ์นี้มองเห็นได้ชัดเจนจาก Woodpecker logs

## 9. Acceptance Criteria

การเปลี่ยนแปลงนี้ถือว่าสำเร็จเมื่อเป็นไปตามเกณฑ์ต่อไปนี้ครบ

1. Pipeline มี step สำหรับ frontend quality gate อย่างน้อย 1 step
2. Step ดังกล่าวรัน `npm run type-check` และ `npm run test:ci` ได้จริง
3. ถ้า frontend fail pipeline ต้องหยุดก่อนถึง `build-push-web`
4. ถ้า frontend pass pipeline ต้องดำเนินต่อได้ตามปกติ
5. ทีมสามารถอธิบายและสาธิต success/failure path ผ่าน Woodpecker UI ได้

## 10. ความเสี่ยงของการเปลี่ยนและแผนรับมือ

| ความเสี่ยง | ผลกระทบ | วิธีรับมือ |
|---|---|---|
| เวลา pipeline เพิ่มขึ้นเล็กน้อย | feedback ช้าลงบ้าง | ใช้เฉพาะ frontend gate ที่จำเป็นก่อน |
| test บางตัว flaky | pipeline fail โดยไม่ใช่ bug จริง | ปรับปรุง test ให้ deterministic ก่อนบังคับใช้เต็ม |
| dependency install ช้า | ใช้เวลา build นานขึ้น | ใช้ cache ภายหลังถ้าจำเป็น |

โดยรวมความเสี่ยงนี้อยู่ในระดับต่ำ และไม่กระทบ production runtime โดยตรง

## 11. Rollback Plan

ถ้าเพิ่ม step แล้วเกิดผลข้างเคียงที่ไม่ต้องการ สามารถ rollback ได้ง่ายมาก เพราะ change นี้แตะเพียง pipeline config

แผน rollback คือ

1. revert commit ที่เพิ่ม `test-frontend`
2. push commit revert
3. Woodpecker ใช้ pipeline เดิมทันทีในรอบถัดไป

จึงเป็น change ที่มี **blast radius ต่ำมาก**

## 12. ทำไม change นี้ดีกว่าข้อเสนอที่ “ไม่ควรทำ” ตามโจทย์

ข้อเสนอนี้ดีกว่า requirement ที่ไม่เหมาะสม เช่น ลบ resource, destroy infra, แก้ secret จริง หรือเปลี่ยน architecture ทั้งระบบ เพราะ

1. ไม่เสี่ยงทำลายสภาพแวดล้อม
2. ไม่ทำให้ค่าใช้จ่ายเพิ่มมาก
3. ไม่เกินขอบเขตที่ควรเสร็จและสาธิตได้ในเวลาอันสั้น
4. เห็นผลชัดใน pipeline ตามเกณฑ์ของอาจารย์

## 13. สรุป

Requirement change ที่เลือกคือ **เพิ่ม frontend quality gate ให้ Woodpecker pipeline** ซึ่งเป็น change ที่เล็ก ปลอดภัย และสังเกตผลได้ชัดที่สุดสำหรับ Phase 2 ของโครงงานนี้ เพราะใช้ของที่มีอยู่แล้วใน repo, ช่วยอุดช่องโหว่สำคัญของ pipeline ปัจจุบัน และสามารถสาธิตได้ชัดทั้งกรณีผ่านและกรณี fail โดยไม่กระทบ production resource หรือทำให้โครงงานบานปลายเกินความจำเป็น

หากจะเลือกเพียงหนึ่ง change request สำหรับ Phase 2 เพื่อโชว์การคิดแบบ DevOps ที่ pragmatic ที่สุด หัวข้อนี้ถือว่าเหมาะมาก เพราะมันเชื่อมตรงกับคุณภาพของ software delivery ไม่ใช่แค่เพิ่ม feature ในเอกสาร
