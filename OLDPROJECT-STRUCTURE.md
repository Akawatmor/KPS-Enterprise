# OLDPROJECT-STRUCTURE

## 📋 ภาพรวมโปรเจค (Project Overview)

โปรเจคนี้เป็น **Three-Tier Web Application** ที่ใช้สำหรับ **To-Do List Application** พัฒนาด้วยสถาปัตยกรรม:

- **Frontend**: ReactJS
- **Backend**: NodeJS (Express.js)
- **Database**: MongoDB

โปรเจคนี้ถูกออกแบบมาเพื่อ Deploy บน **AWS EKS (Elastic Kubernetes Service)** โดยใช้แนวคิด **DevSecOps** ครบวงจร

---

## 📁 โครงสร้างไดเรกทอรี (Directory Structure)

```
original-project/
├── .github/                          # GitHub configurations
│   ├── FUNDING.yml
│   └── ISSUE_TEMPLATE/
├── Application-Code/                 # Source code ของ Application
│   ├── backend/                      # Backend API (NodeJS)
│   └── frontend/                     # Frontend UI (ReactJS)
├── Jenkins-Pipeline-Code/            # Jenkins CI/CD Pipelines
│   ├── Jenkinsfile-Backend
│   └── Jenkinsfile-Frontend
├── Jenkins-Server-TF/                # Terraform สำหรับ Jenkins Server
│   ├── backend.tf
│   ├── ec2.tf
│   ├── gather.tf
│   ├── iam-instance-profile.tf
│   ├── iam-policy.tf
│   ├── iam-role.tf
│   ├── provider.tf
│   ├── tools-install.sh
│   ├── variables.tf
│   ├── variables.tfvars
│   └── vpc.tf
├── Kubernetes-Manifests-file/        # Kubernetes Manifests
│   ├── Backend/
│   ├── Database/
│   ├── Frontend/
│   └── ingress.yaml
├── assets/
├── LICENSE
└── README.md
```

---

## 🖥️ Application Code

### Backend (NodeJS + Express)

**Location**: `Application-Code/backend/`

#### ไฟล์หลัก:

| ไฟล์ | คำอธิบาย |
|------|----------|
| `index.js` | Entry point ของ API Server (Port 3500) |
| `db.js` | MongoDB Connection Configuration |
| `models/task.js` | Mongoose Schema สำหรับ Task |
| `routes/tasks.js` | REST API Routes สำหรับ CRUD operations |
| `Dockerfile` | Docker image build instructions |
| `package.json` | Dependencies และ scripts |

#### Dependencies:
```json
{
  "cors": "^2.8.5",
  "express": "^4.17.1",
  "mongoose": "^6.13.6"
}
```

#### API Endpoints:

| Method | Endpoint | คำอธิบาย |
|--------|----------|----------|
| `GET` | `/api/tasks` | ดึงรายการ Tasks ทั้งหมด |
| `POST` | `/api/tasks` | สร้าง Task ใหม่ |
| `PUT` | `/api/tasks/:id` | อัพเดท Task |
| `DELETE` | `/api/tasks/:id` | ลบ Task |

#### Health Check Endpoints (สำคัญสำหรับ K8s):

| Endpoint | ใช้สำหรับ |
|----------|----------|
| `/healthz` | Liveness Probe |
| `/ready` | Readiness Probe (ตรวจสอบ DB connection) |
| `/started` | Startup Probe |

#### Environment Variables:
```bash
MONGO_CONN_STR     # MongoDB Connection String
MONGO_USERNAME     # MongoDB Username (optional)
MONGO_PASSWORD     # MongoDB Password (optional)
USE_DB_AUTH        # Enable/Disable DB Authentication
PORT               # Server Port (default: 3500)
```

#### Dockerfile (Backend):
```dockerfile
FROM node:14
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "index.js"]
```

---

### Frontend (ReactJS)

**Location**: `Application-Code/frontend/`

#### ไฟล์หลัก:

| ไฟล์ | คำอธิบาย |
|------|----------|
| `src/App.js` | Main React Component (UI) |
| `src/Tasks.js` | Task Management Logic (State & API calls) |
| `src/services/taskServices.js` | API Service Layer (Axios) |
| `Dockerfile` | Docker image build instructions |
| `package.json` | Dependencies และ scripts |

#### Dependencies:
```json
{
  "@material-ui/core": "^4.11.4",
  "axios": "^=0.30.0",
  "react": "^17.0.2",
  "react-dom": "^17.0.2",
  "react-scripts": "4.0.3"
}
```

#### Environment Variables:
```bash
REACT_APP_BACKEND_URL   # Backend API URL
```

#### Dockerfile (Frontend):
```dockerfile
FROM node:14
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
CMD [ "npm", "start" ]
```

---

## 🔄 Jenkins CI/CD Pipeline

### Pipeline Stages (ทั้ง Backend และ Frontend)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DevSecOps Pipeline Stages                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. Cleaning Workspace    → ล้าง workspace ก่อน build                       │
│  2. Checkout from Git     → Clone repository จาก GitHub                     │
│  3. SonarQube Analysis    → Static Code Analysis (SAST)                     │
│  4. Quality Gate          → รอผล Quality Gate จาก SonarQube                 │
│  5. OWASP Dependency-Check→ ตรวจสอบ vulnerable dependencies                 │
│  6. Trivy File Scan       → Scan filesystem หา vulnerabilities              │
│  7. Docker Image Build    → Build Docker image                              │
│  8. ECR Image Pushing     → Push image ไป AWS ECR                           │
│  9. TRIVY Image Scan      → Scan Docker image หา vulnerabilities            │
│  10. Update Deployment    → Update K8s deployment file (GitOps)             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Jenkins Credentials ที่ต้องตั้งค่า:

| Credential ID | ประเภท | คำอธิบาย |
|---------------|--------|----------|
| `GITHUB` | Username/Password | GitHub credentials สำหรับ clone repo |
| `github` | Secret Text | GitHub Token สำหรับ push changes |
| `sonar-token` | Secret Text | SonarQube authentication token |
| `ACCOUNT_ID` | Secret Text | AWS Account ID |
| `ECR_REPO1` | Secret Text | ECR Repository name สำหรับ Frontend |
| `ECR_REPO2` | Secret Text | ECR Repository name สำหรับ Backend |

### Jenkins Tools ที่ต้องติดตั้ง:

| Tool Name | Version/Config |
|-----------|----------------|
| `jdk` | JDK Installation |
| `nodejs` | NodeJS Installation |
| `sonar-scanner` | SonarQube Scanner |
| `DP-Check` | OWASP Dependency-Check |

### Security Scans ใน Pipeline:

| Tool | ประเภท | คำอธิบาย |
|------|--------|----------|
| **SonarQube** | SAST | Static Application Security Testing |
| **OWASP Dependency-Check** | SCA | Software Composition Analysis |
| **Trivy FS** | Vulnerability | File System vulnerability scan |
| **Trivy Image** | Vulnerability | Container Image vulnerability scan |

---

## 🏗️ Jenkins Server Infrastructure (Terraform)

**Location**: `Jenkins-Server-TF/`

### AWS Resources ที่สร้าง:

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure                            │
├─────────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                              │
│  ├── Public Subnet (10.0.1.0/24, us-east-1a)                    │
│  ├── Internet Gateway                                           │
│  ├── Route Table                                                │
│  └── Security Group                                             │
│       └── Allowed Ports: 22, 80, 8080, 9000, 9090              │
│                                                                  │
│  EC2 Instance                                                    │
│  ├── Type: t2.2xlarge                                           │
│  ├── Volume: 30GB                                               │
│  ├── IAM Role: Administrator Access                             │
│  └── User Data: tools-install.sh                                │
└─────────────────────────────────────────────────────────────────┘
```

### Security Group Ports:

| Port | Service |
|------|---------|
| 22 | SSH |
| 80 | HTTP |
| 8080 | Jenkins |
| 9000 | SonarQube |
| 9090 | Prometheus (optional) |

### Tools ที่ติดตั้งอัตโนมัติ (tools-install.sh):

| Tool | เวอร์ชัน/หมายเหตุ |
|------|-------------------|
| Java | OpenJDK 17 |
| Jenkins | Latest |
| Docker | Latest |
| SonarQube | LTS Community (Docker container) |
| AWS CLI | v2 |
| kubectl | v1.28.4 |
| eksctl | Latest |
| Terraform | Latest |
| Trivy | Latest |
| Helm | Latest (snap) |

---

## ☸️ Kubernetes Manifests

**Location**: `Kubernetes-Manifests-file/`

### Namespace
```yaml
namespace: three-tier
```

### Components:

#### 1. Backend (API)

**Files**: `Backend/deployment.yaml`, `Backend/service.yaml`

| Setting | Value |
|---------|-------|
| Replicas | 2 |
| Port | 3500 |
| Service Type | ClusterIP |
| Strategy | RollingUpdate (maxSurge: 1, maxUnavailable: 25%) |

**Probes Configuration**:
```yaml
livenessProbe:
  path: /healthz
  initialDelaySeconds: 2
  periodSeconds: 5

readinessProbe:
  path: /ready
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  path: /started
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30
```

#### 2. Frontend

**Files**: `Frontend/deployment.yaml`, `Frontend/service.yaml`

| Setting | Value |
|---------|-------|
| Replicas | 1 |
| Port | 3000 |
| Service Type | ClusterIP |
| Strategy | RollingUpdate |

#### 3. Database (MongoDB)

**Files**: 
- `Database/deployment.yaml`
- `Database/service.yaml`
- `Database/secrets.yaml`
- `Database/pv.yaml`
- `Database/pvc.yaml`

| Setting | Value |
|---------|-------|
| Image | mongo:4.4.6 |
| Port | 27017 |
| Service Name | mongodb-svc |
| Storage | 1Gi (PersistentVolume) |

**Secrets**:
```yaml
username: admin (base64: YWRtaW4=)
password: password123 (base64: cGFzc3dvcmQxMjM=)
```

#### 4. Ingress (ALB)

**File**: `ingress.yaml`

```yaml
IngressClassName: alb
Annotations:
  - alb.ingress.kubernetes.io/scheme: internet-facing
  - alb.ingress.kubernetes.io/target-type: ip
  - alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
```

**Routing Rules**:

| Path | Service | Port |
|------|---------|------|
| `/api` | api | 3500 |
| `/healthz` | api | 3500 |
| `/ready` | api | 3500 |
| `/started` | api | 3500 |
| `/` | frontend | 3000 |

---

## 🔐 Security Considerations (DevSecOps)

### Pipeline Security:
1. **SAST (Static Application Security Testing)**: SonarQube
2. **SCA (Software Composition Analysis)**: OWASP Dependency-Check
3. **Container Scanning**: Trivy (FS + Image)
4. **Secrets Management**: Kubernetes Secrets, Jenkins Credentials

### Infrastructure Security:
- AWS IAM Role with Instance Profile
- Security Groups with specific port access
- Private ECR for container images
- Kubernetes Secrets for sensitive data

### ⚠️ Security Issues to Address:

| Issue | ปัจจุบัน | แนะนำ |
|-------|---------|------|
| IAM Policy | AdministratorAccess | Least Privilege Principle |
| MongoDB Credentials | Hardcoded in secrets.yaml | External Secrets / Vault |
| Security Group | Open to 0.0.0.0/0 | Restrict to specific IPs |
| Ingress | HTTP only | HTTPS with TLS |

---

## 🛠️ เครื่องมือที่ใช้ในโปรเจค

| Category | Tools |
|----------|-------|
| **IaC** | Terraform |
| **Container Runtime** | Docker |
| **Container Orchestration** | Kubernetes (AWS EKS) |
| **CI/CD** | Jenkins |
| **GitOps** | ArgoCD |
| **Code Quality** | SonarQube |
| **Security Scanning** | OWASP Dependency-Check, Trivy |
| **Container Registry** | AWS ECR |
| **Monitoring** | Prometheus, Grafana |
| **Cloud Provider** | AWS |
| **Package Manager** | Helm |

---

## 🚀 Deployment Flow

```
Developer → Git Push → Jenkins Pipeline
                            │
                            ▼
                    ┌──────────────────┐
                    │  Code Checkout   │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  SonarQube Scan  │ ← SAST
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  OWASP DP-Check  │ ← SCA
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Trivy FS Scan   │ ← Vulnerability
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Docker Build    │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  Push to ECR     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Trivy Image Scan │ ← Container Scan
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │ Update K8s YAML  │ ← GitOps Trigger
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │  ArgoCD Sync     │
                    └────────┬─────────┘
                             │
                             ▼
                    ┌──────────────────┐
                    │   AWS EKS        │
                    └──────────────────┘
```

---

## 📝 สรุปสำหรับการประยุกต์ใช้ CI/CD Pipeline

### สิ่งที่ต้องเตรียม:
1. **AWS Account** พร้อม IAM credentials
2. **GitHub Repository** พร้อม credentials
3. **SonarQube Server** (หรือ SonarCloud)
4. **Jenkins Server** พร้อม plugins ที่จำเป็น
5. **AWS EKS Cluster** สำหรับ deployment
6. **AWS ECR** สำหรับเก็บ Docker images
7. **ArgoCD** สำหรับ GitOps (optional)

### Jenkins Plugins ที่จำเป็น:
- Pipeline
- Git
- SonarQube Scanner
- OWASP Dependency-Check
- Docker Pipeline
- AWS Credentials
- Kubernetes CLI

### Environment ที่ใช้:
- **Region**: us-east-1
- **Kubernetes Namespace**: three-tier
- **Node.js Version**: 14
- **Java Version**: 17

---

## 📚 References

- [Original Project README](original-project/README.md)
- [Medium Article](https://amanpathakdevops.medium.com/advanced-end-to-end-devsecops-kubernetes-three-tier-project-using-aws-eks-argocd-prometheus-fbbfdb956d1a)
- [GitHub Repository](https://github.com/AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project)

---

*เอกสารนี้สร้างขึ้นเพื่อใช้อ้างอิงสำหรับการพัฒนา CI/CD Pipeline ตามแนวทาง DevSecOps*
