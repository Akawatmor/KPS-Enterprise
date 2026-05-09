# Detailed Live Presentation Script — Phase 2 Final

## 1. เป้าหมายของสคริปต์นี้

สคริปต์นี้ออกแบบมาสำหรับการนำเสนอแบบ Owner-led ในรอบ Pod Review ที่มีเวลา 22 นาที และต้องมีทั้งการอธิบาย baseline ของระบบ, การโชว์ normal case, การรับ change request หรือ failure/risk จาก reviewer, และการทำ making change แบบสด ๆ ให้เห็นผ่าน pipeline จริง

แกนหลักที่ต้องยึดตลอดการพูดมี 4 ข้อ

1. อธิบาย baseline เดิมให้คนฟังเข้าใจตรงกันก่อนว่า “ระบบที่ถูกต้อง” หน้าตาเป็นอย่างไร
2. เชื่อมทุกช่วงกับแนวคิด CI/CD ให้ชัด เช่น build, test, deploy, automation, feedback loop
3. ทำ live change ที่เล็ก ปลอดภัย และสังเกตผลได้ผ่าน pipeline ภายในเวลา review
4. จบด้วยการบอกให้ชัดว่าหลังจาก baseline นี้ กลุ่มถัดไปสามารถเล่าเฉพาะส่วนที่ตนเองต่อยอดได้โดยไม่ต้องเล่าทุกอย่างซ้ำ

---

## 2. Source of Truth ที่ต้องยึดระหว่างพูด

ระหว่างนำเสนอ ให้ยึดเอกสารและโค้ดชุดนี้เป็นหลัก

1. `src/phase2-final/` เป็น source of truth หลักของ application, manifests และ Woodpecker pipeline
2. `document/phase2/` เป็น source of truth หลักของการอธิบายเหตุผล, report, guide และ change request
3. `implementation/phase2/implementation-info.md` ใช้เสริมเรื่อง environment และ flow การติดตั้ง
4. `presentation/checkpoint/` ใช้ดู pattern การเล่าเดิมได้ แต่ไม่ใช้เป็น baseline ทางเทคนิคของ Phase 2
5. `document/phase1/` ใช้ได้แค่ในฐานะ “อดีตที่เปลี่ยนผ่านมา” เช่น Jenkins/EKS เดิม ไม่ควรเอามาปนกับของที่ active ใน Phase 2

ประโยคสั้น ๆ ที่ควรพูดตั้งแต่ต้น

> “วันนี้เรายึด Phase 2 เป็นหลักครับ โดย source of truth คือ `src/phase2-final`, `document/phase2`, และ `implementation/phase2` ส่วนของ Phase 1 เราจะใช้แค่เพื่ออธิบายว่าระบบ evolve มาอย่างไร ไม่ใช้เป็น baseline ปัจจุบันของเดโมนี้”

---

## 3. สิ่งที่ต้องพูดเรื่อง Safety Boundary ให้ชัดตั้งแต่นาทีแรก

นี่คือหัวใจสำคัญ เพราะโจทย์กำหนดว่า change request ต้องเป็น small, safe, observable

| หัวข้อ | สิ่งที่ต้องพูด |
|---|---|
| สิ่งที่เราจะทำ | แก้เฉพาะ configuration หรือ code change เล็ก ๆ ที่เห็นผลผ่าน pipeline |
| สิ่งที่เราจะไม่ทำ | ไม่ลบ resource, ไม่ `terraform destroy`, ไม่แก้ production credential จริง, ไม่รันคำสั่ง destructive |
| Blast radius | จำกัดให้แตะเฉพาะไฟล์เดียวหรือจุดเล็กเดียวของ pipeline/application |
| Evidence | ทุก change ต้องมี observable output เช่น pipeline stage ใหม่, health check, test result, rollout status, หรือ UI เปลี่ยนชัด |
| Rollback | ต้อง revert ได้เร็ว เช่น revert commit หรือ `kubectl rollout undo` |

ประโยคที่ควรพูดแบบตรง ๆ

> “เพื่อให้เดโมปลอดภัย เราจะไม่แตะ secret จริง, ไม่ลบ resource, ไม่เปลี่ยน credential production, และไม่ทำ requirement ที่กินเวลากว่า 10 นาที เราจะเลือกการเปลี่ยนที่เล็ก ปลอดภัย และเห็นผลผ่าน pipeline ชัดที่สุด”

---

## 4. สิ่งที่ต้องเตรียมก่อนขึ้นเดโมจริง

## 4.1 หน้าจอที่ควรเปิดค้างไว้ล่วงหน้า

1. สไลด์ `presentation/final-phase2/slides.md` หรือ export ที่จะใช้พรีเซนต์
2. VS Code เปิดที่ `src/phase2-final/.woodpecker.yml`
3. VS Code tab สำรองที่ `document/phase2/reqchange.md`
4. VS Code tab สำรองที่ `src/phase2-final/frontend/package.json`
5. VS Code tab สำรองที่ `src/phase2-final/frontend/__tests__/page.test.tsx`
6. Browser tab ที่หน้าแอป TodoApp Big Calendar
7. Browser tab ที่ Woodpecker UI หรือภาพ run ล่าสุดที่แสดงสถานะสำเร็จ
8. Terminal ที่ล็อกอินไว้พร้อมรัน `kubectl` ได้แล้ว

## 4.2 คำสั่งที่ควรเตรียมไว้ใน terminal

```bash
kubectl get pods -n todoapp
kubectl get deploy -n todoapp
kubectl get ingress -n todoapp
kubectl rollout status deployment/todoapp-core -n todoapp --timeout=60s
kubectl rollout status deployment/todoapp-web -n todoapp --timeout=60s
```

ถ้าต้องเตรียมคำสั่งสำหรับพูดเรื่อง Git และ change สด ให้เตรียมไว้ด้วย

```bash
git status
git add src/phase2-final/.woodpecker.yml
git commit -m "ci: add frontend quality gate before web build"
git push origin main
```

## 4.3 ของที่ต้องเช็กก่อนเริ่ม

1. Browser เข้าหน้าแอปได้จริง
2. Woodpecker UI login ไว้แล้ว
3. Terminal มี kubeconfig พร้อม
4. ไม่มีหน้าจอไหนเปิด secret หรือ token คาไว้
5. Font ใน editor ใหญ่พอให้คนทั้งห้องอ่านได้
6. `git status` ไม่รกด้วยไฟล์ที่ไม่เกี่ยวกับเดโม

---

## 5. ถ้ามี 2 คนในทีม ให้แบ่งบทแบบนี้

| บทบาท | สิ่งที่รับผิดชอบ |
|---|---|
| Owner A | เล่า story, คุมเวลา, รับ requirement จาก reviewer, อธิบายเหตุผลเชิง DevOps/CI/CD |
| Owner B | เปิดจอ, เลื่อนโค้ด, รันคำสั่ง, ทำ live change, ชี้ evidence ให้เห็น |

ถ้ามีคนเดียว ให้ใช้สคริปต์นี้ทั้งหมด แต่ยังควรแยก mindset ให้ชัดว่า “ตอนนี้กำลังเล่า concept” และ “ตอนนี้กำลังปฏิบัติบนจอ”

---

## 6. โครงเรื่องหลักที่ต้องทำให้คนฟังจำได้

ตลอด 22 นาที ให้คนฟังจำให้ได้ 5 เรื่องนี้

1. ระบบนี้คือ TodoApp Big Calendar แบบ full stack
2. Deployment path ปัจจุบันคือ Browser → Traefik Ingress → Frontend/Backend → PostgreSQL บน K3s
3. Delivery path ปัจจุบันคือ Git push → Woodpecker → test → build/push → deploy → rollout check → smoke test → email
4. Live change ที่เราเลือกต้อง reinforce quality gate หรือ feedback loop ไม่ใช่เปลี่ยนอะไรสุ่ม ๆ
5. สิ่งที่กลุ่มถัดไปควรอ้างต่อได้คือ baseline เดิม, ไม่ใช่กลับไปเล่า architecture ใหม่ทั้งหมด

---

## 7. สคริปต์ละเอียดตามช่วงเวลา 22 นาที

## 7.1 นาที 0–3 — Owner Brief ระบบ + repo/app/pipeline + safety boundary

### หน้าจอที่ต้องเปิด

1. Slide หน้าปก
2. Slide ภาพรวมระบบหรือ agenda
3. ถัดมาคือ slide architecture สั้น ๆ

### สิ่งที่ต้องชี้ด้วยเมาส์

1. ชื่อโปรเจกต์และขอบเขตว่าเป็น Phase 2
2. source of truth ของโค้ดและเอกสาร
3. safety boundary ว่าวันนี้จะไม่ทำอะไรเสี่ยง

### บทพูดแนะนำแบบละเอียด

> “สวัสดีครับ วันนี้กลุ่มเราจะนำเสนอ Phase 2 ของ KPS-Enterprise โดย baseline ที่เราใช้จริงคือ TodoApp Big Calendar ที่ deploy อยู่บน K3s แบบ self-hosted และใช้ Woodpecker เป็น CI/CD หลักครับ”

> “เพื่อไม่ให้ข้อมูลปนกัน วันนี้เราจะยึด `src/phase2-final`, `document/phase2` และ `implementation/phase2` เป็น source of truth หลัก ส่วน Phase 1 อย่าง Jenkins หรือ EKS เราจะพูดในฐานะของเดิมที่เคยวิเคราะห์ไว้เท่านั้น”

> “เป้าหมายของเราในรอบนี้มี 3 อย่าง คือ หนึ่ง ทำให้ทุกคนเห็น baseline เดิมที่ถูกต้องก่อน สอง แสดง normal case ของระบบและ pipeline แบบสั้นแต่ครบ และสาม รับ change request ที่เล็ก ปลอดภัย และเห็นผลได้ผ่าน pipeline ในเวลาจำกัด”

> “เรื่อง safety boundary เราจะไม่ลบ resource, ไม่ run terraform destroy, ไม่แก้ production credential จริง และไม่ทำ requirement ที่ใหญ่เกิน 10 นาที เราจะเลือก change ที่มี blast radius ต่ำและ rollback ได้เร็ว”

### ประโยคสรุปท้ายช่วง

> “หลังจาก 3 นาทีแรกนี้ เราต้องทำให้ reviewer และกลุ่มถัดไปเข้าใจตรงกันก่อนว่า baseline เดิมหน้าตาเป็นอย่างไร เพื่อที่รอบต่อไปจะได้เล่าเฉพาะสิ่งที่เปลี่ยน ไม่ต้องย้อนเล่า architecture ทั้งหมดใหม่”

---

## 7.2 นาที 3–7 — แสดง Normal Case สั้น ๆ เพื่อ establish baseline

### หน้าจอที่ต้องเปิดตามลำดับ

1. Browser หน้า TodoApp Big Calendar
2. Terminal `kubectl get pods -n todoapp`
3. VS Code เปิด `src/phase2-final/.woodpecker.yml`
4. Woodpecker UI run ล่าสุด หรือภาพ run ล่าสุด

### สิ่งที่ต้องทำบนจอ

1. เปิดหน้าแอปให้เห็น calendar, stats bar, และ day panel
2. คลิกวันหนึ่งวันเพื่อโชว์ว่า UI หลักใช้งานได้
3. กลับไป terminal ให้เห็น pods ของ `todoapp-core`, `todoapp-web`, และ `todoapp-postgres`
4. เปิด pipeline ให้เห็น flow ปัจจุบัน

### บทพูดแนะนำแบบละเอียด

> “ใน normal case ตอนนี้ user เข้าหน้าแอปผ่าน ingress แล้วจะเจอหน้า Big Calendar เป็น entry point หลัก เห็นภาพรวมงานทั้งเดือน และเมื่อคลิกวันที่ใดวันที่หนึ่ง ก็จะเปิด panel ด้านข้างเพื่อจัดการ todo ของวันนั้นได้ทันที”

> “จุดที่สำคัญของ baseline นี้คือมันไม่ใช่แค่ UI สวย แต่ต้องเชื่อมกับ deployment จริงบน cluster ด้วย ดังนั้นผมจะสลับมาที่ terminal ให้เห็นว่าใน namespace `todoapp` มี frontend, backend, และ PostgreSQL ที่เป็น data layer ทำงานอยู่”

> “ส่วน deployment design ปัจจุบัน backend รัน 2 replicas แบบ RollingUpdate เพื่อให้ rollout ได้แบบลด downtime และ frontend ก็รัน 2 replicas เช่นกัน เพื่อให้พร้อมรับ traffic ผ่าน Traefik ingress”

> “ในมุม pipeline ปัจจุบัน flow หลักของ Woodpecker คือ เริ่มจาก test-backend ก่อน จากนั้น build และ push image ของ backend กับ frontend ไป Docker Hub แล้วจึง deploy ไป K3s, รอ rollout status, ทำ smoke test ที่ `/healthz` และแจ้งผลผ่าน email”

> “ตรงนี้คือ baseline ที่ reviewer ควรเห็นก่อนว่า ถ้าระบบถูกต้อง มันควรทำงานแบบนี้ และหลังจากนี้ไม่ว่าเราจะรับ change แบบไหน เราจะวัดจาก baseline เดิมชุดนี้”

### ข้อสังเกตที่ควรพูดแทรกเพื่อเชื่อมกับ CI/CD

1. “สิ่งที่เราโชว์เมื่อกี้คือ feedback loop จากฝั่ง runtime”
2. “ส่วน pipeline ด้านหลังคือ feedback loop จากฝั่ง delivery”
3. “สองส่วนนี้ต้องสอดกัน ไม่ใช่ green pipeline แต่ runtime ใช้จริงไม่ได้”

---

## 7.3 นาที 7–10 — Reviewer ให้ change request หรือ failure/risk ที่จะตรวจ

### เป้าหมายของช่วงนี้

1. รับ requirement ให้ชัดในคำพูดเดียว
2. ประเมินทันทีว่า small, safe, observable หรือไม่
3. ถ้า reviewer ยังไม่เสนอ ให้เราขอหยิบ requirement ที่เตรียมไว้ล่วงหน้า

### ประโยคที่ควรถาม reviewer

> “ขอรับ requirement หรือ failure/risk ที่เล็ก ปลอดภัย และสามารถสังเกตผลผ่าน pipeline ได้ภายในเวลาประมาณ 10 นาทีครับ”

ถ้า reviewer ยังไม่เลือก ให้เสนอ option ที่เตรียมไว้ทันที

> “ถ้า reviewer ยังไม่ specify เราขอเลือก requirement change ที่เราเตรียมไว้ คือเพิ่ม frontend quality gate ใน Woodpecker ให้ frontend ต้องผ่าน `npm run type-check` และ `npm run test:ci` ก่อน build web image ครับ เพราะ change นี้เล็ก ปลอดภัย และ observable ชัดมากใน pipeline”

### เหตุผลที่ต้องพูดให้ครบ

> “เหตุผลที่เลือกอันนี้เพราะ frontend มี script และ test อยู่แล้วใน repo แต่ baseline pipeline ปัจจุบันยังตรวจ backend เป็นหลัก ถ้าเราเพิ่ม gate ฝั่ง frontend ได้สำเร็จ เราจะยกระดับคุณภาพของ pipeline โดยไม่ต้องเปลี่ยน architecture หรือแตะ production secret”

> “ถ้า change นี้ผ่าน สิ่งที่ reviewer จะเห็นคือมี stage ใหม่เกิดขึ้นใน Woodpecker และ `build-push-web` จะไม่ทำงานจนกว่า frontend gate จะผ่าน นี่คือ observable output ที่ตรงโจทย์ที่สุด”

### สิ่งที่ต้องเปิดเสริมบนจอ

1. `document/phase2/reqchange.md`
2. `src/phase2-final/frontend/package.json`
3. `src/phase2-final/frontend/__tests__/page.test.tsx`

### ประโยคเชื่อมจากเอกสารไปสู่การลงมือแก้

> “จากเอกสาร change request เราเลือก requirement นี้เพราะใช้ของที่มีอยู่แล้วใน repo ได้แก่ script `type-check`, `test:ci` และชุด test หน้า calendar จริง จึงไม่ใช่การสร้าง flow ใหม่จากศูนย์ แต่เป็นการย้าย quality control ที่มีอยู่แล้วมาอยู่ใน pipeline”

---

## 7.4 นาที 10–16 — Owner + Reviewer ทำ live change, trigger, และ test เท่าที่ทำได้

### เป้าหมายของช่วงนี้

1. แก้ไฟล์ให้น้อยที่สุด
2. อธิบายเหตุผลของแต่ละบรรทัดที่เพิ่ม
3. trigger pipeline ให้ได้
4. เริ่มอ่านผลลัพธ์แบบ real time

### ไฟล์ที่ต้องเปิด

1. `src/phase2-final/.woodpecker.yml`
2. `src/phase2-final/frontend/package.json`
3. Woodpecker UI

### Live change ที่แนะนำที่สุด

แทรก step นี้ใน `.woodpecker.yml` ก่อน `build-push-web`

```yaml
  - name: test-frontend
    image: node:22-bookworm-slim
    commands:
      - cd src/phase2-final/frontend
      - npm ci
      - npm run type-check
      - npm run test:ci
```

ถ้าต้องการพูดให้ครบเชิงวิศวกรรม ให้พูดตามนี้ขณะพิมพ์

> “ผมจะเพิ่ม step ชื่อ `test-frontend` ไว้ก่อน `build-push-web` เพื่อให้ web image ถูกสร้างต่อเมื่อ frontend ผ่าน type checking และ automated tests แล้วเท่านั้น”

> “เราใช้ `npm ci` เพราะในบริบท CI มัน deterministic กว่า `npm install` และเหมาะกับ pipeline ที่ต้อง reproducible”

> “เราใช้ `type-check` เพื่อจับ contract error และ `test:ci` เพื่อจับ regression เชิง behavior ของหน้า calendar ก่อน image ถูก build และ push”

### ถ้าต้องการอธิบายให้ reviewer เห็นว่าแตะน้อยจริง

พูดสั้น ๆ ว่า

> “การเปลี่ยนครั้งนี้แตะไฟล์เดียวคือ `.woodpecker.yml` และไม่กระทบ runtime configuration, secret, database, หรือ cluster resource ใด ๆ จึงถือว่า blast radius ต่ำมาก”

### ขั้นตอนหลังแก้ไฟล์

1. Save file
2. `git diff` ให้ reviewer เห็นว่าเปลี่ยนเฉพาะ step ใหม่
3. commit ด้วยข้อความสั้นและชัด
4. push ไป branch ที่ trigger pipeline จริง
5. เปิด Woodpecker UI ให้เห็น run ใหม่เริ่มต้น

### ประโยคที่ควรพูดตอน trigger pipeline

> “ตอนนี้เรายังไม่ได้อ้างว่าระบบดีขึ้นจากการพิมพ์ YAML อย่างเดียว เราจะให้ feedback loop ของ pipeline เป็นคนยืนยันครับ เพราะถ้า step ใหม่รันจริงและเป็นสีเขียว นั่นแปลว่า change มีผลจริง ไม่ใช่แค่แก้เอกสาร”

### สิ่งที่ reviewer ควรได้เห็นภายในช่วงนี้

1. step `test-frontend` ปรากฏใน pipeline
2. log แสดง `npm ci`, `npm run type-check`, `npm run test:ci`
3. ถ้าผ่าน จะเห็น pipeline เดินต่อไปสู่ `build-push-web`

### ถ้าพอมีเวลาและ network ตอบไว

ให้ชี้ log สำคัญ เช่น

1. install dependencies สำเร็จ
2. TypeScript ไม่มี error
3. Jest tests ผ่าน
4. Stage ถัดไปเริ่ม build web image

---

## 7.5 นาที 16–19 — Owner อธิบายผลลัพธ์ ถ้า fail เกิดที่ไหน และจะ improve อย่างไร

ช่วงนี้ต้องตอบให้ได้ทั้งกรณี success และ failure

### ถ้า pipeline ผ่าน

พูดตามนี้ได้เลย

> “ผลลัพธ์ของ change นี้คือ pipeline ของเรามี quality gate ฝั่ง frontend เพิ่มขึ้นอย่างเป็นรูปธรรม และ gate นี้เกิดก่อนการ build web image จริง ดังนั้นถ้าในอนาคตมี type error หรือ test regression ฝั่ง UI ระบบจะหยุดก่อน deploy ได้”

> “สิ่งนี้สอดคล้องกับแนวคิด CI/CD ที่เรียนตรง ๆ คือเราเพิ่มขั้น test ให้เร็วขึ้นใน feedback loop และทำให้ deploy stage เชื่อถือได้มากขึ้น เพราะมันผ่าน quality checks มากกว่าเดิม”

> “ถ้ากลุ่มถัดไปจะต่อยอด เขาไม่จำเป็นต้องอธิบาย app, cluster, ingress หรือ pipeline baseline ใหม่ทั้งหมดแล้ว เขาสามารถเริ่มจาก baseline นี้และบอกเฉพาะว่าตัวเองต่อยอด gate, deploy, security, monitoring หรือ failure handling อย่างไร”

### ถ้า pipeline fail ที่ `test-frontend`

พูดแบบนี้

> “แม้ผลลัพธ์รอบนี้จะเป็น fail แต่จริง ๆ นี่คือพฤติกรรมที่เราต้องการจาก quality gate เพราะระบบหยุดก่อน build และ deploy web image นั่นแปลว่า pipeline จับปัญหาได้เร็วขึ้นแทนที่จะปล่อยของที่มีปัญหาไปถึง cluster”

> “เราจะดู log ว่า fail ที่ `npm ci`, `type-check`, หรือ `test:ci` แล้วแยกแนวทางแก้ตาม root cause ต่อไป แต่ในเชิง DevOps สิ่งที่สำคัญคือ feedback loop ทำงานแล้ว”

### ถ้าระหว่างเดโม pipeline ยังไม่จบ

พูดแบบนี้

> “ในช่วงเวลาของ review เราอย่างน้อยยืนยันได้แล้วว่า stage ใหม่ถูก trigger จริงและกำลังทำงานตามที่ออกแบบไว้ ถ้ามีเวลาพอเราจะรอดูจนจบ แต่ถ้าไม่ เราจะถือว่า observable evidence ตอนนี้คือ pipeline graph เปลี่ยนและ log ของ stage ใหม่เริ่มรันแล้ว”

### ประโยคปิดช่วงนี้

> “ไม่ว่ารอบนี้จะผ่านหรือ fail สิ่งที่ได้คือเราทำให้ change เล็ก ๆ นี้แปลงเป็น evidence ผ่าน pipeline ไม่ใช่แค่การอธิบายด้วยคำพูด”

---

## 7.6 นาที 19–22 — Reviewer เขียน feedback + evidence

### สิ่งที่ owner ควรทำในช่วงนี้

1. หยุดพูดยาว
2. ตอบเฉพาะคำถามของ reviewer
3. ชี้ evidence ที่ reviewer ต้องการอย่างตรงจุด
4. สรุปสั้น ๆ ว่าควรให้ feedback เรื่องไหนได้บ้าง

### ประโยคสรุปส่งให้ reviewer

> “สำหรับ evidence วันนี้ reviewer สามารถอ้างอิงได้ 3 อย่าง คือ baseline app/runtime ที่เราโชว์ก่อน, pipeline baseline เดิมใน `.woodpecker.yml`, และผลของ live change ที่เพิ่ม frontend quality gate จนเห็น stage ใหม่ใน Woodpecker ครับ”

> “ถ้าจะ feedback เชิงปรับปรุงต่อ ผมคิดว่ามุมที่มีประโยชน์ที่สุดคือเรื่อง security gate, config drift cleanup, rollback automation, และ monitoring/logging ครับ”

---

## 8. เมนู Live Change สำรอง ถ้า reviewer ไม่เลือก requirement หลัก

ถ้า reviewer ไม่เอา `test-frontend` ให้เตรียม option สำรอง 3 แบบนี้

| ตัวเลือก | ไฟล์ที่แก้ | สิ่งที่ observable | ทำไมปลอดภัย |
|---|---|---|---|
| เพิ่มข้อความหรือ version label ใน frontend | `src/phase2-final/frontend/app/page.tsx` | UI เปลี่ยนทันทีหลัง deploy | แตะ frontend จุดเดียว |
| เพิ่ม README step เรื่อง health check หรือ rollback plan | `document/phase2/guide-new.md` หรือ `README.md` | reviewer เห็นเอกสารและ reproducibility ดีขึ้น | ไม่แตะ runtime |
| เพิ่ม config validation/health explanation ใน docs หรือ pipeline comment | `document/phase2/reqchange.md` หรือ `.woodpecker.yml` | เห็น reasoning และ pipeline intent ชัดขึ้น | ไม่แตะ secret และ resource |

### วิธีพูดถ้า reviewer ขอ requirement ใหญ่เกินไป

> “requirement นี้มี value ครับ แต่ใหญ่เกิน time box ของรอบ review เพราะจะกระทบ architecture หรือ resource มากเกินไป สำหรับรอบนี้เราขอ break down ให้เป็น change ที่เล็กกว่าและ observable ผ่าน pipeline ก่อน เช่น quality gate, health check, หรือ config validation”

---

## 9. Failure/Risk Investigation ที่ตอบได้ดีถ้า reviewer เลือกแนวตรวจสอบแทน change request

| Failure/Risk | สิ่งที่เปิดให้ดู | คำอธิบายที่ควรพูด |
|---|---|---|
| test fail | Woodpecker logs | pipeline หยุดก่อน build/deploy คือ fail-fast ที่ดี |
| build fail | build-push stage | image ไม่ถูก push, production ไม่เปลี่ยน |
| deploy ไม่อัปเดต | `kubectl rollout status`, `kubectl set image` | ชี้จุดว่า fail ที่ rollout หรือ image tag |
| secret/config missing | `secret.sample.yaml`, `postgres-secret.sample.yaml` | ชี้ว่า secret management แยกจาก git และถ้าขาดจะ fail ที่ readiness/deploy |
| Docker image issue | Docker Hub tag strategy ใน `.woodpecker.yml` | ใช้ commit SHA เพื่อ trace ได้ว่าเวอร์ชันไหนถูก deploy |
| config drift | `k8s/kustomization.yaml` เทียบกับ deploy step | อธิบายได้ว่า manifest กับ pipeline ต้อง sync กันเสมอ และนี่เป็น improvement point ที่ดี |

ประโยคที่ควรใช้เวลาถูกถามเรื่อง fail

> “เราพยายามไม่ตอบเพียงว่า ‘ไม่ผ่าน’ หรือ ‘ผ่าน’ แต่จะแยกให้ชัดว่า fail เกิดใน stage ไหน และ stage นั้นป้องกันไม่ให้ปัญหาหลุดไปถึง production อย่างไร”

---

## 10. Improvement Points ที่ควรพูดต่อท้ายถ้าเหลือเวลา

ถ้ามีเวลาเหลือ 30–60 วินาที ให้พูดส่วนนี้เพื่อเพิ่มคุณค่าเชิง DevOpsSec

1. เพิ่ม Trivy image/config scan เป็น security gate ใน active Phase 2 pipeline
2. เพิ่ม smoke test ที่ลึกกว่า `/healthz` เช่น CRUD path จริง
3. เพิ่ม rollback note หรือ deploy verification ที่ชัดขึ้น
4. cleanup ของเดิมที่เป็น legacy เช่น step หรือ resource ที่เหลือจากยุค SQLite เพื่อหลีกเลี่ยง config drift
5. เพิ่ม monitoring/logging เช่น Prometheus, Loki, Grafana หรืออย่างน้อย deployment event review ที่เป็นระบบ

ประโยคที่ควรพูด

> “ถ้าต่อยอดจาก baseline นี้ในเชิง DevOpsSec สิ่งที่คุ้มที่สุดคือเพิ่ม security gate, runtime observability, และลด config drift ระหว่างเอกสาร, manifest, และ pipeline ให้ตรงกันมากขึ้น”

---

## 11. ประโยคเปิด-กลาง-ปิด ที่จำง่ายที่สุด

### ประโยคเปิด

> “วันนี้เราจะ establish baseline ของระบบและ pipeline ก่อน แล้วค่อยรับ change ที่เล็ก ปลอดภัย และวัดผลได้ผ่าน pipeline จริง”

### ประโยคกลางตอนทำ live change

> “สิ่งที่เราเพิ่มไม่ได้มีเป้าหมายเพื่อให้ YAML ยาวขึ้น แต่เพื่อทำให้ feedback loop ของ pipeline ชัดขึ้นและเชื่อถือได้มากขึ้น”

### ประโยคปิด

> “สิ่งที่ควรจดจากเดโมวันนี้ไม่ใช่แค่ว่าเราแก้ไฟล์ไหน แต่คือ baseline เดิมของระบบ, หลักคิด small-safe-observable, และการใช้ pipeline เป็นตัวพิสูจน์ผลของการเปลี่ยนแปลง”

---

## 12. One-Page Cheat Sheet สำหรับท่องก่อนขึ้นจริง

1. ระบบ: TodoApp Big Calendar บน K3s, ingress ผ่าน Traefik, data layer เป็น PostgreSQL, delivery ใช้ Woodpecker
2. Baseline pipeline: test → build/push → deploy → rollout check → smoke test → email
3. Safety boundary: ไม่ลบ resource, ไม่แตะ secret จริง, ไม่ทำลาย infra, ไม่ทำงานใหญ่เกิน 10 นาที
4. Live change หลัก: เพิ่ม `test-frontend` ก่อน `build-push-web`
5. เหตุผล: frontend มี script และ tests อยู่แล้ว แต่ pipeline baseline ยังไม่บังคับใช้
6. Observable result: เห็น stage ใหม่ใน Woodpecker และ web build จะไม่เกิดจนกว่า gate จะผ่าน
7. ถ้า fail: ถือว่า feedback loop ทำงาน เพราะปัญหาถูกจับก่อน deploy
8. ถ้าสำเร็จ: ถือว่า pipeline น่าเชื่อถือขึ้นและกลุ่มถัดไปอ้าง baseline นี้ต่อได้