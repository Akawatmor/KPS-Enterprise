# Live Presentation Rehearsal Script — A/B Detailed Version

## 1. เอกสารนี้ใช้เมื่อไร

ไฟล์นี้เป็นเวอร์ชันซ้อมบทแบบแบ่งผู้พูด 2 คน สำหรับวันพรีเซนต์สด โดยออกแบบให้ใช้กับรอบ Pod Review 22 นาทีเป็นหลัก และมีเวอร์ชันย่อ 10 นาทีให้ท้ายไฟล์

จุดต่างจาก `presentation-script.md` คือไฟล์นี้ลงในระดับ “ใครเปิดอะไร ใครพูดอะไร ใครรับไม้ตรงไหน” เพื่อให้ซ้อมจริงได้ทันที

---

## 2. บทบาท

| คน | บทบาทหลัก | บทบาทรอง |
|---|---|---|
| Speaker A | เล่าเรื่อง, คุม logic, รับคำถาม reviewer | สรุปผล, เชื่อมกับ CI/CD/DevOpsSec |
| Speaker B | คุมจอ, เปิดไฟล์, รันคำสั่ง, ทำ live change | เสริมเหตุผลเชิงเทคนิคและชี้ evidence |

ถ้ามีคนเดียว ให้รวมบท A และ B เข้าด้วยกันตามลำดับเดิม

---

## 3. สิ่งที่ต้องเปิดค้างก่อนเริ่ม

### Browser

1. หน้า TodoApp Big Calendar
2. Woodpecker UI หรือ pipeline run ล่าสุด

### VS Code tabs

1. `presentation/final-phase2/slides.md` หรือไฟล์ที่ export แล้ว
2. `src/phase2-final/.woodpecker.yml`
3. `document/phase2/reqchange.md`
4. `src/phase2-final/frontend/package.json`
5. `src/phase2-final/frontend/__tests__/page.test.tsx`

### Terminal

```bash
kubectl get pods -n todoapp
kubectl get deploy -n todoapp
kubectl get ingress -n todoapp
kubectl rollout status deployment/todoapp-core -n todoapp --timeout=60s
kubectl rollout status deployment/todoapp-web -n todoapp --timeout=60s
```

---

## 4. 22-Minute Script — Detailed Hand-off Version

## ช่วง 0:00–0:45 — เปิดและตั้งกรอบ

### สิ่งที่ต้องเปิด

1. Slide ปก

### Speaker A พูด

> “สวัสดีครับ วันนี้กลุ่ม KPS-Enterprise จะนำเสนอ Phase 2 ของระบบ TodoApp Big Calendar บน K3s และ Woodpecker CI/CD ครับ”

> “รอบนี้เราจะทำ 3 อย่างให้ชัด คือ establish baseline เดิมของระบบ, แสดง normal case สั้น ๆ, แล้วทำ live change ที่เล็ก ปลอดภัย และเห็นผลได้ผ่าน pipeline จริง”

### Speaker B ทำ

1. อยู่ที่หน้าปกนิ่ง ๆ
2. เตรียม slide ถัดไปแต่ยังไม่เปลี่ยน

### Speaker B พูดเสริม

> “source of truth หลักที่เราใช้คือ `src/phase2-final`, `document/phase2`, และ `implementation/phase2` ครับ เพื่อไม่ให้ข้อมูลปนกับของ Phase 1”

---

## ช่วง 0:45–2:00 — Brief ระบบ + Safety Boundary

### สิ่งที่ต้องเปิด

1. Slide 1 และ Slide 2

### Speaker A พูด

> “ระบบนี้ถ้ามองจากผู้ใช้ก็คือ task management app ที่ใช้ปฏิทินเป็นหน้าหลัก แต่ถ้ามองจากมุมวิศวกรรม มันคือระบบส่งมอบแบบ end-to-end ที่เชื่อมตั้งแต่ source code ไปจนถึง deployment และ feedback จาก runtime”

> “เพื่อให้เดโมปลอดภัย เราจะไม่ลบ resource, ไม่ run terraform destroy, ไม่แตะ production credential จริง และไม่ทำ change ที่ใหญ่เกิน 10 นาที เราจะเลือกเฉพาะงานที่ small, safe, observable เท่านั้นครับ”

### Speaker B พูด

> “ตรงนี้สำคัญเพราะ reviewer จะสามารถให้ requirement ได้ แต่เราจะรับเฉพาะ requirement ที่ blast radius ต่ำ, rollback ได้ง่าย และมี evidence ผ่าน pipeline หรือ runtime ให้เห็น”

### Speaker B ทำ

1. ชี้ source of truth บน slide
2. ชี้ bullet safety boundary

---

## ช่วง 2:00–3:30 — Architecture Summary

### สิ่งที่ต้องเปิด

1. Slide architecture

### Speaker A พูด

> “runtime path ของระบบตอนนี้คือ Browser เข้า Traefik ingress จากนั้น traffic ทั่วไปไป frontend ส่วน `/api`, `/healthz`, และ `/readyz` ไป backend และ backend คุยกับ PostgreSQL ใน cluster path ครับ”

> “แนวคิดสำคัญคือ deployment path ต้องเชื่อถือได้พอ ๆ กับ runtime path ดังนั้นเราไม่ได้สนใจแค่ว่าเว็บขึ้น แต่สนใจด้วยว่าแต่ละรอบ deploy ถูก verify อย่างไร”

### Speaker B พูดเสริม

> “ฝั่ง backend ใช้ 2 replicas และ RollingUpdate เพื่อให้ update ได้ปลอดภัยขึ้น ส่วน frontend ก็มี 2 replicas เพื่อเพิ่ม availability ผ่าน ingress เดียวกัน”

### Speaker B ทำ

1. ชี้เส้น Browser → Traefik → Web/Core → PostgreSQL
2. ชี้คำว่า RollingUpdate / replicas ถ้ามีบน slide

---

## ช่วง 3:30–5:30 — Normal Case ที่ฝั่งแอป

### สิ่งที่ต้องเปิด

1. Browser หน้า TodoApp Big Calendar

### Speaker A พูด

> “ตอนนี้ขอ establish baseline ฝั่งผู้ใช้ก่อนครับ หน้าแรกของระบบคือ Big Calendar ที่แสดงงานทั้งเดือน เมื่อคลิกวันที่ใดวันหนึ่ง ระบบจะเปิด panel ด้านข้างเพื่อจัดการงานของวันนั้นได้ทันที”

> “จุดนี้เราโชว์ก่อนเพราะ reviewer ต้องเห็นว่าปลายทางของ pipeline คือประสบการณ์ผู้ใช้จริง ไม่ใช่แค่ log หรือ YAML”

### Speaker B ทำ

1. เปิด browser หน้าแอป
2. คลิกวันหนึ่งวัน
3. ชี้ stats bar หรือ task pills

### Speaker B พูดเสริม

> “จาก baseline นี้ ถ้า deploy ใหม่หรือ change ใหม่ดีจริง เราต้องเห็นผลกลับมาที่หน้าจอนี้ได้ในที่สุด”

---

## ช่วง 5:30–7:00 — Normal Case ที่ฝั่ง cluster

### สิ่งที่ต้องเปิด

1. Terminal

### Speaker A พูด

> “ต่อไปคือ baseline ฝั่ง runtime infrastructure เราจะดูว่าใน namespace `todoapp` มี component หลักขึ้นอยู่จริงหรือไม่”

### Speaker B ทำ

1. รัน `kubectl get pods -n todoapp`
2. รัน `kubectl get deploy -n todoapp`
3. ถ้ามีเวลาค่อยรัน `kubectl get ingress -n todoapp`

### Speaker B พูด

> “ตรงนี้จะเห็น frontend, backend และ postgres เป็นคนละ workload ชัดเจน และ deployment พร้อมใช้งานตาม baseline ที่เราเล่าเมื่อกี้”

### Speaker A พูดปิดช่วง

> “ตอนนี้ reviewer ควรเห็น baseline ครบทั้งฝั่งผู้ใช้และฝั่ง runtime แล้ว ดังนั้นต่อให้มี change ใหม่ เราก็มีจุดอ้างอิงว่าระบบเดิมที่ถูกต้องหน้าตาเป็นอย่างไร”

---

## ช่วง 7:00–8:30 — Normal Case ที่ฝั่ง pipeline

### สิ่งที่ต้องเปิด

1. `.woodpecker.yml`
2. Woodpecker UI หรือ screenshot run ล่าสุด

### Speaker A พูด

> “ในมุม delivery baseline pipeline ปัจจุบันเริ่มจาก `test-backend` ก่อน จากนั้น build และ push image ทั้ง core กับ web แล้วค่อย deploy ไป K3s, รอ rollout status, ทำ smoke test และส่ง email notification”

### Speaker B ทำ

1. เปิด `.woodpecker.yml`
2. เลื่อนให้เห็น `test-backend`, `build-push-core`, `build-push-web`, `deploy-k3s`, `notify-email`
3. สลับไป Woodpecker UI ถ้าจอพร้อม

### Speaker B พูดเสริม

> “นี่คือ feedback loop หลัง `git push` ครับ ทีมไม่ต้องเดาว่า deploy สำเร็จไหม เพราะ pipeline จะเป็นคนบอกและให้ evidence กลับมา”

---

## ช่วง 8:30–10:00 — รับ Requirement หรือเสนอ Requirement สำรอง

### สิ่งที่ต้องเปิด

1. `document/phase2/reqchange.md`

### Speaker A พูดกับ reviewer

> “ตอนนี้ขอรับ requirement change หรือ failure/risk ที่เล็ก ปลอดภัย และเห็นผลผ่าน pipeline ได้ภายในเวลาจำกัดครับ”

ถ้า reviewer ยังไม่ให้ ให้พูดต่อทันที

> “ถ้า reviewer ยังไม่ specify เราขอใช้ requirement ที่เตรียมไว้ คือเพิ่ม frontend quality gate ให้ Woodpecker รัน `npm run type-check` และ `npm run test:ci` ก่อน `build-push-web` ครับ”

### Speaker B พูดเสริม

> “เหตุผลที่เลือกอันนี้เพราะของมีอยู่แล้วใน repo ทั้ง scripts และ tests ดังนั้น change นี้เล็ก, ไม่แตะ secret, และ observable ชัดใน Woodpecker มากที่สุด”

### Speaker B ทำ

1. เลื่อน `reqchange.md` ให้เห็นคำว่า small / safe / observable

---

## ช่วง 10:00–11:30 — แสดงหลักฐานว่ามี frontend quality artifacts อยู่แล้ว

### สิ่งที่ต้องเปิด

1. `src/phase2-final/frontend/package.json`
2. `src/phase2-final/frontend/__tests__/page.test.tsx`

### Speaker A พูด

> “ก่อนแก้ pipeline เราจะชี้ให้เห็นก่อนว่า frontend มีของพร้อมอยู่แล้ว ไม่ใช่เพิ่มงานจากศูนย์”

### Speaker B ทำ

1. เปิด `package.json`
2. ชี้ `type-check` และ `test:ci`
3. เปิด test file
4. ชี้ชื่อ test ที่เกี่ยวกับ header, calendar nav, day panel, task interactions

### Speaker B พูด

> “ดังนั้น change นี้คือการย้ายสิ่งที่มีอยู่แล้วเข้าสู่ quality gate ของ pipeline เพื่อให้ feedback loop ครอบคลุมฝั่ง UI ด้วย”

---

## ช่วง 11:30–14:00 — Live Change จริงใน `.woodpecker.yml`

### สิ่งที่ต้องเปิด

1. `src/phase2-final/.woodpecker.yml`

### Speaker A พูด

> “ตอนนี้เราจะเพิ่ม step `test-frontend` ก่อน `build-push-web` เพื่อให้ web image ถูกสร้างต่อเมื่อ frontend ผ่าน checks ที่จำเป็นแล้วเท่านั้น”

### Speaker B ทำ

1. เพิ่ม step ใหม่
2. save file
3. ถ้ามีเวลาแสดง diff สั้น ๆ

### Code ที่ต้องเพิ่ม

```yaml
- name: test-frontend
  image: node:22-bookworm-slim
  commands:
    - cd src/phase2-final/frontend
    - npm ci
    - npm run type-check
    - npm run test:ci
```

### Speaker A พูดระหว่างแก้

> “เราใช้ `npm ci` เพราะ deterministic กว่า `npm install` ในบริบท CI”

> “`type-check` ช่วยจับ contract/type error และ `test:ci` ช่วยจับ regression เชิงพฤติกรรมของหน้า calendar ก่อนถึงขั้น build image”

### Speaker B พูดสรุปทันทีหลัง save

> “blast radius ของ change นี้ต่ำมากครับ เพราะแตะไฟล์เดียวและไม่แตะ runtime secret หรือ resource ฝั่ง cluster”

---

## ช่วง 14:00–15:00 — Trigger Pipeline

### สิ่งที่ต้องเปิด

1. Terminal
2. Woodpecker UI

### Speaker B ทำ

1. `git add src/phase2-final/.woodpecker.yml`
2. `git commit -m "ci: add frontend quality gate before web build"`
3. `git push origin main`

### Speaker A พูด

> “ตอนนี้เราจะไม่อ้างว่าการแก้ครั้งนี้สำเร็จเพียงเพราะเขียน YAML เสร็จแล้ว แต่จะให้ pipeline เป็นคนพิสูจน์ เพราะเป้าหมายของรอบนี้คือ evidence-based change ไม่ใช่ config-based claim”

---

## ช่วง 15:00–16:30 — อ่านผลจาก Woodpecker

### สิ่งที่ต้องเปิด

1. Woodpecker UI run ใหม่

### Speaker B ทำ

1. เปิด run ใหม่
2. ชี้ให้เห็น stage `test-frontend`
3. ถ้ามี log แล้วให้เปิด log

### Speaker B พูด

> “ตอนนี้ reviewer จะเห็นได้ชัดว่า pipeline graph เปลี่ยนแล้ว และ `test-frontend` ถูก trigger จริง ซึ่งเป็น observable output ของ change นี้”

### Speaker A พูด

> “ถ้า stage นี้ผ่าน ระบบจะเดินต่อไปสู่ `build-push-web` แต่ถ้า fail ระบบจะหยุดก่อน build และ deploy ซึ่งนั่นคือ behavior ที่เราต้องการจาก quality gate”

---

## ช่วง 16:30–18:00 — อธิบายผลในกรณี Success หรือ Failure

### ถ้า Success

### Speaker A พูด

> “ถ้ารอบนี้ผ่าน เราจะได้ pipeline ที่ครอบคลุม frontend มากขึ้น และเพิ่มความน่าเชื่อถือให้ deploy stage เพราะ web image ไม่ได้ถูก build แบบข้าม quality checks อีกต่อไป”

### Speaker B พูด

> “สิ่งที่ผู้ชมควรจำไม่ใช่แค่ชื่อ stage ใหม่ แต่คือแนวคิดว่า feedback loop ถูกขยับเข้ามาใกล้ source ของปัญหามากขึ้น”

### ถ้า Failure

### Speaker A พูด

> “ถ้ารอบนี้ fail เราถือว่านี่คือความสำเร็จของ quality gate เช่นกัน เพราะ pipeline จับปัญหาได้ก่อน build และ deploy ไม่ใช่ปล่อยของมีปัญหาไปถึง runtime แล้วค่อยรู้ทีหลัง”

### Speaker B พูด

> “จากนั้นเราจะไล่ root cause ตาม log ว่า fail ที่ install, type-check หรือ tests แต่หลักการสำคัญคือ feedback loop ทำงานแล้ว”

---

## ช่วง 18:00–19:30 — เชื่อมกับ DevOps / DevOpsSec

### สิ่งที่ต้องเปิด

1. Slide DevOpsSec หรือ slide recap

### Speaker A พูด

> “จุดที่ change นี้เชื่อมกับสิ่งที่เรียนคือเราเพิ่ม quality gate ก่อน build/deploy และทำให้ feedback loop ฝั่ง UI ชัดขึ้น ซึ่งตรงกับแนวคิด CI/CD โดยตรง”

> “ถ้ามองผ่านเลนส์ DevOpsSec นี่คือการลดโอกาสที่ regression ฝั่งหน้าเว็บจะหลุดไปถึง production path โดยไม่จำเป็นต้องรอ incident จริง”

### Speaker B พูดเสริม

> “ถ้าต่อยอดต่อ สิ่งที่คุ้มที่สุดคือเพิ่ม Trivy scan, SBOM, signing, monitoring/logging และ backup/restore drill ให้ครบวงจรยิ่งขึ้น”

---

## ช่วง 19:30–22:00 — ปิดและส่งไม้ให้ reviewer

### Speaker A พูด

> “สรุปวันนี้เรา establish baseline ของระบบครบทั้ง app, cluster และ pipeline จากนั้นทำ live change ที่เล็ก ปลอดภัย และเห็นผลได้จริงผ่าน Woodpecker”

> “สิ่งที่กลุ่มถัดไปสามารถ assume ได้เลยคือ runtime path, deployment baseline และหลักการ small-safe-observable ดังนั้นเขาไม่จำเป็นต้องเล่า architecture ซ้ำทั้งหมด แต่ควรเล่าเฉพาะส่วนที่ตนเองปรับหรือเสริม”

### Speaker B พูดปิด

> “สำหรับ reviewer วันนี้ evidence หลักมี 3 ชุด คือ baseline app/runtime, baseline pipeline เดิม และ pipeline graph ใหม่ที่มี frontend quality gate เพิ่มเข้ามาครับ”

---

## 5. เวอร์ชันย่อ 10 นาที

ถ้าเวลาถูกบีบ ให้ใช้ flow นี้

| เวลา | Speaker A | Speaker B |
|---|---|---|
| 0:00–1:00 | เปิด, บอก scope และ safety boundary | เปิดหน้าปก/slide overview |
| 1:00–2:30 | สรุป architecture และ pipeline baseline | เปิด slide architecture และ `.woodpecker.yml` |
| 2:30–4:00 | โชว์ app baseline | เปิด browser และคลิก day panel |
| 4:00–5:00 | โชว์ runtime baseline | รัน `kubectl get pods -n todoapp` |
| 5:00–6:30 | รับหรือเสนอ requirement `test-frontend` | เปิด `reqchange.md`, `package.json`, tests |
| 6:30–8:00 | อธิบาย live change | แก้ `.woodpecker.yml` |
| 8:00–9:00 | trigger pipeline | commit + push |
| 9:00–10:00 | สรุป expected evidence และ next steps | เปิด Woodpecker UI |

ประโยคสรุปเวอร์ชัน 10 นาที

> “ถ้าเดโมรอบนี้จำอะไรเพียงเรื่องเดียว ขอให้จำว่าเราไม่ได้แค่เปลี่ยนไฟล์ แต่เราใช้ pipeline เป็นตัวพิสูจน์ว่า change ที่เล็กและปลอดภัยสามารถยกระดับ feedback loop ของระบบได้จริง”

---

## 6. ประโยคสำรองเวลาเดโมสะดุด

### ถ้า browser ช้า

> “หน้าจอฝั่ง user เป็น baseline ที่เราตรวจไว้แล้ว แต่เพื่อไม่ให้เสียเวลา เราจะข้ามไปดู evidence ฝั่ง cluster และ pipeline ซึ่งเป็นจุดที่ใช้วัด live change รอบนี้โดยตรง”

### ถ้า Woodpecker ช้า

> “อย่างน้อยตอนนี้เราเห็นแล้วว่า stage ใหม่ถูก trigger จริง และนั่นคือ observable evidence แรกของ change นี้ ส่วนสถานะสุดท้ายจะขึ้นกับ execution log ของ pipeline”

### ถ้า reviewer ขอ change ใหญ่เกินไป

> “change นี้มี value ครับ แต่เกิน time box และ blast radius สูงเกินรอบ review เราขอแตกให้เป็น change เล็กกว่าที่วัดผลได้ผ่าน pipeline ก่อน”