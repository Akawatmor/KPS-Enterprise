# Detailed Video Recording Script — Phase 2 Final

## 1. วัตถุประสงค์ของคลิปนี้

คลิปนี้ควรทำหน้าที่เป็น “ภาพรวมที่ชัดและซื่อสัตย์” ของ Phase 2 Final โดยให้คนดูเข้าใจว่าโปรเจกต์นี้มีทั้ง application, infrastructure, CI/CD, observability และ evidence flow ที่ต่อกันจริง

สิ่งที่คลิปนี้ต้องทำให้ได้มี 4 ข้อ

1. อธิบาย baseline ของระบบโดยยึด source of truth ที่ active จริง
2. ชี้ delivered improvements ที่สำคัญโดยมีภาพหรือ log รองรับ
3. ทำให้คนดูเข้าใจเส้นทางตั้งแต่ `git push` ไปจนถึง canary, promote/rollback, smoke test และ notification
4. ทิ้งภาพจำว่า Phase 2 Final พร้อมให้กลุ่มถัดไปเริ่มจาก baseline นี้ได้ทันที

ประโยคเปิดที่เหมาะที่สุด

> “คลิปนี้ไม่ได้มีเป้าหมายแค่โชว์ว่าแอปรันได้ แต่จะอธิบายว่าระบบนี้ถูก build, verify, deploy, observe และย้อนหลักฐานได้อย่างไรใน Phase 2 Final”

---

## 2. Message หลักที่ควรส่งผ่านในคลิป

1. TodoApp Big Calendar คือปลายทางที่ผู้ใช้เห็น
2. K3s + Traefik + PostgreSQL คือ runtime baseline ที่ระบบใช้อยู่จริง
3. `.woodpecker/main-push.yml` คือ delivery baseline ที่ active จริง
4. จุดเด่นคือ canary analysis, signed/scanned images, smoke test, monitoring และ notification
5. สิ่งที่พูดต้องแยกชัดว่า **implemented now** กับ **next step**

สิ่งที่ไม่ควรพูดในคลิป

1. อย่าพูดว่า active pipeline อยู่ใน `src/phase2-final/.woodpecker.yml`
2. อย่าพูดว่า frontend quality gate เป็นสิ่งที่จะเพิ่ม เพราะมันมีแล้ว
3. อย่าพูดว่า Trivy, Cosign, SBOM หรือ canary 10% เป็นของอนาคต เพราะอยู่ใน main push pipeline แล้ว

---

## 3. ความยาวที่แนะนำ

ความยาวที่เหมาะคือ 12–15 นาที

ถ้าต้องตัดให้สั้น ให้คง 6 ส่วนนี้ไว้เสมอ

1. ภาพรวมโปรเจกต์และ source of truth
2. หน้าแอปจริง
3. runtime architecture + manifests สำคัญ
4. main push pipeline และ delivered improvements
5. evidence จาก Woodpecker / monitoring / notification
6. สรุปว่าอะไรคือ baseline ที่กลุ่มถัดไปควร assume ได้

---

## 4. หน้าจอที่ต้องเตรียมก่อนเริ่มอัด

1. Slide deck `presentation/final-phase2/slides.md`
2. Browser หน้า `https://todoapp-kps.akawatmor.com`
3. VS Code เปิด `.woodpecker/main-push.yml`
4. VS Code tab สำรองที่
   - `src/phase2-final/k8s/ingress.yaml`
   - `src/phase2-final/k8s/traefik-routing.yaml`
   - `src/phase2-final/k8s/postgres-statefulset.yaml`
   - `src/phase2-final/frontend/package.json`
   - `document/phase2/report.md`
5. Terminal พร้อม `kubectl`
6. Woodpecker UI login แล้ว
7. ถ้าทำได้ เปิด Grafana หรือ screenshot dashboard ที่อธิบายได้จริง

ข้อห้ามระหว่างอัด

1. อย่าให้ secret, token หรือ kubeconfig เต็มโผล่บนจอ
2. อย่า scroll YAML เร็วจนคนดูอ่านไม่ทัน
3. ถ้าใช้ evidence จาก run เก่า ต้องบอกตรง ๆ ว่าเป็น run ล่าสุดที่บันทึกไว้ ไม่ใช่ live run ขณะอัด

---

## 5. Shot List แบบสรุปเร็ว

| Scene | เวลา | จอที่ต้องเปิด | เป้าหมาย |
|---|---|---|---|
| 1 | 0:00–0:45 | Slide ปก | ตั้ง scope และ source of truth |
| 2 | 0:45–2:00 | Slide overview | บอก message หลักของ Phase 2 Final |
| 3 | 2:00–3:20 | Browser หน้าแอป | โชว์ user-facing baseline |
| 4 | 3:20–4:50 | Slide architecture + manifests | อธิบาย runtime path และ weighted route |
| 5 | 4:50–7:20 | `.woodpecker/main-push.yml` | อธิบาย stage 0-10 แบบเป็นกลุ่ม |
| 6 | 7:20–8:30 | Terminal | ยืนยัน runtime state บน cluster |
| 7 | 8:30–10:30 | Woodpecker UI | ชี้ delivered improvements จาก graph และ logs |
| 8 | 10:30–11:40 | Monitoring / email / docs | ปิด feedback loop ให้ครบ |
| 9 | 11:40–12:40 | Slide DevOpsSec / recap | สรุป implemented now vs next step |
| 10 | 12:40–13:20 | Slide closing | บอก baseline ที่กลุ่มถัดไปควร assume |

ถ้าคลิปยาวได้ 15 นาที ให้เพิ่ม Q&A simulation 1–2 นาทีท้าย

---

## 6. Scene-by-Scene Script

## Scene 1 — เปิดคลิปและล็อกขอบเขตให้ชัด

### เวลา

0:00–0:45

### บทพูดที่แนะนำ

> “คลิปนี้อธิบาย KPS-Enterprise Phase 2 Final ครับ โดย source of truth หลักที่เราจะยึดคือ `src/phase2-final` และ `.woodpecker/` เพราะสิ่งที่ต้องการสื่อคือ baseline ที่ active จริงในระบบ ไม่ใช่ baseline ระหว่างทาง”

### สิ่งที่คนดูควรเห็น

1. ชื่อโปรเจกต์
2. คำว่า Phase 2 Final
3. K3s + Woodpecker CI/CD

---

## Scene 2 — อธิบายว่าระบบนี้คืออะไรและทำไม Phase 2 ถึงต่าง

### เวลา

0:45–2:00

### บทพูดที่แนะนำ

> “ถ้ามองจากผู้ใช้ ระบบนี้คือ TodoApp Big Calendar ที่ให้ผู้ใช้จัดการงานผ่านมุมมองแบบปฏิทิน แต่ถ้ามองจากมุมวิศวกรรม Phase 2 Final คือการทำให้เส้นทางส่งมอบซอฟต์แวร์ตั้งแต่ push, build, scan, deploy, canary, verify และ notify เชื่อมกันเป็น flow เดียว”

> “ดังนั้นสิ่งที่เราจะโชว์ต่อจากนี้ไม่ใช่แค่หน้าเว็บ แต่คือระบบพิสูจน์ผลของการเปลี่ยนแปลงด้วย”

---

## Scene 3 — โชว์หน้าแอปจริง

### เวลา

2:00–3:20

### สิ่งที่ต้องทำบนจอ

1. เปิดหน้า Big Calendar
2. คลิกวันที่หนึ่งวันให้เห็น day panel
3. ชี้ stats หรือ colored pills ถ้ามีข้อมูลอยู่แล้ว

### บทพูดที่แนะนำ

> “นี่คือปลายทางของทุก deploy ครับ คือหน้า Big Calendar ที่ผู้ใช้เห็นจริง เมื่อคลิกวันที่ก็เปิด panel เพื่อจัดการงานของวันนั้นได้ทันที”

> “จุดนี้สำคัญเพราะเวลาพูดเรื่อง pipeline เราไม่ได้พูดถึง process ลอย ๆ แต่พูดถึงสิ่งที่จะส่งผลกลับมาที่หน้าจอนี้”

---

## Scene 4 — เชื่อมจาก UI ไปสู่ runtime architecture

### เวลา

3:20–4:50

### จอที่ต้องเปิด

1. Slide architecture
2. `src/phase2-final/k8s/ingress.yaml`
3. `src/phase2-final/k8s/traefik-routing.yaml`
4. `src/phase2-final/k8s/postgres-statefulset.yaml`

### บทพูดที่แนะนำ

> “runtime path ของระบบนี้เริ่มจาก public domain ผ่าน Traefik โดย path ทั่วไปไป frontend ส่วน `/api`, `/healthz`, และ `/readyz` ไป weighted backend route ที่เชื่อม stable กับ canary ผ่าน TraefikService”

> “จุดนี้ทำให้ canary deploy ของเราเกิดขึ้นบน route จริง ไม่ใช่แค่ concept บนสไลด์”

> “ฝั่งฐานข้อมูลเป็น PostgreSQL StatefulSet บน K3s พร้อม probes และ security settings ที่ชัดเจน ทำให้ data layer เป็นส่วนหนึ่งของ baseline ที่อธิบายได้”

---

## Scene 5 — เปิด pipeline source of truth และอธิบายเป็นกลุ่ม stage

### เวลา

4:50–7:20

### จอที่ต้องเปิด

`.woodpecker/main-push.yml`

### สิ่งที่ต้องชี้ให้เห็น

1. Stage 0-2: pre-flight, quality, integration
2. Stage 3-5: build/push, sign/scan, DB ops
3. Stage 6-8: canary deploy, canary analysis, promote/rollback
4. Stage 9-10: smoke test, release tag, post-deploy analysis, email

### บทพูดที่แนะนำ

> “Main push pipeline ของเราไม่ได้เป็นเส้นตรงแบบ test → build → deploy อย่างเดียว แต่เป็นชุดของ gates ที่ลดความเสี่ยงทีละชั้น”

> “ก่อน build เรามี Gitleaks, Hadolint, kube-score และ OPA จากนั้นจึงรัน quality-backend กับ quality-frontend แบบ parallel และค่อยต่อด้วย integration test กับ Postgres”

> “หลัง build เรายังมี Cosign, SBOM, Trivy, database backup, migration test ก่อนถึงขั้น deploy ซึ่งทำให้ deployment path มีหลักฐานชัดว่าของที่ขึ้น production-like path ผ่านอะไรมาแล้วบ้าง”

> “ช่วง deploy เราใช้ canary 10% และวัดจาก Prometheus metrics ก่อนค่อย promote หรือ rollback ดังนั้นคำว่า deploy success ของเราไม่ได้มาจาก rollout status อย่างเดียว”

---

## Scene 6 — ยืนยัน runtime state บน cluster

### เวลา

7:20–8:30

### คำสั่งที่แนะนำ

```bash
kubectl get pods -n todoapp
kubectl get deploy,statefulset -n todoapp
kubectl get ingress,ingressroute,traefikservice -n todoapp
```

### บทพูดที่แนะนำ

> “ตรงนี้คือหลักฐานว่าที่เล่าบนสไลด์กับ YAML สะท้อนระบบที่ขึ้นจริงอยู่บน cluster ไม่ใช่แค่เอกสารประกอบ”

> “การโชว์ cluster state ทำให้คนดูเชื่อมได้ว่าพูดถึง frontend, backend, PostgreSQL และ weighted route บนของจริง ไม่ใช่แค่แนวคิด”

---

## Scene 7 — เปิด Woodpecker UI และชี้ delivered improvements จาก graph จริง

### เวลา

8:30–10:30

### สิ่งที่ต้องชี้บนจอ

1. `quality-frontend` มีอยู่จริงใน Stage 1
2. `sign-and-scan` มีอยู่จริง
3. `canary-analyze` และ `auto-rollback` เป็น path ที่แยกชัด
4. `smoke-test`, `k6-load-test`, `dast-zap`, `email-*` อยู่ช่วงท้าย

### บทพูดที่แนะนำ

> “ตรงนี้คือหัวใจของคลิปครับ เพราะมันทำให้ delivered improvements กลายเป็นสิ่งที่ชี้ได้บน graph จริง”

> “สิ่งที่ควรจำคือ Stage 0-5 ลดความเสี่ยงก่อน deploy, Stage 6-8 คุมความเสี่ยงระหว่าง deploy, และ Stage 9-10 ยืนยันผลหลัง deploy พร้อมแจ้งทีม”

### ถ้าจะเปิด log

เลือกอย่างใดอย่างหนึ่ง

1. `quality-frontend` เพื่อยืนยัน type-check และ Jest
2. `sign-and-scan` เพื่อยืนยัน Cosign/SBOM/Trivy
3. `canary-analyze` เพื่อยืนยัน 160 requests และ metric thresholds

---

## Scene 8 — ปิด feedback loop ด้วย monitoring / email / docs evidence

### เวลา

10:30–11:40

### สิ่งที่ต้องเปิด

1. Grafana หรือ monitoring manifest อย่างน้อยหนึ่งจุด
2. email success/rollback/failure screenshot หรือ UI evidence
3. ถ้ามีเวลา เปิด `document/phase2/report.md` ช่วง summary ที่สรุป improvements

### บทพูดที่แนะนำ

> “ระบบนี้ไม่ควรจบที่ deploy ผ่านครับ แต่ต้องรู้ผลเร็ว รู้สถานะเร็ว และตรวจย้อนกลับได้ ดังนั้น monitoring กับ notification จึงเป็นส่วนหนึ่งของ baseline ไม่ใช่ของตกแต่ง” 

---

## Scene 9 — อธิบาย DevOpsSec แบบซื่อสัตย์

### เวลา

11:40–12:40

### บทพูดที่แนะนำ

> “DevOpsSec ในโปรเจกต์นี้หมายถึงการเอาเรื่องความปลอดภัยและความน่าเชื่อถือเข้าไปอยู่ในหลายจุดของ flow แล้ว ซึ่งของที่ active จริงมีทั้ง secret hygiene, lint/policy gates, signed and scanned images, canary rollout, runtime hardening, monitoring และ notification”

> “ส่วนสิ่งที่ยังควรต่อยอดคือ signature verification ก่อน promote, secret rotation, restore drill, log aggregation และ alert tuning ซึ่งควรแยกเป็น next step อย่างตรงไปตรงมา”

---

## Scene 10 — ปิดคลิปและบอก baseline ที่ส่งต่อได้

### เวลา

12:40–13:20

### บทพูดที่แนะนำ

> “สิ่งที่ Phase 2 Final ส่งต่อให้กลุ่มถัดไปไม่ใช่แค่ app ที่เปิดได้ แต่คือ baseline ที่มี runtime path, pipeline path, canary path, verification path และ evidence path ครบในระดับที่อ้างต่อได้ทันที”

> “ดังนั้นรอบถัดไปควรเล่าเฉพาะสิ่งที่เปลี่ยนจาก baseline นี้ ไม่จำเป็นต้องย้อนเล่า architecture และ pipeline ใหม่ทั้งหมด”

---

## 7. ถ้าจะทำเวอร์ชันยาว 15 นาที ให้เพิ่ม 2 ส่วนนี้

1. Q&A simulation เรื่อง “ถ้า canary fail จะเกิดอะไรขึ้น”
2. Honest next steps เรื่อง signature verification, restore drill, logs และ alert tuning

---

## 8. Checklist สิ่งที่ต้องมีในคลิป

1. หน้าแอปจริง
2. อย่างน้อย 1 manifest ฝั่ง route และ 1 manifest ฝั่ง database
3. `.woodpecker/main-push.yml`
4. `kubectl` output จาก cluster จริง
5. Woodpecker graph หรือ run evidence จริง
6. monitoring หรือ email evidence อย่างน้อย 1 ชิ้น
7. closing statement ที่บอกชัดว่า baseline นี้ส่งต่อได้

---

## 9. Mini Teleprompter Version

1. “คลิปนี้อธิบาย Phase 2 Final โดยยึด `src/phase2-final` และ `.woodpecker/` เป็น source of truth”
2. “ปลายทางของทุก deploy คือหน้า TodoApp Big Calendar ที่ผู้ใช้เห็นจริง”
3. “runtime path ใช้ Traefik แยก frontend route กับ weighted backend route ไป PostgreSQL”
4. “main push pipeline ไม่ใช่แค่ test-build-deploy แต่เป็นชุดของ gates ตั้งแต่ pre-flight ถึง notification”
5. “delivered improvements สำคัญคือ quality gates, sign/scan, canary analysis, smoke test, monitoring และ email”
6. “หลักฐานสำคัญต้องดูทั้ง YAML, cluster state, pipeline graph และ notification”
7. “DevOpsSec ของระบบนี้มีของจริงแล้ว และยังมี next steps ที่พูดได้อย่างซื่อสัตย์”
8. “baseline นี้คือสิ่งที่กลุ่มถัดไปควร assume ได้เลย”