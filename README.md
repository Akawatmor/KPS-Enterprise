![DevOps](https://img.shields.io/badge/DevOps-24292e?style=for-the-badge&logo=githubactions&logoColor=white)
![k3s](https://img.shields.io/badge/k3s-FFC61C?style=for-the-badge&logo=kubernetes&logoColor=black)
![Woodpecker CI](https://img.shields.io/badge/Woodpecker--CI-3E3E3E?style=for-the-badge&logo=woodpecker&logoColor=white)
![Canary Deploy](https://img.shields.io/badge/Canary--Deploy-FF8C00?style=for-the-badge&logo=aircanada&logoColor=white)
![Monitoring](https://img.shields.io/badge/Monitoring-00BFFF?style=for-the-badge&logo=prometheus&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-000000?style=for-the-badge&logo=aquasecurity&logoColor=white)
![Cosign](https://img.shields.io/badge/Cosign-5DADE2?style=for-the-badge&logo=sigstore&logoColor=white)
![k6](https://img.shields.io/badge/k6-7D4698?style=for-the-badge&logo=k6&logoColor=white)
![ZAP](https://img.shields.io/badge/ZAP-000000?style=for-the-badge&logo=owasp&logoColor=white)
![Postgres](https://img.shields.io/badge/Postgres-336791?style=for-the-badge&logo=postgresql&logoColor=white)

# KPS-Enterprise: TodoApp DevSecOps on K3s + Woodpecker CI/CD

ระบบ **Todo Application แบบ Full Stack** พร้อม Big Calendar UI deploy บน **K3s self-hosted cluster** (Proxmox VMs) และส่งมอบผ่าน **Woodpecker CI/CD** pipeline แบบ 10-stage ที่มี canary deploy, auto-rollback, security scanning และ monitoring ครบวงจร

## 📋 Project Overview (Phase 2)

- **Frontend**: Next.js 14 (TypeScript, standalone mode) — Big Calendar UI
- **Backend**: Go 1.25 (distroless image) — REST API + health/readiness endpoints
- **Database**: PostgreSQL 16 (StatefulSet + iSCSI PVC บน Synology NAS)
- **Container Orchestration**: K3s (self-hosted บน Proxmox VMs)
- **CI/CD**: Woodpecker CI — 10-stage DevSecOps pipeline
- **Container Registry**: Docker Hub (`akawatmor/todoapp-core`, `akawatmor/todoapp-web`)
- **Monitoring**: kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
- **Ingress**: Traefik (built-in K3s) + MetalLB (L2 mode)

## 👥 Team Members

1. Ratthatummanoon Kosasang - 6609612178
2. Akawat Moradsatian - 6609681231
3. Virtual Assistants - 0000011111

## 🌐 Live URLs

| Service | URL |
|---------|-----|
| Application | https://todoapp-kps.akawatmor.com |
| Woodpecker CI | https://woodpecker-kps.akawatmor.com |
| Grafana Dashboard | https://dashboard-kps.akawatmor.com |
| GitHub Repository | https://github.com/Akawatmor/KPS-Enterprise |

## 🏗️ Architecture

```
Internet → Cloudflare → Nginx (192.168.111.61) → MetalLB (192.168.111.240)
                                                       ↓
                                               Traefik (K3s built-in)
                                                  ↙         ↘
                                         todoapp-web    todoapp-core
                                         (Next.js×2)    (Go×2, canary+stable)
                                                              ↓
                                                        PostgreSQL (StatefulSet)
                                                        iSCSI PVC → Synology NAS

K3s Cluster (Proxmox VMs):
  VM1 192.168.1.142 — K3s Server + Traefik + Woodpecker Server
  VM2 192.168.1.143 — Worker (App pods, label: role=app)
  VM3 192.168.1.144 — Worker (CI pods, taint: dedicated=ci:NoSchedule)
```

## 🚀 CI/CD Pipeline (10 Stages)

```
git push main
  │
  ├── Stage 0  Pre-flight      Gitleaks · Hadolint · kube-score · OPA conftest
  ├── Stage 1  Quality Gates   backend (go test · gosec · govulncheck) + frontend (type-check · jest) ← parallel
  ├── Stage 2  Integration     go test -tags=integration กับ Postgres service
  ├── Stage 3  Build & Push    build-push-core + build-push-web ← parallel, tag = commit SHA
  ├── Stage 4  Security Scan   Cosign sign · SBOM CycloneDX · Trivy (HIGH/CRITICAL block)
  ├── Stage 5  DB Ops          pg_dump backup + migration test ← parallel
  ├── Stage 6  Canary Deploy   apply manifests · monitoring stack · canary 10%
  ├── Stage 7  Canary Analysis 160 HTTP requests + Prometheus metrics (5xx, p95 latency)
  ├── Stage 8  Promote/Rollback promote 100% หากผ่าน — auto-rollback + email หากไม่ผ่าน
  ├── Stage 9  Verification    smoke test · create release tag (semantic versioning)
  ├── Stage 9b Post-deploy     k6 load test (20VU 60s) · DAST ZAP baseline scan
  └── Stage 10 Notification    HTML email: success / rollback / failure
```

## 🛠️ Technology Stack

### Infrastructure
| Component | Technology |
|-----------|-----------|
| Cluster | K3s v1.31 (single binary, ~512MB RAM) |
| VMs | Proxmox VE (3 VMs: 1 master + 2 workers) |
| Ingress | Traefik (K3s built-in) + IngressRoute CRD |
| Load Balancer | MetalLB L2 mode (192.168.111.240–250) |
| Storage | iSCSI PVC → Synology NAS (hardware RAID) |
| DNS/TLS | Cloudflare + TrueDDNS + Nginx origin |

### Application
| Component | Technology |
|-----------|-----------|
| Frontend | Next.js 14, TypeScript, output: standalone |
| Backend | Go 1.25, distroless/static-debian12:nonroot |
| Database | PostgreSQL 16-alpine (StatefulSet) |
| Deploy Strategy | RollingUpdate (maxUnavailable: 0) |

### CI/CD & Security
| Tool | Purpose |
|------|---------|
| Woodpecker CI | Pipeline orchestration (YAML-based) |
| Gitleaks | Secret scanning |
| Hadolint + kube-score | Dockerfile + K8s manifest lint |
| conftest (OPA) | Policy-as-code checks |
| gosec + govulncheck | Go SAST + dependency vulnerability |
| Trivy | Container image scanning (HIGH/CRITICAL block) |
| Cosign | Image signing (SBOM attach) |
| k6 | Load testing (performance baseline) |
| OWASP ZAP | DAST baseline scan post-deploy |

### Monitoring
| Component | Details |
|-----------|---------|
| Prometheus | scrapes todoapp + Traefik via ServiceMonitor |
| Grafana | dashboard-kps.akawatmor.com |
| Alertmanager | AlertmanagerConfig CR → email alert |
| PrometheusRule | alert rules สำหรับ error rate, latency, pod health |

## 📦 Repository Structure

```
KPS-Enterprise/
├── .woodpecker/
│   ├── main-push.yml          # Production pipeline (10 stages)
│   ├── develop-push.yml       # Dev pipeline (fast feedback)
│   └── tag-release.yml        # Release tagging pipeline
├── src/phase2-final/
│   ├── backend/               # Go 1.25 REST API
│   ├── frontend/              # Next.js 14 Big Calendar UI
│   ├── k8s/                   # Kubernetes manifests
│   ├── monitoring/            # Prometheus stack + Alertmanager
│   └── scripts/
│       ├── k6/load-test.js    # k6 load test (20VU, 60s)
│       └── release/release-plan.sh  # Semantic versioning
├── document/
│   ├── phase1/                # Phase 1 analysis docs
│   └── phase2/                # Phase 2 reports, guides, change log
│       ├── report.md          # Final project report
│       ├── delivers.md        # DevOps deliverables analysis
│       ├── reqchange.md       # Requirement change (frontend quality gate)
│       ├── add-pipeline.md    # Pipeline improvement plan + status
│       └── changesmall.md     # Small changes log + root cause analysis
├── policies/security.rego     # OPA policy
├── original-project/          # Phase 1 original source (archived)
└── README.md
```

## 🔐 Security Features (DevSecOps)

Pipeline มี security gate 4 ชั้น:

1. **Pre-commit layer** — Gitleaks ตรวจ secret ทุก push
2. **Code layer** — gosec (SAST) + govulncheck (dependency CVE) สำหรับ Go
3. **Image layer** — Trivy scan HIGH/CRITICAL block + Cosign sign + SBOM CycloneDX
4. **Runtime layer** — DAST ZAP baseline scan หลัง deploy + NetworkPolicy ใน cluster

## 📊 Project Status

### Phase 2 — ✅ Complete

| Component | Status | Detail |
|-----------|--------|--------|
| Application | ✅ Live | https://todoapp-kps.akawatmor.com |
| CI/CD Pipeline | ✅ Active | 10-stage Woodpecker pipeline |
| Canary Deploy | ✅ Verified | 0/160 errors at 90/10 weight |
| Auto-rollback | ✅ Implemented | triggers on error rate >5% or p95 >1.5s |
| Monitoring | ✅ Deployed | Prometheus + Grafana + Alertmanager |
| Security Scan | ✅ Full | 4-layer DevSecOps (Gitleaks/gosec/Trivy/ZAP) |
| Load Test | ✅ Verified | k6: p95=44ms, 0% errors (20VU, 60s) |
| Release Tag | ✅ Auto | semantic versioning บน merge |
| Feature Flags | ✅ Live | ConfigMap-based (FEATURE_DARK_MODE etc.) |
| Email Notify | ✅ Active | HTML success/rollback/failure |

## 🚀 Quick Start (Local Development)

```bash
# Clone
git clone https://github.com/Akawatmor/KPS-Enterprise.git
cd KPS-Enterprise

# Run locally with Docker Compose (SQLite mode)
cd src/phase2-final
docker compose up -d

# Open
open http://localhost:3000
```

## 🔧 Cluster Operations

```bash
# ดู pods ทั้งหมด
kubectl get pods -n todoapp

# toggle feature flag (no rebuild needed)
kubectl edit cm todoapp-config -n todoapp
kubectl rollout restart deployment -n todoapp

# manual rollback
kubectl rollout undo deployment/todoapp-core-stable -n todoapp

# ดู pipeline
open https://woodpecker-kps.akawatmor.com
```

## 📚 Documentation

| เอกสาร | คำอธิบาย |
|--------|---------|
| [document/phase2/report.md](document/phase2/report.md) | รายงานสรุปโครงงาน Phase 2 |
| [document/phase2/delivers.md](document/phase2/delivers.md) | DevOps deliverables + tool analysis |
| [document/phase2/reqchange.md](document/phase2/reqchange.md) | Requirement change: frontend quality gate |
| [document/phase2/add-pipeline.md](document/phase2/add-pipeline.md) | Pipeline improvement plan + สถานะ |
| [document/phase2/changesmall.md](document/phase2/changesmall.md) | Small changes log + root cause analysis |
| [document/phase2/guide-new.md](document/phase2/guide-new.md) | K3s cluster setup guide (step-by-step) |

## 📄 License

This project is for educational purposes as part of the Thammasat University curriculum.

---

## 📦 Phase 1 Summary (Archived)

> Phase 1 ศึกษาและปรับ original project (Node.js + MongoDB + Jenkins + AWS EKS) ให้ทำงานได้ใน AWS Learner Lab  
> Phase 2 ย้ายมาใช้ K3s self-hosted + Woodpecker CI/CD ทั้งหมด (ดู [document/phase2/](document/phase2/) สำหรับรายละเอียด)

| Component | Phase 1 | Phase 2 |
|-----------|---------|---------|
| Frontend | ReactJS + Material-UI | Next.js 14 (TypeScript) |
| Backend | Node.js + Express.js | Go 1.25 (distroless) |
| Database | MongoDB | PostgreSQL 16 |
| Cluster | AWS EKS (Learner Lab) | K3s self-hosted (Proxmox) |
| CI/CD | Jenkins + Groovy pipeline | Woodpecker CI + YAML pipeline |
| Security | SonarQube + OWASP + Trivy | Gitleaks + gosec + Trivy + Cosign + ZAP |
| Infra-as-code | Terraform (EC2 + EKS) | K8s manifests + HelmChart |
| Ingress | AWS ALB | Traefik + MetalLB |
| Monitoring | — | Prometheus + Grafana + Alertmanager |

Phase 1 source code และ documents ยังคงอยู่ใน:
- `original-project/` — original Jenkins/EKS source
- `document/phase1/` — Phase 1 analysis, architecture, and implementation docs
