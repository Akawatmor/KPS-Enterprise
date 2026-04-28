# 🛠️ Step-by-Step: ติดตั้ง K3s Cluster ทำมือ ละเอียดทุกขั้นตอน

## 📋 สิ่งที่จะได้ตอนจบ

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  VM1 (k3s-main): K3s Server + App Pods                 │
│  ├── PostgreSQL                                         │
│  ├── Go Backend (×2)                                    │
│  ├── Next.js Frontend (×1)                              │
│  ├── Traefik (built-in)                                 │
│  ├── MetalLB                                            │
│  └── Woodpecker Server                                  │
│                                                         │
│  VM2 (k3s-ci): K3s Agent + CI Pods                     │
│  └── Woodpecker Agent + Pipeline containers             │
│                                                         │
│  Nginx (existing) → Traefik → Pods                     │
│  CF Proxy ON → TrueDDNS → Nginx → K3s                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 0: Proxmox — สร้าง VM

### 0.1 Download Ubuntu Server ISO

```bash
# บน Proxmox host
cd /var/lib/vz/template/iso/
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
```

### 0.2 สร้าง VM1: k3s-main

```
Proxmox Web UI → Create VM

Tab: General
├── VM ID:    201
├── Name:     k3s-main

Tab: OS
├── ISO:      ubuntu-24.04-live-server-amd64.iso

Tab: System
├── BIOS:     OVMF (UEFI)    หรือ SeaBIOS (ง่ายกว่า)
├── Machine:  q35
├── SCSI Controller: VirtIO SCSI single
├── Qemu Agent: ✅ Enabled

Tab: Disks
├── Bus:      VirtIO Block (หรือ SCSI)
├── Storage:  local-lvm
├── Size:     45 GB
├── Discard:  ✅ (SSD trim)
├── SSD emulation: ✅
├── IO Thread: ✅

Tab: CPU
├── Cores:    6
├── Type:     host          ← สำคัญ! ได้ AES-NI, AVX2

Tab: Memory
├── Memory:   24576 (24 GB)
├── Ballooning: ✅ Enabled
├── Minimum:  8192 (8 GB)

Tab: Network
├── Bridge:   vmbr0
├── Model:    VirtIO (paravirtualized)
├── Firewall: ❌ Off (K3s จัดการเอง)
```

### 0.3 สร้าง VM2: k3s-ci

```
เหมือน VM1 แต่เปลี่ยน:
├── VM ID:    202
├── Name:     k3s-ci
├── Disk:     35 GB
├── Cores:    4
├── Memory:   12288 (12 GB)
├── Minimum:  4096 (4 GB)
```

### 0.4 Install Ubuntu ทั้ง 2 VM

```
Boot VM → Ubuntu Installer

Language: English
Keyboard: English
Network: DHCP (จด IP ไว้) หรือ Static ดีกว่า:

VM1 Static IP example:
├── Subnet:  192.168.1.0/24
├── Address: 192.168.1.201
├── Gateway: 192.168.1.1
├── DNS:     1.1.1.1, 8.8.8.8

VM2 Static IP example:
├── Address: 192.168.1.202

Storage: Use entire disk (LVM)
Profile:
├── Name:     k3sadmin
├── Server:   k3s-main (หรือ k3s-ci)
├── Username: k3sadmin
├── Password: <strong password>

OpenSSH: ✅ Install
Featured Snaps: ❌ ไม่เลือกอะไร

→ Install → Reboot
```

---

## Phase 1: OS Configuration (ทำทั้ง 2 VMs)

### 1.1 SSH เข้า VM

```bash
# จากเครื่อง host หรือเครื่องตัวเอง
ssh k3sadmin@192.168.1.201    # VM1
ssh k3sadmin@192.168.1.202    # VM2
```

### 1.2 Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  curl \
  wget \
  git \
  htop \
  net-tools \
  jq \
  unzip \
  qemu-guest-agent

# เปิด QEMU Guest Agent (Proxmox ใช้)
sudo systemctl enable --now qemu-guest-agent
```

### 1.3 ตั้ง Hostname (ถ้ายังไม่ได้ตั้ง)

```bash
# VM1
sudo hostnamectl set-hostname k3s-main

# VM2
sudo hostnamectl set-hostname k3s-ci
```

### 1.4 แก้ /etc/hosts (ทั้ง 2 VMs)

```bash
sudo tee -a /etc/hosts << 'EOF'
192.168.1.201  k3s-main
192.168.1.202  k3s-ci
EOF
```

### 1.5 Kernel Parameters (ทั้ง 2 VMs)

```bash
cat << 'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
# ── Network ──
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
net.core.somaxconn                  = 65535
net.ipv4.ip_local_port_range        = 1024 65535

# ── Memory (สำหรับ 800MT/s RAM) ──
vm.swappiness                       = 5
vm.dirty_ratio                      = 20
vm.dirty_background_ratio           = 5
vm.vfs_cache_pressure               = 50

# ── File limits ──
fs.file-max                         = 2097152
fs.inotify.max_user_instances       = 8192
fs.inotify.max_user_watches         = 524288
EOF

sudo sysctl --system
```

### 1.6 Disable Swap

```bash
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# verify
free -h    # Swap ต้องเป็น 0
```

### 1.7 Disable Transparent Hugepages (ช่วย PostgreSQL)

```bash
# VM1 เท่านั้น (มี PostgreSQL)
cat << 'EOF' | sudo tee /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=basic.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=basic.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-thp
```

### 1.8 Firewall (ทั้ง 2 VMs)

```bash
# ปิด UFW (K3s ใช้ iptables เอง)
sudo ufw disable
sudo systemctl disable ufw

# หรือถ้าอยากเปิด UFW ต้อง allow:
# sudo ufw allow 6443/tcp      # K3s API
# sudo ufw allow 10250/tcp     # Kubelet
# sudo ufw allow 8472/udp      # Flannel VXLAN
# sudo ufw allow 51820/udp     # Flannel WireGuard
# sudo ufw allow 80/tcp        # Traefik HTTP
# sudo ufw allow 443/tcp       # Traefik HTTPS
```

### 1.9 Reboot

```bash
sudo reboot
```

---

## Phase 2: K3s Server (VM1 เท่านั้น)

### 2.1 Install K3s Server

```bash
# SSH เข้า VM1
ssh k3sadmin@192.168.1.201

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="\
  server \
  --write-kubeconfig-mode 644 \
  --disable servicelb \
  --disable local-storage \
  --tls-san 192.168.1.201 \
  --tls-san k3s-main \
  --node-label role=main \
  --kubelet-arg=image-gc-high-threshold=70 \
  --kubelet-arg=image-gc-low-threshold=50 \
  --kubelet-arg=eviction-hard=memory.available<256Mi,nodefs.available<5% \
  --kubelet-arg=system-reserved=cpu=300m,memory=512Mi \
  --kubelet-arg=kube-reserved=cpu=300m,memory=512Mi \
" sh -
```

### 2.2 Verify K3s Server

```bash
# รอ 30-60 วินาที แล้วเช็ค
sudo systemctl status k3s

# ดู node
kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# k3s-main   Ready    control-plane,master   1m    v1.31.x+k3s1

# ดู system pods
kubectl get pods -A
# NAMESPACE     NAME                                     READY   STATUS
# kube-system   coredns-xxx                              1/1     Running
# kube-system   traefik-xxx                              1/1     Running
# kube-system   metrics-server-xxx                       1/1     Running
# kube-system   local-path-provisioner-xxx               1/1     Running
```

### 2.3 จด Node Token (ใช้ตอนเพิ่ม Agent)

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# K10xxxxxxxxxxxxxxxxxxxxxxxxxxxx::server:xxxxxxxxxxxxxxxx
# เก็บ token นี้ไว้!
```

### 2.4 Copy kubeconfig ไว้ใช้จากเครื่องอื่น (optional)

```bash
# ดู kubeconfig
cat /etc/rancher/k3s/k3s.yaml

# copy ไปเครื่องตัวเอง
# เปลี่ยน server: https://127.0.0.1:6443
# เป็น  server: https://192.168.1.201:6443
```

---

## Phase 3: K3s Agent (VM2 เท่านั้น)

### 3.1 Install K3s Agent

```bash
# SSH เข้า VM2
ssh k3sadmin@192.168.1.202

# ใส่ token จาก Phase 2.3
curl -sfL https://get.k3s.io | K3S_URL="https://192.168.1.201:6443" \
  K3S_TOKEN="K10xxxxxxxxxxxxxxxxxxxxxxxxxxxx::server:xxxxxxxxxxxxxxxx" \
  INSTALL_K3S_EXEC="\
  agent \
  --node-label role=ci \
  --kubelet-arg=image-gc-high-threshold=65 \
  --kubelet-arg=image-gc-low-threshold=40 \
  --kubelet-arg=eviction-hard=memory.available<256Mi,nodefs.available<5% \
  --kubelet-arg=system-reserved=cpu=200m,memory=256Mi \
  --kubelet-arg=kube-reserved=cpu=200m,memory=256Mi \
" sh -
```

### 3.2 Verify Agent (กลับไปที่ VM1)

```bash
# SSH เข้า VM1
ssh k3sadmin@192.168.1.201

kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# k3s-main   Ready    control-plane,master   5m    v1.31.x
# k3s-ci     Ready    <none>                 1m    v1.31.x

# ดู labels
kubectl get nodes --show-labels
# k3s-main: role=main
# k3s-ci:   role=ci
```

### 3.3 Taint CI Node (ไม่ให้ App pods ไป schedule)

```bash
# ทำที่ VM1
kubectl taint nodes k3s-ci dedicated=ci:NoSchedule
```

---

## Phase 4: MetalLB

### 4.1 Install MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# รอ pods ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=120s

kubectl get pods -n metallb-system
# NAME                          READY   STATUS
# controller-xxx                1/1     Running
# speaker-xxx                   1/1     Running
# speaker-xxx                   1/1     Running
```

### 4.2 Configure IP Pool

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.240-192.168.1.250
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

### 4.3 Verify MetalLB

```bash
kubectl get ipaddresspool -n metallb-system
# NAME           AUTO ASSIGN   AVOID BUGGY IPS
# default-pool   true          false
```

---

## Phase 5: Traefik Configuration

### 5.1 Configure Traefik (Trust Nginx Proxy)

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
      - "--entrypoints.web.forwardedHeaders.trustedIPs=192.168.1.171/32"
      - "--api.dashboard=true"
      - "--api.insecure=true"
    logs:
      general:
        level: WARN
      access:
        enabled: true
        format: json
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 500m
        memory: 256Mi
    nodeSelector:
      role: main
EOF

# Traefik จะ restart อัตโนมัติ
# รอ 30-60 วินาที
kubectl rollout status deployment traefik -n kube-system
```

### 5.2 Verify Traefik ได้ MetalLB IP

```bash
kubectl get svc -n kube-system traefik
# NAME      TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)
# traefik   LoadBalancer   10.43.x.x     192.168.1.240   80:3xxxx/TCP,443:3xxxx/TCP
```

```
✅ EXTERNAL-IP = 192.168.1.240
จำ IP นี้ไว้ — ใส่ใน Nginx upstream
```

---

## Phase 6: Namespaces + Secrets

### 6.1 Create Namespaces

```bash
kubectl create namespace app
kubectl create namespace woodpecker
```

### 6.2 Create Secrets

```bash
# ── PostgreSQL Secret ──
kubectl create secret generic pg-secret \
  --namespace app \
  --from-literal=username=todouser \
  --from-literal=password='YourStr0ngP@ssword!' \
  --from-literal=database=todoapp \
  --from-literal=url='postgres://todouser:YourStr0ngP@ssword!@postgresql:5432/todoapp?sslmode=disable'

# ── Docker Hub Secret (สำหรับ pull private images) ──
kubectl create secret docker-registry dockerhub-cred \
  --namespace app \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=your@email.com

# Copy ไป namespace woodpecker ด้วย
kubectl create secret docker-registry dockerhub-cred \
  --namespace woodpecker \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=your@email.com

# Verify
kubectl get secrets -n app
kubectl get secrets -n woodpecker
```

---

## Phase 7: PostgreSQL

### 7.1 สร้าง Data Directory บน VM1

```bash
# SSH เข้า VM1
sudo mkdir -p /opt/pg-data
sudo chmod 777 /opt/pg-data
```

### 7.2 Deploy PostgreSQL

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: app
  labels:
    app: postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      nodeSelector:
        role: main
      containers:
      - name: postgresql
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: pg-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: pg-secret
              key: password
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: pg-secret
              key: database
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        args:
          - "-c"
          - "shared_buffers=256MB"
          - "-c"
          - "effective_cache_size=8GB"
          - "-c"
          - "work_mem=16MB"
          - "-c"
          - "maintenance_work_mem=64MB"
          - "-c"
          - "random_page_cost=1.1"
          - "-c"
          - "effective_io_concurrency=200"
          - "-c"
          - "max_connections=50"
          - "-c"
          - "synchronous_commit=off"
          - "-c"
          - "checkpoint_completion_target=0.9"
          - "-c"
          - "wal_buffers=16MB"
          - "-c"
          - "huge_pages=try"
        resources:
          requests:
            cpu: 200m
            memory: 384Mi
          limits:
            cpu: "1"
            memory: 1Gi
        volumeMounts:
        - name: pg-data
          mountPath: /var/lib/postgresql/data
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - todouser
            - -d
            - todoapp
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - todouser
            - -d
            - todoapp
          initialDelaySeconds: 15
          periodSeconds: 20
      volumes:
      - name: pg-data
        hostPath:
          path: /opt/pg-data
          type: DirectoryOrCreate
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: app
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None
EOF
```

### 7.3 Verify PostgreSQL

```bash
kubectl get pods -n app -l app=postgresql
# NAME                          READY   STATUS    AGE
# postgresql-xxxxxxxxxx-xxxxx   1/1     Running   30s

# ดู logs
kubectl logs -n app -l app=postgresql

# ทดสอบ connect
kubectl exec -it -n app deployment/postgresql -- \
  psql -U todouser -d todoapp -c "SELECT version();"

# ควรเห็น:
# PostgreSQL 16.x on x86_64-pc-linux-musl, compiled by gcc...
```

---

## Phase 8: Go Backend

### 8.1 สร้าง Go Project (บนเครื่องตัวเอง)

```bash
mkdir -p ~/kps-enterprise/backend
cd ~/kps-enterprise/backend

go mod init github.com/yourusername/kps-backend
```

### 8.2 โค้ด Backend (Minimal — ทดสอบ deploy ก่อน)

```go
// main.go
package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/lib/pq"
)

var db *sql.DB

type HealthResponse struct {
	Status    string `json:"status"`
	Timestamp string `json:"timestamp"`
	Database  string `json:"database"`
}

type Todo struct {
	ID        int       `json:"id"`
	Title     string    `json:"title"`
	Completed bool      `json:"completed"`
	CreatedAt time.Time `json:"created_at"`
}

func main() {
	// ── Database Connection ──
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://todouser:password@localhost:5432/todoapp?sslmode=disable"
	}

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(30 * time.Minute)

	// ── Init Table ──
	initDB()

	// ── Routes ──
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", healthHandler)
	mux.HandleFunc("GET /api/todos", getTodosHandler)
	mux.HandleFunc("POST /api/todos", createTodoHandler)
	mux.HandleFunc("DELETE /api/todos/{id}", deleteTodoHandler)

	// ── Server ──
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	server := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	log.Printf("Backend starting on :%s", port)
	log.Fatal(server.ListenAndServe())
}

func initDB() {
	query := `
	CREATE TABLE IF NOT EXISTS todos (
		id SERIAL PRIMARY KEY,
		title TEXT NOT NULL,
		completed BOOLEAN DEFAULT false,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`
	_, err := db.Exec(query)
	if err != nil {
		log.Fatal("Failed to init database:", err)
	}
	log.Println("Database initialized")
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	dbStatus := "connected"
	if err := db.Ping(); err != nil {
		dbStatus = "disconnected: " + err.Error()
	}
	json.NewEncoder(w).Encode(HealthResponse{
		Status:    "ok",
		Timestamp: time.Now().Format(time.RFC3339),
		Database:  dbStatus,
	})
}

func getTodosHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, title, completed, created_at FROM todos ORDER BY created_at DESC")
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()

	todos := []Todo{}
	for rows.Next() {
		var t Todo
		rows.Scan(&t.ID, &t.Title, &t.Completed, &t.CreatedAt)
		todos = append(todos, t)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(todos)
}

func createTodoHandler(w http.ResponseWriter, r *http.Request) {
	var t Todo
	json.NewDecoder(r.Body).Decode(&t)
	err := db.QueryRow(
		"INSERT INTO todos (title, completed) VALUES ($1, $2) RETURNING id, created_at",
		t.Title, t.Completed,
	).Scan(&t.ID, &t.CreatedAt)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(t)
}

func deleteTodoHandler(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	_, err := db.Exec("DELETE FROM todos WHERE id = $1", id)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

```bash
# ติดตั้ง dependency
go get github.com/lib/pq
go mod tidy
```

### 8.3 Dockerfile (Backend)

```dockerfile
# backend/Dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /server .

FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /server /server
EXPOSE 8000
ENTRYPOINT ["/server"]
```

### 8.4 Build & Push to Docker Hub

```bash
cd ~/kps-enterprise/backend

# Build
docker build -t YOUR_DOCKERHUB/kps-backend:v1 .

# Test locally (optional)
docker run --rm -p 8000:8000 \
  -e DATABASE_URL="postgres://todouser:password@host.docker.internal:5432/todoapp?sslmode=disable" \
  YOUR_DOCKERHUB/kps-backend:v1

# Push
docker login
docker push YOUR_DOCKERHUB/kps-backend:v1
docker tag YOUR_DOCKERHUB/kps-backend:v1 YOUR_DOCKERHUB/kps-backend:latest
docker push YOUR_DOCKERHUB/kps-backend:latest
```

### 8.5 Deploy Backend to K3s

```bash
# กลับไปที่ VM1
ssh k3sadmin@192.168.1.201

cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: app
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      nodeSelector:
        role: main
      imagePullSecrets:
      - name: dockerhub-cred
      containers:
      - name: backend
        image: YOUR_DOCKERHUB/kps-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: pg-secret
              key: url
        - name: GOMAXPROCS
          value: "2"
        - name: GOMEMLIMIT
          value: "200MiB"
        resources:
          requests:
            cpu: 50m
            memory: 16Mi
          limits:
            cpu: 500m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /api/health
            port: 8000
          initialDelaySeconds: 2
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /api/health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: app
spec:
  selector:
    app: backend
  ports:
  - port: 8000
    targetPort: 8000
EOF
```

### 8.6 Verify Backend

```bash
kubectl get pods -n app -l app=backend
# NAME                       READY   STATUS    AGE
# backend-xxxxxxxxxx-xxxxx   1/1     Running   30s
# backend-xxxxxxxxxx-yyyyy   1/1     Running   30s

# ดู logs
kubectl logs -n app -l app=backend

# ทดสอบ API
kubectl exec -it -n app deployment/backend -- /bin/sh
# ❌ scratch image ไม่มี shell

# ใช้ port-forward แทน
kubectl port-forward -n app svc/backend 8000:8000 &
curl http://localhost:8000/api/health
# {"status":"ok","timestamp":"...","database":"connected"}

curl -X POST http://localhost:8000/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test todo","completed":false}'
# {"id":1,"title":"Test todo","completed":false,"created_at":"..."}

curl http://localhost:8000/api/todos
# [{"id":1,"title":"Test todo","completed":false,"created_at":"..."}]

# หยุด port-forward
kill %1
```

---

## Phase 9: Next.js Frontend

### 9.1 สร้าง Next.js Project (บนเครื่องตัวเอง)

```bash
cd ~/kps-enterprise
npx create-next-app@latest frontend --typescript --tailwind --app --src-dir --no-eslint
cd frontend
```

### 9.2 Minimal Frontend (ทดสอบ deploy ก่อน)

```tsx
// src/app/page.tsx
export default async function Home() {
  return (
    <main className="min-h-screen p-8">
      <h1 className="text-3xl font-bold mb-4">KPS Todo App</h1>
      <p className="text-gray-600">Frontend is running! 🚀</p>
      <p className="text-sm text-gray-400 mt-2">
        API: {process.env.NEXT_PUBLIC_API_URL || "not set"}
      </p>
    </main>
  );
}
```

### 9.3 next.config.ts (Standalone Mode)

```typescript
// next.config.ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone", // สำคัญ! ลด image size
};

export default nextConfig;
```

### 9.4 Dockerfile (Frontend)

```dockerfile
# frontend/Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
CMD ["node", "server.js"]
```

### 9.5 Build & Push

```bash
cd ~/kps-enterprise/frontend
docker build -t YOUR_DOCKERHUB/kps-frontend:v1 .
docker push YOUR_DOCKERHUB/kps-frontend:v1
docker tag YOUR_DOCKERHUB/kps-frontend:v1 YOUR_DOCKERHUB/kps-frontend:latest
docker push YOUR_DOCKERHUB/kps-frontend:latest
```

### 9.6 Deploy Frontend to K3s

```bash
# VM1
cat << 'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: app
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      nodeSelector:
        role: main
      imagePullSecrets:
      - name: dockerhub-cred
      containers:
      - name: frontend
        image: YOUR_DOCKERHUB/kps-frontend:latest
        ports:
        - containerPort: 3000
        env:
        - name: NEXT_PUBLIC_API_URL
          value: "https://todo.akawatmor.com/api"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: app
spec:
  selector:
    app: frontend
  ports:
  - port: 3000
    targetPort: 3000
EOF
```

### 9.7 Verify Frontend

```bash
kubectl get pods -n app -l app=frontend
# NAME                        READY   STATUS    AGE
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   30s

kubectl port-forward -n app svc/frontend 3000:3000 &
curl http://localhost:3000
# ควรได้ HTML ของ Next.js
kill %1
```

---

## Phase 10: Traefik IngressRoutes

### 10.1 Middlewares

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: rate-limit-auth
  namespace: app
spec:
  rateLimit:
    average: 10
    burst: 20
    period: 1s
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: cors-app
  namespace: app
spec:
  headers:
    accessControlAllowMethods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
    accessControlAllowHeaders:
      - Content-Type
      - Authorization
    accessControlAllowOriginList:
      - "https://todo.akawatmor.com"
    accessControlMaxAge: 86400
    addVaryHeader: true
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: app
spec:
  headers:
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: "strict-origin-when-cross-origin"
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    customResponseHeaders:
      X-Powered-By: ""
---
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: compress
  namespace: app
spec:
  compress:
    excludedContentTypes:
      - text/event-stream
EOF
```

### 10.2 IngressRoutes

```bash
cat << 'EOF' | kubectl apply -f -
# ═══ Todo App: Frontend ═══
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: frontend
  namespace: app
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`todo.akawatmor.com`) && !PathPrefix(`/api`)
      kind: Rule
      priority: 1
      services:
        - name: frontend
          port: 3000
      middlewares:
        - name: security-headers
        - name: compress

---
# ═══ Todo App: Backend API ═══
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backend-api
  namespace: app
spec:
  entryPoints:
    - web
  routes:
    # Health (no middleware)
    - match: Host(`todo.akawatmor.com`) && Path(`/api/health`)
      kind: Rule
      priority: 60
      services:
        - name: backend
          port: 8000

    # Auth (rate limited)
    - match: Host(`todo.akawatmor.com`) && PathPrefix(`/api/auth`)
      kind: Rule
      priority: 50
      services:
        - name: backend
          port: 8000
      middlewares:
        - name: cors-app
        - name: security-headers
        - name: rate-limit-auth

    # WebSocket
    - match: Host(`todo.akawatmor.com`) && PathPrefix(`/api/ws`)
      kind: Rule
      priority: 50
      services:
        - name: backend
          port: 8000
      middlewares:
        - name: cors-app

    # All other API
    - match: Host(`todo.akawatmor.com`) && PathPrefix(`/api`)
      kind: Rule
      priority: 10
      services:
        - name: backend
          port: 8000
      middlewares:
        - name: cors-app
        - name: security-headers
        - name: compress

---
# ═══ Traefik Dashboard ═══
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`traefik.akawatmor.com`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
EOF
```

### 10.3 Verify IngressRoutes

```bash
kubectl get ingressroute -A
# NAMESPACE     NAME                AGE
# app           frontend            10s
# app           backend-api         10s
# kube-system   traefik-dashboard   10s

kubectl get middleware -A
# NAMESPACE   NAME               AGE
# app         rate-limit-auth    30s
# app         cors-app           30s
# app         security-headers   30s
# app         compress           30s
```

---

## Phase 11: ทดสอบจากภายใน LAN

### 11.1 ทดสอบผ่าน MetalLB IP

```bash
# จาก VM1 หรือเครื่องอื่นใน LAN
# ต้องใส่ Host header เพราะ Traefik route ตาม hostname

# Frontend
curl -H "Host: todo.akawatmor.com" http://192.168.1.240/
# ได้ HTML

# Backend Health
curl -H "Host: todo.akawatmor.com" http://192.168.1.240/api/health
# {"status":"ok","timestamp":"...","database":"connected"}

# Backend CRUD
curl -H "Host: todo.akawatmor.com" \
     -X POST http://192.168.1.240/api/todos \
     -H "Content-Type: application/json" \
     -d '{"title":"First real todo!","completed":false}'

curl -H "Host: todo.akawatmor.com" http://192.168.1.240/api/todos

# Traefik Dashboard
curl -H "Host: traefik.akawatmor.com" http://192.168.1.240/
```

### 11.2 ทดสอบจาก Browser (เครื่องใน LAN)

```bash
# เพิ่มใน /etc/hosts ของเครื่องที่จะเปิด browser
# (หรือ C:\Windows\System32\drivers\etc\hosts บน Windows)
echo "192.168.1.240 todo.akawatmor.com traefik.akawatmor.com ci.akawatmor.com" \
  | sudo tee -a /etc/hosts

# เปิด Browser:
# http://todo.akawatmor.com         → Frontend
# http://todo.akawatmor.com/api/health → Backend
# http://traefik.akawatmor.com      → Dashboard
```

---

## Phase 12: Nginx (Update Upstream)

### 12.1 แก้ Nginx Config

```bash
# SSH เข้าเครื่อง Nginx (192.168.1.171)

sudo nano /etc/nginx/conf.d/k3s.conf
```

```nginx
# /etc/nginx/conf.d/k3s.conf

upstream k3s {
    server 192.168.1.240:80;     # MetalLB IP → Traefik
    keepalive 256;
    keepalive_requests 10000;
    keepalive_timeout 60s;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      '';
}

server {
    listen 56260 ssl;
    listen 56260 quic reuseport;
    http2 on;

    server_name
        todo.akawatmor.com
        ci.akawatmor.com
        traefik.akawatmor.com;

    # SSL cert (จัดการแล้ว)
    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    ssl_protocols TLSv1.3;
    add_header Alt-Svc 'h3=":56260"; ma=86400' always;

    location / {
        proxy_pass http://k3s;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port  $server_port;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        $connection_upgrade;
        proxy_buffering off;
        proxy_redirect off;
        proxy_read_timeout  86400s;
        proxy_send_timeout  86400s;
    }
}
```

### 12.2 Test & Reload Nginx

```bash
sudo nginx -t
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful

sudo nginx -s reload
```

### 12.3 ทดสอบผ่าน Nginx (LAN)

```bash
# จากเครื่องอื่นใน LAN
curl -k https://todo.akawatmor.com:56260/api/health
# {"status":"ok","timestamp":"...","database":"connected"}
```

---

## Phase 13: Cloudflare DNS + Origin Rule

### 13.1 DNS Records

```
Cloudflare Dashboard → DNS → Records

Type   Name      Content                  Proxy    TTL
─────  ────────  ───────────────────────  ───────  ────
CNAME  todo      yourname.trueddns.com    🟠 ON    Auto
CNAME  ci        yourname.trueddns.com    🟠 ON    Auto
CNAME  traefik   yourname.trueddns.com    🟠 ON    Auto
```

### 13.2 Origin Rule

```
Cloudflare Dashboard → Rules → Origin Rules → Create Rule

Rule name:  "K3s Port Rewrite"

When:
  Hostname equals "todo.akawatmor.com"
  OR Hostname equals "ci.akawatmor.com"
  OR Hostname equals "traefik.akawatmor.com"

Then:
  Destination Port → Rewrite to → 56260

→ Deploy
```

### 13.3 SSL/TLS Setting

```
Cloudflare Dashboard → SSL/TLS → Overview

Encryption mode: Full (Strict)
← เพราะ Nginx มี valid cert แล้ว
   ถ้า self-signed ใช้ "Full" (ไม่ Strict)
```

### 13.4 ทดสอบจากภายนอก

```bash
# จากเครื่องอื่น (มือถือ, 4G, VPN ออกนอก)
curl https://todo.akawatmor.com/api/health
# {"status":"ok","timestamp":"...","database":"connected"}

# เปิด Browser
# https://todo.akawatmor.com → Frontend
```

---

## Phase 14: ตรวจสอบทั้งระบบ

### 14.1 Checklist

```bash
# ── Nodes ──
kubectl get nodes -o wide
# 2 nodes, STATUS Ready

# ── All Pods ──
kubectl get pods -A
# kube-system:  coredns, traefik, metallb-controller, metallb-speaker, metrics-server
# app:          postgresql, backend(×2), frontend

# ── Services ──
kubectl get svc -A
# kube-system: traefik (LoadBalancer, EXTERNAL-IP: 192.168.1.240)
# app:         postgresql (ClusterIP None), backend (ClusterIP), frontend (ClusterIP)

# ── IngressRoutes ──
kubectl get ingressroute -A

# ── Resource Usage ──
kubectl top nodes
kubectl top pods -n app
```

### 14.2 Full Path Test

```bash
echo "=== Test 1: Internal (MetalLB) ==="
curl -s -H "Host: todo.akawatmor.com" http://192.168.1.240/api/health | jq

echo "=== Test 2: Via Nginx (LAN) ==="
curl -sk https://todo.akawatmor.com:56260/api/health | jq

echo "=== Test 3: Via Cloudflare (Internet) ==="
curl -s https://todo.akawatmor.com/api/health | jq

echo "=== Test 4: CRUD ==="
# Create
curl -s https://todo.akawatmor.com/api/todos \
  -X POST -H "Content-Type: application/json" \
  -d '{"title":"Hello from internet!"}' | jq

# Read
curl -s https://todo.akawatmor.com/api/todos | jq

echo "=== Test 5: Traefik Dashboard ==="
curl -s -o /dev/null -w "%{http_code}" https://traefik.akawatmor.com/
# 200
```

---

## 📊 สรุปสิ่งที่ได้

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  ✅ K3s Cluster: 1 cluster, 2 nodes                           │
│                                                                │
│  ✅ VM1 (k3s-main): 6C / 24GB / 45GB                          │
│     ├── K3s Server (control plane)                             │
│     ├── Traefik (ingress + routing)                            │
│     ├── MetalLB (IP: 192.168.1.240)                            │
│     ├── PostgreSQL (1 pod)                                     │
│     ├── Go Backend (2 pods)                                    │
│     └── Next.js Frontend (1 pod)                               │
│                                                                │
│  ✅ VM2 (k3s-ci): 4C / 12GB / 35GB                            │
│     └── (พร้อมสำหรับ Woodpecker CI — Phase ถัดไป)               │
│                                                                │
│  ✅ Network Path:                                              │
│     Internet → CF Edge → :56260 → TrueDDNS                    │
│     → Nginx QUIC → MetalLB → Traefik → Pods                   │
│                                                                │
│  ✅ URLs:                                                      │
│     https://todo.akawatmor.com     → Todo App                 │
│     https://traefik.akawatmor.com  → Dashboard                │
│     https://ci.akawatmor.com       → Woodpecker (ยังไม่ลง)    │
│                                                                │
│  ⏳ ยังเหลือ:                                                  │
│     - Woodpecker CI/CD (Phase ถัดไป)                           │
│     - Tailscale (team access)                                  │
│     - App features (auth, calendar, noti)                      │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**ต้องการให้ทำ Woodpecker CI setup ต่อไหม?**
