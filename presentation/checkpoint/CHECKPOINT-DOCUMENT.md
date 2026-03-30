# KPS-Enterprise: Three-Tier DevSecOps Project
## Checkpoint Phase 1 - Detailed Documentation

---

## 📋 ข้อมูลกลุ่ม

| รายการ | รายละเอียด |
|--------|-----------|
| **ชื่อกลุ่ม** | KPS-Enterprise Team |
| **ชื่อระบบโซลูชัน** | Three-Tier DevSecOps on Kubernetes |
| **สมาชิกคนที่ 1** | นาย XXXXXX XXXXXX (รหัส: 6XXXXXXXXX) |
| **สมาชิกคนที่ 2** | นาย XXXXXX XXXXXX (รหัส: 6XXXXXXXXX) |
| **Repository** | https://github.com/Akawatmor/KPS-Enterprise |
| **Branch หลัก** | `develop`, `phase1-implementation` |

---

## 1. คำอธิบายภาพรวมของระบบและบริบทการใช้งาน

### 1.1 Application คืออะไร?

**Three-Tier To-Do List Application** เป็นเว็บแอปพลิเคชันสำหรับจัดการงาน (Task Management) ที่ออกแบบมาเพื่อสาธิตสถาปัตยกรรมแบบ Three-Tier และ DevSecOps pipeline โดยประกอบด้วย:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Frontend     │────▶│    Backend      │────▶│    Database     │
│   (React.js)    │◀────│  (Node.js/      │◀────│   (MongoDB)     │
│   Port: 3000    │     │   Express)      │     │   Port: 27017   │
│                 │     │   Port: 3500    │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
     Presentation           Business              Data Layer
        Layer                Logic
```

### 1.2 สถานการณ์การใช้งาน

| สถานการณ์ | รายละเอียด |
|-----------|-----------|
| **ทีมพัฒนาขนาดเล็ก** | ต้องการระบบ CI/CD อัตโนมัติเพื่อ deploy แอปพลิเคชันบ่อยครั้ง |
| **การเรียนรู้ DevOps** | เป็นตัวอย่างสำหรับศึกษา Kubernetes, Jenkins, Security Scanning |
| **Demo/POC** | สาธิตความสามารถของ DevSecOps pipeline ให้ stakeholders |

### 1.3 CI/CD สนับสนุนการพัฒนาอย่างไร?

```
┌──────────────────────────────────────────────────────────────────┐
│                     DevSecOps Pipeline                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Developer ──▶ Git Push ──▶ Jenkins ──▶ Security Scans ──▶ Deploy│
│                                                                  │
│  Benefits:                                                       │
│  • Automated testing & deployment                                │
│  • Security scanning integrated (shift-left security)            │
│  • Reproducible builds                                           │
│  • Fast feedback loop                                            │
│  • Infrastructure as Code                                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. ความต้องการของระบบ (Requirements)

### 2.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | ผู้ใช้สามารถสร้าง Task ใหม่ได้ | High | ✅ Done |
| FR-02 | ผู้ใช้สามารถดูรายการ Task ทั้งหมดได้ | High | ✅ Done |
| FR-03 | ผู้ใช้สามารถแก้ไข Task ได้ | High | ✅ Done |
| FR-04 | ผู้ใช้สามารถลบ Task ได้ | High | ✅ Done |
| FR-05 | ผู้ใช้สามารถ Mark task as completed ได้ | High | ✅ Done |
| FR-06 | ระบบต้องมี Health Check endpoints | Medium | ✅ Done |
| FR-07 | ผู้ใช้สามารถ Login/Register ได้ | Medium | 🔄 Phase 2 |
| FR-08 | ผู้ใช้สามารถกำหนด Priority ของ Task ได้ | Low | 🔄 Phase 2 |
| FR-09 | ผู้ใช้สามารถ Search/Filter Task ได้ | Low | 🔄 Phase 2 |

### 2.2 Non-Functional Requirements

| Category | Requirement | Implementation |
|----------|-------------|----------------|
| **Automation** | Pipeline ทำงานอัตโนมัติเมื่อ push code | Jenkins webhook trigger |
| **Reproducibility** | สามารถ reproduce environment ได้ | Docker containers, IaC (Terraform) |
| **Reliability** | ระบบทำงานได้แม้ pod ล้ม | Kubernetes self-healing, replicas |
| **Security** | Code ต้องผ่าน security scan | SonarQube, OWASP, Trivy |
| **Scalability** | รองรับการขยายตัว | Kubernetes HPA (future) |
| **Observability** | สามารถ monitor ระบบได้ | Health endpoints, Prometheus (future) |

### 2.3 AWS Learner Lab Constraints

| Constraint | Impact | Workaround |
|------------|--------|------------|
| Cannot create IAM roles | ไม่สามารถใช้ Terraform สร้าง IAM | ใช้ `LabInstanceProfile` ที่มีอยู่แล้ว |
| ECR is read-only | ไม่สามารถ push Docker images | ใช้ Docker Hub แทน |
| Max instance type: t2.large | Jenkins อาจช้าลง | ปรับลด memory usage |
| Max 9 instances, 32 vCPU | จำกัดจำนวน nodes | ใช้ 3-4 nodes สำหรับ EKS |
| Region: us-east-1 only | ต้องใช้ region เดียว | ตั้งค่าทุกอย่างใน us-east-1 |

---

## 3. กรณีการใช้งานของระบบ (Use Cases)

### 3.1 Use Case Diagram

```
                    ┌─────────────────────────────────────────┐
                    │           KPS-Enterprise System         │
                    │                                         │
    ┌───────┐       │  ┌─────────────────────────────────┐   │
    │       │       │  │         Application             │   │
    │ User  │───────┼─▶│  • Create/View/Edit/Delete Task │   │
    │       │       │  │  • Mark task completed          │   │
    └───────┘       │  │  • View task list               │   │
                    │  └─────────────────────────────────┘   │
                    │                                         │
    ┌───────┐       │  ┌─────────────────────────────────┐   │
    │       │       │  │         CI/CD Pipeline          │   │
    │  Dev  │───────┼─▶│  • Push code → Auto build       │   │
    │       │       │  │  • Security scan results        │   │
    └───────┘       │  │  • Auto deploy to K8s           │   │
                    │  └─────────────────────────────────┘   │
                    │                                         │
    ┌───────┐       │  ┌─────────────────────────────────┐   │
    │       │       │  │         Infrastructure          │   │
    │  Ops  │───────┼─▶│  • Provision with Terraform     │   │
    │       │       │  │  • Monitor health status        │   │
    └───────┘       │  │  • Scale resources              │   │
                    │  └─────────────────────────────────┘   │
                    └─────────────────────────────────────────┘
```

### 3.2 Use Case Details

#### UC-01: User Creates a Task

| Field | Description |
|-------|-------------|
| **Actor** | End User |
| **Precondition** | User opens the web application |
| **Main Flow** | 1. User enters task text<br>2. User clicks "Add Task"<br>3. System saves task to MongoDB<br>4. System updates task list |
| **Postcondition** | New task appears in the list |
| **Alternative Flow** | If task is empty, show validation error |

#### UC-02: Developer Deploys Code Change

| Field | Description |
|-------|-------------|
| **Actor** | Developer |
| **Precondition** | Code changes committed to feature branch |
| **Main Flow** | 1. Developer pushes to GitHub<br>2. Jenkins detects change (webhook)<br>3. Pipeline runs: build → scan → push → deploy<br>4. New version deployed to K8s |
| **Postcondition** | New version running in cluster |
| **Alternative Flow** | If scan fails, pipeline stops and notifies |

#### UC-03: Ops Provisions Infrastructure

| Field | Description |
|-------|-------------|
| **Actor** | Operations Team |
| **Precondition** | AWS credentials configured |
| **Main Flow** | 1. Ops runs `terraform init`<br>2. Ops runs `terraform plan`<br>3. Ops reviews plan<br>4. Ops runs `terraform apply` |
| **Postcondition** | Jenkins EC2 instance running |

### 3.3 ประโยชน์ที่ได้รับ

| ผู้ใช้/ทีม | ประโยชน์ |
|-----------|---------|
| **End Users** | ใช้งานแอปพลิเคชันได้ตลอดเวลา, ได้รับ features ใหม่เร็วขึ้น |
| **Developers** | Deploy บ่อยได้อย่างมั่นใจ, ได้ feedback จาก security scan ทันที |
| **Ops Team** | Infrastructure เป็น code, ทำซ้ำได้, version control |
| **Organization** | ลดเวลา time-to-market, เพิ่ม security posture |

---

## 4. สถาปัตยกรรมของระบบและ CI/CD Pipeline

### 4.1 Overall Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                        │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                        VPC (10.0.0.0/16)                         │    │
│  │                                                                   │    │
│  │  ┌─────────────────┐         ┌───────────────────────────────┐   │    │
│  │  │  Jenkins EC2    │         │      EKS Cluster               │   │    │
│  │  │  (t2.large)     │         │  ┌────────────────────────┐   │   │    │
│  │  │                 │         │  │    Worker Nodes (3x)    │   │   │    │
│  │  │  • Jenkins      │         │  │    t2.large             │   │   │    │
│  │  │  • SonarQube    │         │  │                         │   │   │    │
│  │  │  • Docker       │         │  │  ┌─────┐ ┌─────┐       │   │   │    │
│  │  │  • Trivy        │────────▶│  │  │Front│ │Back │       │   │   │    │
│  │  │                 │         │  │  │end  │ │end  │       │   │   │    │
│  │  └─────────────────┘         │  │  └──┬──┘ └──┬──┘       │   │   │    │
│  │                              │  │     │       │          │   │   │    │
│  │                              │  │     └───┬───┘          │   │   │    │
│  │                              │  │         │              │   │   │    │
│  │                              │  │     ┌───▼───┐          │   │   │    │
│  │                              │  │     │MongoDB│          │   │   │    │
│  │                              │  │     └───────┘          │   │   │    │
│  │                              │  └────────────────────────┘   │   │    │
│  │                              │                               │   │    │
│  │                              │     ALB Ingress Controller    │   │    │
│  │                              └───────────────────────────────┘   │    │
│  │                                          │                       │    │
│  └──────────────────────────────────────────│───────────────────────┘    │
│                                              │                            │
└──────────────────────────────────────────────│────────────────────────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │      Internet       │
                                    │      (Users)        │
                                    └─────────────────────┘
```

### 4.2 CI/CD Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Jenkins Pipeline (Jenkinsfile)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Stage 1        Stage 2         Stage 3         Stage 4         Stage 5    │
│ ┌─────────┐   ┌───────────┐   ┌───────────┐   ┌───────────┐   ┌─────────┐ │
│ │Checkout │──▶│ SonarQube │──▶│  OWASP    │──▶│  Trivy    │──▶│ Docker  │ │
│ │  Git    │   │ Analysis  │   │Dep-Check  │   │ FS Scan   │   │ Build   │ │
│ └─────────┘   └───────────┘   └───────────┘   └───────────┘   └────┬────┘ │
│                                                                     │      │
│                     Stage 6         Stage 7         Stage 8        ▼      │
│                   ┌───────────┐   ┌───────────┐   ┌───────────┐  ┌─────┐  │
│                   │  Docker   │──▶│  Trivy    │──▶│  Update   │  │Push │  │
│                   │Hub Push   │   │Image Scan │   │ K8s YAML  │◀─┤Image│  │
│                   └───────────┘   └───────────┘   └───────────┘  └─────┘  │
│                                                           │               │
│                                                           ▼               │
│                                                   ┌───────────────┐       │
│                                                   │  ArgoCD/GitOps│       │
│                                                   │  (Auto Sync)  │       │
│                                                   └───────────────┘       │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 องค์ประกอบและบทบาท

| Component | Role | Technology |
|-----------|------|------------|
| **GitHub** | Source code repository, webhook trigger | Git |
| **Jenkins** | CI/CD orchestration, pipeline execution | Jenkins Pipeline |
| **SonarQube** | Static code analysis, code quality | SonarQube LTS |
| **OWASP Dep-Check** | Dependency vulnerability scan | OWASP Dependency-Check |
| **Trivy** | Container image vulnerability scan | Trivy |
| **Docker Hub** | Container image registry | Docker Hub |
| **Kubernetes/EKS** | Container orchestration, deployment | Amazon EKS |
| **ALB Ingress** | Load balancing, routing | AWS Load Balancer Controller |
| **MongoDB** | Data persistence | MongoDB 4.4.6 |

---

## 5. แนวคิดและขั้นตอนหลักในการพัฒนา

### 5.1 ขั้นตอนการตั้งค่า Application

#### Step 1: Clone และเตรียม Source Code
```bash
# Clone repository
git clone https://github.com/Akawatmor/KPS-Enterprise.git
cd KPS-Enterprise

# Source code อยู่ใน src/Application-Code/
ls src/Application-Code/
# backend/  frontend/
```

#### Step 2: ทดสอบ Local ด้วย Docker Compose
```bash
# ใช้ docker-compose ที่เตรียมไว้
cd docker
docker compose -f docker-compose.src.yml up -d --build

# ตรวจสอบ status
docker compose -f docker-compose.src.yml ps

# ทดสอบ API
curl http://localhost:3500/healthz  # Expected: "Healthy"
curl http://localhost:3500/api/tasks  # Expected: []
```

### 5.2 ขั้นตอนการตั้งค่า Infrastructure (Terraform)

#### Step 1: เตรียม Terraform Files
```bash
cd src/Jenkins-Server-TF

# แก้ไข variables.tfvars
# - เปลี่ยน key-name เป็น key pair ของคุณ
```

#### Step 2: Provision Jenkins Server
```bash
# Initialize Terraform
terraform init

# Plan (ตรวจสอบก่อน apply)
terraform plan -var-file="variables.tfvars"

# Apply
terraform apply -var-file="variables.tfvars" -auto-approve
```

### 5.3 ขั้นตอนการตั้งค่า CI/CD Pipeline

#### Step 1: Configure Jenkins Credentials
| Credential ID | Type | Description |
|---------------|------|-------------|
| `GITHUB` | Username/Password | GitHub access |
| `github-token` | Secret text | GitHub Personal Access Token |
| `dockerhub-credentials` | Username/Password | Docker Hub login |
| `sonar-token` | Secret text | SonarQube token |
| `ACCOUNT_ID` | Secret text | AWS Account ID |

#### Step 2: Create Jenkins Pipeline
1. New Item → Pipeline
2. Pipeline from SCM → Git
3. Repository URL: `https://github.com/Akawatmor/KPS-Enterprise.git`
4. Script Path: `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend`

### 5.4 ขั้นตอนการ Deploy บน Kubernetes

#### Step 1: Create EKS Cluster
```bash
eksctl create cluster \
  --name kps-cluster \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t2.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 4 \
  --with-oidc \
  --ssh-access \
  --ssh-public-key YOUR_KEY_NAME \
  --managed
```

#### Step 2: Deploy Application
```bash
cd src/Kubernetes-Manifests-file

# Create namespace
kubectl apply -f namespace.yaml

# Deploy Database
kubectl apply -f Database/

# Deploy Backend
kubectl apply -f Backend/

# Deploy Frontend
kubectl apply -f Frontend/

# Create Ingress
kubectl apply -f ingress.yaml
```

---

## 6. ผลการทดสอบ End-to-End (3+ Test Cases)

### Test Case 1: Successful CRUD Operations ✅

| Test Item | Expected | Actual | Status |
|-----------|----------|--------|--------|
| **Create Task** | POST /api/tasks returns 200, task object | `{"task":"Test","completed":false,"_id":"..."}` | ✅ Pass |
| **Read Tasks** | GET /api/tasks returns array | `[{"_id":"...","task":"Test",...}]` | ✅ Pass |
| **Update Task** | PUT /api/tasks/:id returns 200 | Task updated successfully | ✅ Pass |
| **Delete Task** | DELETE /api/tasks/:id returns 200 | Task removed from list | ✅ Pass |

**Evidence:**
```bash
# Create
$ curl -X POST http://localhost:3500/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"task":"Test task","completed":false}'
{"task":"Test task","completed":false,"_id":"69c62f2d1e675a99074f5cf7","__v":0}

# Read
$ curl http://localhost:3500/api/tasks
[{"_id":"69c62f2d1e675a99074f5cf7","task":"Test task","completed":false,"__v":0}]
```

### Test Case 2: Health Check Endpoints ✅

| Endpoint | Expected Response | Actual Response | Status |
|----------|-------------------|-----------------|--------|
| `/healthz` | 200 "Healthy" | 200 "Healthy" | ✅ Pass |
| `/ready` | 200 "Ready" (when DB connected) | 200 "Ready" | ✅ Pass |
| `/started` | 200 "Started" | 200 "Started" | ✅ Pass |

**Evidence:**
```bash
$ curl -w "\nStatus: %{http_code}\n" http://localhost:3500/healthz
Healthy
Status: 200

$ curl -w "\nStatus: %{http_code}\n" http://localhost:3500/ready
Ready
Status: 200
```

### Test Case 3: Failure Scenario - Database Disconnection ❌→✅

| Scenario | Expected Behavior | Actual Behavior | Status |
|----------|-------------------|-----------------|--------|
| MongoDB down | `/ready` returns 503 "Not Ready" | Returns 503 | ✅ Pass |
| MongoDB back up | `/ready` returns 200 "Ready" | Self-heals, returns 200 | ✅ Pass |

**Evidence:**
```bash
# Stop MongoDB
$ docker stop kps-mongodb

# Check readiness
$ curl -w "\nStatus: %{http_code}\n" http://localhost:3500/ready
Not Ready
Status: 503

# Start MongoDB
$ docker start kps-mongodb

# Wait for reconnection, then check
$ sleep 10 && curl -w "\nStatus: %{http_code}\n" http://localhost:3500/ready
Ready
Status: 200
```

**ระบบรับมืออย่างไร:**
1. Mongoose มี auto-reconnect built-in
2. `/ready` endpoint ตรวจสอบ `mongoose.connection.readyState`
3. Kubernetes readiness probe จะหยุดส่ง traffic ไป pod ที่ไม่ ready
4. เมื่อ DB กลับมา, pod จะ ready อีกครั้งโดยอัตโนมัติ

### Test Case 4: Docker Build Failure Scenario ❌→✅

| Scenario | Expected Behavior | Actual Behavior | Status |
|----------|-------------------|-----------------|--------|
| Invalid package.json | Build fails with clear error | npm install error shown | ✅ Pass |
| Fix package.json | Build succeeds | Build completes | ✅ Pass |

**Evidence (before fix):**
```bash
# With "axios": "^=0.30.0" (invalid semver)
$ docker build -t test .
# ERROR: npm WARN invalid semver
```

**Evidence (after fix):**
```bash
# With "axios": "^0.30.0" (correct)
$ docker build -t test .
# Successfully built
```

---

## 7. การวิเคราะห์ระบบตามแนวคิดที่เรียน

### 7.1 ข้อดีของระบบ

| Concept | Implementation | Benefit |
|---------|----------------|---------|
| **Automation** | Jenkins pipeline triggers on push | ลด manual work, ลด human error |
| **Infrastructure as Code** | Terraform for EC2, eksctl for EKS | Version control, reproducible |
| **Containerization** | Docker images | Consistent environment, portable |
| **Orchestration** | Kubernetes | Auto-scaling, self-healing |
| **Security Shift-Left** | SonarQube, OWASP, Trivy in pipeline | Find vulnerabilities early |
| **GitOps** | Pipeline updates K8s manifests | Declarative, auditable deployments |
| **Health Checks** | /healthz, /ready, /started endpoints | Better reliability, K8s integration |

### 7.2 ข้อจำกัดของระบบ

| Limitation | Impact | Potential Solution |
|------------|--------|-------------------|
| **No Authentication** | Anyone can access tasks | Implement JWT auth (Phase 2) |
| **No HTTPS** | Data in transit not encrypted | Add TLS with cert-manager |
| **Single DB replica** | Single point of failure | MongoDB replica set |
| **No HPA** | Manual scaling only | Add Horizontal Pod Autoscaler |
| **No centralized logging** | Hard to debug across pods | Add EFK/Loki stack |
| **Learner Lab limits** | Limited resources | Design within constraints |

### 7.3 Analysis Summary Table

| Criteria | Score (1-5) | Notes |
|----------|-------------|-------|
| **Reliability** | 3/5 | Basic health checks, needs redundancy |
| **Automation** | 4/5 | Good CI/CD, can add more tests |
| **Security** | 3/5 | Scans in place, needs auth + TLS |
| **Maintainability** | 4/5 | IaC, containerized, well-documented |
| **Scalability** | 3/5 | K8s ready, needs HPA |
| **Observability** | 2/5 | Basic health, needs monitoring |

---

## 8. ข้อเสนอแนะในการต่อยอดระบบ

### 8.1 Short-term Improvements (Phase 2)

| ส่วนที่ต้องปรับปรุง | เหตุผล | วิธีการ |
|-------------------|--------|--------|
| **User Authentication** | ปัจจุบันไม่มี login | เพิ่ม JWT-based auth, User model |
| **Task Priority** | ผู้ใช้จัดลำดับความสำคัญไม่ได้ | เพิ่ม priority field (high/medium/low) |
| **Task Due Date** | ไม่มี deadline tracking | เพิ่ม dueDate field + overdue highlight |
| **Search/Filter** | หา task ลำบาก | เพิ่ม search endpoint + frontend filter |
| **Node.js Upgrade** | v14 is EOL | Upgrade to v18 LTS |
| **Multi-stage Dockerfile** | Image ใหญ่เกินไป | Separate build/runtime stages |

### 8.2 Medium-term Improvements

| ส่วนที่ต้องปรับปรุง | เหตุผล | วิธีการ |
|-------------------|--------|--------|
| **HTTPS/TLS** | Data encryption in transit | cert-manager + Let's Encrypt |
| **Monitoring** | ขาด visibility | Prometheus + Grafana stack |
| **Centralized Logging** | Debug ยากข้าม pods | Loki + Promtail or EFK |
| **Network Policies** | Pod-to-pod unrestricted | K8s NetworkPolicy resources |
| **Resource Limits** | Pods can use unlimited resources | Add requests/limits |

### 8.3 Long-term Vision

```
Current State                    Target State
──────────────                   ─────────────
• Basic To-Do app               • Full-featured Task Management
• Manual scaling                • Auto-scaling (HPA/VPA)
• No auth                       • OAuth/OIDC integration
• Single region                 • Multi-region HA
• HTTP only                     • Full TLS/mTLS
• No GitOps                     • ArgoCD for GitOps
• Basic pipeline                • Blue/Green deployments
```

---

## 9. ลิงก์ที่เกี่ยวข้อง

### 9.1 Repository & Code

| Resource | URL |
|----------|-----|
| **GitHub Repository** | https://github.com/Akawatmor/KPS-Enterprise |
| **Main Branch** | `develop` |
| **Implementation Branch** | `phase1-implementation` |
| **Checkpoint Branch** | `checkpoint-phase1` |

### 9.2 Documentation

| Document | Location |
|----------|----------|
| Phase 1 Implementation Result | `document/phase1/implement-result.md` |
| Backend Analysis | `document/phase1/issue4-backend-source-code-doc.md` |
| Frontend Analysis | `document/phase1/issue5-frontend-source-code-doc.md` |
| Learner Lab Limitations | `document/phase1/issue11-requirements-mapping.md` |

### 9.3 Demo Video

| Resource | URL |
|----------|-----|
| **Video Demo** | [Link จะเพิ่มหลังจาก record] |
| **Duration** | ≤ 5 minutes |
| **Content** | Local Docker test + Pipeline explanation |

---

## 10. Appendix

### A. Directory Structure

```
KPS-Enterprise/
├── src/                              # Modified source code
│   ├── Application-Code/
│   │   ├── backend/                  # Node.js/Express API
│   │   └── frontend/                 # React.js UI
│   ├── Jenkins-Pipeline-Code/        # Jenkinsfiles
│   ├── Jenkins-Server-TF/            # Terraform for Jenkins
│   └── Kubernetes-Manifests-file/    # K8s YAML files
├── docker/
│   ├── docker-compose.yml            # Local test (Issue #7)
│   └── docker-compose.src.yml        # Test src/ code
├── document/
│   └── phase1/                       # Phase 1 documentation
├── presentation/
│   └── checkpoint/                   # This presentation
└── original-project/                 # Submodule (unchanged)
```

### B. Technology Versions

| Technology | Version |
|------------|---------|
| Node.js | 14 (target: 18 LTS) |
| React | 17.0.2 |
| Express | 4.17.1 |
| MongoDB | 4.4.6 |
| Mongoose | 6.13.6 |
| Docker | 24.x |
| Kubernetes | 1.28.x |
| Jenkins | Latest LTS |
| Terraform | ≥0.13.0 |
| Trivy | Latest |

---

*Document Version: 1.0*
*Last Updated: March 27, 2026*
*Authors: KPS-Enterprise Team*
