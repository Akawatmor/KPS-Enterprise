# 📘 Complete Guide: KPS-Enterprise on K3s Self-Hosted + Woodpecker CI

> **สถานะ**: เปลี่ยนจาก AWS EKS → K3s Self-Hosted บน Proxmox VMs  
> **CI/CD**: เปลี่ยนจาก Jenkins → Woodpecker CI  
> **App**: Todo App (Node.js + React + MongoDB)

---

## 📋 สารบัญ

1. [สรุปภาพรวม](#1-สรุปภาพรวม)
2. [สิ่งที่ต้องมีก่อนเริ่ม (Prerequisites)](#2-prerequisites)
3. [Phase 1: OS + K3s Cluster Setup](#3-phase-1-os--k3s-cluster)
4. [Phase 2: MetalLB + Traefik](#4-phase-2-metallb--traefik)
5. [Phase 3: Deploy Application (MongoDB + Backend + Frontend)](#5-phase-3-deploy-application)
6. [Phase 4: Traefik IngressRoute (Routing)](#6-phase-4-traefik-ingressroute)
7. [Phase 5: Woodpecker CI/CD Setup](#7-phase-5-woodpecker-cicd)
8. [Phase 6: Woodpecker Pipeline (.woodpecker.yml)](#8-phase-6-woodpecker-pipeline)
9. [Phase 7: Nginx Reverse Proxy + Cloudflare](#9-phase-7-nginx--cloudflare)
10. [Phase 8: ทดสอบ End-to-End](#10-phase-8-ทดสอบ-end-to-end)
11. [Troubleshooting](#11-troubleshooting)
12. [เปรียบเทียบ EKS vs K3s](#12-เปรียบเทียบ)

---

## 1. สรุปภาพรวม

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Internet                                                       │
│  User → Cloudflare (Proxy) → TrueDDNS → Nginx (:56260)         │
│              ↓                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  K3s Cluster (1 Master + 2 Workers)                     │    │
│  │                                                         │    │
│  │  VM1 (kps-k3-m-c1) — Master/Control Plane                │    │
│  │  ├── K3s Server                                         │    │
│  │  ├── Traefik (Ingress + MetalLB IP: 192.168.111.240)    │    │
│  │  └── Woodpecker Server                                  │    │
│  │                                                         │    │
│  │  VM2 (kps-k3-w1-c1) — Worker (App)                      │    │
│  │  ├── MongoDB (1 pod)                                    │    │
│  │  ├── Backend - Node.js/Express (2 pods)                 │    │
│  │  └── Frontend - React (1 pod)                           │    │
│  │                                                         │    │
│  │  VM3 (kps-k3-w2-c1) — Worker (CI)                       │    │
│  │  └── Woodpecker Agent (รัน CI pipeline)                 │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### เปลี่ยนอะไรบ้าง (EKS → K3s)

| Component | EKS (เดิม) | K3s (ใหม่) |
|-----------|------------|-------------|
| Cluster | AWS EKS Managed | K3s Self-hosted (Proxmox VM) |
| Ingress | AWS ALB Controller | Traefik (built-in K3s) |
| Load Balancer | AWS ALB | MetalLB (L2 mode) |
| CI/CD | Jenkins on EC2 | Woodpecker CI on K3s |
| Container Registry | Docker Hub | Docker Hub (เหมือนเดิม) |
| Storage | hostPath | hostPath (เหมือนเดิม) |
| Namespace | `three-tier` | `three-tier` (เหมือนเดิม) |
| DNS/SSL | - | Cloudflare + Nginx + TrueDDNS |

### App Info

| Service | Port | Image |
|---------|------|-------|
| MongoDB | 27017 | `mongo:4.4.6` |
| Backend (Express) | 3500 | `akawatmor/kps-backend` |
| Frontend (React) | 3000 | `akawatmor/kps-frontend` |

---

## 2. Prerequisites

### สิ่งที่ต้องมี

- [x] Proxmox VE สร้าง VM ได้
- [x] VM1: kps-k3-m-c1 — Master/Control Plane (แนะนำ 4+ core, 8+ GB RAM, 40+ GB disk)
- [x] VM2: kps-k3-w1-c1 — Worker สำหรับ App (แนะนำ 4+ core, 8+ GB RAM, 40+ GB disk)
- [x] VM3: kps-k3-w2-c1 — Worker สำหรับ CI (แนะนำ 2+ core, 4+ GB RAM, 30+ GB disk)
- [x] Ubuntu Server 22.04/24.04 ติดตั้งแล้วบนทั้ง 3 VMs
- [x] เครื่องทั้ง 3 อยู่ใน LAN เดียวกัน (เช่น 192.168.1.0/24)
- [x] Docker Hub account (username: `akawatmor`)
- [x] GitHub repository: `Akawatmor/KPS-Enterprise`
- [x] Domain ชี้มาที่ Nginx ผ่าน TrueDDNS + Cloudflare

### IP Plan

```
VM1 (kps-k3-m-c1):   192.168.1.142 / 192.168.111.42   ← Master + Woodpecker Server
VM2 (kps-k3-w1-c1):  192.168.1.143 / 192.168.111.43   ← Worker: App (MongoDB, Backend, Frontend) | label: role=app
VM3 (kps-k3-w2-c1):  192.168.1.144 / 192.168.111.44   ← Worker: CI (Woodpecker Agent) | label: role=ci

MetalLB Pool:      192.168.111.240-192.168.111.250  ← Link Local (L2 เดียวกับ Nginx 192.168.111.61)
Nginx (Link Local): 192.168.111.61                  ← Upstream ไป K3s
Nginx (Public):     192.168.1.171                   ← Rceive DDNS ทาง Internet
```

> **ทำไมถึงใช้ Link Local Pool (192.168.111.x) ไม่ใช้ Router Pool:**
>
> ```
> Internet → DDNS → Nginx (192.168.1.171) → Nginx (192.168.111.61) → MetalLB (192.168.111.240) → Traefik → Pods
>                        ↑ Router Pool (inbound)  ↑ Link Local (upstream to K8s)
> ```
>
> Nginx ส่ง traffic ไป K3s ผ่าน **interface `192.168.111.61`**  
> MetalLB L2 ARP ต้องอยู่ใน subnet เดียวกับ interface นั้น → `192.168.111.x` ✅  
> K8s nodes มี interface `192.168.111.42-44` → MetalLB speaker ARP สำเร็จ ✅

---

## 3. Phase 1: OS + K3s Cluster

> **หมายเหตุ**: ถ้าทำขั้นตอนนี้เสร็จแล้ว ข้ามไปได้เลย

### 3.1 ตั้งค่า OS (ทำทั้ง 3 VMs)

```bash
# Update & install tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git htop net-tools jq unzip

# ตั้ง Hostname (ทำแต่ละ VM)
sudo hostnamectl set-hostname kps-k3-m-c1    # VM1
# sudo hostnamectl set-hostname kps-k3-w1-c1  # VM2
# sudo hostnamectl set-hostname kps-k3-w2-c1  # VM3

# แก้ /etc/hosts (ทำทั้ง 3 VMs เหมือนกัน)
sudo tee -a /etc/hosts << 'EOF'
192.168.1.142  kps-k3-m-c1
192.168.1.143  kps-k3-w1-c1
192.168.1.144  kps-k3-w2-c1
EOF

# ปิด swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# ปิด firewall (K3s จัดการ iptables เอง)
sudo ufw disable 2>/dev/null || true
```

### 3.2 Install K3s Server (VM1)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="\
  server \
  --write-kubeconfig-mode 644 \
  --disable servicelb \
  --tls-san 192.168.1.142 \
  --tls-san kps-k3-m-c1 \
  --node-label role=main \
" sh -
```

**ตรวจสอบ:**

```bash
sudo systemctl status k3s
kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# kps-k3-m-c1   Ready    control-plane,master   1m    v1.3x.x
```

**จด Token ไว้ใช้ตอนเพิ่ม Agent:**

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

### 3.3 Install K3s Agent (VM2 — kps-k3-w1-c1)

```bash
# SSH เข้า VM2
# เปลี่ยน K3S_TOKEN เป็นค่าจริงจาก VM1
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.1.142:6443" \
  K3S_TOKEN="<TOKEN_จาก_VM1>" \
  INSTALL_K3S_EXEC="agent --node-label role=app" \
  sh -
```

### 3.4 Install K3s Agent (VM3 — kps-k3-w2-c1)

```bash
# SSH เข้า VM3
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.1.142:6443" \
  K3S_TOKEN="<TOKEN_จาก_VM1>" \
  INSTALL_K3S_EXEC="agent --node-label role=ci" \
  sh -
```

**ตรวจสอบ (กลับไป VM1):**

```bash
kubectl get nodes
# NAME          STATUS   ROLES                  AGE   VERSION
# kps-k3-m-c1    Ready    control-plane,master   5m    v1.3x.x
# kps-k3-w1-c1   Ready    <none>                 2m    v1.3x.x
# kps-k3-w2-c1   Ready    <none>                 1m    v1.3x.x

# ดู labels
kubectl get nodes --show-labels | grep role
```

### 3.5 Taint CI Node (ไม่ให้ app pods ไป schedule บน kps-k3-w2-c1)

```bash
kubectl taint nodes kps-k3-w2-c1 dedicated=ci:NoSchedule
```

---

## 4. Phase 2: MetalLB + Traefik

### 4.1 Install MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# รอ pods ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=120s
```

### 4.2 Configure MetalLB IP Pool

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.111.240-192.168.111.250   # Link Local Pool — L2 เดียวกับ Nginx (192.168.111.61)
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
```

### 4.3 ตรวจสอบ Traefik ได้รับ External IP

```bash
kubectl get svc -n kube-system traefik
# NAME      TYPE           CLUSTER-IP    EXTERNAL-IP       PORT(S)
# traefik   LoadBalancer   10.43.x.x     192.168.111.240   80/TCP,443/TCP
```

> ถ้า EXTERNAL-IP ยังเป็น `<pending>` ให้รอ 30 วินาทีแล้วเช็คอีกครั้ง

### 4.4 (Optional) Configure Traefik เพิ่มเติม

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    additionalArguments:
      - "--entrypoints.web.forwardedHeaders.trustedIPs=192.168.111.61/32"   # Nginx Link Local interface
    logs:
      general:
        level: WARN
    nodeSelector:
      role: main
EOF
```

---

## 5. Phase 3: Deploy Application

### 5.1 สร้าง Namespace

```bash
kubectl create namespace three-tier
```

### 5.2 สร้าง Secrets

```bash
# MongoDB credentials
kubectl create secret generic mongo-sec \
  --namespace three-tier \
  --from-literal=username=admin \
  --from-literal=password='password123'

# (Optional) Docker Hub credentials ถ้าใช้ private image
kubectl create secret docker-registry dockerhub-secret \
  --namespace three-tier \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=akawatmor \
  --docker-password='<DOCKER_HUB_TOKEN>' \
  --docker-email=akawat.mor@dome.tu.ac.th
```

### 5.3 สร้าง Data Directory (VM2 — kps-k3-w1-c1)

เนื่องจาก MongoDB จะ schedule บน `kps-k3-w1-c1` (role=app) ต้องสร้าง directory บน **VM2**:

```bash
# SSH เข้า VM2
sudo mkdir -p /opt/mongo-data
sudo chmod 777 /opt/mongo-data
```

### 5.4 Deploy MongoDB

```bash
cat << 'EOF' | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
  labels:
    type: local
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /opt/mongo-data
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-volume-claim
  namespace: three-tier
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: three-tier
  name: mongodb
  labels:
    app: mongodb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      nodeSelector:
        role: app
      containers:
      - name: mongodb
        image: mongo:4.4.6
        command:
          - "numactl"
          - "--interleave=all"
          - "mongod"
          - "--wiredTigerCacheSizeGB"
          - "0.1"
          - "--bind_ip"
          - "0.0.0.0"
        ports:
        - containerPort: 27017
        env:
          - name: MONGO_INITDB_ROOT_USERNAME
            valueFrom:
              secretKeyRef:
                name: mongo-sec
                key: username
          - name: MONGO_INITDB_ROOT_PASSWORD
            valueFrom:
              secretKeyRef:
                name: mongo-sec
                key: password
        volumeMounts:
          - name: mongo-volume
            mountPath: /data/db
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mongo-volume
        persistentVolumeClaim:
          claimName: mongo-volume-claim
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-svc
  namespace: three-tier
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
  clusterIP: None
EOF
```

**ตรวจสอบ:**

```bash
kubectl get pods -n three-tier -l app=mongodb
# NAME                       READY   STATUS    AGE
# mongodb-xxxxxxxxxx-xxxxx   1/1     Running   30s

# ทดสอบ connection
kubectl exec -it -n three-tier deployment/mongodb -- \
  mongo --username admin --password password123 --authenticationDatabase admin --eval "db.stats()"
```

### 5.5 Deploy Backend

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: three-tier
  labels:
    role: api
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      role: api
  template:
    metadata:
      labels:
        role: api
    spec:
      nodeSelector:
        role: app
      containers:
      - name: api
        image: akawatmor/kps-backend:latest
        imagePullPolicy: Always
        env:
          - name: MONGO_CONN_STR
            value: "mongodb://mongodb-svc:27017/todo?directConnection=true"
          - name: USE_DB_AUTH
            value: "true"
          - name: MONGO_USERNAME
            valueFrom:
              secretKeyRef:
                name: mongo-sec
                key: username
          - name: MONGO_PASSWORD
            valueFrom:
              secretKeyRef:
                name: mongo-sec
                key: password
        ports:
        - containerPort: 3500
        livenessProbe:
          httpGet:
            path: /healthz
            port: 3500
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3500
          initialDelaySeconds: 3
          periodSeconds: 5
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: three-tier
spec:
  selector:
    role: api
  ports:
  - port: 3500
    targetPort: 3500
EOF
```

**ตรวจสอบ:**

```bash
kubectl get pods -n three-tier -l role=api
# NAME                   READY   STATUS    AGE
# api-xxxxxxxxxx-xxxxx   1/1     Running   30s
# api-xxxxxxxxxx-yyyyy   1/1     Running   30s

# ดู logs
kubectl logs -n three-tier -l role=api --tail=20

# ทดสอบ health
kubectl port-forward -n three-tier svc/api 3500:3500 &
curl http://localhost:3500/healthz
# Healthy
curl http://localhost:3500/ready
# Ready
kill %1
```

### 5.6 Deploy Frontend

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: three-tier
  labels:
    role: frontend
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 25%
  selector:
    matchLabels:
      role: frontend
  template:
    metadata:
      labels:
        role: frontend
    spec:
      nodeSelector:
        role: app
      containers:
      - name: frontend
        image: akawatmor/kps-frontend:latest
        imagePullPolicy: Always
        env:
          - name: REACT_APP_BACKEND_URL
            value: "https://todo.akawatmor.com/api/tasks"
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 300m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: three-tier
spec:
  selector:
    role: frontend
  ports:
  - port: 3000
    targetPort: 3000
EOF
```

> **⚠️ สำคัญ**: `REACT_APP_BACKEND_URL` ต้องเป็น URL ที่ **browser** เข้าถึงได้ (ไม่ใช่ internal cluster URL)  
> ถ้ายังไม่มี domain ใช้ `http://192.168.111.240/api/tasks` ไปก่อน

**ตรวจสอบ:**

```bash
kubectl get pods -n three-tier -l role=frontend
# NAME                        READY   STATUS    AGE
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   30s
```

### 5.7 สรุป Pods ที่ควรเห็น

```bash
kubectl get pods -n three-tier
# NAME                        READY   STATUS    AGE
# mongodb-xxx                 1/1     Running   5m
# api-xxx                     1/1     Running   3m
# api-yyy                     1/1     Running   3m
# frontend-xxx                1/1     Running   1m
```

---

## 6. Phase 4: Traefik IngressRoute

### 6.1 สร้าง IngressRoute (แทน ALB Ingress)

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: app-router
  namespace: three-tier
spec:
  entryPoints:
    - web
  routes:
    # Backend API — ทุก request ที่ขึ้นต้นด้วย /api
    - match: Host(`todo.akawatmor.com`) && PathPrefix(`/api`)
      kind: Rule
      priority: 10
      services:
        - name: api
          port: 3500

    # Health check endpoints (สำหรับ monitoring)
    - match: Host(`todo.akawatmor.com`) && (Path(`/healthz`) || Path(`/ready`) || Path(`/started`))
      kind: Rule
      priority: 20
      services:
        - name: api
          port: 3500

    # Frontend — ทุก request อื่นๆ
    - match: Host(`todo.akawatmor.com`)
      kind: Rule
      priority: 1
      services:
        - name: frontend
          port: 3000
EOF
```

### 6.2 ตรวจสอบ IngressRoute

```bash
kubectl get ingressroute -n three-tier
# NAME         AGE
# app-router   10s
```

### 6.3 ทดสอบจาก LAN

```bash
# ทดสอบผ่าน MetalLB IP โดยส่ง Host header
# (192.168.111.240 = MetalLB ที่ได้จาก Link Local Pool)
curl -H "Host: todo.akawatmor.com" http://192.168.111.240/healthz
# Healthy

curl -H "Host: todo.akawatmor.com" http://192.168.111.240/api/tasks
# [] (หรือ list ของ tasks)

curl -H "Host: todo.akawatmor.com" http://192.168.111.240/
# HTML ของ React app
```

---

## 7. Phase 5: Woodpecker CI/CD Setup

### 7.1 สร้าง Namespace + OAuth App

**7.1.1 สร้าง GitHub OAuth App:**

1. ไปที่ GitHub → Settings → Developer settings → OAuth Apps → New OAuth App
2. กรอก:
   - **Application name**: `Woodpecker CI`
   - **Homepage URL**: `https://ci.akawatmor.com`
   - **Authorization callback URL**: `https://ci.akawatmor.com/authorize`
3. จด `Client ID` และ `Client Secret` ไว้

**7.1.2 สร้าง Namespace:**

```bash
kubectl create namespace woodpecker
```

### 7.2 สร้าง Secrets สำหรับ Woodpecker

```bash
# สร้าง Agent Secret (random string ที่ server กับ agent ใช้คุยกัน)
WOODPECKER_AGENT_SECRET=$(openssl rand -hex 32)
echo "Agent Secret: $WOODPECKER_AGENT_SECRET"
# จด secret นี้ไว้!

kubectl create secret generic woodpecker-secret \
  --namespace woodpecker \
  --from-literal=WOODPECKER_GITHUB_CLIENT='<GITHUB_CLIENT_ID>' \
  --from-literal=WOODPECKER_GITHUB_SECRET='<GITHUB_CLIENT_SECRET>' \
  --from-literal=WOODPECKER_AGENT_SECRET="$WOODPECKER_AGENT_SECRET"
```

### 7.3 Deploy Woodpecker Server

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: woodpecker-server
  namespace: woodpecker
  labels:
    app: woodpecker-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: woodpecker-server
  template:
    metadata:
      labels:
        app: woodpecker-server
    spec:
      nodeSelector:
        kubernetes.io/hostname: kps-k3-m-c1
      containers:
      - name: woodpecker-server
        image: woodpeckerci/woodpecker-server:latest
        ports:
        - containerPort: 8000
          name: http
        - containerPort: 9000
          name: grpc
        env:
        - name: WOODPECKER_HOST
          value: "https://ci.akawatmor.com"
        - name: WOODPECKER_OPEN
          value: "true"
        - name: WOODPECKER_GITHUB
          value: "true"
        - name: WOODPECKER_GITHUB_CLIENT
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_GITHUB_CLIENT
        - name: WOODPECKER_GITHUB_SECRET
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_GITHUB_SECRET
        - name: WOODPECKER_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_AGENT_SECRET
        - name: WOODPECKER_ADMIN
          value: "Akawatmor"
        - name: WOODPECKER_LOG_LEVEL
          value: "info"
        volumeMounts:
        - name: data
          mountPath: /var/lib/woodpecker
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: data
        hostPath:
          path: /opt/woodpecker-data
          type: DirectoryOrCreate

# สร้าง directory บน VM1 ก่อน:
# sudo mkdir -p /opt/woodpecker-data && sudo chmod 777 /opt/woodpecker-data
---
apiVersion: v1
kind: Service
metadata:
  name: woodpecker-server
  namespace: woodpecker
spec:
  selector:
    app: woodpecker-server
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  - name: grpc
    port: 9000
    targetPort: 9000
EOF
```

### 7.4 Deploy Woodpecker Agent

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: woodpecker-agent
  namespace: woodpecker
  labels:
    app: woodpecker-agent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: woodpecker-agent
  template:
    metadata:
      labels:
        app: woodpecker-agent
    spec:
      # Agent รันบน CI node
      nodeSelector:
        role: ci
      tolerations:
      - key: "dedicated"
        operator: "Equal"
        value: "ci"
        effect: "NoSchedule"
      containers:
      - name: woodpecker-agent
        image: woodpeckerci/woodpecker-agent:latest
        env:
        - name: WOODPECKER_SERVER
          value: "woodpecker-server.woodpecker.svc.cluster.local:9000"
        - name: WOODPECKER_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_AGENT_SECRET
        - name: WOODPECKER_MAX_WORKFLOWS
          value: "2"
        - name: WOODPECKER_BACKEND_ENGINE
          value: "docker"
        - name: DOCKER_HOST
          value: "unix:///var/run/docker.sock"
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: "2"
            memory: 2Gi
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
          type: Socket
EOF
```

> **⚠️ Docker บน VM3**: Woodpecker Agent ต้องการ Docker  
> ถ้า VM3 (kps-k3-w2-c1) ยังไม่มี Docker ให้ติดตั้งก่อน:
> ```bash
> # SSH เข้า VM3
> curl -fsSL https://get.docker.com | sh
> sudo usermod -aG docker k3sadmin
> # logout แล้ว login ใหม่เพื่อให้ group มีผล
> ```

### 7.5 Woodpecker IngressRoute

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: woodpecker
  namespace: woodpecker
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`ci.akawatmor.com`)
      kind: Rule
      services:
        - name: woodpecker-server
          port: 8000
EOF
```

### 7.6 ตรวจสอบ Woodpecker

```bash
kubectl get pods -n woodpecker
# NAME                                  READY   STATUS    AGE
# woodpecker-server-xxxxxxxxxx-xxxxx    1/1     Running   1m
# woodpecker-agent-xxxxxxxxxx-xxxxx     1/1     Running   1m

# ดู logs
kubectl logs -n woodpecker -l app=woodpecker-server --tail=20
kubectl logs -n woodpecker -l app=woodpecker-agent --tail=20

# ทดสอบเข้า web
curl -H "Host: ci.akawatmor.com" http://192.168.111.240/
# ได้ HTML ของ Woodpecker UI
```

---

## 8. Phase 6: Woodpecker Pipeline

### 8.1 สร้าง Woodpecker Secrets (ใน UI)

เข้า Woodpecker UI → Repository Settings → Secrets → เพิ่ม:

| Name | Value | Description |
|------|-------|-------------|
| `docker_username` | `akawatmor` | Docker Hub username |
| `docker_password` | `<token>` | Docker Hub access token |
| `k3s_kubeconfig` | เนื้อหาไฟล์ `/etc/rancher/k3s/k3s.yaml` (เปลี่ยน server เป็น IP จริง) | สำหรับ kubectl deploy |

**สร้าง kubeconfig สำหรับ CI:**

```bash
# VM1 - copy kubeconfig แล้วเปลี่ยน IP
sudo cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/192.168.1.142/g'
# copy output ทั้งหมดไปใส่ใน secret k3s_kubeconfig
```

### 8.2 สร้าง Pipeline File

สร้างไฟล์ `.woodpecker.yml` ที่ root ของ repository:

```yaml
# .woodpecker.yml
# Woodpecker CI Pipeline for KPS-Enterprise
# เทียบเท่า Jenkinsfile เดิม แต่ใช้ Woodpecker syntax

when:
  branch: main
  event: [push, pull_request]

steps:
  # ═══════════════════════════════════
  # Backend Pipeline
  # ═══════════════════════════════════

  backend-test:
    image: node:14
    directory: docker/backend
    commands:
      - npm install
      - echo "Backend dependencies installed successfully"
    when:
      path:
        include:
          - "docker/backend/**"
          - ".woodpecker.yml"

  backend-security-scan:
    image: aquasec/trivy:latest
    commands:
      - trivy fs --severity HIGH,CRITICAL --exit-code 0 docker/backend/
    when:
      path:
        include:
          - "docker/backend/**"

  backend-build:
    image: plugins/docker
    settings:
      repo: akawatmor/kps-backend
      tags:
        - "${CI_COMMIT_SHA:0:8}"
        - latest
      dockerfile: docker/backend/Dockerfile
      context: docker/backend
      username:
        from_secret: docker_username
      password:
        from_secret: docker_password
    when:
      event: push
      branch: main
      path:
        include:
          - "docker/backend/**"

  # ═══════════════════════════════════
  # Frontend Pipeline
  # ═══════════════════════════════════

  frontend-test:
    image: node:14
    directory: docker/frontend
    commands:
      - npm install
      - echo "Frontend dependencies installed successfully"
    when:
      path:
        include:
          - "docker/frontend/**"
          - ".woodpecker.yml"

  frontend-security-scan:
    image: aquasec/trivy:latest
    commands:
      - trivy fs --severity HIGH,CRITICAL --exit-code 0 docker/frontend/
    when:
      path:
        include:
          - "docker/frontend/**"

  frontend-build:
    image: plugins/docker
    settings:
      repo: akawatmor/kps-frontend
      tags:
        - "${CI_COMMIT_SHA:0:8}"
        - latest
      dockerfile: docker/frontend/Dockerfile
      context: docker/frontend
      username:
        from_secret: docker_username
      password:
        from_secret: docker_password
    when:
      event: push
      branch: main
      path:
        include:
          - "docker/frontend/**"

  # ═══════════════════════════════════
  # Deploy to K3s
  # ═══════════════════════════════════

  deploy:
    image: bitnami/kubectl:latest
    commands:
      - mkdir -p ~/.kube
      - echo "$KUBECONFIG_CONTENT" > ~/.kube/config
      - chmod 600 ~/.kube/config
      # Restart deployments เพื่อ pull image ใหม่ (imagePullPolicy: Always)
      - kubectl rollout restart deployment/api -n three-tier
      - kubectl rollout restart deployment/frontend -n three-tier
      # รอให้ rollout เสร็จ
      - kubectl rollout status deployment/api -n three-tier --timeout=120s
      - kubectl rollout status deployment/frontend -n three-tier --timeout=120s
    environment:
      KUBECONFIG_CONTENT:
        from_secret: k3s_kubeconfig
    when:
      event: push
      branch: main
```

### 8.3 เปรียบเทียบ Jenkins vs Woodpecker Pipeline

| Jenkins (เดิม) | Woodpecker (ใหม่) | หมายเหตุ |
|----------------|-------------------|----------|
| SonarQube Analysis | - | (Optional: เพิ่มทีหลัง) |
| Quality Gate | - | (Optional) |
| OWASP Scan | `trivy fs` | Trivy ทำได้คล้ายกัน |
| Trivy File Scan | `backend-security-scan` | เหมือนเดิม |
| Docker Build | `plugins/docker` | Built-in plugin |
| Docker Push | `plugins/docker` | รวมอยู่ใน step เดียว |
| Update deployment.yaml | `kubectl rollout restart` | ง่ายกว่า เพราะใช้ `:latest` tag |

### 8.4 Activate Repository ใน Woodpecker

1. เปิด Woodpecker UI: `https://ci.akawatmor.com`
2. Login ด้วย GitHub
3. คลิก "Add repository" → เลือก `KPS-Enterprise`
4. Repository จะ sync webhook กับ GitHub อัตโนมัติ
5. Push code เพื่อ trigger pipeline

### 8.5 ทดสอบ Pipeline

```bash
# ทดสอบด้วย push เล็กๆ
cd ~/git-repository/KPS-Enterprise
echo "# trigger CI" >> README.md
git add . && git commit -m "test: trigger woodpecker pipeline"
git push
```

จากนั้นเปิด Woodpecker UI ดู pipeline ทำงาน

---

## 9. Phase 7: Nginx + Cloudflare

### 9.1 Nginx Configuration

```bash
# SSH เข้า Nginx server (192.168.1.171)
sudo nano /etc/nginx/conf.d/k3s.conf
```

```nginx
# /etc/nginx/conf.d/k3s.conf

upstream k3s_backend {
    server 192.168.111.240:80;   # MetalLB IP (Link Local Pool) → Traefik
    keepalive 64;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}

server {
    listen 56260 ssl http2;
    server_name todo.akawatmor.com ci.akawatmor.com traefik.akawatmor.com;

    # SSL Certificates (ปรับ path ตามจริง)
    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://k3s_backend;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        $connection_upgrade;
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

```bash
sudo nginx -t && sudo nginx -s reload
```

### 9.2 Cloudflare DNS

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `todo` | `yourname.trueddns.com` | 🟠 ON |
| CNAME | `ci` | `yourname.trueddns.com` | 🟠 ON |

### 9.3 Cloudflare Origin Rule

```
Rules → Origin Rules → Create Rule

Name: "K3s Port Rewrite"
When: Hostname equals "todo.akawatmor.com" OR "ci.akawatmor.com"
Then: Destination Port → Rewrite to → 56260

→ Deploy
```

### 9.4 SSL Mode

```
SSL/TLS → Overview → Full (Strict)
```

---

## 10. Phase 8: ทดสอบ End-to-End

### 10.1 ตรวจ Cluster Status

```bash
# Nodes
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Services
kubectl get svc -A
```

### 10.2 ทดสอบ App ทีละ Layer

```bash
echo "=== 1. Internal: MetalLB Direct (Link Local Pool IP) ==="
curl -s -H "Host: todo.akawatmor.com" http://192.168.111.240/healthz
# Healthy

echo "=== 2. Internal: API CRUD ==="
# Create
curl -s -H "Host: todo.akawatmor.com" \
  -X POST http://192.168.111.240/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"Test from K3s!"}'

# Read
curl -s -H "Host: todo.akawatmor.com" http://192.168.111.240/api/tasks

echo "=== 3. Via Nginx (LAN) ==="
curl -sk https://todo.akawatmor.com:56260/healthz
# Healthy

echo "=== 4. Via Cloudflare (Internet) ==="
curl -s https://todo.akawatmor.com/healthz
# Healthy

echo "=== 5. Woodpecker UI ==="
curl -s -o /dev/null -w "%{http_code}" https://ci.akawatmor.com/
# 200

# ทดสอบผ่าน Link Local โดยตรง
curl -H "Host: ci.akawatmor.com" http://192.168.111.240/
# HTML ของ Woodpecker UI

echo "=== 6. Frontend ==="
curl -s https://todo.akawatmor.com/ | head -5
# HTML ของ React app
```

### 10.3 ทดสอบ Full CI/CD Flow

1. แก้ไฟล์ใน `docker/backend/` หรือ `docker/frontend/`
2. `git push`
3. ดู Woodpecker UI → pipeline ทำงาน
4. เมื่อ pipeline เสร็จ → pods restart อัตโนมัติ
5. เข้า `https://todo.akawatmor.com` → เห็นการเปลี่ยนแปลง

---

## 11. Troubleshooting

### Pod ไม่ขึ้น (CrashLoopBackOff / Error)

```bash
# ดู event
kubectl describe pod <pod-name> -n three-tier

# ดู logs
kubectl logs <pod-name> -n three-tier

# ดู logs ก่อน restart
kubectl logs <pod-name> -n three-tier --previous
```

### MongoDB connection failed

```bash
# เช็คว่า MongoDB pod running
kubectl get pods -n three-tier -l app=mongodb

# เช็คว่า Service ถูก resolve ได้
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup mongodb-svc.three-tier.svc.cluster.local

# เช็ค endpoint
kubectl get endpoints mongodb-svc -n three-tier
```

### Traefik ไม่ route ถูก

```bash
# ดู IngressRoute
kubectl describe ingressroute app-router -n three-tier

# ดู Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50

# ดู Traefik Dashboard (port-forward)
kubectl port-forward -n kube-system svc/traefik 9000:9000 &
# เปิด browser: http://localhost:9000/dashboard/
kill %1
```

### MetalLB ไม่ assign IP

```bash
# เช็ค MetalLB pods
kubectl get pods -n metallb-system

# เช็ค IPAddressPool
kubectl get ipaddresspool -n metallb-system -o yaml

# เช็ค events
kubectl get events -n metallb-system
```

### Woodpecker Agent ไม่เชื่อมต่อ

```bash
# เช็ค logs
kubectl logs -n woodpecker -l app=woodpecker-agent

# เช็คว่า Docker socket mounted ถูก
kubectl exec -it -n woodpecker deployment/woodpecker-agent -- ls -la /var/run/docker.sock

# เช็คว่า GRPC port accessible
kubectl exec -it -n woodpecker deployment/woodpecker-agent -- \
  nc -zv woodpecker-server.woodpecker.svc.cluster.local 9000
```

### Image pull failed

```bash
# เช็คว่า secret ถูก
kubectl get secret dockerhub-secret -n three-tier -o yaml

# ลอง pull ด้วยมือ (VM1)
sudo k3s crictl pull akawatmor/kps-backend:latest
```

### Pipeline ไม่ trigger

1. เช็ค GitHub webhook: Repo → Settings → Webhooks → Recent Deliveries
2. เช็คว่า `.woodpecker.yml` อยู่ที่ root ของ repo
3. เช็ค branch ตรงกับที่ set ใน `when.branch`
4. ดู Woodpecker Server logs:
   ```bash
   kubectl logs -n woodpecker -l app=woodpecker-server --tail=50
   ```

---

## 12. เปรียบเทียบ

### Architecture Comparison

```
┌─────────────── EKS (Phase 1) ────────────────┐
│                                               │
│  AWS Cloud                                    │
│  ├── VPC + Subnets + IGW                     │
│  ├── EKS Control Plane (managed)             │
│  ├── EC2 Worker Nodes (t3.large × 3)        │
│  ├── ALB Ingress Controller                  │
│  ├── Jenkins on EC2 (t3.large)               │
│  └── S3 + DynamoDB (TF state)               │
│                                               │
│  Cost: ~$200-300/month (หรือ Learner Lab)    │
│  Complexity: สูง (AWS services หลายตัว)       │
└───────────────────────────────────────────────┘

┌─────────────── K3s (Phase 2) ────────────────┐
│                                               │
│  Proxmox (Self-hosted)                       │
│  ├── VM1: K3s Server + App Pods              │
│  │   ├── Traefik (built-in)                  │
│  │   ├── MetalLB                             │
│  │   ├── MongoDB + Backend + Frontend        │
│  │   └── Woodpecker Server                   │
│  ├── VM2: K3s Agent + Woodpecker Agent       │
│  └── Nginx (existing)                        │
│                                               │
│  Cost: ค่าไฟ + Internet เท่านั้น              │
│  Complexity: ปานกลาง (ควบคุมเองทุกอย่าง)     │
└───────────────────────────────────────────────┘
```

### CI/CD Comparison

| Feature | Jenkins (เดิม) | Woodpecker (ใหม่) |
|---------|----------------|-------------------|
| Config | Jenkinsfile (Groovy) | .woodpecker.yml (YAML) |
| Plugins | Jenkins Plugins | Docker-based plugins |
| Resource | EC2 t3.large ตลอด | ใช้ตอน run pipeline เท่านั้น |
| Security Scan | SonarQube + OWASP + Trivy | Trivy (+ optional SonarQube) |
| Docker Build | shell commands | `plugins/docker` (declarative) |
| Deploy | sed + git push | kubectl direct |
| UI | Java-based heavy | Lightweight web UI |

### Kubernetes Manifest Changes

| Resource | EKS | K3s | เปลี่ยนอะไร |
|----------|-----|-----|------------|
| Namespace | `three-tier` | `three-tier` | เหมือนเดิม |
| Secrets | `mongo-sec` | `mongo-sec` | เหมือนเดิม |
| MongoDB Deploy | ✅ | ✅ | `nodeSelector: role=app` (kps-k3-w1-c1) |
| Backend Deploy | ✅ | ✅ | `nodeSelector: role=app` (kps-k3-w1-c1) |
| Frontend Deploy | ✅ | ✅ | `nodeSelector: role=app` (kps-k3-w1-c1), เปลี่ยน URL |
| PV/PVC | hostPath | hostPath | path อยู่บน kps-k3-w1-c1 (`/opt/mongo-data`) |
| Ingress | ALB (nginx class) | Traefik IngressRoute | **เปลี่ยนทั้งหมด** |

---

## 📁 ไฟล์ที่เกี่ยวข้องใน Repository

```
KPS-Enterprise/
├── docker/
│   ├── backend/          ← Source code + Dockerfile
│   │   ├── Dockerfile
│   │   ├── index.js      (Express server, port 3500)
│   │   ├── db.js         (MongoDB connection)
│   │   ├── models/task.js
│   │   └── routes/tasks.js (CRUD: GET/POST/PUT/DELETE)
│   └── frontend/         ← Source code + Dockerfile
│       ├── Dockerfile
│       ├── src/App.js     (React + Material-UI)
│       └── src/services/taskServices.js (Axios → REACT_APP_BACKEND_URL)
│
├── src/Kubernetes-Manifests-file/   ← K8s manifests (EKS version)
│   ├── namespace.yaml
│   ├── ingress.yaml                 ← ALB Ingress (ไม่ใช้แล้ว)
│   ├── Backend/deployment.yaml
│   ├── Backend/service.yaml
│   ├── Database/deployment.yaml
│   ├── Database/service.yaml
│   ├── Database/pv.yaml
│   ├── Database/pvc.yaml
│   ├── Database/secrets.yaml
│   ├── Frontend/deployment.yaml
│   └── Frontend/service.yaml
│
├── .woodpecker.yml                  ← ไฟล์ CI/CD ใหม่ (สร้างจาก guide นี้)
│
└── document/phase2/
    ├── plan-woodpecker-new.md       ← แผน (reference)
    └── guide-new.md                 ← 📘 ไฟล์นี้
```

---

## ✅ Checklist สรุป

- [ ] K3s Server (kps-k3-m-c1) running
- [ ] K3s Agent (kps-k3-w1-c1) running — label `role=app`
- [ ] K3s Agent (kps-k3-w2-c1) running + tainted — label `role=ci`
- [ ] MetalLB installed + IP assigned
- [ ] Traefik ได้ External IP (192.168.111.240)
- [ ] Namespace `three-tier` สร้างแล้ว
- [ ] Secret `mongo-sec` สร้างแล้ว
- [ ] MongoDB deployed + running
- [ ] Backend deployed (2 replicas) + health check pass
- [ ] Frontend deployed (1 replica)
- [ ] IngressRoute configured (routing ถูก)
- [ ] Woodpecker Server deployed
- [ ] Woodpecker Agent deployed + connected
- [ ] Woodpecker IngressRoute configured
- [ ] Nginx upstream → MetalLB IP
- [ ] Cloudflare DNS + Origin Rule
- [ ] `.woodpecker.yml` ใน repository
- [ ] Woodpecker secrets configured (docker_username, docker_password, k3s_kubeconfig)
- [ ] Push trigger pipeline สำเร็จ
- [ ] App เข้าถึงได้จาก Internet

---

## 🔑 คำสั่งที่ใช้บ่อย

```bash
# ดู pods ทั้งหมด
kubectl get pods -A

# ดู logs ของ pod
kubectl logs -f -n three-tier deployment/api

# Restart deployment (force pull image ใหม่)
kubectl rollout restart deployment/api -n three-tier

# ดู resource usage
kubectl top pods -n three-tier

# เข้า shell ใน pod
kubectl exec -it -n three-tier deployment/mongodb -- bash

# ดู events (debug)
kubectl get events -n three-tier --sort-by='.lastTimestamp'

# Port-forward สำหรับ debug
kubectl port-forward -n three-tier svc/api 3500:3500

# Scale replicas
kubectl scale deployment/api -n three-tier --replicas=3
```
