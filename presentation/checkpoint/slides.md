---
marp: true
theme: default
paginate: true
backgroundColor: #ffffff
style: |
  section {
    font-family: 'Sarabun', 'Noto Sans Thai', sans-serif;
  }
  h1 { color: #1a365d; }
  h2 { color: #2c5282; }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
  table { font-size: 0.8em; }
  code { font-size: 0.85em; }
  .small { font-size: 0.75em; }
---

<!-- _class: lead -->
<!-- _paginate: false -->
<!-- _backgroundColor: #1a365d -->
<!-- _color: white -->

# KPS-Enterprise
## Three-Tier DevSecOps Project

**สมาชิกกลุ่ม:**
- นายรัฐธรรมนูญ โกศาสังข์ (6609612178)
- นายเอกวัส มรสาเทียน (6609681231)

**ชื่อกลุ่ม:** KPS-Enterprise Team
**ชื่อระบบ:** Three-Tier DevSecOps on Kubernetes (AWS Learner Lab)

*Checkpoint Phase 1 Week 2 | เมษายน 2569*

---

# Slide 1: Application Overview & Requirements

<div class="columns">
<div>

## 📱 แอปพลิเคชัน: Three-Tier To-Do List

**ทำหน้าที่:** ระบบจัดการงาน (Task Management)
- **Frontend:** React.js (Port 3000)
- **Backend:** Node.js/Express API (Port 3500)
- **Database:** MongoDB (Port 27017)

### ✅ Functional Requirements
| Feature | Status |
|---------|--------|
| สร้าง/ดู/แก้ไข/ลบ Task (CRUD) | ✅ Done |
| Mark task as completed | ✅ Done |
| Health endpoints (`/healthz`, `/ready`) | ✅ Done |

</div>
<div>

### ❌ ข้อจำกัด AWS Learner Lab

| Constraint | Solution |
|------------|----------|
| ห้ามสร้าง IAM Role | ใช้ `LabInstanceProfile` |
| ECR Read-only | ใช้ Docker Hub แทน |
| Max t2.large | Optimize resources |
| Max 9 instances | ใช้ 3 EKS nodes |

### 🔄 Phase 2 (Future)
- User Authentication (JWT)
- Task Priority & Due Date
- Search/Filter

</div>
</div>

---

# Slide 2: Design & Tools Selection

<div class="columns">
<div>

## ��️ Technology Stack

| Layer | Technology | เหตุผล |
|-------|------------|--------|
| **Frontend** | React 17 + MUI | Modern, Component-based |
| **Backend** | Node.js + Express | Lightweight, Fast |
| **Database** | MongoDB 4.4 | NoSQL, Flexible |
| **Container** | Docker | Portable |
| **Orchestration** | Kubernetes (EKS) | Self-healing, Scaling |
| **IaC** | Terraform | Version-controlled |
| **Registry** | Docker Hub | (ECR read-only) |

</div>
<div>

## 🛡️ DevSecOps Security (Shift-Left)

| Tool | Type | ตรวจอะไร |
|------|------|---------|
| **SonarQube** | SAST | Code quality, bugs |
| **OWASP** | SCA | Dependencies CVEs |
| **Trivy** | Scanner | Container images |

### 🔧 Bug Fixes ใน Original Code
```javascript
// db.js: Boolean parsing fix
// Before: "false" is truthy!
const useDBAuth = env || false; // WRONG
// After:
const useDBAuth = env === "true"; // CORRECT
```
```json
// package.json: Semver fix
"axios": "^=0.30.0" → "^0.30.0"
```

</div>
</div>

---

# Slide 3: CI/CD Flow & Architecture

## 🔄 DevSecOps Pipeline (10 Stages)

```
Developer → Git Push → Jenkins Trigger
    │
    ├─ Stage 1-2: Checkout + npm install
    ├─ Stage 3-4: SonarQube Analysis + Quality Gate  ──┐
    ├─ Stage 5-6: OWASP Dep-Check + Trivy FS Scan    ──┼─ Security (Shift-Left)
    ├─ Stage 7-8: Docker Build + Trivy Image Scan    ──┘
    └─ Stage 9-10: Push Docker Hub + Update K8s Manifests (GitOps)
                                    │
                           Kubernetes Deploy
```

<div class="columns">
<div>

### Key Features
- **Fail-Fast:** ถ้า security scan ไม่ผ่าน → Pipeline หยุด
- **GitOps:** Update image tag ใน Git → K8s sync
- **3-Layer Security:** SAST + SCA + Container Scan

</div>
<div>

### Learner Lab Adaptations
- ECR → **Docker Hub** (push images)
- IAM roles → **LabInstanceProfile**
- t2.2xlarge → **t2.large**
- **15+ files modified**

</div>
</div>

---

# Slide 4: Implementation Progress & Evaluation

<div class="columns">
<div>

## ✅ Completed (Phase 1 Week 2)
- Source code analysis (Backend/Frontend/DB)
- Learner Lab constraint mapping
- **2 critical bugs fixed** (db.js, package.json)
- Terraform adaptation (IAM removed)
- Jenkins pipeline → Docker Hub
- Kubernetes manifests updated
- **Local Docker test verified** ✅
- DevSecOps pipeline designed (10 stages)
- **15+ documents** created

## ⏳ Remaining
- Provision Jenkins on AWS
- Create EKS cluster
- Full E2E pipeline test

</div>
<div>

## 📊 Evaluation: ระบบทำงานถูกต้อง?

| Test Case | Result |
|-----------|--------|
| Docker build | ✅ Pass |
| `/healthz` endpoint | ✅ 200 OK |
| `/ready` endpoint | ✅ 200 OK |
| CRUD operations | ✅ All pass |
| **DB disconnect → recovery** | ✅ Self-heal |

## 📋 Next Plan → Final Demo
| Week | Milestone |
|------|-----------|
| W2 | AWS Infrastructure + EKS |
| W3 | Full pipeline test |
| W4 | Phase 2 features (Auth) |
| Final | Complete demo |

</div>
</div>

---

# Slide 5: Demo & Repository

<div class="columns">
<div>

## 🎯 Live Demo (Local Docker)

```bash
# Start containers
cd docker
docker compose -f docker-compose.src.yml up -d

# Test endpoints
curl localhost:3500/healthz  # → "Healthy"
curl localhost:3500/ready    # → "Ready"

# Test CRUD
curl -X POST localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"Demo"}'
curl localhost:3500/api/tasks  # → [tasks]
```

**GitHub:** [github.com/Akawatmor/KPS-Enterprise](https://github.com/Akawatmor/KPS-Enterprise)

</div>
<div>

## 📁 Repository Structure
```
KPS-Enterprise/
├── src/                  # Modified code
│   ├── Application-Code/ # Bugs fixed
│   ├── Jenkins-Pipeline-Code/
│   ├── Jenkins-Server-TF/
│   └── Kubernetes-Manifests-file/
├── docker/               # Local testing
├── document/phase1/      # 15+ docs
└── presentation/checkpoint/
```

## 🎉 Summary
✅ Analyzed & documented entire codebase
✅ Fixed bugs + adapted 15+ files
✅ Designed 10-stage DevSecOps pipeline
✅ Local testing verified
**Ready for AWS deployment!** 🚀

</div>
</div>

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Thank You!
## Questions?

**GitHub:** github.com/Akawatmor/KPS-Enterprise
**Branch:** `phase1-implementation`

*KPS-Enterprise Team | AI-Assisted Development*
