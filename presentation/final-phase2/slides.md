---
marp: true
theme: default
paginate: true
backgroundColor: #f7f1e3
style: |
  section {
    font-family: 'Sarabun', 'Noto Sans Thai', sans-serif;
    color: #102a43;
    background: linear-gradient(180deg, #f7f1e3 0%, #fffaf1 100%);
  }
  h1, h2, h3 {
    color: #8c2f1c;
  }
  strong {
    color: #0f766e;
  }
  table {
    font-size: 0.78em;
  }
  code {
    font-size: 0.8em;
  }
  .small {
    font-size: 0.75em;
  }
  .tiny {
    font-size: 0.66em;
  }
  .accent {
    color: #7c2d12;
    font-weight: 700;
  }
  .cols {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
  .box {
    border: 2px solid #d8c3a5;
    border-radius: 14px;
    padding: 0.7rem 0.9rem;
    background: rgba(255,255,255,0.55);
  }
---

<!-- _paginate: false -->
<!-- _backgroundColor: #8c2f1c -->
<!-- _color: white -->

# KPS-Enterprise Phase 2
## TodoApp Big Calendar on K3s + Woodpecker CI/CD

**Owner Demo + Live Change + DevOpsSec Baseline**

กลุ่ม KPS-Enterprise Team

---

# 1. Presentation Contract

เราจะทำ 3 อย่างให้ชัดในรอบนี้

1. **Establish baseline เดิม** ของ app, cluster และ pipeline ให้ reviewer เข้าใจตรงกัน
2. **แสดง normal case** สั้น ๆ เพื่อให้เห็นว่าระบบและ pipeline ควรทำงานอย่างไร
3. **ทำ live change แบบ small, safe, observable** และให้ pipeline เป็นคนพิสูจน์ผล

สิ่งที่เราจะไม่ทำ

1. ไม่ลบ resource
2. ไม่ `terraform destroy`
3. ไม่แก้ production secret จริง
4. ไม่ทำ change ใหญ่เกิน 10 นาที

---

# 2. Source of Truth

<div class="cols">
<div class="box">

## ใช้อ้างอิงหลัก

1. `src/phase2-final/`
2. `document/phase2/`
3. `implementation/phase2/`

นี่คือ baseline ของ Phase 2 ปัจจุบัน

</div>
<div class="box">

## ใช้เป็นบริบทเท่านั้น

1. `document/phase1/`
2. `presentation/checkpoint/`
3. Jenkins/EKS เดิม

พูดได้เพื่อเทียบวิวัฒนาการ แต่ไม่ใช้เป็น runtime baseline

</div>
</div>

ประเด็นสำคัญ: **กลุ่มถัดไปควรอ้าง baseline Phase 2 นี้ต่อได้โดยไม่ต้องเล่าใหม่ทั้งระบบ**

---

# 3. ระบบนี้คืออะไร

TodoApp Big Calendar คือ full-stack task management system ที่มี 2 มุมพร้อมกัน

1. **มุมผู้ใช้**: เห็นงานทั้งเดือนผ่านปฏิทิน, เปิด panel รายวัน, จัดการงาน, priority และ status
2. **มุมวิศวกรรม**: ทุกการเปลี่ยนผ่าน pipeline, สร้าง image, deploy ไป K3s, ตรวจ rollout, และส่ง feedback กลับอัตโนมัติ

จุดที่ต้องจำ

1. เป้าหมายไม่ใช่แค่ build เว็บให้ขึ้น
2. เป้าหมายคือทำให้ **delivery path** เชื่อถือได้พอ ๆ กับ **runtime path**

---

# 4. Functional Baseline

| ความสามารถ | สิ่งที่ผู้ชมควรเห็น |
|---|---|
| Big Calendar | เห็นรายการงานตามวันในมุมมองเดือน |
| Day Panel | คลิกวันที่แล้วเปิด panel ด้านข้างได้ |
| Task CRUD | เพิ่ม, แก้ไข, ลบ, เปลี่ยนสถานะได้ |
| Priority / Status | สีและ badge สื่อความต่างของงาน |
| Stats Bar | เห็น open, done, today, overdue |
| API & Meta | backend มี `/api/v1/...`, `/healthz`, `/readyz`, `/api/v1/meta` |
| Readiness | app พร้อมรับ traffic ก่อนค่อยถือว่า deploy สมบูรณ์ |

ข้อความสั้นที่ใช้พูด: **ผู้ใช้เห็น calendar แต่ทีมวิศวกรรมเห็น feedback loop อยู่เบื้องหลังทุก click และทุก deploy**

---

# 5. Runtime Architecture

```text
Browser
  -> Traefik Ingress
     -> /                 -> todoapp-web (Next.js) x2
     -> /api,/healthz,... -> todoapp-core (Go) x2
                              -> todoapp-postgres (StatefulSet) x1
```

สิ่งที่ architecture นี้ตอบโจทย์

1. แยก frontend และ backend ชัด
2. route ด้วย ingress ภายใต้ host เดียว
3. backend ใช้ PostgreSQL ใน cluster path เพื่อรองรับ multi-replica ได้ดีขึ้น
4. scale และ rollout ได้โดยไม่ต้องเล่าพึ่งพาการแก้ด้วยมือทุกครั้ง

---

# 6. Cluster Topology

| Node/Role | สิ่งที่รัน | ประโยชน์ |
|---|---|---|
| K3s Server / Main | control plane, Traefik, Woodpecker server | รวม control plane และจุดสั่งงาน CI/CD |
| Worker-App | `todoapp-core`, `todoapp-web` | แยก workload ของแอปออกจาก CI |
| Worker-CI | Woodpecker agent / pipeline pods | ลดการแย่ง resource กับ production path |

หลักคิดที่ต้องพูด

1. **แยก CI ออกจาก app workload** ทำให้ pipeline ไม่น็อค service ง่าย
2. **self-hosted K3s** เหมาะกับ resource limit และควบคุมสภาพแวดล้อมเองได้

---

# 7. Kubernetes Design Decisions

| มิติ | สิ่งที่ใช้ | เหตุผล |
|---|---|---|
| Namespace | `todoapp` | แยก resource และจัดการง่าย |
| Deployments | `todoapp-core`, `todoapp-web` | รองรับ replica และ rollout |
| StatefulSet | `todoapp-postgres` | data layer มีตัวตนและ volume ต่อเนื่อง |
| Ingress | Traefik | route path เดียวแต่หลาย service |
| Config | ConfigMap + Secret | แยก config ออกจาก image |
| Health | readiness + liveness probes | ให้ K8s ตัดสินใจเรื่องพร้อมใช้งาน |
| Hardening | non-root securityContext, resource limits | ลดสิทธิ์เกินจำเป็นและควบคุมทรัพยากร |

---

# 8. CI/CD Baseline ใน Woodpecker

แม้ในไฟล์ `.woodpecker.yml` จะมี 5 named steps หลัก แต่เชิงแนวคิด flow คือ

1. **Test**: `test-backend`
2. **Build / Push Core**: `build-push-core`
3. **Build / Push Web**: `build-push-web`
4. **Deploy**: apply config + set image + rollout status + smoke test `/healthz`
5. **Notify**: ส่ง email success/failure

คุณค่าที่ได้จาก flow นี้

1. ลด manual deploy
2. trace image ด้วย commit SHA
3. มี feedback loop หลัง `git push`
4. มี deployment verification ก่อนประกาศว่ารอบนั้นสำเร็จ

---

# 9. Normal Case ที่ต้องโชว์ก่อน

Baseline demo ที่ reviewer ควรเห็นก่อนรับ change request

1. เปิดหน้า TodoApp Big Calendar และคลิกวันที่หนึ่งวัน
2. แสดง `kubectl get pods -n todoapp`
3. แสดง `kubectl get deploy -n todoapp`
4. เปิด `.woodpecker.yml` ให้เห็น flow ปัจจุบัน
5. เปิด Woodpecker run ล่าสุด หรือ evidence ของ pipeline สำเร็จ

ประโยคสำคัญ: **ถ้า reviewer ยังไม่เห็น baseline เดิม เขาจะไม่มีกรอบวัดว่าการเปลี่ยนใหม่ดีขึ้นหรือแย่ลงอย่างไร**

---

# 10. Requirement ที่เราเตรียมสำหรับ Live Change

**เพิ่ม Frontend Quality Gate ก่อน `build-push-web`**

เหตุผลที่เลือก

1. **Small**: แตะไฟล์เดียว คือ `.woodpecker.yml`
2. **Safe**: ไม่แตะ secret, database, หรือ resource production
3. **Observable**: เห็น stage ใหม่ใน Woodpecker ทันที
4. **Useful**: frontend มี `type-check` และ `test:ci` อยู่แล้วใน repo แต่ baseline pipeline ยังไม่บังคับใช้

ผลลัพธ์ที่ต้องการให้ reviewer เห็น

1. มี stage `test-frontend`
2. web image จะไม่ build จนกว่า gate จะผ่าน
3. ถ้า fail จะหยุดก่อน deploy

---

# 11. Live Change Patch

```yaml
- name: test-frontend
  image: node:22-bookworm-slim
  commands:
    - cd src/phase2-final/frontend
    - npm ci
    - npm run type-check
    - npm run test:ci
```

ขณะพิมพ์ต้องอธิบาย

1. `npm ci` = reproducible CI install
2. `type-check` = จับ type/contract error เร็วขึ้น
3. `test:ci` = จับ regression เชิง behavior ของหน้า calendar

Expected observable outcome

1. pipeline graph เปลี่ยน
2. logs เพิ่มขึ้นอย่างมีความหมาย
3. quality gate ใกล้ source change มากขึ้น

---

# 12. Pod Review Flow ที่ใช้จริง

| เวลา | บทบาท | สิ่งที่ทำ |
|---|---|---|
| 0–3 | Owner | Brief ระบบ + repo/app/pipeline + safety boundary |
| 3–7 | Owner | โชว์ normal case เพื่อ establish baseline |
| 7–10 | Reviewer | ให้ change request หรือ failure/risk |
| 10–16 | Owner + Reviewer | แก้, trigger, test, และอ่าน evidence |
| 16–19 | Owner | อธิบายผล, จุด fail, จุด improve |
| 19–22 | Reviewer | เขียน feedback พร้อม evidence |

หลักที่ต้องไม่หลุด: **ทุกช่วงต้องโยงกลับมาที่ build, test, deploy, automation, feedback loop**

---

# 13. ถ้า Fail เราจะอธิบายอย่างไร

| กรณี | สิ่งที่พูด | สิ่งที่ต้องโชว์ |
|---|---|---|
| test fail | feedback loop ทำงานก่อน build/deploy | stage log |
| build fail | image ไม่ถูก push, production ไม่เปลี่ยน | build step log |
| rollout fail | deploy stage สั่งแล้วแต่ pod ไม่พร้อม | `kubectl rollout status` |
| secret/config missing | readiness หรือ startup จะสะท้อนปัญหา | sample secret/manifests |
| runtime ยังไม่พร้อม | pipeline ต้องไม่รีบประกาศ success | probes / health endpoints |

Rollback line ที่ควรพูด

> “ถ้ารุ่นใหม่มีปัญหา เรามีทั้ง revert commit และ `kubectl rollout undo` เป็นเส้นทางกลับที่ชัดเจน”

---

# 14. DevOpsSec ที่มีอยู่ตอนนี้

| พื้นที่ | หลักฐานใน repo/runtime | คุณค่า |
|---|---|---|
| Secret hygiene | `from_secret`, `Secret`, `secret.sample.yaml` | ไม่ hardcode credential ใน git |
| Deployment safety | rollout status + smoke test `/healthz` | ไม่ถือว่า deploy สำเร็จก่อน verify |
| Runtime hardening | `runAsNonRoot`, resource limits, probes | ลด privilege และควบคุมเสถียรภาพ |
| Traceability | image tag จาก commit SHA | รู้ว่ารุ่นไหนถูก deploy |
| Feedback | email notification + health endpoints | ทีมรู้ผลเร็วและตรวจย้อนหลังได้ |

สรุป: **DevOpsSec baseline มีแล้ว แต่ยังมีพื้นที่ให้ยกระดับอีกมาก**

---

# 15. DevOpsSec ที่ควรเสริมต่อ

| ประเด็น | สิ่งที่ควรเพิ่ม | ประโยชน์ |
|---|---|---|
| Security gate | Trivy image/config scan | block image ที่เสี่ยงก่อน deploy |
| Supply chain | SBOM + provenance + Cosign sign/verify | รู้ที่มา image และลดความเสี่ยง tampering |
| Policy | OPA / Kyverno / policy checks | กัน misconfiguration ก่อนขึ้น cluster |
| Runtime isolation | NetworkPolicy, PodDisruptionBudget | จำกัด blast radius และเพิ่ม resilience |
| Data safety | backup/restore drill ของ PostgreSQL | พร้อมรับ incident จริง |
| Observability | metrics, logs, alerts | รู้เร็วกว่าแค่รอผู้ใช้แจ้ง |

หมายเหตุ: ใน repo root มี pattern ขั้นสูงเรื่อง SBOM/Cosign/Trivy อยู่แล้ว แต่ active Phase 2 baseline ยังเป็น `src/phase2-final/.woodpecker.yml`

---

# 16. Feedback Loop ที่เราต้องการให้ผู้ฟังเห็น

<div class="cols">
<div class="box">

## Code Feedback

1. test
2. type-check
3. lint / scan ในอนาคต

</div>
<div class="box">

## Deploy Feedback

1. rollout status
2. smoke test
3. email notification

</div>
</div>

<div class="cols">
<div class="box">

## Runtime Feedback

1. `/healthz`
2. `/readyz`
3. pod/deployment state

</div>
<div class="box">

## Human Feedback

1. reviewer comment
2. evidence-based discussion
3. improvement backlog

</div>
</div>

หัวใจของ Phase 2 คือ **ทำให้ feedback เร็วขึ้น ชัดขึ้น และเชื่อถือได้มากขึ้น**

---

# 17. สิ่งที่กลุ่มถัดไป “Assume ได้เลย”

หลังจบ presentation นี้ กลุ่มถัดไปไม่จำเป็นต้องเล่าซ้ำเรื่องเหล่านี้ เว้นแต่เขาเปลี่ยนมัน

1. แอปหลักคือ TodoApp Big Calendar
2. runtime path คือ Browser → Traefik → Web/Core → PostgreSQL
3. cluster ใช้ K3s self-hosted
4. CI/CD ใช้ Woodpecker
5. baseline pipeline คือ test → build/push → deploy → verify → notify
6. live review ต้องยึดหลัก small, safe, observable

ดังนั้นกลุ่มถัดไปควรเล่าเฉพาะสิ่งที่ตนเอง “ปรับ/แตกต่าง/ต่อยอด”

---

# 18. Lightning Supplement Prompts

ถ้าเพื่อนหรือ reviewer จะเสริมให้ทั้งห้องได้ประโยชน์ ควรเสริมในมุมนี้

1. **Config**: ค่าคอนฟิกไหนควร validate ตั้งแต่ต้น pipeline
2. **Failure handling**: ถ้า test/build/deploy fail ควรมี evidence อะไรบ้าง
3. **Deployment**: rolling update, rollback, readiness สำคัญอย่างไร
4. **Security**: secret flow, image scan, signing, policy checks
5. **Monitoring/Logging**: ถ้าไม่มี metrics/log aggregation จะ blind ตรงไหน
6. **Data**: backup/restore และ disaster recovery ของ PostgreSQL

---

# 19. Key Takeaways

1. เรา establish baseline ของระบบ Phase 2 ได้ครบทั้ง app, infra และ pipeline
2. เราเลือก live change ที่เล็ก ปลอดภัย และเห็นผลชัดผ่าน Woodpecker
3. เราเชื่อมทุกอย่างกับแนวคิด CI/CD ที่เรียน ไม่ใช่โชว์แต่ UI หรือ YAML แยกกัน
4. เราเตรียมพื้นที่ให้กลุ่มถัดไปเล่าเฉพาะส่วนที่ต่อยอดได้ทันที
5. เราวางฐาน DevOpsSec ทั้งในส่วนที่มีแล้วและส่วนที่ควรเสริมต่ออย่างตรงไปตรงมา

---

<!-- _backgroundColor: #0f766e -->
<!-- _color: white -->

# 20. Q&A

**Baseline ที่ต้องจำ:**

TodoApp Big Calendar  
K3s + Traefik + PostgreSQL  
Woodpecker test → build → deploy → verify → notify  
Live change ต้อง small, safe, observable

ขอบคุณครับ