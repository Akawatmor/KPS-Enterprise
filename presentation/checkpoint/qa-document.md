# ❓ Q&A Document
## KPS-Enterprise: Potential Questions & Answers

---

## Quick Reference Table

| # | Question (Short) | Category |
|---|------------------|----------|
| Q1 | ทำไมถึงเลือก original project นี้? | Rationale |
| Q2 | AWS Learner Lab มีข้อจำกัดอะไรบ้าง? | Technical |
| Q3 | ทำไมใช้ Docker Hub แทน ECR? | Technical |
| Q4 | Shift-Left Security คืออะไร? | Concept |
| Q5 | GitOps คืออะไร? | Concept |
| Q6 | ถ้า Pod crash ระบบจัดการอย่างไร? | Technical |
| Q7 | ความแตกต่าง health endpoints? | Technical |
| Q8 | ทำไมถึงใช้ Kubernetes? | Rationale |
| Q9 | Bug ที่เจอใน original code? | Implementation |
| Q10 | Test case failure scenario? | Testing |
| Q11 | Security scans ตรวจอะไรบ้าง? | Security |
| Q12 | ถ้า security scan ไม่ผ่าน? | Security |
| Q13 | ถ้ามี 0 downtime? | Advanced |
| Q14 | AI ช่วยในส่วนไหน? | Process |
| Q15 | Next steps / Phase 2? | Planning |

---

## Detailed Q&A

### Q1: ทำไมถึงเลือก original project นี้มาทำ?

**Answer:**
> เราเลือก project นี้เพราะหลายเหตุผลครับ/ค่ะ:
>
> 1. **ครอบคลุม DevSecOps ครบถ้วน** - มีทั้ง CI/CD, security scanning, Kubernetes deployment ในตัว
>
> 2. **Three-Tier Architecture** - เป็นสถาปัตยกรรมที่พบเห็นได้ทั่วไปในงานจริง ได้เรียนรู้การจัดการ frontend, backend, database แยกกัน
>
> 3. **Modern Tech Stack** - ใช้ React, Node.js, MongoDB, Kubernetes ซึ่งเป็น technology ที่นิยมในอุตสาหกรรม
>
> 4. **Documentation ค่อนข้างดี** - Original project มี README และ architecture diagram ที่ช่วยให้เข้าใจได้เร็ว
>
> 5. **Challenge ที่เหมาะสม** - ต้องปรับให้รองรับ Learner Lab ซึ่งทำให้เราได้เรียนรู้การ adapt infrastructure

---

### Q2: AWS Learner Lab มีข้อจำกัดอะไรบ้างที่กระทบต่อการ implement?

**Answer:**
> Learner Lab มีข้อจำกัดหลักๆ 5 ข้อครับ/ค่ะ:
>
> | ข้อจำกัด | ผลกระทบ | วิธีแก้ไข |
> |---------|---------|----------|
> | ❌ ห้ามสร้าง IAM Role/Policy | Terraform ใช้ไม่ได้ตรงๆ | ใช้ `LabInstanceProfile` ที่มีอยู่แล้ว |
> | ❌ ECR เป็น Read-only | Push image ไม่ได้ | ใช้ Docker Hub แทน |
> | ❌ Max instance: t2.large | Jenkins อาจช้า | ปรับ resource usage |
> | ❌ Max 9 instances | Node จำกัด | ใช้ 3-4 nodes สำหรับ EKS |
> | ❌ us-east-1 only | Multi-region ไม่ได้ | ตั้งค่าทุกอย่างใน us-east-1 |
>
> เราจัดทำเอกสาร `issue11-requirements-mapping.md` ที่ map ข้อจำกัดทั้งหมดพร้อมวิธีแก้ไขครับ/ค่ะ

---

### Q3: ทำไมถึงเปลี่ยนจาก ECR มาใช้ Docker Hub?

**Answer:**
> เหตุผลหลักคือ **LabRole มีสิทธิ์แค่ Read ECR** ครับ/ค่ะ
>
> จากเอกสาร `learnerlab-limit.txt`:
> - LabRole มี `ecr:BatchGet*`, `ecr:Get*` (read only)
> - **ไม่มี** `ecr:BatchCheckLayerAvailability`, `ecr:PutImage` (write)
>
> ดังนั้น pipeline push image ไป ECR ไม่ได้ เราจึงเปลี่ยนมาใช้ Docker Hub ซึ่ง:
> - ✅ Free tier รองรับ public images
> - ✅ ไม่มีข้อจำกัด push/pull
> - ✅ ใช้งานง่าย ไม่ต้อง setup registry
>
> ข้อเสียคือ: Docker Hub rate limit 100 pulls/6hr สำหรับ anonymous แต่ในโปรเจคนี้ไม่น่าจะถึง limit

---

### Q4: Shift-Left Security คืออะไร? และนำมาใช้อย่างไร?

**Answer:**
> **Shift-Left Security** คือแนวคิดที่ย้าย security testing มาทำตั้งแต่ต้นของ SDLC (Software Development Life Cycle) ไม่ใช่รอตอน production ครับ/ค่ะ
>
> ```
> Traditional:      Code → Build → Test → Deploy → Security Check ❌
> Shift-Left:       Code → Security Scan ✅ → Build → Test → Deploy
> ```
>
> **เราใช้ในโปรเจค:**
>
> | Tool | ตรวจตอนไหน | ตรวจอะไร |
> |------|-----------|---------|
> | SonarQube | หลัง checkout | Code quality, code smells, bugs |
> | OWASP | หลัง SonarQube | Known vulnerabilities ใน dependencies |
> | Trivy FS | หลัง OWASP | File system vulnerabilities |
> | Trivy Image | หลัง Docker build | Container image vulnerabilities |
>
> ข้อดี: เจอปัญหาเร็ว แก้ไขได้ถูก ลด cost of fix ที่ยิ่งแก้ทีหลังยิ่งแพง

---

### Q5: GitOps คืออะไร? และโปรเจคนี้ใช้ GitOps ไหม?

**Answer:**
> **GitOps** คือแนวคิดที่ใช้ Git repository เป็น **Single Source of Truth** สำหรับ infrastructure และ application ครับ/ค่ะ
>
> **หลักการ:**
> 1. ทุกอย่างอยู่ใน Git (declarative)
> 2. มี agent คอย sync state จาก Git → Cluster
> 3. ถ้ามีใคร manual change, agent จะ revert กลับ
>
> **ในโปรเจคเรา:**
> - Pipeline **อัปเดต image tag** ใน `deployment.yaml`
> - **Push กลับ** ไป GitHub
> - (Future) ArgoCD จะ detect change และ deploy อัตโนมัติ
>
> ตอนนี้ยังไม่ได้ setup ArgoCD แต่ pipeline เตรียม GitOps flow ไว้แล้วครับ/ค่ะ

---

### Q6: ถ้า Pod crash หรือ node ล้ม ระบบจัดการอย่างไร?

**Answer:**
> Kubernetes มี **Self-Healing** built-in ครับ/ค่ะ
>
> **กรณี Pod crash:**
> 1. **Liveness Probe** ตรวจพบว่า pod ไม่ตอบ `/healthz`
> 2. Kubernetes **restart** pod อัตโนมัติ
> 3. ถ้า restart หลายครั้งก็จะเข้า **CrashLoopBackOff**
>
> **กรณี Node ล้ม:**
> 1. Kubernetes ตรวจพบว่า node ไม่ตอบ (NotReady)
> 2. **Reschedule** pods ไป node อื่น
> 3. Deployment ของเรากำหนด `replicas: 2` ดังนั้นมี redundancy
>
> **Health endpoints ที่เราใช้:**
> - `/healthz` → Liveness (pod ยังทำงานอยู่ไหม?)
> - `/ready` → Readiness (พร้อมรับ traffic ไหม?)
> - `/started` → Startup (ใช้กับ slow-starting apps)

---

### Q7: อธิบายความแตกต่างระหว่าง `/healthz`, `/ready`, และ `/started`?

**Answer:**
> ทั้ง 3 endpoints ใช้คู่กับ Kubernetes probes ครับ/ค่ะ:
>
> | Endpoint | Probe | ถ้า Fail | Use Case |
> |----------|-------|---------|----------|
> | `/healthz` | Liveness | **Restart** pod | App hang/deadlock |
> | `/ready` | Readiness | **Remove** จาก service | DB disconnected |
> | `/started` | Startup | **Wait** ก่อนเริ่ม liveness | Slow initialization |
>
> **ตัวอย่างในโปรเจค:**
>
> ```javascript
> // /healthz - ถ้า app ยังทำงาน return OK
> app.get('/healthz', (req, res) => res.send('Healthy'));
>
> // /ready - ถ้า DB connected return OK
> app.get('/ready', (req, res) => {
>   if (mongoose.connection.readyState === 1) {
>     res.send('Ready');
>   } else {
>     res.status(503).send('Not Ready');
>   }
> });
> ```
>
> ใน Test Case 3 เราทดสอบว่าเมื่อปิด MongoDB, `/ready` return 503 ซึ่งถูกต้องตาม design

---

### Q8: ทำไมถึงเลือกใช้ Kubernetes แทน Docker Compose หรือ ECS?

**Answer:**
> เราเลือก Kubernetes เพราะเหตุผลดังนี้ครับ/ค่ะ:
>
> | Feature | Docker Compose | ECS | Kubernetes |
> |---------|---------------|-----|------------|
> | Self-healing | ❌ | ✅ | ✅ |
> | Auto-scaling | ❌ | ✅ | ✅ |
> | Rolling updates | ❌ | ✅ | ✅ |
> | Declarative config | ❌ | Partial | ✅ |
> | Vendor lock-in | ❌ | AWS only | Multi-cloud |
> | Learning value | Low | Medium | **High** |
>
> **เหตุผลหลัก:**
> 1. **Industry Standard** - เป็น skill ที่ต้องการในตลาดแรงงาน
> 2. **Portable** - ไม่ติด vendor สามารถย้ายไป GKE, AKS ได้
> 3. **Rich Ecosystem** - Helm, ArgoCD, Prometheus, Istio ฯลฯ
> 4. **Course Alignment** - ตรงกับหลักการที่เรียนในคลาส
>
> Docker Compose ใช้สำหรับ **local dev** เท่านั้น ส่วน production ใช้ EKS (Kubernetes)

---

### Q9: Bug หรือปัญหาที่เจอใน original code มีอะไรบ้าง?

**Answer:**
> เราเจอ 2 bugs หลักครับ/ค่ะ:
>
> **Bug 1: Boolean parsing ใน `db.js`**
> ```javascript
> // Original (WRONG)
> const useDBAuth = process.env.USE_DB_AUTH || false;
> // ปัญหา: "false" (string) ก็เป็น truthy!
>
> // Fixed
> const useDBAuthStr = process.env.USE_DB_AUTH || "false";
> const useDBAuth = useDBAuthStr === "true" || useDBAuthStr === "1";
> ```
>
> **Bug 2: Invalid semver ใน `package.json`**
> ```json
> // Original (WRONG)
> "axios": "^=0.30.0"  // "^=" is invalid
>
> // Fixed
> "axios": "^0.30.0"
> ```
>
> **ผลกระทบ:**
> - Bug 1: Connection string ผิด ทำให้ connect DB ไม่ได้
> - Bug 2: `npm install` fail
>
> เราบันทึกไว้ใน `implement-result.md` พร้อม diff ครับ/ค่ะ

---

### Q10: อธิบาย Failure Scenario Test Case ที่ทำ?

**Answer:**
> เราทดสอบ **Database Disconnection Scenario** ครับ/ค่ะ:
>
> **ขั้นตอน:**
> 1. รัน app ปกติ ตรวจสอบ `/ready` → 200 OK
> 2. **Stop MongoDB** ด้วย `docker stop`
> 3. เรียก `/ready` → 503 "Not Ready" ✅
> 4. **Start MongoDB** กลับมา
> 5. รอ ~10 วินาที (reconnect)
> 6. เรียก `/ready` → 200 OK ✅
>
> **สิ่งที่ระบบทำอัตโนมัติ:**
> - Mongoose มี **auto-reconnect** built-in
> - Kubernetes readiness probe จะหยุดส่ง traffic ไป pod ที่ไม่ ready
> - เมื่อ DB กลับมา pod จะ ready และรับ traffic ได้อีกครั้ง
>
> **บทเรียน:** ระบบควรออกแบบให้ **graceful degrade** ไม่ใช่ crash ทันที

---

### Q11: Security scans ที่ใช้ ตรวจอะไรบ้าง?

**Answer:**
> เราใช้ 3 tools หลักครับ/ค่ะ:
>
> | Tool | ตรวจสอบอะไร | ตัวอย่าง Finding |
> |------|------------|-----------------|
> | **SonarQube** | Code quality, SAST, bugs | Code smells, security hotspots |
> | **OWASP Dep-Check** | Known CVEs ใน dependencies | express@4.17.1 มี vulnerability |
> | **Trivy** | Container image layers | High severity ใน base image |
>
> **Pipeline Behavior:**
> - ถ้า SonarQube **Quality Gate FAIL** → Pipeline หยุด
> - ถ้า OWASP พบ **CRITICAL** → Pipeline หยุด
> - ถ้า Trivy พบ **HIGH/CRITICAL** → Pipeline หยุด (configurable)
>
> **ทำไม 3 tools?**
> - SonarQube = **Static Analysis** (code level)
> - OWASP = **Dependencies** (supply chain)
> - Trivy = **Container** (runtime environment)
>
> ครอบคลุม security ตั้งแต่ code ถึง deployment image ครับ/ค่ะ

---

### Q12: ถ้า security scan ไม่ผ่าน จะเกิดอะไรขึ้น?

**Answer:**
> Pipeline จะ **Fail-Fast** ครับ/ค่ะ:
>
> ```
> Stage: SonarQube → FAIL
>                     ↓
>         Build Stage: SKIPPED
>                     ↓
>         Push Stage: SKIPPED
>                     ↓
>         Deploy: NEVER HAPPENS
> ```
>
> **การแจ้งเตือน:**
> - Jenkins แสดง **Red Build**
> - Email notification ถึง team (ถ้า configure)
> - GitHub shows **failed check** บน commit
>
> **Developer ต้องทำ:**
> 1. ดู Jenkins log เพื่อดู failure reason
> 2. แก้ไข code หรือ update dependency
> 3. Push commit ใหม่
> 4. Pipeline รันใหม่อัตโนมัติ
>
> นี่คือหลักการ **"No deploy without passing security"** ครับ/ค่ะ

---

### Q13: ถ้าต้องการ deploy แบบ Zero Downtime จะทำอย่างไร?

**Answer:**
> Kubernetes รองรับ **Rolling Update** เป็น default ครับ/ค่ะ:
>
> **วิธีทำงาน:**
> ```yaml
> spec:
>   strategy:
>     type: RollingUpdate
>     rollingUpdate:
>       maxSurge: 1        # สร้าง pod ใหม่ได้ 1 ตัว
>       maxUnavailable: 0  # ห้ามลด pod ถ้ายังไม่ ready
> ```
>
> **ขั้นตอน:**
> 1. สร้าง pod ใหม่ด้วย new image
> 2. รอ readiness probe pass
> 3. เริ่ม route traffic ไป pod ใหม่
> 4. terminate pod เก่า
> 5. ทำซ้ำจนครบทุก replicas
>
> **ปัจจุบันในโปรเจค:**
> - ✅ Rolling update configured
> - ✅ Readiness probe configured
> - ⚠️ `replicas: 1` (ควรเป็น 2+ สำหรับ zero downtime จริง)
>
> **Advanced (Phase 2+):** Blue/Green deployment, Canary releases

---

### Q14: AI ช่วยในส่วนไหนของโปรเจค?

**Answer:**
> เราใช้ AI เป็น **Co-pilot** ในหลายส่วนครับ/ค่ะ:
>
> | ส่วนงาน | AI ช่วยอย่างไร | Human ทำอะไร |
> |--------|---------------|-------------|
> | **Code Analysis** | วิเคราะห์ structure, หา bugs | Review และยืนยัน |
> | **Documentation** | Draft documents, format | Edit, validate accuracy |
> | **Troubleshooting** | Suggest fixes | Test และ implement |
> | **Learning** | Explain concepts | Apply และ practice |
> | **Presentation** | Draft slides, scripts | Customize, rehearse |
>
> **หลักการใช้:**
> - AI เสนอ, **Human ตัดสินใจ**
> - ทุกอย่างต้อง **verify ก่อนใช้**
> - ใช้เป็น **เครื่องมือเร่งความเร็ว** ไม่ใช่แทนที่ความเข้าใจ
>
> **ตัวอย่าง:** AI ช่วยวิเคราะห์ `db.js` และเสนอ bug fix แต่เราต้อง test ด้วย Docker Compose เพื่อ verify ว่า fix ถูกต้อง

---

### Q15: Next Steps และ Phase 2 จะทำอะไร?

**Answer:**
> **Immediate Next Steps (หลัง Checkpoint):**
>
> 1. **Provision Jenkins on AWS** - ใช้ Terraform ที่แก้ไขแล้ว
> 2. **Create EKS Cluster** - ใช้ eksctl ตาม document
> 3. **Deploy to Kubernetes** - Apply manifests
> 4. **Full Pipeline Test** - Push code → Auto deploy
>
> **Phase 2 Plan:**
>
> | Feature | Priority | Effort |
> |---------|----------|--------|
> | User Authentication (JWT) | High | Medium |
> | Task Priority | Medium | Low |
> | Task Due Date | Medium | Low |
> | Search/Filter | Low | Low |
> | Node.js 18 upgrade | Medium | Low |
>
> **Long-term Vision:**
> - HTTPS with cert-manager
> - Monitoring (Prometheus + Grafana)
> - ArgoCD for GitOps
> - Blue/Green deployments
>
> **Timeline:**
> - Week 3: Full AWS deployment
> - Week 4: Phase 2 features
> - Final: Complete demo with all features

---

## 🎯 Category Index

### Rationale Questions (Q1, Q8)
ถามว่าทำไมเลือก technology/approach นี้

### Technical Questions (Q2, Q3, Q6, Q7)
ถามเกี่ยวกับการ implement รายละเอียดทางเทคนิค

### Concept Questions (Q4, Q5)
ถามหลักการ/แนวคิดที่เรียนในคลาส

### Implementation Questions (Q9)
ถามเกี่ยวกับปัญหาที่เจอและวิธีแก้ไข

### Security Questions (Q11, Q12)
ถามเกี่ยวกับ security practices

### Testing Questions (Q10)
ถามเกี่ยวกับการทดสอบ

### Advanced Questions (Q13)
ถามเกี่ยวกับ advanced topics

### Process Questions (Q14)
ถามเกี่ยวกับ process ทำงาน

### Planning Questions (Q15)
ถามเกี่ยวกับ next steps

---

*Q&A Document Version: 1.0*
*Total Questions: 15*
*Categories: 9*
