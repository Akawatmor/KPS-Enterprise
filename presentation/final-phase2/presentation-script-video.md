# Detailed Video Recording Script — Phase 2 Final

## 1. วัตถุประสงค์ของคลิปนี้

คลิปนี้ไม่ใช่เวอร์ชัน “โชว์สดแบบเสี่ยงที่สุด” แต่เป็นเวอร์ชันอธิบายภาพรวมของระบบ, workflow, แนวคิด, และ evidence ให้ผู้ชมเข้าใจครบตั้งแต่ application, infrastructure, CI/CD, ไปจนถึง DevOpsSec และ change request ที่เลือกใช้ในวันเดโมจริง

เป้าหมายของคลิปมี 4 ข้อ

1. ให้คนดูเข้าใจระบบทั้งหมดใน Phase 2 โดยไม่ต้องเปิด repo เอง
2. ให้เห็น flow ตั้งแต่ user-facing app ไปจนถึง pipeline และ deployment
3. ให้เห็นแนวคิดที่ใช้ตัดสินใจ เช่น small-safe-observable, quality gate, rollout, rollback, feedback loop
4. ให้ใช้คลิปนี้เป็น baseline อ้างอิงได้ในวันรีวิวหรือเวลาส่งงาน

---

## 2. ความยาวที่แนะนำ

ความยาวแนะนำคือ 12–15 นาที ถ้าจำเป็นต้องตัดให้สั้น ให้ลดเวลาตอนเปิด repo tree และลดช่วงอธิบายรายละเอียดของ test file แต่ยังต้องคง 5 ส่วนนี้ไว้

1. ภาพรวมระบบ
2. สถาปัตยกรรมและ deployment path
3. pipeline และ feedback loop
4. baseline runtime evidence
5. แนวคิด DevOpsSec และ live change ที่เลือก

---

## 3. หน้าจอที่ต้องเตรียมก่อนเริ่มอัด

1. Slide deck `presentation/final-phase2/slides.md`
2. Browser tab หน้า TodoApp Big Calendar
3. VS Code เปิด folder `src/phase2-final`
4. VS Code tab ที่ `.woodpecker.yml`
5. VS Code tab ที่ `k8s/core-deployment.yaml`, `k8s/postgres-statefulset.yaml`, `k8s/ingress.yaml`
6. VS Code tab ที่ `frontend/package.json` และ `frontend/__tests__/page.test.tsx`
7. Terminal พร้อม `kubectl`
8. Woodpecker UI หรืออย่างน้อย screenshot/log ของ run สำเร็จล่าสุด

ข้อห้ามระหว่างอัด

1. อย่าเปิดหน้า secret settings ของ Woodpecker แบบเห็นค่า
2. อย่าให้ terminal แสดง token, password, หรือ kubeconfig แบบเต็ม
3. อย่าอัดตอน notifications เด้งบนหน้าจอ
4. อย่าเลื่อนไฟล์เร็วเกินจนคนดูอ่านตามไม่ทัน

---

## 4. Shot List สรุปแบบเร็ว

| Scene | เวลา | จอที่ต้องเปิด | เป้าหมาย |
|---|---|---|---|
| 1 | 0:00–0:40 | Slide ปก | บอก scope และ source of truth |
| 2 | 0:40–1:40 | Slide agenda / project context | บอกว่าระบบนี้แก้อะไรและ Phase 2 ต่างจากเดิมอย่างไร |
| 3 | 1:40–3:10 | Browser หน้าแอป | โชว์ user-facing baseline |
| 4 | 3:10–4:20 | Slide architecture | อธิบาย Browser → Ingress → Web/Core → Postgres |
| 5 | 4:20–5:40 | VS Code `k8s/` | ชี้ manifests สำคัญและ deployment strategy |
| 6 | 5:40–7:10 | VS Code `.woodpecker.yml` | อธิบาย pipeline baseline |
| 7 | 7:10–8:20 | Terminal `kubectl` | โชว์ runtime evidence และ rollout thinking |
| 8 | 8:20–9:40 | `reqchange.md`, `package.json`, tests | อธิบาย live change ที่เลือก |
| 9 | 9:40–11:10 | Slide DevOpsSec / docs | อธิบาย security, feedback loop, rollback, observability |
| 10 | 11:10–12:30 | Slide recap | สรุป baseline ที่กลุ่มถัดไปควรอ้างต่อ |

ถ้าคลิปยาวได้ถึง 15 นาที ให้เพิ่ม Scene พิเศษสำหรับ Q&A simulation หรือ risk discussion อีก 2–3 นาทีท้าย

---

## 4.1 Cue Sheet แบบละเอียดมาก

ส่วนนี้ใช้เป็นแผ่นกันลืมระหว่างอัดจริง ถ้าไม่อยากเปิดดูหลาย section ให้ดูตารางนี้ก่อนแล้วค่อยลง Scene detail ด้านล่าง

| Scene | เปิดอะไร | ทำอะไรบนจอ | ประโยคหลักที่ควรพูด |
|---|---|---|---|
| 1 | Slide ปก | ค้างหน้าปก 5–8 วินาที | “คลิปนี้อธิบายภาพรวมของ KPS-Enterprise Phase 2 โดยยึด Phase 2 เป็น source of truth หลัก” |
| 2 | Slide overview | เลื่อนไป agenda/context | “เราจะดูทั้ง app, architecture, pipeline และ DevOpsSec ไม่ใช่แค่หน้าเว็บ” |
| 3 | Browser หน้าแอป | คลิกวันหนึ่งวัน, ชี้ panel และ stats | “ปลายทางของทุก deploy คือประสบการณ์ผู้ใช้ตรงนี้” |
| 4 | Slide architecture | ชี้ Browser → Ingress → Web/Core → Postgres | “runtime path ต้องถูกอธิบายให้ชัดก่อนจะพูดเรื่อง deploy” |
| 5 | VS Code `k8s/` | ชี้ replicas, RollingUpdate, probes, ingress | “สิ่งที่เล่าใน slide มีหลักฐานใน manifest จริง” |
| 6 | VS Code `.woodpecker.yml` | ชี้ test, build, deploy, verify, notify | “หลัง `git push` pipeline จะสร้าง feedback loop กลับมา” |
| 7 | Terminal | รัน `kubectl get pods -n todoapp` และ `get deploy` | “runtime evidence ยืนยันว่า baseline นี้ขึ้นจริงบน cluster” |
| 8 | `reqchange.md`, `package.json`, tests | ชี้ quality gate ที่เลือก | “change นี้ small, safe, observable และมีของรองรับอยู่แล้วใน repo” |
| 9 | Slide DevOpsSec | ชี้ current vs next | “เรามี baseline แล้ว แต่ยังมีพื้นที่ให้เสริม security gate และ observability” |
| 10 | Slide recap | ค้างหน้าสรุป 8–10 วินาที | “baseline นี้คือสิ่งที่กลุ่มถัดไปควร assume ได้เลย” |

---

## 4.2 เปิดอะไรล่วงหน้าก่อนกดอัด

ก่อนเริ่ม Scene 1 ให้จัดจอแบบนี้

1. Browser เปิดหน้า TodoApp และ login/ready แล้ว
2. VS Code เปิด `src/phase2-final` และเรียง tab ตามลำดับที่จะใช้
3. Terminal ขยาย font เรียบร้อยแล้ว
4. Woodpecker UI login แล้ว
5. Slide deck พร้อมกด next

ลำดับ tab ใน VS Code ที่แนะนำ

1. `.woodpecker.yml`
2. `k8s/core-deployment.yaml`
3. `k8s/postgres-statefulset.yaml`
4. `k8s/ingress.yaml`
5. `frontend/package.json`
6. `frontend/__tests__/page.test.tsx`
7. `document/phase2/reqchange.md`

---

## 5. Detailed Scene-by-Scene Script

## Scene 1 — เปิดคลิปและตั้งขอบเขตให้ชัด

### เวลา

0:00–0:40

### หน้าจอที่ต้องเปิด

Slide หน้าปก

### สิ่งที่ต้องให้คนดูเห็น

1. ชื่อโปรเจกต์
2. คำว่า Phase 2
3. ชื่อทีม
4. คำว่า K3s + Woodpecker CI/CD

### บทพูดที่แนะนำ

> “คลิปนี้เป็นภาพรวมของ KPS-Enterprise Phase 2 ครับ โดยระบบปัจจุบันคือ TodoApp Big Calendar ที่ deploy บน K3s แบบ self-hosted และใช้ Woodpecker เป็น CI/CD หลัก”

> “ในคลิปนี้เราจะยึด `src/phase2-final`, `document/phase2`, และ `implementation/phase2` เป็น source of truth เพื่ออธิบายทั้ง app, pipeline, deployment flow, และแนวคิด DevOpsSec ที่ใช้ในงานนี้”

### หมายเหตุด้านภาพ

1. อย่าอยู่หน้าปกนานเกิน 40 วินาที
2. ชี้ด้วยเมาส์สั้น ๆ แค่ชื่อระบบและ Phase 2

---

## Scene 2 — อธิบายภาพรวมโปรเจกต์และสิ่งที่เปลี่ยนจากอดีต

### เวลา

0:40–1:40

### หน้าจอที่ต้องเปิด

Slide project context หรือ overview

### สิ่งที่ต้องให้คนดูเห็น

1. ระบบนี้ไม่ใช่แค่ web app แต่เป็น full delivery system
2. Phase 1 เคยเน้น Jenkins/EKS เป็นบริบทเก่า
3. Phase 2 ย้าย baseline มาเป็น K3s + Woodpecker + TodoApp Big Calendar

### บทพูดที่แนะนำ

> “ถ้ามองจากมุมผู้ใช้ ระบบนี้คือ Todo application ที่ใช้ปฏิทินเป็นหน้าหลัก ผู้ใช้สามารถเปิดวันใดวันหนึ่งแล้วจัดการ todo ของวันนั้นได้ทันที”

> “แต่ถ้ามองจากมุม DevOps Phase 2 ไม่ได้จบที่หน้าเว็บครับ เราทำให้ทั้งการทดสอบ, การ build image, การ deploy, การ rollout verification และการแจ้งผล กลายเป็น flow ที่อัตโนมัติและตรวจสอบย้อนกลับได้”

> “ดังนั้นเวลาเราพูดคำว่าระบบในคลิปนี้ เราหมายถึงทั้ง application path และ delivery path พร้อมกัน”

### หมายเหตุด้านภาพ

ถ้ามี slide เปรียบเทียบก่อน-หลัง ให้ชี้เฉพาะสิ่งที่ผู้ชมต้องจำ เช่น self-hosted K3s, Traefik ingress, Woodpecker pipeline, PostgreSQL backend

---

## Scene 3 — โชว์แอปจริงให้เข้าใจ user-facing baseline

### เวลา

1:40–3:10

### หน้าจอที่ต้องเปิด

Browser หน้า TodoApp Big Calendar

### สิ่งที่ต้องทำให้เห็นบนจอ

1. หน้า calendar แบบเต็มจอ
2. stats bar ด้านบนหรือส่วนสรุปงาน
3. คลิกวันหนึ่งวันให้เห็น side panel
4. ถ้ามี task อยู่แล้ว ให้ชี้สี, priority, status

### บทพูดที่แนะนำ

> “นี่คือ baseline ฝั่งผู้ใช้ครับ หน้าแรกเป็น Big Calendar ที่แสดง todo ตามวันจริง ไม่ใช่แค่ list ทั่วไป ผู้ใช้เห็นภาพรวมของเดือน และสามารถคลิกวันเพื่อเปิด panel ด้านข้างแล้วจัดการงานของวันนั้นได้”

> “ประโยชน์ของ UI แบบนี้คือ user มองงานในเชิงเวลาได้ทันที เช่น งานวันนี้, งานค้าง, งานเสร็จแล้ว หรือ task ที่มี priority สูง”

> “จุดที่ต้องจำไว้คือ ตอนเราพูดเรื่อง pipeline เราไม่ได้ build/deploy อะไรที่ลอยจากผู้ใช้ เพราะ output ปลายทางของ pipeline ก็คือหน้าจอนี้เอง”

### การเคลื่อนหน้าจอ

1. เลื่อนเมาส์ให้ช้า
2. คลิกวันหนึ่งครั้งพอ
3. ถ้าจะเพิ่ม task สั้น ๆ ก็ได้ แต่ไม่จำเป็นในคลิป overview

---

## Scene 4 — อธิบายสถาปัตยกรรมจากผู้ใช้ไปถึง data layer

### เวลา

3:10–4:20

### หน้าจอที่ต้องเปิด

Slide architecture

### สิ่งที่ต้องให้คนดูเห็น

1. Browser → Traefik Ingress
2. Frontend และ backend แยกกัน
3. Backend คุยกับ PostgreSQL
4. ทั้งหมดอยู่บน K3s

### บทพูดที่แนะนำ

> “request path ของระบบนี้เริ่มจาก browser ผ่านโดเมนเข้า Traefik ingress ซึ่งเป็น default ingress controller ของ K3s จากนั้น path ทั่วไปจะไป frontend ส่วน `/api`, `/healthz`, และ `/readyz` จะ route ไปที่ backend”

> “ฝั่ง backend เป็น Go service และ data layer ปัจจุบันใน cluster path ใช้ PostgreSQL StatefulSet ทำให้ backend สามารถรันหลาย replica และใช้ RollingUpdate ได้ง่ายกว่าแนว SQLite แบบ single writer”

> “ดังนั้น deployment story ของ Phase 2 คือพยายามทำให้ runtime path ตรงกับแนวคิด availability, reproducibility และ update แบบควบคุมได้”

### หมายเหตุด้านภาพ

ถ้ามี diagram ให้ค้างประมาณ 10 วินาทีตอนอธิบาย path เพื่อให้คนดูจับ flow ทัน

---

## Scene 5 — เปิด manifests จริงให้เห็นว่า architecture ไม่ได้มีแค่ใน slide

### เวลา

4:20–5:40

### หน้าจอที่ต้องเปิด

1. `src/phase2-final/k8s/core-deployment.yaml`
2. `src/phase2-final/k8s/postgres-statefulset.yaml`
3. `src/phase2-final/k8s/ingress.yaml`

### สิ่งที่ต้องชี้บนจอ

1. backend `replicas: 2`
2. `RollingUpdate`
3. readiness/liveness probes
4. PostgreSQL StatefulSet
5. ingress route แยก `/api` และ `/healthz`/`/readyz`

### บทพูดที่แนะนำ

> “ตรงนี้คือหลักฐานจาก manifest จริงครับ ไม่ใช่แค่สไลด์ เราจะเห็นว่า backend ถูกตั้งให้รัน 2 replicas และใช้ `RollingUpdate` เพื่อให้ rollout ใหม่ไม่ต้องดับทั้งระบบพร้อมกัน”

> “นอกจากนี้ยังมี readiness และ liveness probes ซึ่งสำคัญมากในมุม DevOps เพราะมันบอกทั้ง Kubernetes และ pipeline ว่า pod พร้อมรับ traffic จริงหรือยัง”

> “ฝั่งฐานข้อมูล เราใช้ PostgreSQL แบบ StatefulSet เพื่อแยก data layer ออกจากตัว app ทำให้ deployment ของ backend ยืดหยุ่นขึ้น และสอดคล้องกับเป้าหมายการ scale และการ update ที่ควบคุมได้”

> “ส่วน ingress คือจุดที่ทำให้ frontend กับ backend อยู่ใต้โดเมนเดียวกัน แต่ยัง route traffic ไปคนละ service ได้อย่างเป็นระบบ”

### หมายเหตุด้านภาพ

1. เลื่อนเฉพาะจุดสำคัญ อย่าเลื่อนทั้งไฟล์เร็วเกินไป
2. ถ้าต้องเลือกเพียงไฟล์เดียว ให้เลือก `core-deployment.yaml` ก่อน เพราะมี replicas, strategy และ probes ครบ

---

## Scene 6 — เปิด pipeline baseline และอธิบาย feedback loop ของ CI/CD

### เวลา

5:40–7:10

### หน้าจอที่ต้องเปิด

`src/phase2-final/.woodpecker.yml`

### สิ่งที่ต้องชี้บนจอ

1. `test-backend`
2. `build-push-core`
3. `build-push-web`
4. `deploy-k3s`
5. `notify-email`

### บทพูดที่แนะนำ

> “baseline pipeline ของ Phase 2 ปัจจุบันเริ่มจาก test-backend ก่อน เพื่อให้ backend ผ่าน unit and vet checks จากนั้น build และ push image ของ core กับ web ไป Docker Hub แล้วจึง deploy ไปยัง K3s ด้วย `kubectl`”

> “หลัง deploy pipeline จะรอ rollout status ของ deployment ทั้งสองตัว และมี smoke test เบื้องต้นที่ยิง `/healthz` เพื่อเช็กว่าระบบตอบสนองได้จริง สุดท้ายจึงส่ง email notification กลับไปให้ทีม”

> “นี่คือ feedback loop ที่สำคัญมาก เพราะหลัง `git push` ทีมไม่ต้องเดาสุ่มเองว่า deploy สำเร็จหรือไม่ แต่มี pipeline เป็นคนบอกอย่างเป็นระบบ”

### ประโยคที่ต้องไม่ลืม

> “ถ้าเราจะอธิบาย CI/CD ให้เข้าใจง่ายที่สุด ระบบนี้คือการแปลงคำว่า ‘เดิมต้องทำมือหลายขั้น’ ให้กลายเป็นคำสั่งเดียวคือ `git push` แล้วปล่อยให้ pipeline สร้าง feedback กลับมาเป็นลำดับ”

---

## Scene 7 — โชว์ runtime evidence ผ่าน kubectl

### เวลา

7:10–8:20

### หน้าจอที่ต้องเปิด

Terminal

### คำสั่งที่แนะนำ

```bash
kubectl get pods -n todoapp
kubectl get deploy -n todoapp
kubectl get ingress -n todoapp
```

### สิ่งที่ต้องชี้บนจอ

1. pod ของ web, core และ postgres
2. deployment พร้อมใช้งาน
3. ingress host

### บทพูดที่แนะนำ

> “ตรงนี้คือ runtime evidence ที่ช่วยยืนยันว่าคำอธิบายใน slide และ YAML สะท้อนระบบที่ขึ้นจริงบน cluster ไม่ใช่เอกสารลอย ๆ”

> “เวลาสอนหรือสาธิตเรื่อง CI/CD ผมคิดว่าสำคัญมากที่ต้องเชื่อม pipeline กับ runtime state ให้ได้ เพราะถ้าโชว์แต่ YAML โดยไม่โชว์ cluster คนฟังจะไม่เห็นปลายทางของ deployment จริง”

### หมายเหตุด้านภาพ

1. ถ้า output ยาว ให้ขยาย terminal font ล่วงหน้า
2. อย่ารันคำสั่งเยอะเกินจนเสียเวลา

---

## Scene 8 — อธิบาย change request ที่เลือกและทำไมมันเหมาะกับวันเดโม

### เวลา

8:20–9:40

### หน้าจอที่ต้องเปิด

1. `document/phase2/reqchange.md`
2. `src/phase2-final/frontend/package.json`
3. `src/phase2-final/frontend/__tests__/page.test.tsx`

### สิ่งที่ต้องชี้บนจอ

1. requirement ที่เลือกคือ frontend quality gate
2. scripts `type-check` และ `test:ci`
3. หลักฐานว่ามี frontend tests อยู่จริง

### บทพูดที่แนะนำ

> “change request ที่เราเลือกใช้ในวันเดโมสดคือเพิ่ม frontend quality gate ใน Woodpecker pipeline ให้ frontend ต้องผ่าน `npm run type-check` และ `npm run test:ci` ก่อนถึงขั้น build web image”

> “เหตุผลที่เลือก change นี้เพราะมันตรงโจทย์ small, safe, observable มากที่สุด เราแตะไฟล์เดียวคือ pipeline config, ไม่แตะ production secret, ไม่แตะ database, และ observable result ชัดมากใน Woodpecker UI”

> “ที่สำคัญคือมันไม่ใช่ requirement ที่คิดลอย ๆ เพราะใน repo มีทั้ง script และ tests อยู่แล้ว ดังนั้นการเปลี่ยนนี้คือการยกระดับ quality gate จากของที่มีอยู่ให้เข้าไปอยู่ใน feedback loop จริง”

### หมายเหตุด้านภาพ

1. เลื่อน `package.json` ให้เห็น scripts ชัด ๆ
2. เลื่อน test file ให้เห็นชื่อ test ที่ผูกกับ calendar behavior สัก 2–3 อัน

---

## Scene 9 — อธิบาย DevOpsSec แบบผูกกับของจริง ไม่ใช่คำสวย ๆ

### เวลา

9:40–11:10

### หน้าจอที่ต้องเปิด

Slide DevOpsSec หรือเอกสาร `presentation/final-phase2/devopssec-supplement.md`

### แกนที่ต้องพูด

1. secret management
2. deployment safety
3. container hardening
4. pipeline quality gates
5. future hardening ที่ควรเสริม

### บทพูดที่แนะนำ

> “สำหรับโปรเจกต์นี้คำว่า DevOpsSec ไม่ได้หมายถึงแค่เพิ่ม scanner เข้าไปหนึ่งตัว แต่หมายถึงการฝังมุมความปลอดภัยและความน่าเชื่อถือไว้ในทุกช่วงของ delivery flow”

> “ของที่มีอยู่แล้วใน baseline ปัจจุบัน เช่น การใช้ secret ผ่าน pipeline และ Kubernetes, การไม่ hardcode credential ใน repo, การใช้ readiness/liveness probe, การใช้ non-root security context, และการรอ rollout status ก่อนถือว่า deploy สำเร็จ”

> “ส่วนของที่ควรต่อยอดทันทีถ้ามีเวลามากขึ้นคือ Trivy scan, SBOM, image signing ด้วย Cosign, policy check, monitoring/logging, และ backup/restore flow ที่เป็นระบบ”

### หมายเหตุด้านภาพ

ถ้ามีเวลา ให้ชี้ว่าใน repo root มี pattern ขั้นสูงกว่าเรื่อง Cosign/SBOM อยู่แล้ว แต่ source of truth สำหรับ Phase 2 เดิมยังเป็น `src/phase2-final/.woodpecker.yml`

---

## Scene 10 — สรุปให้คนดูรู้ว่ากลุ่มถัดไปควรเริ่มจากตรงไหน

### เวลา

11:10–12:30

### หน้าจอที่ต้องเปิด

Slide recap หรือ closing

### สิ่งที่ต้องพูดให้ครบ

1. baseline application
2. baseline deployment path
3. baseline pipeline flow
4. selected live change
5. สิ่งที่กลุ่มถัดไปไม่ต้องเล่าซ้ำ

### บทพูดที่แนะนำ

> “สรุป Phase 2 ของเรา ระบบนี้คือ TodoApp Big Calendar ที่ deploy บน K3s ผ่าน Traefik, backend คุยกับ PostgreSQL, และใช้ Woodpecker pipeline ทำ test, build, push, deploy, rollout verification และ notification แบบอัตโนมัติ”

> “สำหรับวันเดโมสด เราจะใช้ baseline นี้เป็นจุดตั้งต้น แล้วทำ change แบบ small-safe-observable โดยเลือกเพิ่ม frontend quality gate เพื่อ reinforce feedback loop ของ pipeline”

> “ดังนั้นถ้ากลุ่มถัดไปจะอธิบายงานต่อ เขาสามารถ assume baseline นี้ได้เลย แล้วค่อยเล่าเฉพาะส่วนที่ตนเองแก้ต่างหรือเสริม เช่น security, config, failure handling, deployment strategy หรือ monitoring”

> “นี่คือเหตุผลว่าทำไมเราไม่ได้เล่าแค่ฟีเจอร์ของแอป แต่เล่าทั้งระบบส่งมอบ เพราะสิ่งที่อยากให้ผู้ฟังเข้าใจไม่ใช่แค่ app ทำอะไรได้ แต่คือ app ถูกส่งมอบและควบคุมคุณภาพอย่างไร”

---

## 6. ถ้าจะทำเวอร์ชันคลิปยาว 15 นาที ให้เพิ่ม 2 scene นี้

## Scene 11 — Q&A simulation

### เวลา

12:30–13:40

### ประเด็นที่แนะนำ

1. ทำไมเลือก Woodpecker แทน Jenkins ใน Phase 2
2. ถ้า pipeline fail จะรู้ root cause ยังไง
3. ถ้าต้อง rollback ทำอะไรบ้าง

### ประโยคสั้นที่ใช้ได้

> “Woodpecker ตรงกับ self-hosted K3s pipeline ที่เรียบง่ายกว่าและตั้งต้นได้เร็วกว่า Jenkins ในบริบทนี้”

> “ถ้า pipeline fail เราไม่มองว่าเป็นเรื่องแย่โดยอัตโนมัติ แต่ดูว่า fail เร็วพอไหมและหยุดก่อนของไม่ดีจะไปถึง production ได้หรือไม่”

---

## Scene 12 — Risk and Improvement Discussion

### เวลา

13:40–15:00

### ประเด็นที่แนะนำ

1. security scan ยังควรเพิ่มใน active pipeline
2. config drift ต้องลด
3. monitoring/logging ควรถูกยกขึ้นเป็นส่วนหนึ่งของ operational baseline
4. backup และ restore ของ PostgreSQL ควรมี runbook และการทดสอบจริง

### บทพูดที่แนะนำ

> “จุดที่ยังพัฒนาได้ต่อมีอยู่ชัดเจนครับ เช่น security gate เชิงลึก, config drift cleanup ระหว่าง manifest กับ deploy step, และ operational observability ที่ทำให้ทีมไม่เพียง deploy ได้ แต่ operate ได้อย่างมั่นใจต่อเนื่อง”

---

## 7. Checklist สิ่งที่ต้องโชว์ให้ครบในคลิป

1. หน้าแอปจริง
2. อย่างน้อย 1 manifest ที่มี replicas และ probes
3. อย่างน้อย 1 ส่วนของ `.woodpecker.yml`
4. output จาก `kubectl get pods -n todoapp`
5. เอกสาร change request หรือ source ของ live change
6. แนวคิด DevOpsSec ที่พูดจากของจริง ไม่ใช่ลอย ๆ

---

## 8. เทคนิคการอัดให้ดูมืออาชีพขึ้น

1. ใช้ zoom หน้าจอ 125–135% เพื่อให้อ่าน YAML และ terminal ง่าย
2. เวลาสลับจาก slide ไป code ให้หยุด 1 วินาทีก่อนเริ่มพูดหัวข้อใหม่
3. อย่า scroll ไฟล์ระหว่างพูดประโยคสำคัญ เพราะคนดูจะอ่านไม่ทัน
4. ถ้าต้องรอ pipeline หรือ network ให้ตัดต่อได้ แต่อย่าตัด logic ของ flow ออก
5. ถ้าต้องใช้ screenshot ของ Woodpecker run ให้พูดตรง ๆ ว่าเป็น evidence จาก run ล่าสุด ไม่ควรทำเหมือนกำลังเกิด realtime ถ้าไม่ใช่จริง

---

## 9. ประโยคปิดคลิปที่แนะนำ

> “ภาพรวมของ Phase 2 คือเราไม่ได้สร้างแค่ Todo application แต่สร้างระบบส่งมอบที่มี baseline ชัด, deploy path ชัด, feedback loop ชัด และพร้อมรับ change แบบเล็ก ปลอดภัย และตรวจสอบได้ผ่าน pipeline จริง ขอบคุณครับ”

---

## 9.1 Mini Teleprompter Version

ถ้าต้องอัดแบบเกือบอ่านตามได้เลย ให้ยึด 10 บรรทัดนี้

1. “คลิปนี้อธิบาย KPS-Enterprise Phase 2 โดยยึด Phase 2 เป็น source of truth หลัก”
2. “ระบบนี้มีทั้งมุมผู้ใช้และมุม delivery flow อยู่พร้อมกัน”
3. “หน้า Big Calendar คือปลายทางที่ทุก deploy ต้องส่งผลกลับมาให้เห็น”
4. “runtime path คือ Browser ผ่าน Traefik ไป frontend และ backend ที่คุยกับ PostgreSQL”
5. “manifest จริงยืนยันเรื่อง replicas, RollingUpdate, probes และ ingress routing”
6. “Woodpecker pipeline คือ feedback loop หลัง `git push`”
7. “cluster state ยืนยันว่า baseline นี้ขึ้นจริง ไม่ได้อยู่แค่ในเอกสาร”
8. “live change ที่เลือกคือเพิ่ม frontend quality gate ก่อน build web image”
9. “DevOpsSec ของระบบนี้มี baseline แล้ว แต่ยังควรเสริม security gate, supply chain trust และ observability”
10. “สิ่งที่กลุ่มถัดไปควรรับช่วงต่อคือ baseline นี้ แล้วเล่าเฉพาะสิ่งที่ตัวเองต่อยอด”