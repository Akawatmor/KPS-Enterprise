# Live Presentation Rehearsal Script — A/B Detailed Version

## 1. เอกสารนี้ใช้เมื่อไร

ไฟล์นี้ใช้ซ้อมเดโมจริงแบบมีผู้พูด 2 คน โดยออกแบบให้เน้น **Final Phase 2 baseline ที่ทำเสร็จแล้ว** ไม่ใช่การแสดง requirement change แบบเดิมที่ตอนนี้กลายเป็นส่วนหนึ่งของ baseline ไปแล้ว

แนวคิดของไฟล์นี้คือ

1. Speaker A คุม story และ logic
2. Speaker B คุมจอและชี้ evidence
3. ถ้า reviewer ขอ live change ให้ใช้เป็น backup เท่านั้น
4. ทุกช่วงต้องมีคำตอบว่ากำลังพิสูจน์อะไรบนจอ

---

## 2. บทบาท

| คน | บทบาทหลัก | บทบาทรอง |
|---|---|---|
| Speaker A | เล่าเรื่อง, คุม flow, เชื่อมกับ CI/CD/DevOpsSec | ปิดประเด็นและตอบ reviewer |
| Speaker B | เปิดไฟล์, รันคำสั่ง, ชี้ evidence | เสริมเหตุผลเชิงเทคนิค |

ถ้ามีคนเดียว ให้รวมบท A และ B เข้าด้วยกันตามลำดับเดิม

---

## 3. สิ่งที่ต้องเปิดค้างก่อนเริ่ม

### Browser

1. หน้า `https://todoapp-kps.akawatmor.com`
2. Woodpecker UI run ล่าสุดของ main push
3. ถ้ามีเวลา เปิด Grafana ไว้ด้วย

### VS Code tabs

1. `presentation/final-phase2/slides.md`
2. `.woodpecker/main-push.yml`
3. `src/phase2-final/k8s/ingress.yaml`
4. `src/phase2-final/k8s/traefik-routing.yaml`
5. `src/phase2-final/k8s/postgres-statefulset.yaml`
6. `src/phase2-final/frontend/package.json`
7. `document/phase2/reqchange.md`

### Terminal

```bash
kubectl get pods -n todoapp
kubectl get deploy,statefulset -n todoapp
kubectl get ingress,ingressroute,traefikservice -n todoapp
kubectl get servicemonitor,prometheusrule -n monitoring
```

---

## 4. สิ่งที่ทั้งสองคนต้องจำตรงกัน

1. active pipeline อยู่ที่ `.woodpecker/main-push.yml`
2. `quality-frontend`, Trivy, Cosign, SBOM และ canary 10% เป็น baseline ที่มีอยู่แล้ว
3. ถ้าจะทำ live change ห้ามหยิบ baseline เดิมมาขายว่าเป็น new change
4. เรื่องหลักของเดโมคือ “ระบบพิสูจน์ผลการส่งมอบได้จริง”

---

## 5. 22-Minute Script — Detailed Hand-off Version

## ช่วง 0:00–1:30 — เปิดและล็อก scope

### สิ่งที่ต้องเปิด

1. Slide ปก
2. Slide source of truth

### Speaker A พูด

> “สวัสดีครับ วันนี้กลุ่ม KPS-Enterprise จะนำเสนอ Phase 2 Final ของระบบ TodoApp Big Calendar บน K3s และ Woodpecker CI/CD โดยเราจะยึด `src/phase2-final` และ `.woodpecker/` เป็น source of truth หลักครับ”

> “เป้าหมายของรอบนี้ไม่ใช่แค่โชว์ว่าแอปขึ้น แต่โชว์ว่าเรามี baseline ที่ build, verify, deploy, observe และอธิบาย evidence ได้ครบ”

### Speaker B ทำ

1. ค้างหน้าปก
2. ชี้ slide source of truth

### Speaker B พูดเสริม

> “สิ่งที่เราจะเล่าต่อจากนี้จะอ้างเฉพาะสิ่งที่ active จริง เช่น `.woodpecker/main-push.yml` ไม่ใช่ pipeline path เก่าที่ไม่ได้ใช้แล้วครับ”

---

## ช่วง 1:30–4:00 — โชว์ user-facing baseline และ runtime state

### สิ่งที่ต้องเปิด

1. Browser หน้าแอป
2. Terminal

### Speaker A พูด

> “ปลายทางของทุก deploy คือหน้า Big Calendar ตรงนี้ครับ เมื่อคลิกวันก็สามารถเปิด panel มาจัดการงานของวันนั้นได้จริง”

> “แต่เพื่อไม่ให้เดโมลอย เราจะสลับไปดู runtime state ด้วยว่า workload หลักของระบบขึ้นอยู่จริงใน cluster”

### Speaker B ทำ

1. เปิด browser หน้า TodoApp
2. คลิกวันหนึ่งวัน
3. สลับไป terminal แล้วรัน `kubectl get pods -n todoapp`
4. รัน `kubectl get deploy,statefulset -n todoapp`

### Speaker B พูด

> “ตรงนี้จะเห็น frontend, backend path และ PostgreSQL StatefulSet อยู่ใน namespace `todoapp` จริง ซึ่งเป็น baseline ฝั่ง runtime ของเรา”

---

## ช่วง 4:00–6:30 — อธิบาย architecture และ routing ที่ใช้จริง

### สิ่งที่ต้องเปิด

1. Slide architecture
2. `src/phase2-final/k8s/ingress.yaml`
3. `src/phase2-final/k8s/traefik-routing.yaml`
4. `src/phase2-final/k8s/postgres-statefulset.yaml`

### Speaker A พูด

> “runtime path ของระบบนี้คือ Browser ผ่าน public domain เข้า Traefik แล้วแยก path ทั่วไปไป frontend ส่วน `/api`, `/healthz`, และ `/readyz` ไป weighted backend route ที่เชื่อม stable กับ canary ไว้”

> “จุดนี้สำคัญเพราะ canary analysis ของเราผูกกับ route จริง ไม่ใช่แค่ rollout status อย่างเดียว”

### Speaker B ทำ

1. ชี้ frontend Ingress catch-all
2. ชี้ TraefikService weighted route
3. ชี้ PostgreSQL probes และ security settings

### Speaker B พูดเสริม

> “พูดง่าย ๆ คือ route, data layer และ health model ของระบบนี้อยู่ใน baseline เดียวกัน ไม่ได้แยกเป็นคนละเรื่อง”

---

## ช่วง 6:30–11:00 — เปิด `.woodpecker/main-push.yml` และเล่า pipeline เป็นกลุ่ม

### สิ่งที่ต้องเปิด

1. `.woodpecker/main-push.yml`
2. Woodpecker UI หากต้องสลับดู graph

### Speaker A พูด

> “main push pipeline ของเราเป็นหัวใจของ Phase 2 Final ครับ เพราะมันไม่ได้ทำแค่ build แล้ว deploy แต่ลดความเสี่ยงทีละชั้น”

> “Stage 0 ถึง 2 คือ pre-flight checks, quality gates และ integration test กับ Postgres”

> “Stage 3 ถึง 5 คือ build/push, sign-and-scan, และ database safety เช่น pg_dump กับ migration test”

> “Stage 6 ถึง 8 คือ canary deploy, metric-based analysis และ promote หรือ rollback”

> “Stage 9 ถึง 10 คือ smoke test, release tag, post-deploy analysis และ email notification”

### Speaker B ทำ

1. เลื่อน `.woodpecker/main-push.yml` ตามกลุ่ม stage ที่ A พูด
2. ชี้ `quality-frontend`, `sign-and-scan`, `canary-analyze`, `auto-rollback`, `smoke-test`, `email-success`
3. สลับไป Woodpecker graph ถ้าจังหวะเหมาะ

### Speaker B พูดเสริม

> “ตรงนี้คือสิ่งที่อยากให้คนดูเห็นว่า improvement ของ Phase 2 ไม่ได้อยู่ที่ step เดียว แต่เป็น chain ของ gates และ evidence ที่ต่อกัน”

---

## ช่วง 11:00–14:00 — ชี้ delivered improvements จาก evidence จริง

### สิ่งที่ต้องเปิด

1. Woodpecker run ล่าสุด
2. ถ้าพร้อม เปิด monitoring หรือ email evidence

### Speaker A พูด

> “เวลาพูดคำว่า delivered improvements เราไม่ได้หมายถึง list ในเอกสารอย่างเดียว แต่หมายถึงสิ่งที่ชี้ได้จาก run จริง เช่น quality-frontend ที่ active อยู่แล้ว, sign-and-scan ที่ทำ Cosign/SBOM/Trivy, และ canary analysis ที่วัดจาก traffic กับ Prometheus metrics”

### Speaker B ทำ

1. ชี้ stage `quality-frontend`
2. ชี้ stage `sign-and-scan`
3. ชี้ stage `canary-analyze` และ `auto-rollback` หรือ `promote-stable`
4. ถ้ามี เปิด email success/rollback screenshot

### Speaker B พูด

> “สิ่งที่ผู้ชมควรจำคือแต่ละ stage ลดความเสี่ยงต่างกัน และเรามีจุดพิสูจน์ของแต่ละอย่างบนจอจริง”

---

## ช่วง 14:00–16:30 — อธิบาย success path กับ failure path

### Speaker A พูด

> “ถ้า success เราต้องอธิบายได้ว่าเพราะผ่านทั้ง quality, security, canary และ smoke test ไม่ใช่เพียงเพราะ rollout ผ่าน”

> “ถ้า fail เราก็ต้องอธิบายเป็น stage-by-stage เช่น fail ใน pre-flight, fail ใน quality gate, หรือ fail ใน canary analysis ซึ่งแต่ละแบบสะท้อนว่าระบบหยุดความเสี่ยงได้เร็วแค่ไหน”

### Speaker B พูดเสริม

> “ดังนั้น pipeline แดงไม่ใช่เรื่องน่าอายถ้ามันแดงในจุดที่ควรแดงและอธิบาย root cause ได้ชัด”

---

## ช่วง 16:30–18:30 — เชื่อมกับ DevOpsSec

### สิ่งที่ต้องเปิด

1. Slide DevOpsSec หรือ supplement doc

### Speaker A พูด

> “DevOpsSec ของระบบนี้ไม่ได้เริ่มที่ scanner ตัวเดียว แต่เริ่มตั้งแต่ secret hygiene, policy/lint gates, signed and scanned images, weighted rollout, runtime hardening, monitoring และ notification”

### Speaker B พูดเสริม

> “ส่วน next step ที่ยังควรพูดอย่างซื่อสัตย์คือ signature verification ก่อน promote, secret rotation, restore drill, log aggregation และ alert tuning”

---

## ช่วง 18:30–20:00 — ถ้า reviewer ขอ live change

### Speaker A พูด

> “ถ้าต้องมี live change เราจะเลือก change ที่เป็น delta จริงจาก baseline ปัจจุบัน เช่น frontend microcopy, notification wording หรือ documentation clarity โดยไม่หยิบ feature ที่ทำเสร็จแล้วมาขายว่าเป็นของใหม่”

### Speaker B ทำ

1. เปิด `document/phase2/reqchange.md` ถ้าต้องอธิบายเหตุผล
2. ชี้ว่า `quality-frontend` เป็น implemented change แล้ว ไม่ใช่ตัวเลือก live change หลักอีกต่อไป

---

## ช่วง 20:00–22:00 — ปิดเรื่องและส่งไม้ให้ reviewer

### Speaker A พูด

> “สรุปวันนี้เรา establish baseline ของระบบครบทั้ง app, runtime, route, pipeline, monitoring และ notification แล้ว และสิ่งที่กลุ่มถัดไปควร assume ได้เลยคือ baseline นี้ทั้งหมด”

### Speaker B พูดปิด

> “ถ้าจะดู evidence หลักของรอบนี้ ให้ดู 3 ชุดคือ cluster state, `.woodpecker/main-push.yml` กับ Woodpecker run จริง และ feedback หลัง deploy เช่น smoke test, monitoring และ email ครับ”

---

## 6. เวอร์ชันย่อ 10 นาที

| เวลา | Speaker A | Speaker B |
|---|---|---|
| 0:00–1:00 | เปิด, บอก source of truth และ message หลัก | เปิด slide ปกและ source of truth |
| 1:00–2:30 | โชว์ app baseline | เปิด browser และ day panel |
| 2:30–4:00 | อธิบาย runtime path | เปิด architecture + manifests |
| 4:00–6:00 | สรุป pipeline เป็น 4 กลุ่ม stage | เปิด `.woodpecker/main-push.yml` |
| 6:00–7:30 | ชี้ delivered improvements | เปิด Woodpecker graph |
| 7:30–8:30 | สรุป success/failure logic | ชี้ canary/promote/rollback |
| 8:30–9:30 | เชื่อมกับ DevOpsSec | เปิด slide supplement |
| 9:30–10:00 | ปิดและบอกสิ่งที่กลุ่มถัดไป assume ได้ | เปิด closing slide |

---

## 7. ประโยคสำรองเวลาเดโมสะดุด

### ถ้า browser ช้า

> “หน้าแอปเป็นปลายทางที่เราตรวจไว้แล้ว แต่เพื่อไม่ให้เสียเวลาเราจะข้ามไปดู evidence ฝั่ง pipeline และ cluster ซึ่งเป็นหัวใจของ Phase 2 Final”

### ถ้า Woodpecker ช้า

> “อย่างน้อยเรายังชี้ source of truth และ run ล่าสุดที่แสดง stage หลักได้ ซึ่งยังสะท้อน logic ของระบบจริงอยู่”

### ถ้า reviewer ขอ change ใหญ่เกินไป

> “change นี้มี value ครับ แต่เกิน time box และเกิน blast radius ที่เหมาะกับรอบเดโม เราขอแตกเป็น change เล็กกว่าที่พิสูจน์ผลได้ชัดแทน”