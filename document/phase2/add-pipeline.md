# Pipeline Improvement Status — Phase 2 Final

> เอกสารนี้สรุปว่า Phase 2 Final “เพิ่มอะไรเข้า pipeline แล้วบ้าง”, “หลักฐานอยู่ตรงไหน”, และ “ควรโชว์อะไรในวันนำเสนอ” เพื่อไม่ให้สับสนระหว่างของที่ทำเสร็จแล้วกับของที่ยังเป็น next step

---

## 1. ภาพรวมของ main push pipeline ปัจจุบัน

active production pipeline ของ Phase 2 อยู่ที่ `.woodpecker/main-push.yml` และมี logic แบบ 12-stage ดังนี้

1. Stage 0: Pre-flight checks
2. Stage 1: Quality gates
3. Stage 2: Integration test
4. Stage 3: Build & Push
5. Stage 4: Sign & Scan
6. Stage 5: DB Operations
7. Stage 6: Canary Deploy + Monitoring Sync
8. Stage 7: Canary Analysis
9. Stage 8: Promote / Auto-Rollback
10. Stage 9: Smoke Test + Release Tag
11. Stage 9b: k6 + ZAP
12. Stage 10: Email Notifications

ดังนั้นเวลาพูดหน้าห้อง ไม่ควรสรุปสั้นเกินไปว่า pipeline มีแค่ test → build → deploy → email

---

## 2. Improvement Matrix: ทำแล้วอะไรบ้าง

| Improvement | สถานะ | อยู่ตรงไหน | สิ่งที่ควรโชว์ |
|---|---|---|---|
| Pre-flight policy/security checks | ทำแล้ว | Stage 0 | `secret-scan`, `dockerfile-lint`, `k8s-lint`, `opa-policy` |
| Frontend + backend quality gates | ทำแล้ว | Stage 1 | `quality-backend`, `quality-frontend` |
| Integration test กับ Postgres | ทำแล้ว | Stage 2 | `integration-test` |
| Immutable image tags | ทำแล้ว | Stage 3 | image tag จาก commit SHA |
| Cosign + SBOM + Trivy | ทำแล้ว | Stage 4 | `sign-and-scan` log |
| pg_dump backup + migration test | ทำแล้ว | Stage 5 | `db-prep`, `migration-test` |
| Canary deploy 10% + metric analysis | ทำแล้ว | Stage 6-7 | `canary-deploy`, `canary-analyze` |
| Promote / auto-rollback | ทำแล้ว | Stage 8 | `promote-stable`, `auto-rollback` |
| Public smoke test + release tag | ทำแล้ว | Stage 9 | `smoke-test`, `create-release-tag` |
| k6 load test + ZAP baseline | ทำแล้ว | Stage 9b | `k6-load-test`, `dast-zap` |
| HTML email notification | ทำแล้ว | Stage 10 | `email-success`, `email-rollback`, `email-failure` |
| Restore drill / retention policy | ยังไม่ครบ | Outside main push | อธิบายเป็น next step |
| Signature verification ก่อน promote | ยังไม่ครบ | Outside main push | อธิบายเป็น next step |

---

## 3. จุดปรับปรุงสำคัญที่ควรเล่าอย่างละเอียด

## 3.1 Frontend Quality Gate

### สิ่งที่เปลี่ยน

1. จากเดิม pipeline ตรวจฝั่ง backend เป็นหลัก
2. ตอนนี้ `quality-frontend` เป็นส่วนหนึ่งของ baseline แล้ว
3. pipeline บังคับ `npm ci`, `type-check` และ Jest coverage path จริงก่อนเดินต่อ

### ทำไมสำคัญ

1. ลด blind spot ฝั่ง UI
2. ทำให้ feedback loop ฝั่ง frontend เกิดก่อน build/deploy
3. เป็นตัวอย่าง change ที่ small, safe, observable และตอนนี้ active อยู่จริง

### สิ่งที่ควรโชว์

1. `.woodpecker/main-push.yml` ตรง Stage 1
2. `frontend/package.json`
3. Woodpecker run ล่าสุดที่ผ่าน `quality-frontend`

---

## 3.2 Sign & Scan หลัง Build

### สิ่งที่เปลี่ยน

1. image ไม่ได้ถูก build แล้วปล่อย deploy ทันที
2. main push pipeline ทำ Cosign signing, SBOM generation และ Trivy scan ก่อนถึง DB ops และ deploy

### ทำไมสำคัญ

1. เพิ่ม traceability และ trust ของ artifact
2. ช่วยสื่อว่าระบบไม่ได้วัดแค่ functional correctness แต่ดู artifact risk ด้วย

### สิ่งที่ควรโชว์

1. Stage `sign-and-scan`
2. image tag จาก commit SHA
3. ถ้ามีเวลา ชี้คำว่า Cosign/SBOM/Trivy ใน log

---

## 3.3 Database Safety ก่อน Deploy

### สิ่งที่เปลี่ยน

1. มี `pg_dump` snapshot ก่อน deploy
2. มี migration test path แยกก่อนถึง canary
3. production cluster ใช้ PostgreSQL StatefulSet เป็น baseline

### ทำไมสำคัญ

1. ช่วยให้ Phase 2 Final ไม่ได้เล่าแค่ app path แต่เล่า data safety ด้วย
2. ทำให้ deployment story มีมิติของ recoverability มากขึ้น

### สิ่งที่ควรโชว์

1. Stage `db-prep`
2. Stage `migration-test`
3. `postgres-statefulset.yaml`

---

## 3.4 Canary Deploy + Analysis

### สิ่งที่เปลี่ยน

1. backend ไม่ถูกปล่อย 100% ทันที
2. ระบบใช้ weighted route 90/10 ระหว่าง analysis
3. วัดผลจาก 160 requests และ Prometheus metrics ก่อน promote

### ทำไมสำคัญ

1. ลด blast radius ของ release
2. ช่วยให้คำว่า rollback มี path ที่ตรวจสอบได้จริง
3. เป็น highlight ที่ควรพูดให้ชัดที่สุดในวันเดโม

### สิ่งที่ควรโชว์

1. `src/phase2-final/k8s/traefik-routing.yaml`
2. Stage `canary-deploy`
3. Stage `canary-analyze`
4. Stage `promote-stable` หรือ `auto-rollback`

---

## 3.5 Post-Deploy Verification และ Notification

### สิ่งที่เปลี่ยน

1. หลัง promote ยังมี smoke test บน public URL
2. มี release tag automation
3. มี k6 และ ZAP เป็น post-deploy analysis
4. มี HTML email notifications สำหรับ success / rollback / failure

### ทำไมสำคัญ

1. ปิด feedback loop หลัง deploy
2. ช่วยให้ reviewer เห็นว่าความสำเร็จของระบบถูกพิสูจน์หลายชั้น
3. เพิ่มความเป็น production-like ของ pipeline story

### สิ่งที่ควรโชว์

1. Stage `smoke-test`
2. Stage `k6-load-test` และ `dast-zap`
3. email evidence หรือ screenshot

---

## 4. สิ่งที่ควรพูดเวลาอธิบาย improvement เหล่านี้

ใช้ pattern นี้ได้กับทุก improvement

1. ก่อนมีสิ่งนี้ ระบบเสี่ยงอะไร
2. หลังเพิ่มสิ่งนี้ ระบบกันความเสี่ยงได้ตรงไหน
3. หลักฐานของมันอยู่ที่ stage ไหน / log ไหน / manifest ไหน

ตัวอย่างประโยค

> “สิ่งที่เปลี่ยนใน Phase 2 Final ไม่ใช่แค่จำนวน step ที่มากขึ้น แต่คือการย้าย risk checks ไปอยู่ใกล้จุดที่ควรตรวจและมี evidence รองรับชัดขึ้น”

---

## 5. สิ่งที่ยังเป็น next step จริง ๆ

แม้ pipeline จะโตขึ้นมากแล้ว แต่ยังมีสิ่งที่ควรพูดว่า “ยังไม่ครบ” อย่างตรงไปตรงมา

1. signature verification ก่อน promote
2. restore drill และ retention policy ของ backup
3. log aggregation และ alert tuning
4. frontend lint / E2E / synthetic CRUD checks
5. secret rotation หรือ external secret manager

ประเด็นนี้สำคัญ เพราะช่วยกันการ overclaim ตอนตอบคำถาม reviewer

---

## 6. สิ่งที่ควรโชว์ในวันนำเสนอจากเอกสารนี้

ถ้ามีเวลาเปิดเพียง 5 จุด ให้เรียงลำดับดังนี้

1. `.woodpecker/main-push.yml`
2. Woodpecker run ล่าสุด
3. `traefik-routing.yaml`
4. `postgres-statefulset.yaml`
5. email หรือ monitoring evidence

---

## 7. สรุป

Phase 2 Final ไม่ได้มีแค่ “pipeline เพิ่มขึ้น” แต่มี pipeline ที่ทำหน้าที่ชัดเจนขึ้นเป็นลำดับ ตั้งแต่ policy/quality checks, artifact trust, data safety, canary control, post-deploy verification ไปจนถึง notification เอกสารนี้จึงควรถูกใช้เป็น map สำหรับอธิบายว่า improvement ไหนอยู่ตรงไหนและควรโชว์ evidence ตรงจุดใดในวันเดโม