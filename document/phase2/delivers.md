# 📦 DevOps Pipeline Deliverables — KPS-Enterprise Phase 2

> **เอกสารนี้อธิบาย:** ประโยชน์ที่ได้รับจาก DevOps Pipeline, เหตุผลในการเลือกใช้เครื่องมือแต่ละตัว,  
> การออกแบบสถาปัตยกรรม, การรับมือเมื่อเกิดข้อผิดพลาด และภาพรวม Flow การทำงานของระบบ

---

## สารบัญ

1. [ประโยชน์ที่ได้จาก DevOps Pipeline](#1-ประโยชน์ที่ได้จาก-devops-pipeline)
2. [ทำไมถึงเลือก Woodpecker แทน Jenkins](#2-ทำไมถึงเลือก-woodpecker-แทน-jenkins)
3. [การวิเคราะห์เครื่องมือแต่ละตัว](#3-การวิเคราะห์เครื่องมือแต่ละตัว)
4. [เหตุผลในการออกแบบสถาปัตยกรรม](#4-เหตุผลในการออกแบบสถาปัตยกรรม)
5. [การรับมือเมื่อเกิดความผิดพลาด](#5-การรับมือเมื่อเกิดความผิดพลาด)
6. [โฟลว์การทำงานโดยภาพรวมของระบบ](#6-โฟลว์การทำงานโดยภาพรวมของระบบ)

---

## 1. ประโยชน์ที่ได้จาก DevOps Pipeline

### 1.1 ก่อน vs หลัง มี Pipeline

| หัวข้อ | ก่อนมี Pipeline (Manual) | หลังมี Pipeline (Woodpecker) |
|--------|--------------------------|------------------------------|
| **การ Deploy** | SSH เข้าเครื่อง → `docker build` → `kubectl apply` ด้วยมือ | `git push` → ระบบทำให้อัตโนมัติ |
| **เวลา Deploy** | 15–30 นาที (ต้องทำเองทุกขั้น) | 3–8 นาที (อัตโนมัติ) |
| **ความผิดพลาด** | Human error สูง (ลืม step, พิมพ์ผิด) | Reproducible ทุกครั้ง |
| **การทดสอบ** | มักข้ามเพราะเสียเวลา | บังคับผ่านก่อน deploy ได้ |
| **Rollback** | จำ version เก่าไม่ได้, ยาก | `kubectl rollout undo` ทันที |
| **Visibility** | ไม่รู้ว่าใคร deploy อะไร เมื่อไหร่ | ดูได้จาก Woodpecker UI + Git log |
| **Security Scan** | ไม่มี | `go vet` + `go test` บังคับผ่านก่อน build |
| **Notification** | ไม่รู้ว่า deploy สำเร็จหรือล้มเหลว | แจ้ง Email ทันที |

### 1.2 สิ่งที่ Pipeline ทำให้ได้โดยตรง

```
git push origin main
    │
    ├── ✅ โค้ดผ่าน unit test ทุก function (`go test ./... -v -count=1`)
    ├── ✅ go vet ผ่าน (ไม่มี compile error)
    ├── ✅ Docker image build สำเร็จ (backend + frontend)
    ├── ✅ Image push ไป Docker Hub ด้วย commit SHA tag (immutable)
    ├── ✅ Rolling deploy บน K3s (zero downtime)
    ├── ✅ Kubernetes health check (/healthz, /readyz) ผ่าน
    └── ✅ Email notification ส่งถึงผู้รับที่กำหนด
```

### 1.3 ตัวชี้วัดที่ปรับปรุง (DevOps Metrics)

| Metric | ค่า (ประมาณ) | ความหมาย |
|--------|-------------|----------|
| **Lead Time for Change** | < 10 นาที | เวลาจาก commit ถึง production |
| **Deployment Frequency** | หลายครั้ง/วัน | ทำได้บ่อยขึ้นเพราะมั่นใจมากขึ้น |
| **Mean Time to Recovery** | < 5 นาที | `kubectl rollout undo` ทันที |
| **Change Failure Rate** | ลดลง | เพราะ test บังคับก่อน deploy |

---

## 2. ทำไมถึงเลือก Woodpecker แทน Jenkins

### 2.1 เปรียบเทียบโดยตรง

| มิติ | Woodpecker CI | Jenkins | GitHub Actions |
|------|:---:|:---:|:---:|
| **License** | Apache 2.0 (Free) | MIT (Free) | Proprietary (Free tier) |
| **Self-hosted** | ✅ ใช่ | ✅ ใช่ | ❌ ต้องใช้ GitHub Cloud |
| **Kubernetes-native** | ✅ Native (backend: k8s) | ⚠️ ต้อง plugin | ❌ ไม่รองรับ |
| **GitHub integration** | ✅ First-class OAuth | ⚠️ Plugin ที่ไม่สมบูรณ์ | ✅ Native |
| **Pipeline syntax** | YAML (เรียบง่าย) | Groovy/Jenkinsfile (ซับซ้อน) | YAML (ซับซ้อน) |
| **RAM เมื่อ idle** | ~64 MB | ~512 MB – 1 GB | N/A |
| **Setup time** | 15 นาที | 1–2 ชั่วโมง | 0 (แต่ต้องใช้ GitHub) |
| **Docker build in K8s** | ✅ Plugin พร้อม | ⚠️ ต้อง configure DinD | ❌ ไม่รองรับ |
| **Plugin ecosystem** | กำลังเติบโต | สมบูรณ์มาก | สมบูรณ์มาก |
| **Code privacy** | ✅ อยู่ใน self-hosted | ✅ อยู่ใน self-hosted | ❌ code ผ่าน GitHub |
| **Secret management** | UI + Repo-level | Credentials store | GitHub Secrets |

### 2.2 เหตุผลหลักที่เลือก Woodpecker

#### เหตุผล 1: Kubernetes-native backend
```
Jenkins + K8s:
  Jenkins Master → สั่ง Pod ผ่าน Kubernetes Plugin
  → ต้องตั้งค่า Pod template ใน Jenkins UI ซับซ้อน
  → Credential management คนละที่กับ K8s Secrets

Woodpecker + K8s:
  Agent backend = "kubernetes" → สร้าง K8s Jobs โดยตรง
  → ใช้ K8s RBAC ที่มีอยู่แล้ว
  → Pipeline container = K8s Pod → ใช้ resource limits/requests ของ K8s
```

#### เหตุผล 2: GitHub OAuth integration แบบ first-class
```yaml
# Woodpecker config - เพียงแค่นี้
WOODPECKER_GITHUB: "true"
WOODPECKER_GITHUB_CLIENT: "<github_oauth_client_id>"
WOODPECKER_GITHUB_SECRET: "<github_oauth_secret>"
# → webhook สร้างอัตโนมัติเมื่อ Activate repo ใน Woodpecker UI
# → login ผ่าน GitHub OAuth
```

Jenkins + GitHub ต้องการ plugin หลายตัว (GitHub Plugin, Generic Webhook Trigger, GitHub OAuth), configure หลายหน้าจอ

#### เหตุผล 3: Resource constraint
เราทำงานบน VM ที่ RAM จำกัด (12 GB สำหรับ VM1 ที่รัน K3s server + App pods):
- Jenkins idle: ~512 MB RAM → กิน budget VM ไปมาก
- Woodpecker Server idle: ~64 MB RAM → เหลือ RAM ให้ App pods

#### เหตุผล 4: Pipeline-as-Code ที่อ่านง่าย
```yaml
# Woodpecker (.woodpecker.yml) — ชัดเจน อ่านเข้าใจได้ทันที
when:
  event: push
  branch: main

steps:
  - name: test-backend
    image: golang:1.25-alpine
    commands:
      - cd src/phase2-final/backend
      - go mod download
      - go vet ./...
      - go test ./... -v -count=1

  - name: build-push-core
    image: woodpeckerci/plugin-docker-buildx
    settings:
      repo: akawatmor/todoapp-core
      tags: ["${CI_COMMIT_SHA:0:7}", "latest"]
      username:
        from_secret: DOCKER_USERNAME
      password:
        from_secret: DOCKER_PASSWORD
```

```groovy
// Jenkins Groovy — ต้องเรียนรู้ syntax เพิ่ม
pipeline {
  agent { kubernetes { yaml """...""" } }
  stages {
    stage('Test') {
      steps {
        container('golang') {
          sh 'go test ./...'
        }
      }
    }
  }
}
```

### 2.3 ข้อจำกัดของ Woodpecker และวิธีรับมือ

| ข้อจำกัด | วิธีรับมือ |
|----------|-----------|
| Plugin น้อยกว่า Jenkins | ใช้ Docker image โดยตรง (`image: bitnami/kubectl`) |
| ไม่มี built-in test report | Export JUnit XML → เก็บใน artifact |
| Database เป็น SQLite (default) | เพียงพอสำหรับ self-hosted; upgrade เป็น PostgreSQL ได้ |
| Parallel pipelines จำกัด | ตั้ง `WOODPECKER_MAX_PROCS` บน Agent |

---

## 3. การวิเคราะห์เครื่องมือแต่ละตัว

### 3.1 K3s — Lightweight Kubernetes

**บทบาท:** Container orchestration platform

**ทำไมเลือก K3s แทน full Kubernetes:**
```
Full K8s (kubeadm):
  - etcd แยก: 512 MB+ RAM
  - kube-apiserver: 512 MB+ RAM
  - รวม control plane: 2–3 GB RAM
  - Setup: 2–4 ชั่วโมง

K3s:
  - Single binary รวมทุกอย่าง
  - RAM สำหรับ control plane: ~512 MB
  - รวม Traefik + CoreDNS + Flannel ไว้ในตัว
  - Setup: 15 นาที
  - Production-ready (used by Rancher, SUSE)
```

**สิ่งที่ K3s จัดการให้:**
- Pod scheduling, self-healing (restart crashed pods)
- Rolling updates (zero-downtime deploys)
- Service discovery (DNS ภายใน cluster)
- ConfigMap / Secret management
- Resource limits enforcement
- Node taint/toleration สำหรับ workload isolation

### 3.2 Traefik — Ingress Controller

**บทบาท:** HTTP reverse proxy + load balancer ภายใน Kubernetes

**ทำไมใช้ Traefik แทน Nginx Ingress:**

| ด้าน | Traefik | Nginx Ingress |
|------|---------|---------------|
| รวมใน K3s | ✅ ใช่ (ไม่ต้องติดตั้งเพิ่ม) | ❌ ต้องติดตั้งแยก |
| Dynamic config | ✅ อัปเดตโดยไม่ restart | ❌ ต้อง reload |
| K8s CRD | ✅ IngressRoute (ยืดหยุ่นกว่า) | ⚠️ Ingress + Annotations |
| Dashboard | ✅ Built-in | ❌ ต้องติดตั้งเอง |
| Middleware | ✅ Rate limit, auth, headers (built-in) | ❌ ต้อง configure nginx.conf |

**Middleware ที่ใช้ในระบบนี้:**
```
cors-app        → ตั้ง CORS headers สำหรับ API
security-headers → X-Frame-Options, X-XSS-Protection ฯลฯ
rate-limit      → จำกัด 30 req/s (ป้องกัน DDoS)
compress        → gzip compression
```

### 3.3 MetalLB — Bare Metal Load Balancer

**บทบาท:** ให้ Kubernetes Service Type=LoadBalancer ทำงานได้ใน on-premise

**ปัญหาที่แก้:**
```
ปกติ: kubectl expose deployment ... --type=LoadBalancer
→ รอ External IP ... <pending>  ← stuck ตลอดไปถ้าไม่มี cloud provider

MetalLB แก้ด้วย:
→ ARP announcement ใน LAN: "IP 192.168.111.200 อยู่ที่ MAC ของ VM1"
→ Traefik ได้รับ External IP: 192.168.111.200
→ Nginx → 192.168.111.200 → Traefik → Pods ✅
```

**Layer 2 mode (ที่เลือกใช้):**
- Speaker pod บน แต่ละ node ทำ ARP
- Node ที่ "เป็นเจ้าของ" IP จะรับ traffic ทั้งหมดก่อน แล้วกระจายต่อผ่าน kube-proxy
- เหมาะกับ home lab / small cluster ที่ไม่มี BGP router

### 3.4 SQLite บน local-path PVC

**บทบาท:** Embedded database สำหรับ Todo application (ไม่ต้องการ DB server แยก)

**ทำไมใช้ SQLite แทน MongoDB (Phase 1) / PostgreSQL:**

| ด้าน | SQLite (Phase 2) | MongoDB (Phase 1) | PostgreSQL |
|------|:---:|:---:|:---:|
| DB server แยก | ❌ ไม่ต้องมี | ✅ ต้องการ | ✅ ต้องการ |
| RAM overhead | ~0 MB | ~256 MB | ~64 MB |
| Setup | ไม่ต้อง setup | ต้องติดตั้ง + init | ต้องติดตั้ง + init |
| Concurrent writes | ⚠️ Single writer | ✅ | ✅ |
| เหมาะกับ | personal app, low traffic | high-write, distributed | structured, ACID |

**ทำไม local-path PVC แทน hostPath:**
```
hostPath:
  ข้อมูลอยู่ที่ directory บน node ที่ pod รันอยู่
  → pod schedule ไป node อื่น → ข้อมูลหาย
  → ไม่มี StorageClass lifecycle management

local-path PVC (K3s built-in provisioner):
  K3s สร้าง directory ให้อัตโนมัติ (/var/lib/rancher/k3s/...)
  → PVC lifecycle ผูกกับ namespace/pod
  → ลบ PVC → K3s ลบ data ให้อัตโนมัติ
  → รองรับ ReadWriteOnce (SQLite ต้องการ single writer)
```

**Strategy: Recreate แทน RollingUpdate:**
```
SQLite = single writer → PVC = ReadWriteOnce
RollingUpdate จะมี 2 pods พยายาม mount PVC เดียวกัน → Error!

Recreate strategy:
  T=0: ลบ pod เก่าก่อน (brief downtime ~5 วินาที)
  T=1: สร้าง pod ใหม่ → mount PVC สำเร็จ
  → ยอมรับ downtime สั้น ๆ เพื่อ data consistency
```

### 3.5 Go 1.25 Backend

**บทบาท:** REST API server พร้อม GitHub OAuth, CalDAV sync, reminder system

**ทำไมใช้ Go แทน Node.js (Phase 1):**

| ด้าน | Go 1.25 | Node.js (Phase 1) |
|------|:---:|:---:|
| Container size | ~6 MB (distroless) | ~200 MB (node:alpine) |
| Memory usage | ~20–30 MB idle | ~80–150 MB idle |
| CPU (concurrent req) | ✅ goroutines (lightweight) | ⚠️ Event loop (single thread) |
| Cold start | < 50 ms | ~300–500 ms |
| Static binary | ✅ ไม่ต้อง runtime | ❌ ต้องการ Node runtime |
| Built-in HTTP routing | ✅ Go 1.22+ ServeMux | ❌ ต้องใช้ Express |

**ทำไมใช้ distroless image:**
```
alpine image:
  ✓ เล็กกว่า ubuntu (~5 MB)
  ✗ มี shell (sh), package manager (apk)
  ✗ มี attack surface

distroless/static-debian12:nonroot:
  ✓ ไม่มี shell เลย
  ✓ ไม่มี package manager
  ✓ รัน process ด้วย user nonroot (UID 65532)
  ✓ มีแค่ CA certificates + timezone data ที่จำเป็น
  → CVE น้อยลง, attack surface เล็กที่สุด
```

### 3.6 Next.js 14 Frontend

**บทบาท:** React-based frontend สำหรับ Todo UI

**ทำไม `output: "standalone"`:**
```
Next.js standalone mode:
  - bundle dependencies เข้าไปใน .next/standalone/
  - ไม่ต้อง node_modules ใน production container
  - Container size ลดจาก ~400 MB → ~120 MB
  - รัน: node server.js (ไม่ต้อง next start)
```

**Multi-stage Dockerfile ทำไม 3 stages:**
```
Stage 1 (deps):    ติดตั้ง production dependencies เท่านั้น
Stage 2 (builder): ติดตั้ง dev dependencies + build Next.js
Stage 3 (runner):  copy เฉพาะ .next/standalone + static
→ Final image ไม่มี node_modules ของ dev tools
→ ไม่มี source code อยู่ใน production image
```

### 3.7 Docker Hub

**บทบาท:** Container image registry

**ทำไม Docker Hub แทน self-hosted registry:**
- Infrastructure นี้มีอยู่แล้ว ไม่ต้องดูแลเพิ่ม
- Free tier เพียงพอสำหรับ project ขนาดนี้
- Pull จาก K3s nodes ง่ายกว่า (ไม่ต้อง configure insecure registry)
- หาก self-hosted ต้องดูแล Harbor/Gitea registry เพิ่มอีก VM

**Image tagging strategy:**
```
:latest          → ใช้สำหรับ human reference เท่านั้น
:a1b2c3d         → commit SHA (7 chars) → immutable, traceable
:main            → branch tag → ชี้ไปยัง latest ของ branch นั้น
```

### 3.8 Cloudflare + Nginx + TrueDDNS

**บทบาท:** Public access layer สำหรับ home lab

**ทำไมต้องมี Nginx ทั้งที่มี Traefik แล้ว:**
```
โฟลว์ Traffic:
Internet → Cloudflare (TLS #1) → Nginx (TLS #2) → Traefik (plaintext) → Pods

Cloudflare: รับ request จาก Internet, DDoS protection, TLS termination
Nginx:      รับจาก Cloudflare ผ่าน origin cert, forward ไป MetalLB (port 80)
Traefik:    routing ภายใน K3s cluster

ทำไมไม่ตัด Nginx ออก?
- Nginx มีอยู่แล้วในระบบ ใช้กับ service อื่นด้วย
- Nginx รับ HTTPS จาก CF แล้วส่ง HTTP ไป MetalLB (Traefik ไม่ต้องมี cert)
- มี firewall rule บน router: port 56260 → Nginx เท่านั้น
```

---

## 4. เหตุผลในการออกแบบสถาปัตยกรรม

### 4.1 ทำไม 3 VM แยก roles

```
VM1 (k3s-main)   — Control plane + App workloads
VM2 (k3s-worker) — Worker node (รองรับ app scale-out ในอนาคต)
VM3 (k3s-ci)     — Dedicated CI node (tainted: dedicated=ci:NoSchedule)
```

**เหตุผลที่แยก CI node ออกมา:**
- CI pipeline รัน Docker build → CPU spike สูง (100% ชั่วคราว)
- ถ้า CI รันปนกับ App pods → App latency พุ่งขึ้นระหว่าง build
- Taint บังคับให้ App pods ไม่ไปรันบน VM3
- CI Agent มี toleration → ไปรันบน VM3 ได้เท่านั้น

**ทำไม App pods schedule บน worker nodes (VM1 + VM2):**
- `todoapp-core` มี `nodeAffinity: preferredDuringScheduling` → prefer worker nodes
- `todoapp-web` มี `topologySpreadConstraints` → กระจาย 2 replicas ใน 2 nodes
- SQLite PVC ใช้ `local-path` → K3s สร้าง data directory บน node ที่ core pod รันอยู่
- VM3 taint `dedicated=ci:NoSchedule` → app pods ไม่ไปรันบน CI node

### 4.2 ทำไม Rolling Update (maxUnavailable=0)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # สร้าง pod ใหม่ได้ +1 เกิน desired
    maxUnavailable: 0  # ห้ามมี pod unavailable ระหว่าง deploy

ผลลัพธ์:
  T=0: backend pods [old-1, old-2]              (2 running)
  T=1: backend pods [old-1, old-2, new-1]       (3 running, new-1 starting)
  T=2: new-1 ReadinessProbe ผ่าน → ลบ old-1
  T=3: backend pods [old-2, new-1, new-2]       (new-2 starting)
  T=4: new-2 ReadinessProbe ผ่าน → ลบ old-2
  T=5: backend pods [new-1, new-2]              (deploy complete)
  
→ User ไม่รู้สึกถึง downtime เลย
```

### 4.3 ทำไม ReadinessProbe + LivenessProbe ต่างกัน

```
ReadinessProbe (initialDelaySeconds: 2, periodSeconds: 5):
  → ถามว่า "pod พร้อมรับ traffic ไหม?"
  → ถ้าไม่ผ่าน → K8s หยุดส่ง traffic ไปยัง pod นั้น
  → ใช้ detect: startup ยังไม่เสร็จ, DB connection ยังไม่พร้อม

LivenessProbe (initialDelaySeconds: 5, periodSeconds: 10):
  → ถามว่า "pod ยัง alive ไหม?"
  → ถ้าไม่ผ่าน 3 ครั้ง → K8s restart pod
  → ใช้ detect: deadlock, memory leak ที่ทำให้ HTTP hang

ไม่ใช้ probe เดียวกัน เพราะ:
  - Liveness strict เกินไป → restart pod ระหว่าง startup (พัง)
  - Readiness หละหลวมเกินไป → ส่ง traffic ไปยัง pod ที่ยังไม่พร้อม
```

### 4.4 ทำไม Woodpecker Agent ใช้ Kubernetes backend แทน Docker

```
Docker backend:
  Agent รัน pipeline containers ผ่าน Docker socket
  → ต้องมี Docker daemon บน VM3
  → ต้อง mount /var/run/docker.sock (security risk)
  → resource ไม่ถูก K8s จัดการ

Kubernetes backend:
  Agent สร้าง K8s Jobs/Pods สำหรับแต่ละ pipeline step
  → ใช้ K8s resource limits/requests ได้เต็มที่
  → K8s จัดการ lifecycle ของ pipeline pods อัตโนมัติ
  → Audit log จาก K8s events ด้วย
  → ไม่ต้องมี Docker daemon บน VM3
```

### 4.5 ทำไม CI_COMMIT_SHA แทน :latest tag

```
ปัญหาของ :latest:
  push :latest → K8s imagePullPolicy: IfNotPresent → ไม่ pull ใหม่
  → pod ยังรัน image เก่าอยู่ทั้งที่ push ใหม่ไปแล้ว

ปัญหาของ :latest เรื่อง rollback:
  latest เมื่อ 3 วันที่แล้ว ≠ latest เมื่อวาน
  → rollback กลับไปเวอร์ชันอะไร?

CI_COMMIT_SHA:
  image: akawatmor/todoapp-core:a1b2c3d   (unique ทุก commit)
  → K8s ต้อง pull เสมอ (tag ใหม่ = image ใหม่)
  → rollback: kubectl rollout undo → K8s จำ SHA เก่าได้
  → audit trail: ดูได้ว่า production รัน commit อะไร
```

---

## 5. การรับมือเมื่อเกิดความผิดพลาด

### 5.1 Incident Response Matrix

| สถานการณ์ | ตรวจพบอย่างไร | ผลกระทบ | วิธีแก้ไข | เวลา Recovery |
|-----------|--------------|---------|-----------|--------------|
| Backend pod crash | `kubectl get pods` แสดง CrashLoopBackOff | API ล่ม ชั่วคราว | K8s restart อัตโนมัติ / `kubectl rollout undo` | < 1 นาที |
| Deploy ใหม่มี bug | Health check `/healthz` ล้มเหลวหลัง deploy | API ล่มบางส่วน | `kubectl rollout undo deployment/todoapp-core -n todoapp` | < 2 นาที |
| SQLite PVC corrupted | pod ไม่ start, log แสดง DB error | Backend ล่ม | restore จาก backup หรือ recreate PVC | 10 นาที |
| VM1 reboot | Cluster control plane ล่ม | ทุก service ล่ม | K3s auto-start หลัง boot | 3–5 นาที |
| Woodpecker pipeline fail | Discord notification + Woodpecker UI | Code ไม่ deploy | แก้ bug → push ใหม่; หรือ skip step ที่ fail | ขึ้นกับ bug |
| Docker Hub rate limit | Build log: "toomanyrequests" | Pipeline ล้มเหลว | ใช้ `docker-password` ใน imagePullSecrets; retry | 10 นาที |
| MetalLB IP ถูกชิง | Traefik ไม่ได้ IP | ทุก service ล่ม | ตรวจ ARP table; restart MetalLB speaker | 5 นาที |

### 5.2 การ Rollback แต่ละ Layer

#### Layer 1: Application (K8s Rollback)
```bash
# ดู history
kubectl rollout history deployment/todoapp-core -n todoapp
kubectl rollout history deployment/todoapp-web  -n todoapp

# rollback ไป revision ก่อนหน้า
kubectl rollout undo deployment/todoapp-core -n todoapp
kubectl rollout undo deployment/todoapp-web  -n todoapp

# ตรวจสอบ
kubectl rollout status deployment/todoapp-core -n todoapp
```

#### Layer 2: Database (SQLite Recovery)
```bash
# SQLite file อยู่ใน PVC ที่ /var/lib/todoapp/todoapp.db ใน pod

# ── Option A: copy backup ออกมาก่อนที่ PVC จะเสีย ──
kubectl exec -n todoapp deployment/todoapp-core -- \
  cp /var/lib/todoapp/todoapp.db /tmp/todoapp.db.backup
kubectl cp todoapp/<pod-name>:/tmp/todoapp.db.backup ./todoapp.db.backup

# ── Option B: restore กลับเข้าไป ──
kubectl cp ./todoapp.db.backup todoapp/<pod-name>:/var/lib/todoapp/todoapp.db
kubectl rollout restart deployment/todoapp-core -n todoapp
```

#### Layer 3: Infrastructure (Node Recovery)
```bash
# ── VM1 crash → reboot ──
# K3s เริ่มอัตโนมัติหลัง boot (systemd unit)
# ตรวจสอบหลัง reboot:
kubectl get nodes
kubectl get pods -n todoapp

# ── VM3 (CI) crash ──
# ไม่กระทบ App — เฉพาะ pipeline ที่กำลังรันจะ fail
# Woodpecker Agent restart เอง (Deployment)
```

### 5.3 การ Debug Pipeline ที่ Fail

```bash
# ── 1. ดู log ใน Woodpecker UI ──
# https://ci.yourdomain.com → repo → pipeline → click ที่ step ที่ fail

# ── 2. ดู K8s events ระหว่าง pipeline รัน ──
kubectl get events -n woodpecker --sort-by='.lastTimestamp' | tail -20

# ── 3. ดู log ของ Agent ──
kubectl logs -n woodpecker deployment/woodpecker-agent --tail=50

# ── 4. ทดสอบ pipeline step แบบ manual ──
# เข้า container image เดียวกับที่ pipeline ใช้
docker run --rm -it golang:1.22-alpine sh
cd /workspace
go test ./...

# ── 5. Retry pipeline ──
# Woodpecker UI → pipeline → "Restart pipeline" button
```

### 5.4 Monitoring และ Alerting

```bash
# ── Cluster-level monitoring ──
kubectl top nodes                           # CPU/RAM ของแต่ละ node
kubectl top pods -n todoapp                 # CPU/RAM ของแต่ละ pod

# ── ดู events ที่ผิดปกติ ──
kubectl get events -A --field-selector type=Warning

# ── ดู pod ที่ restart บ่อย ──
kubectl get pods -n todoapp -o wide

# ── ตรวจ storage ──
df -h                                       # disk บน VM1
sudo iscsiadm -m session -P 3 | grep -E "disk|State"

# ── ตรวจ cluster health ──
kubectl get componentstatuses 2>/dev/null || \
  kubectl get --raw='/healthz' | cat
```

### 5.5 การป้องกันไม่ให้เกิดปัญหา (Prevention)

| มาตรการ | รายละเอียด | บังคับใน Pipeline |
|---------|-----------|------------------|
| Unit Tests | `go test ./...` + `go vet` | ✅ step: test-backend |
| Resource Limits | CPU/RAM limits บน K8s pods | ✅ ใน deployment YAML |
| Readiness Probe | ไม่ส่ง traffic ไปยัง pod ที่ไม่พร้อม | ✅ `/readyz` endpoint |
| Liveness Probe | restart pod ถ้า hang | ✅ `/healthz` endpoint |
| Immutable Tags | ใช้ commit SHA แทน `:latest` | ✅ step: build-push-core/web |
| SQLite backup | copy file ออกจาก PVC เป็นระยะ | ⚠️ manual หรือ CronJob |

---

## 6. โฟลว์การทำงานโดยภาพรวมของระบบ

### 6.1 User Request Flow (Runtime)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER REQUEST FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

[User Browser]
    │  HTTPS GET https://todo.yourdomain.com/
    ▼
[Cloudflare Edge Node]
    │  • TLS termination (Cloudflare cert ↔ User)
    │  • DDoS protection / WAF
    │  • Rewrite: port 443 → :56260 (Origin Rule)
    │  • Forward to TrueDDNS IP
    ▼
[Router NAT]
    │  • NAT port 56260 → 192.168.111.171:56260
    ▼
[Nginx (192.168.111.171:56260)]
    │  • TLS termination ครั้งที่ 2 (Cloudflare Origin cert)
    │  • Add X-Forwarded-For, X-Real-IP headers
    │  • proxy_pass → http://192.168.111.200:80
    ▼
[MetalLB (192.168.111.200)]
    │  • L2 ARP: IP 192.168.111.200 อยู่ที่ VM1 (MAC address)
    │  • forward ไปยัง Traefik service บน VM1
    ▼
[Traefik Ingress (VM1)]
    │  • Match: Host(todo.yourdomain.com)
    │  • Apply Middleware: security-headers, compress
    │  ├── Path /api/* → backend:8000 (+ cors-app, rate-limit)
    │  └── Path /* → frontend:3000
    ▼
[Pods (VM1)]
    │
    ├── [Next.js Frontend Pod :3000]
    │       • serve static HTML/CSS/JS
    │       • SSR/CSR pages
    │       • API calls: fetch('/api/todos')
    │
    └── [Go Backend Pod :8000]
            │  • parse HTTP request
            │  • validate input
            ▼
        [PostgreSQL Pod :5432]
                │  • SQL query
                ▼
            [iSCSI LUN — Synology NAS 192.168.111.10]
                    • persistent storage บน hardware RAID
                    • MTU 9000 jumbo frame

Response กลับ User: < 100 ms (typical)
```

### 6.2 CI/CD Pipeline Flow (Deployment)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CI/CD PIPELINE FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

[Developer]
    │  git push origin main
    ▼
[Gitea Repository (git.yourdomain.com)]
    │  • ตรวจว่ามี .woodpecker/ directory ไหม
    │  • ส่ง webhook POST → Woodpecker Server
    ▼
[Woodpecker Server (VM1, namespace: woodpecker)]
    │  • รับ webhook event
    │  • ตรวจ when: conditions (branch=main, event=push)
    │  • สร้าง pipeline record ใน SQLite
    │  • ส่ง task ไปยัง Woodpecker Agent ผ่าน gRPC (port 9000)
    ▼
[Woodpecker Agent (VM3, namespace: woodpecker)]
    │  • รับ task จาก Server
    │  • ใช้ K8s backend → สร้าง K8s Job/Pod สำหรับแต่ละ step
    │
    │  ── Step 1: test-backend ────────────────────────────────────
    │  สร้าง K8s Pod: image=golang:1.25-alpine
    │  คำสั่ง:
    │    cd src/phase2-final/backend
    │    go mod download
    │    go vet ./...
    │    go test ./... -v -count=1
    │  ✅ PASS → ไปต่อ   ❌ FAIL → หยุด pipeline + email notification
    │
    │  ── Step 2: build-push-core (backend) ─────────────────────
    │  สร้าง K8s Pod: image=woodpeckerci/plugin-docker-buildx
    │  คำสั่ง:
    │    docker buildx build src/phase2-final/backend/
    │    → image: akawatmor/todoapp-core:a1b2c3d
    │    → image: akawatmor/todoapp-core:latest
    │  ✅ PUSH สำเร็จ → Docker Hub
    │
    │  ── Step 3: build-push-web (frontend) ─────────────────────
    │  สร้าง K8s Pod: image=woodpeckerci/plugin-docker-buildx
    │  build_args: NEXT_PUBLIC_API_BASE_URL= (ว่าง = relative path)
    │  คำสั่ง:
    │    docker buildx build src/phase2-final/frontend/
    │    → image: akawatmor/todoapp-web:a1b2c3d
    │    → image: akawatmor/todoapp-web:latest
    │  ✅ PUSH สำเร็จ
    │
    │  ── Step 4: deploy-k3s ─────────────────────────────────────
    │  สร้าง K8s Pod: image=bitnami/kubectl:1.29
    │  คำสั่ง:
    │    echo "$KUBECONFIG_B64" | base64 -d > /tmp/kubeconfig
    │    kubectl apply -f src/phase2-final/k8s/namespace.yaml
    │    kubectl apply -f src/phase2-final/k8s/configmap.yaml
    │    kubectl apply -f src/phase2-final/k8s/core-pvc.yaml
    │    kubectl set image deployment/todoapp-core \
    │      core=akawatmor/todoapp-core:a1b2c3d -n todoapp
    │    kubectl set image deployment/todoapp-web \
    │      web=akawatmor/todoapp-web:a1b2c3d -n todoapp
    │    kubectl rollout status deployment/todoapp-core -n todoapp --timeout=180s
    │    kubectl rollout status deployment/todoapp-web  -n todoapp --timeout=180s
    │    kubectl run smoke-test-a1b2c3d --image=curlimages/curl --restart=Never \
    │      --rm -i -n todoapp -- curl -sf http://todoapp-core:8080/healthz
    │
    ▼
[K3s Cluster — Rolling Update]
    │
    │  Backend Rolling Update:
    │    T=0: [backend-old-1, backend-old-2]
    │    T=1: [backend-old-1, backend-old-2, backend-new-1 (starting)]
    │    T=2: new-1 ReadinessProbe ✅ → ลบ old-1
    │    T=3: [backend-old-2, backend-new-1, backend-new-2 (starting)]
    │    T=4: new-2 ReadinessProbe ✅ → ลบ old-2
    │    T=5: [backend-new-1, backend-new-2] ✅ COMPLETE
    │
    │  → User ไม่รู้สึก downtime ตลอดกระบวนการ
    ▼
[Email Notification Step]
    │  สร้าง K8s Pod: image=drillster/drone-email (หรือ woodpecker email plugin)
    │  ส่ง Email ไปยังผู้รับที่กำหนด:
    │    ✅ Subject: "[KPS] Deploy สำเร็จ — commit:a1b2c3d branch:main"
    │    ❌ Subject: "[KPS] Pipeline FAILED — step:test-backend commit:a1b2c3d"
    ▼
[Email Inbox ของผู้รับ]
    • ได้รับ notification ทันที
    • Pipeline สำเร็จใช้เวลา: ~5–8 นาที

ทั้งหมดนี้เกิดขึ้นอัตโนมัติหลังจาก git push เพียงครั้งเดียว
```

### 6.3 Storage Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                         STORAGE FLOW                             │
└──────────────────────────────────────────────────────────────────┘

[K8s PersistentVolumeClaim: pg-iscsi-pvc]
    │  storageClassName: ""  (static provisioning)
    │  volumeName: pg-iscsi-pv
    │  capacity: 16Gi
    ▼
[K8s PersistentVolume: pg-iscsi-pv]
    │  spec.iscsi:
    │    targetPortal: 192.168.111.10:3260
    │    iqn: iqn.2000-01.com.synology:PetchSynologyV2...
    │    lun: 0
    │    fsType: ext4
    ▼
[iSCSI initiator บน VM1 (open-iscsi)]
    │  session: tcp [1] 192.168.111.10:3260,1
    │  MTU 9000 jumbo frame
    ▼
[Network Interface ens18 (VM1)]
    │  192.168.111.42 → 192.168.111.10
    ▼
[Synology NAS 192.168.111.10]
    │  iSCSI Target: iqn.2000-01.com.synology:...
    │  LUN: pg-lun (16 GB, Thick Provisioning)
    │  Volume: RAID-based (hardware protection)
    │
    └── Snapshot schedule: ทุกคืน (point-in-time recovery)
        Retention: 7 วัน
```

### 6.4 Security Layers

```
┌──────────────────────────────────────────────────────────────────┐
│                       SECURITY LAYERS                            │
└──────────────────────────────────────────────────────────────────┘

Layer 1: Network
  └── Cloudflare WAF + DDoS protection
  └── Router: เฉพาะ port 56260 เปิดจาก Internet
  └── K3s: nftables ปิด, ใช้ iptables ของ K3s เอง

Layer 2: Transport
  └── CF ↔ User: TLS 1.3 (Cloudflare cert)
  └── CF ↔ Nginx: TLS 1.2+ (Origin cert)
  └── Nginx ↔ Traefik: HTTP (ภายใน LAN เท่านั้น)

Layer 3: Application (Traefik Middleware)
  └── security-headers: X-Frame-Options, X-XSS-Protection, HSTS
  └── rate-limit: 30 req/s per IP (ป้องกัน brute force)
  └── cors-app: restrict origins

Layer 4: Container
  └── Backend: gcr.io/distroless/static-debian12:nonroot (no shell)
  └── Frontend: node image + USER nextjs (non-root)
  └── PostgreSQL: securityContext.fsGroup=999
  └── All: resource limits (ป้องกัน resource exhaustion)

Layer 5: CI Pipeline
  └── gosec: static analysis สำหรับ Go
  └── Trivy: scan Docker image ก่อน deploy
  └── Secrets: ใช้ Woodpecker Secrets (ไม่ hardcode ใน code)
  └── KUBECONFIG: base64 encoded ใน Woodpecker Secrets
```

---

## 📊 สรุป: คุณค่าที่ได้จากการทำ Phase 2

```
ก่อน Phase 2 (Manual):              หลัง Phase 2 (Automated):
─────────────────────────────        ────────────────────────────────
Deploy: 15–30 นาที/ครั้ง             Deploy: 5–8 นาที (อัตโนมัติ)
Test: ทำเองหรือข้าม                   Test: บังคับทุก commit
Rollback: ยาก ไม่มี history           Rollback: kubectl rollout undo
Security: ตรวจ manual                Security: Trivy scan ทุก build
Visibility: ไม่มี                    Visibility: Woodpecker UI + Discord
Storage: ข้อมูลอาจหายถ้า VM พัง       Storage: iSCSI NAS + Synology Snapshot
Scale: ต้อง reconfigure ทุกอย่าง      Scale: kubectl scale deployment/backend
```

> **สรุปแก่น:** DevOps Pipeline เปลี่ยน "manual, error-prone process"  
> ให้กลายเป็น "automated, reproducible, auditable process"  
> ที่ทีมเดียวสามารถ deliver feature ได้บ่อยขึ้น และมั่นใจมากขึ้น
