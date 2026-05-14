# Detailed Live Presentation Script — Phase 2 Final

## 1. จุดประสงค์ของสคริปต์นี้

สคริปต์นี้ออกแบบมาสำหรับการนำเสนอ Final Demo ของ Phase 2 ที่ต้องทำให้คนฟังเข้าใจว่าโปรเจกต์นี้ไม่ได้มีแค่ Todo application ที่เปิดใช้งานได้ แต่มีทั้ง runtime path, deployment path, observability path และ evidence path ที่สอดกันจริง

ประเด็นสำคัญที่เอกสารนี้ยึดคือ

1. ใช้ **สิ่งที่ active จริงใน Phase 2** เป็นฐาน ไม่เล่าย้อนกลับไปหา pipeline หรือไฟล์เก่าที่ไม่ได้ใช้งานแล้ว
2. เน้น **delivered improvements** ที่ทำเสร็จแล้ว เช่น quality gates, security scan, canary analysis, smoke test, monitoring และ notification
3. ใช้ live change เป็น **ตัวเลือกสำรอง** เฉพาะกรณี reviewer ขอเท่านั้น ไม่ใช้เป็นแกนหลักของเรื่องเล่า
4. ทุกช่วงต้องตอบได้ว่า “สิ่งที่พูดอยู่พิสูจน์ด้วยจอไหนหรือ log ไหน”

พูดสั้น ๆ ได้ว่า

> “Final Demo นี้เราจะไม่ขาย concept เปล่า ๆ แต่จะชี้ให้เห็นว่าระบบ Phase 2 มี baseline ที่ deploy ได้, ตรวจได้, rollback ได้ และอธิบาย evidence ได้จริง”

---

## 2. Message หลักที่ต้องทำให้ผู้ฟังจำให้ได้

ตลอดการพูด ให้ผู้ฟังจำ 5 เรื่องนี้ให้ได้

1. ระบบคือ **TodoApp Big Calendar** ที่มีปลายทางชัดเจนฝั่งผู้ใช้
2. runtime path คือ **Browser → Nginx/Traefik → Frontend + Weighted Backend → PostgreSQL**
3. delivery path คือ **`.woodpecker/main-push.yml`** ที่ทำ pre-flight, quality, build, sign/scan, canary, verify และ notify ครบ
4. จุดเด่นของ Phase 2 คือ **evidence-driven delivery** ไม่ใช่แค่ deploy automation
5. ถ้าจะทำ live change ระหว่างเดโม ให้เลือก change เล็ก ๆ ที่ไม่ขายของเก่าว่าเป็นของใหม่

ประโยคเปิดที่จำง่ายที่สุด

> “วันนี้เราจะพาเห็นว่า Phase 2 ของเราไม่ใช่แค่ app ที่ขึ้นได้ แต่เป็นระบบส่งมอบที่มี baseline, safety gate, observability และ rollback path ที่อธิบายได้ครบครับ”

---

## 3. Source of Truth และเส้นแบ่งที่ต้องพูดให้ชัด

ระหว่างนำเสนอ ให้ยึดชุดนี้เป็นหลัก

1. `src/phase2-final/` สำหรับแอป, manifests, monitoring resources และ scripts
2. `.woodpecker/main-push.yml` สำหรับ production deployment pipeline
3. `.woodpecker/develop-push.yml`, `.woodpecker/pull-request.yml`, `.woodpecker/tag-release.yml` สำหรับ routing ของ event อื่น
4. `document/phase2/` สำหรับเหตุผล, รายงาน, mapping ของ improvements และเดโม
5. `implementation/phase2/implementation-info.md` สำหรับบริบทการติดตั้ง

สิ่งที่พูดได้อย่างมั่นใจ

1. backend ใช้ Go 1.25
2. frontend ใช้ Next.js 15.5 และ React 19
3. production database บน K3s ใช้ PostgreSQL 16 StatefulSet
4. pipeline active เป็นแบบ split files ใน `.woodpecker/` ไม่ใช่ root `.woodpecker.yml`
5. main push pipeline มี 12-stage logic ถ้านับ 0-10 พร้อม stage 9b
6. canary ใช้ weighted route 90/10 ระหว่าง analysis และกลับเป็น 100/0 หลัง promote หรือ rollback

สิ่งที่ไม่ควรพูดอีก

1. อย่าพูดว่า active pipeline อยู่ใน `src/phase2-final/.woodpecker.yml`
2. อย่าพูดว่า “วันนี้จะเพิ่ม frontend quality gate” เพราะ `quality-frontend` อยู่ใน baseline แล้ว
3. อย่าพูดว่า Trivy, Cosign, SBOM หรือ canary 10% เป็น next step เพราะของเหล่านี้ active แล้ว
4. อย่าพูดว่า pipeline มีแค่ test → build → deploy → email เพราะนั่นลดค่าของสิ่งที่ทำไว้จริง

ประโยคที่ควรใช้ตั้งแต่ต้น

> “Source of truth หลักของรอบนี้คือ `src/phase2-final` กับ `.woodpecker/` ครับ เพราะสิ่งที่เราต้องการสื่อคือ baseline ที่ active จริงใน Phase 2 Final ไม่ใช่ baseline ระหว่างทาง”

---

## 4. สิ่งที่ต้องเตรียมก่อนขึ้นเดโม

### 4.1 หน้าจอที่ควรเปิดค้างไว้

1. Slide deck จาก `presentation/final-phase2/slides.md`
2. Browser หน้า `https://todoapp-kps.akawatmor.com`
3. Woodpecker UI ที่ run ล่าสุดของ main push
4. VS Code เปิด `.woodpecker/main-push.yml`
5. VS Code tab สำรองที่
   - `src/phase2-final/k8s/ingress.yaml`
   - `src/phase2-final/k8s/traefik-routing.yaml`
   - `src/phase2-final/k8s/postgres-statefulset.yaml`
   - `src/phase2-final/frontend/package.json`
   - `document/phase2/reqchange.md`
6. ถ้ามีเวลา เปิด Grafana หรืออย่างน้อย monitoring manifests

### 4.2 คำสั่งที่ควรเตรียมใน terminal

```bash
kubectl get pods -n todoapp
kubectl get deploy,statefulset -n todoapp
kubectl get ingress,ingressroute,traefikservice -n todoapp
kubectl get servicemonitor,prometheusrule -n monitoring
```

### 4.3 สิ่งที่ต้องเช็กก่อนเริ่ม

1. Browser เข้าแอปได้จริง
2. Woodpecker login ค้างไว้แล้ว
3. terminal พร้อม `kubectl`
4. ไม่มี secret, token, หรือ kubeconfig แบบเต็มเปิดค้างบนจอ
5. ฟอนต์ editor และ terminal ใหญ่พอสำหรับคนทั้งห้อง
6. ถ้าจะใช้ screenshot ของ run ก่อนหน้า ต้องพูดตรง ๆ ว่าเป็น evidence จาก run ล่าสุด ไม่ใช่ live execution

---

## 5. Improvements ที่ “ต้องโชว์” ให้ครบ

| กลุ่ม improvement | สิ่งที่ต้องสื่อ | สิ่งที่ต้องเปิดให้ดู |
|---|---|---|
| Quality | pipeline ไม่ได้เช็กแค่ backend แต่เช็ก frontend และ integration ด้วย | Stage 1 และ Stage 2 ใน Woodpecker |
| Security / Policy | pre-flight และ sign/scan มีจริง | `secret-scan`, `dockerfile-lint`, `k8s-lint`, `opa-policy`, `sign-and-scan` |
| Data safety | ก่อน deploy มี `pg_dump` และ migration test | `db-prep`, `migration-test`, PostgreSQL StatefulSet |
| Delivery safety | ไม่ deploy แบบ blind แต่ใช้ canary + metrics | `canary-deploy`, `canary-analyze`, weighted route |
| Runtime verification | หลัง promote ยังมี smoke test และ public health check | `smoke-test`, `/healthz`, public root page |
| Observability | มี monitoring และ notification | Grafana/Prometheus evidence, email success/rollback/failure |
| Post-deploy analysis | มี k6 และ ZAP แม้เป็น non-blocking | Stage 9b |

ประโยคสั้น ๆ ที่ช่วยล็อกใจความ

> “สิ่งที่เราควรโชว์ไม่ใช่แค่ pipeline สีเขียว แต่ต้องโชว์ว่าแต่ละ stage ลดความเสี่ยงอะไรให้ระบบ”

---

## 6. 22-Minute Detailed Flow

## 6.1 นาที 0–2 — เปิดเรื่องและล็อก baseline ให้ตรงกัน

### หน้าจอที่ต้องเปิด

1. Slide ปก
2. Slide contract / source of truth

### สิ่งที่ควรพูด

> “วันนี้เราจะใช้ Phase 2 Final เป็น baseline เดียวกันทั้งชุดครับ โดย source of truth หลักคือ `src/phase2-final` กับ `.woodpecker/` เพราะสิ่งที่อยากให้เห็นไม่ใช่แค่ฟีเจอร์ของแอป แต่คือระบบส่งมอบทั้งหมดที่ active จริง”

> “แกนของรอบนี้มี 2 อย่าง คือ หนึ่ง establish baseline ให้ชัด และสองพิสูจน์ delivered improvements ด้วย evidence บนจอ เช่น pipeline, runtime state, canary route, monitoring และ notification”

### สิ่งที่ต้องย้ำ

1. เราไม่ได้จะพรีเซนต์ feature ที่ยังไม่ทำ
2. ถ้ามี live change จะเป็น optional backup เท่านั้น
3. เรื่องที่เล่าต่อจากนี้ต้องอ้างอิงไฟล์ active จริงทั้งหมด

---

## 6.2 นาที 2–5 — โชว์ user-facing baseline และ runtime state

### หน้าจอที่ต้องเปิด

1. Browser หน้า TodoApp Big Calendar
2. Terminal `kubectl get pods -n todoapp`

### สิ่งที่ควรทำบนจอ

1. เปิดหน้า calendar
2. คลิกวันที่หนึ่งวันให้เห็น day panel
3. สลับไป terminal เพื่อโชว์ pods, deployments และ statefulset

### สิ่งที่ควรพูด

> “ปลายทางของทุก deploy คือประสบการณ์ผู้ใช้ตรงนี้ครับ คือหน้า Big Calendar ที่ผู้ใช้คลิกวันแล้วจัดการงานได้จริง”

> “แต่เพื่อไม่ให้เดโมลอยจาก runtime ผมจะสลับมาดู cluster state ด้วยว่า frontend, backend path และ PostgreSQL ขึ้นอยู่จริงใน namespace `todoapp`”

### จุดที่ผู้ชมควรเห็น

1. มี frontend route ที่ตอบได้จริง
2. มี PostgreSQL StatefulSet เป็น data layer จริง
3. baseline ฝั่ง runtime ไม่ใช่แค่รูปในสไลด์

---

## 6.3 นาที 5–8 — อธิบาย runtime architecture และ routing ที่สำคัญ

### หน้าจอที่ต้องเปิด

1. Slide architecture
2. `src/phase2-final/k8s/ingress.yaml`
3. `src/phase2-final/k8s/traefik-routing.yaml`
4. `src/phase2-final/k8s/postgres-statefulset.yaml`

### สิ่งที่ควรพูด

> “runtime path ของระบบนี้เริ่มจาก public domain ผ่าน Nginx/Traefik โดย path ทั่วไปไป frontend ส่วน `/api`, `/healthz`, และ `/readyz` ไป backend weighted route ที่สามารถสลับระหว่าง stable กับ canary ได้”

> “ประเด็นนี้สำคัญมาก เพราะ canary analysis ของเราไม่ได้อาศัยแค่ rollout status แต่ใช้ weighted backend route จริงใน TraefikService”

> “ฝั่ง data layer ใช้ PostgreSQL StatefulSet บน iSCSI-backed storage และมี readiness/liveness/startup probes ชัดเจน ดังนั้น story ของเราไม่ใช่แค่ deploy app แต่คือ deploy app บนฐานข้อมูลที่ตรวจสุขภาพได้จริง”

### สิ่งที่ต้องชี้ด้วยเมาส์

1. frontend Ingress catch-all
2. backend IngressRoute + TraefikService weighted
3. PostgreSQL probes และ securityContext

---

## 6.4 นาที 8–12 — เปิด `.woodpecker/main-push.yml` และเล่า pipeline เป็นกลุ่ม stage

### หน้าจอที่ต้องเปิด

1. `.woodpecker/main-push.yml`
2. ถ้าทำได้ สลับไป Woodpecker graph หลังอธิบายแต่ละกลุ่ม stage

### วิธีเล่าที่ชัดที่สุด

แบ่งการเล่าเป็น 4 กลุ่ม ไม่ต้องอ่านทุก step ตรง ๆ

1. **ก่อน build**: Stage 0-2 คือ pre-flight, quality gates และ integration test
2. **หลัง build**: Stage 3-5 คือ build/push, sign/scan และ DB operations
3. **ตอน deploy**: Stage 6-8 คือ canary deploy, canary analysis, promote หรือ rollback
4. **หลัง deploy**: Stage 9-10 คือ smoke test, release tag, post-deploy analysis และ email

### บทพูดที่ใช้ได้ทันที

> “ถ้าจะสรุป pipeline ของเราให้ง่ายที่สุด มันไม่ใช่ test → build → deploy แบบเส้นเดียว แต่เป็นชุดของ gates ที่ลดความเสี่ยงทีละชั้นครับ”

> “ก่อน build เรามีทั้ง secret scan, Dockerfile lint, K8s lint, OPA policy, แล้วจึงรัน quality-backend กับ quality-frontend แบบขนาน ก่อนต่อด้วย integration test กับ Postgres”

> “หลังจากนั้นเราค่อย build/push images แล้ว sign และ scan ด้วย Cosign, SBOM, Trivy จากนั้นจึงทำ pg_dump backup และ migration test ก่อนถึงขั้น deploy จริง”

> “จุดที่อยากให้คนฟังจำคือ deploy ของเราไม่ใช่ยิงขึ้น 100% ทันที แต่ปล่อย canary 10% แล้ววัดผลจาก traffic จริง 160 requests และ Prometheus metrics ก่อนค่อย promote หรือ rollback”

---

## 6.5 นาที 12–15 — พิสูจน์ delivered improvements ด้วย evidence

### หน้าจอที่ต้องเปิด

1. Woodpecker run ล่าสุด
2. ถ้ามีเวลา เปิด Grafana หรือ monitoring manifests
3. ถ้ามี evidence พร้อม เปิด email notification หรือ screenshot ที่ใช้งานได้จริง

### สิ่งที่ควรพูด

> “ตรงนี้คือ evidence หลักของ Phase 2 ครับ คือเราไม่ได้อ้างว่ามี canary, monitoring หรือ security scan แต่มี run ที่แสดง stage เหล่านี้จริง และสามารถชี้ได้ว่าแต่ละ stage ทำหน้าที่อะไร”

> “ถ้าดูจาก graph นี้ คนฟังควรเห็นว่า Stage 0-5 คือการลดความเสี่ยงก่อน deploy, Stage 6-8 คือการคุม blast radius ตอน deploy, และ Stage 9-10 คือการยืนยันผลหลัง deploy”

### สิ่งที่ต้องชี้ให้เห็น

1. `quality-frontend` มีอยู่แล้วใน baseline
2. `sign-and-scan` มี Cosign/SBOM/Trivy จริง
3. `canary-analyze` ใช้ metrics ไม่ใช่แค่ “รู้สึกว่าระบบโอเค”
4. `auto-rollback` เป็นเส้นทางที่อธิบายได้
5. `email-success` หรือ `email-rollback` มีไว้ปิด feedback loop ให้ทีม

---

## 6.6 นาที 15–17 — อธิบาย success/failure path ให้เป็นประโยชน์

### สิ่งที่ควรพูดเมื่อถูกถามเรื่อง “ถ้า fail ล่ะ?”

> “ถ้า fail ใน pre-flight หรือ quality gate เราถือว่าระบบทำงานถูก เพราะหยุดปัญหาก่อน image ถูกสร้าง”

> “ถ้า fail ตอน canary analysis นั่นยิ่งสำคัญ เพราะ pipeline จะไม่ดัน traffic ไปของใหม่เต็มระบบ และ rollback route กลับสู่ stable path ได้ชัดเจน”

> “ดังนั้นคำว่า fail ในระบบนี้ต้องอธิบายเป็น stage-by-stage ไม่ใช่ตอบแค่ว่า pipeline แดง”

### สิ่งที่ต้องเน้น

1. failure ที่ดีคือ failure ที่เร็วและมี evidence
2. success ที่ดีคือ success ที่พิสูจน์ผ่านทั้ง metrics และ public smoke test

---

## 6.7 นาที 17–19 — เชื่อมกับ DevOpsSec แบบไม่ overclaim

### สิ่งที่ควรพูด

> “ถ้ามองผ่านเลนส์ DevOpsSec จุดเด่นของ Phase 2 คือเราฝังความปลอดภัยและความน่าเชื่อถือไว้ในหลายชั้นแล้ว เช่น secret hygiene, policy/lint gates, signed and scanned images, weighted rollout, runtime hardening, monitoring และ alert/email feedback”

> “สิ่งที่ยังพูดต่อได้อย่างซื่อสัตย์คือเรายังควรเพิ่ม signature verification ก่อน promote, secret rotation, restore drill, log aggregation และ alert tuning เพื่อให้ระบบ operate ได้แข็งแรงขึ้นอีก”

### อย่าลืมชี้ให้ชัด

1. ของที่มีแล้วคือ active baseline
2. ของที่เหลือคือ next steps ไม่ใช่ของที่แอบอ้างว่าทำครบแล้ว

---

## 6.8 นาที 19–20 — ถ้า reviewer ขอ live change ให้ใช้เป็น backup เท่านั้น

### ทางเลือกที่แนะนำ

1. เปลี่ยนข้อความ/label เล็ก ๆ ใน frontend เพื่อให้เห็น deploy effect ชัด
2. ปรับ wording หรือ link ใน email template เพื่อโชว์ notification path
3. ปรับเอกสาร evidence ใน `document/phase2/` ให้ตรงกับ baseline

### สิ่งที่ไม่ควรทำ

1. อย่าเสนอเพิ่ม `quality-frontend`
2. อย่าเสนอเพิ่ม Trivy, Cosign, SBOM หรือ canary 10% เพราะเป็น baseline แล้ว
3. อย่าแก้ secret, database, หรือ routing กลางเดโมถ้าไม่ได้ถูกขอเฉพาะเจาะจงจริง ๆ

ประโยคที่ใช้ได้ทันที

> “ถ้าต้องมี live change เราขอเลือก change ที่เล็กและเป็น delta จริงจาก baseline ปัจจุบัน ไม่ใช่หยิบของที่ active อยู่แล้วมาทำเหมือนเพิ่งเพิ่มวันนี้ครับ”

---

## 6.9 นาที 20–22 — ปิดเรื่องและส่งไม้ให้ผู้ฟัง

### ประโยคปิดที่แนะนำ

> “สรุป Phase 2 Final ของเราไม่ใช่แค่ Todo application ที่ deploy ขึ้นได้ แต่เป็น baseline ที่มี runtime path, delivery path, canary path และ evidence path ครบพอให้กลุ่มถัดไปอ้างต่อได้ทันทีครับ”

> “สิ่งที่ควรจำจากรอบนี้คือเราไม่ได้ใช้ pipeline แค่ทำ automation แต่ใช้ pipeline เป็นเครื่องพิสูจน์คุณภาพ ความปลอดภัย และผลลัพธ์ของการเปลี่ยนแปลงจริง”

---

## 7. Optional Live Change Menu

| ตัวเลือก | ไฟล์ที่แตะ | สิ่งที่เห็นได้ | เหตุผลที่เหมาะ |
|---|---|---|---|
| Frontend microcopy / release label | `src/phase2-final/frontend/...` | UI เปลี่ยนหลัง pipeline | ปลอดภัยและเห็นผลชัด |
| Email wording / CTA link | `.woodpecker/main-push.yml` | notification evidence เปลี่ยน | แตะ path ที่ไม่กระทบ data |
| Documentation clarity | `document/phase2/report.md` หรือ `reqchange.md` | reviewer เห็น reasoning ดีขึ้น | ไม่มี runtime risk |

ถ้าเลือกข้อใดข้อหนึ่ง ให้ย้ำ 3 อย่างเสมอ

1. แตะไฟล์น้อย
2. rollback ง่าย
3. ผลลัพธ์พิสูจน์ได้จากจอหรือ log จริง

---

## 8. สิ่งที่ไม่ควรพูดหรือทำ

1. อย่าเปิด `src/phase2-final/.woodpecker.yml` เพราะไม่ใช่ active file
2. อย่าใช้คำว่า “pipeline ของเรามีแค่ test/build/deploy/email” เพราะไม่สะท้อนของจริง
3. อย่าพูดว่า frontend quality gate เป็น planned change เพราะมันอยู่ใน baseline แล้ว
4. อย่าพูดว่า Trivy/Cosign/SBOM เป็นของที่ repo root มีเฉย ๆ เพราะ main push pipeline ใช้อยู่จริง
5. อย่าทำให้คนฟังสับสนระหว่าง dev/local path ที่ยังมี SQLite กับ production cluster path ที่ใช้ PostgreSQL

---

## 9. One-Page Cheat Sheet

1. แอป: TodoApp Big Calendar เป็นปลายทางของทุก deploy
2. Runtime: Browser → Nginx/Traefik → Frontend + Weighted Backend → PostgreSQL
3. Pipeline: `.woodpecker/main-push.yml` คือ source of truth ของ main deployment
4. Must show: quality gates, sign/scan, canary, smoke test, monitoring, email
5. Must say: evidence-first, active baseline, delivered improvements
6. Must avoid: โชว์ของเก่าเป็นของใหม่, path pipeline เก่า, stage count เก่า
7. Optional live change: frontend text, email wording, docs clarity
8. Closing line: เราส่งมอบทั้ง app และระบบพิสูจน์ผลของ app
