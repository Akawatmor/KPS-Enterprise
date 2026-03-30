---
marp: true
theme: default
paginate: true
backgroundColor: #ffffff
style: |
  section {
    font-family: 'Sarabun', 'Noto Sans Thai', sans-serif;
  }
  h1 {
    color: #1a365d;
  }
  h2 {
    color: #2c5282;
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
  .highlight {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    padding: 0.5rem 1rem;
    border-radius: 8px;
  }
  .status-done { color: #38a169; }
  .status-progress { color: #d69e2e; }
  .status-pending { color: #718096; }
---

<!-- _class: lead -->
<!-- _paginate: false -->

# KPS-Enterprise
## Three-Tier DevSecOps Project
### AWS Learner Lab Edition

---

<!-- _class: lead -->
<!-- _paginate: false -->
<!-- _backgroundColor: #1a365d -->
<!-- _color: white -->

# Checkpoint Phase 1
## Progress Report

**สมาชิกกลุ่ม:**
- นายXXXXXX XXXXXX (รหัส: 6XXXXXXXXX)  
- นายXXXXXX XXXXXX (รหัส: 6XXXXXXXXX)

**ชื่อกลุ่ม:** KPS-Enterprise Team
**Solution:** Three-Tier DevSecOps on Kubernetes

*วันที่นำเสนอ: 1-3 เมษายน 2569*

---

# Slide 1: Application Overview & Requirements

## 📱 แอปพลิเคชันที่เลือก: Three-Tier To-Do List

<div class="columns">
<div>

### ทำหน้าที่อะไร?
- ระบบจัดการงาน (Task Management)
- เว็บแอปพลิเคชัน 3 ชั้น
  - **Frontend:** React.js (UI)
  - **Backend:** Node.js/Express (API)
  - **Database:** MongoDB (Storage)

</div>
<div>

### ต้องทำอะไรได้?
✅ สร้าง/ดู/แก้ไข/ลบ Task (CRUD)
✅ Mark task as completed
✅ Health check endpoints
✅ Container-ready deployment

### ข้อจำกัด (AWS Learner Lab)
❌ ไม่สามารถสร้าง IAM Role
❌ ECR เป็น Read-only
❌ Instance type max: t2.large

</div>
</div>

---

# Slide 2: Design & Tools Selection

## 🛠️ เครื่องมือและเทคโนโลยี

| Layer | Technology | เหตุผลที่เลือก |
|-------|------------|---------------|
| **Frontend** | React 17 + Material-UI | Component-based, Modern UI |
| **Backend** | Node.js 14 + Express | Lightweight, Fast API |
| **Database** | MongoDB 4.4 | NoSQL, Schema-flexible |
| **Container** | Docker | Portable, Reproducible |
| **Orchestration** | Kubernetes (EKS) | Auto-scaling, Self-healing |
| **CI/CD** | Jenkins | Extensible, Pipeline-as-Code |
| **Security Scan** | SonarQube, Trivy, OWASP | DevSecOps best practices |
| **IaC** | Terraform | Declarative, Version-controlled |

---

# Slide 3: CI/CD Flow & Architecture

## 🔄 Pipeline Flow

```
┌──────────┐    ┌─────────┐    ┌──────────────┐    ┌───────────┐    ┌─────────┐
│ Git Push │───▶│ Jenkins │───▶│ Build & Scan │───▶│ Push Image│───▶│ Deploy  │
│ (GitHub) │    │ Trigger │    │ (Security)   │    │(Docker Hub│    │ (K8s)   │
└──────────┘    └─────────┘    └──────────────┘    └───────────┘    └─────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    ▼                ▼                ▼
              ┌──────────┐    ┌───────────┐    ┌───────────┐
              │SonarQube │    │  OWASP    │    │  Trivy    │
              │  (SAST)  │    │(Dep-Check)│    │(Image Scan│
              └──────────┘    └───────────┘    └───────────┘
```

### Key Stages:
1. **Checkout** → Clone repository
2. **Analysis** → SonarQube code quality
3. **Security** → OWASP + Trivy scans
4. **Build** → Docker image creation
5. **Push** → Docker Hub (not ECR - Learner Lab limit)
6. **Deploy** → Update K8s manifests (GitOps)

---

# Slide 4: Implementation Progress & Evaluation

## 📊 Current Status

<div class="columns">
<div>

### ✅ เสร็จแล้ว (Phase 1 Week 1-2)
- <span class="status-done">✓</span> Source code analysis & documentation
- <span class="status-done">✓</span> Learner Lab limitations mapping
- <span class="status-done">✓</span> Code modifications for Learner Lab
- <span class="status-done">✓</span> Local Docker test (verified)
- <span class="status-done">✓</span> Terraform adaptation
- <span class="status-done">✓</span> Jenkins pipeline adaptation

</div>
<div>

### 🔄 กำลังทำ / Next Steps
- <span class="status-progress">○</span> Provision Jenkins on AWS
- <span class="status-progress">○</span> Create EKS cluster
- <span class="status-progress">○</span> Deploy application to K8s
- <span class="status-pending">○</span> Full pipeline test
- <span class="status-pending">○</span> Add authentication (Phase 2)

</div>
</div>

### 📈 การประเมินความถูกต้อง
| Test Case | Expected | Actual |
|-----------|----------|--------|
| Docker build | Success | ✅ Pass |
| Backend API health | 200 OK | ✅ Pass |
| CRUD operations | Create/Read/Update/Delete | ✅ Pass |

---

<!-- _class: lead -->
<!-- _backgroundColor: #38a169 -->
<!-- _color: white -->

# 🎯 Demo

## Local Docker Test
```bash
cd docker
docker compose -f docker-compose.src.yml up -d --build
curl http://localhost:3500/healthz  # → "Healthy"
curl http://localhost:3500/api/tasks  # → []
```

**GitHub Repository:** 
https://github.com/Akawatmor/KPS-Enterprise

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Thank You!
## Questions?

**Contact:**
- GitHub: github.com/Akawatmor/KPS-Enterprise
- Branch: `phase1-implementation`

