# 📝 Presentation Script
## KPS-Enterprise: Three-Tier DevSecOps Project
### 10-Minute Presentation for 2 Presenters

---

## Timing Overview

| Section | Duration | Presenter |
|---------|----------|-----------|
| Opening & Cover | 0:30 | Presenter 1 |
| Slide 1: Application Overview | 2:00 | Presenter 1 |
| Slide 2: Design & Tools | 2:00 | Presenter 1 |
| Slide 3: CI/CD Flow | 2:30 | Presenter 2 |
| Slide 4: Progress & Demo | 2:30 | Presenter 2 |
| Closing & Q&A Intro | 0:30 | Both |
| **Total** | **10:00** | |

---

## 📢 Presenter 1 Script

### Opening & Cover Slide (0:30)

> สวัสดีครับ/ค่ะ อาจารย์และเพื่อนๆ ทุกคน
>
> วันนี้พวกเราจากกลุ่ม **KPS-Enterprise Team** จะมานำเสนอความก้าวหน้าของโปรเจค **Three-Tier DevSecOps Project on Kubernetes** ครับ/ค่ะ
>
> สมาชิกในกลุ่มมี 2 คน ได้แก่:
> - [ชื่อ-สกุล] รหัส [XXXXXXXXXX]
> - [ชื่อ-สกุล] รหัส [XXXXXXXXXX]
>
> โซลูชันของเราชื่อ **KPS-Enterprise** โดยเป็นการบูรณาการทำงานร่วมกับ AI ครับ/ค่ะ

---

### Slide 1: Application Overview & Requirements (2:00)

> เริ่มต้นที่ **Application Overview** ครับ/ค่ะ
>
> แอปพลิเคชันที่เราเลือกคือ **Three-Tier To-Do List Application** ซึ่งเป็นระบบจัดการงานหรือ Task Management แบบเว็บแอปพลิเคชัน
>
> ระบบนี้มี **สถาปัตยกรรม 3 ชั้น** คือ:
> 1. **Frontend** - ใช้ React.js สำหรับ UI รันที่ port 3000
> 2. **Backend** - ใช้ Node.js กับ Express เป็น API รันที่ port 3500
> 3. **Database** - ใช้ MongoDB สำหรับเก็บข้อมูล รันที่ port 27017
>
> **Functional Requirements** หรือสิ่งที่ระบบต้องทำได้ คือ:
> - CRUD operations คือ สร้าง ดู แก้ไข และลบ Task ได้
> - Mark task เป็น completed ได้
> - มี Health check endpoints สำหรับ Kubernetes
>
> แต่ระบบเราต้องรันบน **AWS Learner Lab** ซึ่งมีข้อจำกัดสำคัญคือ:
> - ❌ ไม่สามารถสร้าง IAM Role ได้ ต้องใช้ LabInstanceProfile ที่มีอยู่แล้ว
> - ❌ ECR เป็น Read-only push ไม่ได้ ต้องใช้ Docker Hub แทน
> - ❌ Instance type ใหญ่สุดได้แค่ t2.large
>
> ข้อจำกัดเหล่านี้คือความท้าทายที่เราต้องปรับ code ให้รองรับครับ/ค่ะ

---

### Slide 2: Design & Tools Selection (2:00)

> มาที่ **Design & Tools Selection** ครับ/ค่ะ
>
> เราเลือกใช้ **Technology Stack** ดังนี้:
>
> สำหรับ **Application Layer**:
> - **React 17** กับ Material-UI สำหรับ Frontend เพราะเป็น component-based และมี UI ที่ทันสมัย
> - **Node.js 14** กับ Express สำหรับ Backend เพราะเป็น Lightweight และสร้าง API ได้เร็ว
> - **MongoDB 4.4** สำหรับ Database เพราะเป็น NoSQL ที่ schema flexible
>
> สำหรับ **DevOps Layer**:
> - **Docker** สำหรับ containerization ทำให้ environment เหมือนกันทุกที่
> - **Kubernetes บน EKS** สำหรับ orchestration มี auto-scaling และ self-healing
> - **Jenkins** สำหรับ CI/CD เพราะ extensible และรองรับ Pipeline-as-Code
> - **Terraform** สำหรับ Infrastructure as Code ทำให้ version control infrastructure ได้
>
> สำหรับ **Security Layer**:
> - **SonarQube** สำหรับ static code analysis
> - **OWASP Dependency-Check** สำหรับตรวจ vulnerabilities ใน dependencies
> - **Trivy** สำหรับ scan Docker images
>
> การรวม security tools เข้าไปใน pipeline เป็นหลักการ **Shift-Left Security** ที่ทำให้เราเจอ bugs เร็วขึ้นครับ/ค่ะ
>
> ตอนนี้ขอส่งต่อให้เพื่อนอธิบาย CI/CD Flow ครับ/ค่ะ

---

## 📢 Presenter 2 Script

### Slide 3: CI/CD Flow & Architecture (2:30)

> ขอบคุณครับ/ค่ะ มาที่ **CI/CD Flow & Architecture** กันครับ/ค่ะ
>
> Pipeline ของเราทำงานดังนี้:
>
> **เริ่มจาก Developer push code ไป GitHub**
> เมื่อมี push event เกิดขึ้น GitHub webhook จะ trigger Jenkins ให้เริ่มทำงาน
>
> **Stage 1-2: Checkout และ SonarQube Analysis**
> Jenkins จะ clone code แล้วส่งไป SonarQube วิเคราะห์ code quality
>
> **Stage 3-4: Security Scans**
> - OWASP Dependency-Check ตรวจ dependencies ว่ามี known vulnerabilities หรือไม่
> - Trivy File System Scan ตรวจ source code และ configs
>
> **Stage 5-6: Build และ Push**
> - สร้าง Docker image ด้วย Dockerfile
> - Push ไป **Docker Hub** (ไม่ใช่ ECR เพราะ Learner Lab จำกัด)
>
> **Stage 7: Image Scan**
> - Trivy scan Docker image อีกครั้งก่อน deploy
>
> **Stage 8: Update K8s Manifests**
> - Pipeline อัปเดต image tag ใน deployment.yaml
> - Push กลับไป GitHub repo
> - ซึ่งจะ trigger ArgoCD หรือ GitOps flow ให้ deploy อัตโนมัติ
>
> **ข้อดีของ flow นี้คือ**:
> - ทุกขั้นตอนเป็น automated
> - Security scan ทุกครั้งก่อน deploy
> - ถ้า stage ไหน fail pipeline จะหยุดทันที ไม่ deploy code ที่มีปัญหา
>
> นี่คือหลักการ **fail-fast** ที่เราเรียนในคลาสครับ/ค่ะ

---

### Slide 4: Implementation Progress & Evaluation (2:30)

> มาที่ **Progress และ Evaluation** ครับ/ค่ะ
>
> **สิ่งที่ทำเสร็จแล้วใน Phase 1 Week 1-2**:
> - ✅ วิเคราะห์ source code ทั้ง backend และ frontend
> - ✅ จัดทำเอกสาร mapping ข้อจำกัดของ Learner Lab
> - ✅ แก้ไข code สำหรับ Learner Lab เช่น:
>   - แก้ `db.js` ให้ parse boolean ถูกต้อง
>   - แก้ `package.json` ที่มี semver ผิด
>   - แก้ Terraform ให้ใช้ LabInstanceProfile แทน
>   - แก้ Jenkinsfile ให้ push Docker Hub แทน ECR
>   - แก้ K8s manifests ให้ใช้ Docker Hub images
> - ✅ ทดสอบ local ด้วย Docker Compose ผ่านแล้ว
>
> **กำลังทำอยู่และ Next Steps**:
> - 🔄 Provision Jenkins บน AWS
> - 🔄 สร้าง EKS cluster
> - 🔄 Deploy application บน Kubernetes
> - 📋 Full pipeline test
> - 📋 Phase 2: เพิ่ม Authentication
>
> **การประเมินความถูกต้อง**:
>
> เราทดสอบ 3 กรณี:
> 1. **CRUD Operations** - สร้าง/ดู/แก้/ลบ Task ผ่านทุก operation
> 2. **Health Check Endpoints** - `/healthz`, `/ready`, `/started` ตอบถูกต้อง
> 3. **Failure Scenario** - เมื่อปิด MongoDB, `/ready` return 503 และเมื่อเปิดกลับมาระบบ self-heal ได้
>
> **[ถ้ามีเวลา Demo]**
>
> ขอ demo สั้นๆ ครับ/ค่ะ
>
> ```bash
> curl http://localhost:3500/healthz  # → "Healthy"
> curl http://localhost:3500/api/tasks  # → []
> curl -X POST http://localhost:3500/api/tasks \
>      -H "Content-Type: application/json" \
>      -d '{"task":"Demo task"}'  # → Created
> ```

---

### Closing (0:30)

> **สรุป** แล้วระบบ KPS-Enterprise ของเราได้ปรับแก้ให้รองรับ Learner Lab ทั้งหมดแล้ว และทดสอบ local ผ่านเรียบร้อยครับ/ค่ะ
>
> Next milestone คือการ deploy บน AWS จริงและทดสอบ full pipeline
>
> ขอบคุณครับ/ค่ะ รับคำถามได้เลยครับ/ค่ะ
>
> **GitHub**: github.com/Akawatmor/KPS-Enterprise
> **Branch**: `phase1-implementation`

---

## 💡 Tips for Presenters

### Before Presentation:
1. ทดสอบ local Docker test ให้พร้อม demo
2. เปิด browser tabs: GitHub repo, Docker Desktop (ถ้ามี)
3. เตรียม terminal สำหรับ curl commands
4. ซ้อมพูดจับเวลาหลายรอบ

### During Presentation:
1. พูดช้าๆ ชัดๆ ไม่ต้องรีบ
2. มอง audience ไม่ใช่จอ
3. ถ้าติดขัดให้ผู้ช่วยเสริมได้
4. ถ้า demo fail ให้อธิบายเป็นคำพูดแทน (ไม่ต้อง panic)

### Common Transitions:
- "ก่อนอื่น..." / "เริ่มต้นที่..."
- "ต่อมา..." / "ถัดไป..."
- "ตอนนี้ขอส่งต่อให้เพื่อน..."
- "สรุปแล้ว..."

---

## 🔄 Backup Plan

ถ้า Demo ไม่ทำงาน:
> "ขออนุญาตแสดงผลลัพธ์จาก screenshot/video แทนครับ/ค่ะ เนื่องจาก [network/technical issue]"

ถ้าหมดเวลา:
> "ขอสรุปสั้นๆ ว่าเราทำ Phase 1 เสร็จแล้ว ทดสอบ local ผ่าน และพร้อม deploy บน AWS ในสัปดาห์หน้าครับ/ค่ะ"

---

*Script Version: 1.0*
*Estimated Time: 10 minutes*
