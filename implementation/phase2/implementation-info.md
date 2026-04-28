# 🚀 K3s Deploy + Woodpecker CI/CD Pipeline (Debian 13)

```
Stack: Next.js 14 (Frontend) · Go 1.25 (Backend) · SQLite (DB via PVC)
OS:    Debian 13 (Trixie)
CI/CD: Woodpecker CI
Storage: local-path PVC (SQLite) — ไม่ใช้ iSCSI สำหรับ app นี้
```

---

## ✅ Prerequisites (สิ่งที่ต้องมีก่อนเริ่ม)

| สิ่งที่ต้องการ | รายละเอียด |
|---|---|
| Proxmox VE | สร้าง VM ได้ (ทดสอบบน Proxmox 8.x) |
| Debian 13 ISO | `debian-testing-amd64-netinst.iso` |
| IP สำหรับ VMs | 192.168.111.42 / .43 / .44 |
| IP สำหรับ MetalLB | 192.168.111.200-210 (ว่างในวง LAN) |
| Synology NAS | 192.168.111.10, iSCSI enabled, MTU 9000 |
| Docker Hub account | สำหรับ push images |
| Gitea server | สำหรับ Woodpecker OAuth + webhook |
| Domain + Cloudflare | สำหรับ public HTTPS |
| Nginx (existing) | 192.168.111.171 ← reverse proxy |

> **ก่อน Phase 0:** ตั้งค่า iSCSI บน Synology NAS ให้เรียบร้อยก่อน (Phase 7.0)

---

## 📋 ภาพรวม Cluster

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  VM1 (k3s-main): K3s Server + App Pods                 │
│  ├── PostgreSQL (iSCSI → Synology NAS)                  │
│  ├── Go Backend (×2)                                    │
│  ├── Next.js Frontend (×1)                              │
│  ├── Traefik (built-in)                                 │
│  ├── MetalLB                                            │
│  └── Woodpecker Server                                  │
│                                                         │
│  VM2 (k3s-worker): K3s Agent                           │
│  └── App workloads (role=worker)                        │
│                                                         │
│  VM3 (k3s-ci): K3s Agent + CI Pods                     │
│  └── Woodpecker Agent + Pipeline containers             │
│                                                         │
│  Synology NAS — 192.168.111.10 (MTU 9000)              │
│  └── iSCSI LUN 16GB → PostgreSQL                       │
│                                                         │
│  Nginx (existing) → Traefik → Pods                     │
│  CF Proxy ON → TrueDDNS → Nginx → K3s                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

```
Phase 0  → Proxmox — สร้าง VM
Phase 1  → OS Configuration (Debian 13)
Phase 2  → K3s Server (VM1)
Phase 3  → K3s Agent (VM2, VM3)
Phase 4  → MetalLB
Phase 5  → Traefik Configuration
Phase 6  → Namespaces + Secrets
Phase 7  → PostgreSQL + iSCSI Storage (Synology)
Phase 8  → Go Backend Deploy
Phase 9  → Next.js Frontend Deploy
Phase 10 → Traefik IngressRoutes
Phase 11 → Woodpecker CI/CD (Main)
Phase 12 → Pipeline Features (ลูกเล่น)
Phase 13 → ทดสอบ End-to-End
Q&A      → 10 ข้อที่อาจารย์อาจถาม
```

---

## Phase 0: Proxmox — สร้าง VM

### 0.1 Download Debian 13 ISO

```bash
# บน Proxmox host
cd /var/lib/vz/template/iso/
wget https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/debian-testing-amd64-netinst.iso
```

### 0.2 สร้าง VM1: k3s-main

```
Proxmox Web UI → Create VM

Tab: General
├── VM ID:    201
├── Name:     k3s-main

Tab: OS
├── ISO:      debian-testing-amd64-netinst.iso

Tab: System
├── BIOS:     OVMF (UEFI) หรือ SeaBIOS (ง่ายกว่า)
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
├── Cores:    4
├── Type:     host    ← สำคัญ! ได้ AES-NI, AVX2

Tab: Memory
├── Memory:   12288 (12 GB)
├── Ballooning: ✅ Enabled
├── Minimum:  4096 (4 GB)

Tab: Network
├── Bridge:   vmbr0
├── Model:    VirtIO (paravirtualized)
├── Firewall: ❌ Off (K3s จัดการเอง)
```

### 0.3 สร้าง VM2: k3s-worker

```
เหมือน VM1 แต่เปลี่ยน:
├── VM ID:    202
├── Name:     k3s-worker
├── Disk:     35 GB
├── Cores:    3
├── Memory:   8192 (8 GB)
└── Minimum:  4096 (4 GB)
```

### 0.4 สร้าง VM3: k3s-ci

```
เหมือน VM2:
├── VM ID:    203
├── Name:     k3s-ci
├── Disk:     35 GB
├── Cores:    3
├── Memory:   8192 (8 GB)
└── Minimum:  4096 (4 GB)
```

### 0.5 Install Debian 13 ทั้ง 3 VM

```
Boot VM → Debian Installer

Language: English
Country/Region: Thailand
Keyboard: American English

Network:
├── Primary interface: ens18 (LAN)
├── Hostname: k3s-main (หรือ k3s-worker / k3s-ci)
├── Domain: (ปล่อยว่าง)

Partitioning: Guided — use entire disk (LVM)

User:
├── Root password: <strong password>
├── Username: k3sadmin
├── Password: <strong password>

Software selection:
├── ✅ SSH server
├── ✅ standard system utilities
└── ❌ ไม่เลือกอื่น (Debian 13 ไม่มี snap)

→ Install → Reboot
```

---

## Phase 1: OS Configuration (ทำทั้ง 3 VMs)

### 1.1 SSH เข้า VM

```bash
ssh k3sadmin@192.168.111.42    # VM1 (k3s-main)
ssh k3sadmin@192.168.111.43    # VM2 (k3s-worker)
ssh k3sadmin@192.168.111.44    # VM3 (k3s-ci)
```

### 1.2 ติดตั้ง Packages

```bash
# ทำทั้ง 3 VMs
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  curl wget git htop net-tools jq unzip \
  qemu-guest-agent ca-certificates gnupg2

sudo systemctl enable --now qemu-guest-agent
```

> **หมายเหตุ Debian 13:** ไม่มี `snap`, ไม่ต้อง `--break-system-packages`
> ใช้ `apt` ตรง ๆ ได้เลย

### 1.3 ตั้ง Hostname

```bash
# VM1
sudo hostnamectl set-hostname k3s-main

# VM2
sudo hostnamectl set-hostname k3s-worker

# VM3
sudo hostnamectl set-hostname k3s-ci
```

### 1.4 แก้ /etc/hosts (ทั้ง 3 VMs)

```bash
sudo tee -a /etc/hosts << 'EOF'
192.168.111.42  k3s-main
192.168.111.43  k3s-worker
192.168.111.44  k3s-ci
EOF
```

### 1.5 Kernel Parameters (ทั้ง 3 VMs)

```bash
cat << 'EOF' | sudo tee /etc/sysctl.d/99-k3s.conf
# ── Network ──
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
net.core.somaxconn                  = 65535
net.ipv4.ip_local_port_range        = 1024 65535

# ── Memory ──
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

### 1.7 Disable Transparent Hugepages (VM1 เท่านั้น — ช่วย PostgreSQL)

```bash
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

### 1.8 Firewall (ทั้ง 3 VMs)

```bash
# Debian 13 ใช้ nftables — ปิดไว้ให้ K3s จัดการ iptables เอง
sudo systemctl disable --now nftables 2>/dev/null || true
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
ssh k3sadmin@192.168.111.42

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="\
  server \
  --write-kubeconfig-mode 644 \
  --disable servicelb \
  --disable local-storage \
  --tls-san 192.168.111.42 \
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
sudo systemctl status k3s

kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# k3s-main   Ready    control-plane,master   1m    v1.31.x+k3s1

kubectl get pods -A
# NAMESPACE     NAME                                     READY   STATUS
# kube-system   coredns-xxx                              1/1     Running
# kube-system   traefik-xxx                              1/1     Running
# kube-system   metrics-server-xxx                       1/1     Running
```

### 2.3 จด Node Token

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
# K10xxxxxxxxxxxxxxxxxxxxxxxxxxxx::server:xxxxxxxxxxxxxxxx
# เก็บ token นี้ไว้!
```

### 2.4 Copy kubeconfig (optional — ใช้จากเครื่องอื่น)

```bash
# เปลี่ยน server: https://127.0.0.1:6443
# เป็น  server: https://192.168.111.42:6443
cat /etc/rancher/k3s/k3s.yaml
```

---

## Phase 3: K3s Agent (VM2 และ VM3)

### 3.1 Install K3s Agent บน VM2 (k3s-worker)

```bash
# SSH เข้า VM2
ssh k3sadmin@192.168.111.43

# ใส่ token จาก Phase 2.3
curl -sfL https://get.k3s.io | K3S_URL="https://192.168.111.42:6443" \
  K3S_TOKEN="K10xxxxxxxxxxxxxxxxxxxxxxxxxxxx::server:xxxxxxxxxxxxxxxx" \
  INSTALL_K3S_EXEC="\
  agent \
  --node-label role=worker \
  --kubelet-arg=image-gc-high-threshold=65 \
  --kubelet-arg=image-gc-low-threshold=40 \
  --kubelet-arg=eviction-hard=memory.available<256Mi,nodefs.available<5% \
  --kubelet-arg=system-reserved=cpu=200m,memory=256Mi \
  --kubelet-arg=kube-reserved=cpu=200m,memory=256Mi \
" sh -
```

### 3.2 Install K3s Agent บน VM3 (k3s-ci)

```bash
# SSH เข้า VM3
ssh k3sadmin@192.168.111.44

curl -sfL https://get.k3s.io | K3S_URL="https://192.168.111.42:6443" \
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

### 3.3 Verify Agents (กลับไปที่ VM1)

```bash
ssh k3sadmin@192.168.111.42

kubectl get nodes
# NAME          STATUS   ROLES                  AGE   VERSION
# k3s-main      Ready    control-plane,master   5m    v1.31.x
# k3s-worker    Ready    <none>                 2m    v1.31.x
# k3s-ci        Ready    <none>                 1m    v1.31.x

kubectl get nodes --show-labels
# k3s-main:   role=main
# k3s-worker: role=worker
# k3s-ci:     role=ci
```

### 3.4 Taint CI Node (VM3 เท่านั้น)

```bash
kubectl taint nodes k3s-ci dedicated=ci:NoSchedule
```

---

## Phase 4: MetalLB

### 4.1 Install MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=120s

kubectl get pods -n metallb-system
# NAME                          READY   STATUS
# controller-xxx                1/1     Running
# speaker-xxx (×3)              1/1     Running
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
    - 192.168.111.200-192.168.111.210
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
      - "--entrypoints.web.forwardedHeaders.trustedIPs=192.168.111.171/32"
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

# รอ Traefik restart
kubectl rollout status deployment traefik -n kube-system
```

### 5.2 Verify Traefik ได้ MetalLB IP

```bash
kubectl get svc -n kube-system traefik
# NAME      TYPE           CLUSTER-IP    EXTERNAL-IP       PORT(S)
# traefik   LoadBalancer   10.43.x.x     192.168.111.200   80:3xxxx/TCP

# ✅ EXTERNAL-IP = 192.168.111.200 → ใส่ใน Nginx upstream
```

---

## Phase 6: Namespaces + Secrets

### 6.1 Create Namespaces

```bash
kubectl create namespace app
kubectl create namespace woodpecker
```

### 6.2 Secrets

```bash
# ── PostgreSQL ──
kubectl create secret generic pg-secret \
  --namespace app \
  --from-literal=username=todouser \
  --from-literal=password='Str0ngP@ss2024!' \
  --from-literal=database=todoapp \
  --from-literal=url='postgres://todouser:Str0ngP@ss2024!@postgresql:5432/todoapp?sslmode=disable'

# ── Docker Hub (namespace: app) ──
kubectl create secret docker-registry dockerhub-cred \
  --namespace app \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=your@email.com

# ── Docker Hub (namespace: woodpecker) ──
kubectl create secret docker-registry dockerhub-cred \
  --namespace woodpecker \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=your@email.com

# ── Woodpecker ──
WOODPECKER_AGENT_SECRET=$(openssl rand -hex 32)
echo "Agent Secret: $WOODPECKER_AGENT_SECRET"   # จด!

kubectl create secret generic woodpecker-secret \
  --namespace woodpecker \
  --from-literal=WOODPECKER_AGENT_SECRET="$WOODPECKER_AGENT_SECRET" \
  --from-literal=WOODPECKER_GITEA_CLIENT=YOUR_GITEA_OAUTH_CLIENT \
  --from-literal=WOODPECKER_GITEA_SECRET=YOUR_GITEA_OAUTH_SECRET

# Verify
kubectl get secrets -n app
kubectl get secrets -n woodpecker
```

---

## Phase 7: PostgreSQL + iSCSI Storage (Synology)

> ```
> Synology NAS  192.168.111.10  (MTU 9000)
> Target IQN:   iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8
> LUN Size:     16 GB
> Network:      192.168.111.x/24 (LAN subnet เดียวกัน)
> ```

---

### 7.0 ตั้งค่า Synology iSCSI (ฝั่ง NAS — ทำก่อน)

```
Synology DSM → Storage Manager → iSCSI Manager

1. LUN
   ├── Create → Thick Provisioning (Better performance)
   ├── Name:     pg-lun
   ├── Size:     16 GB
   └── Location: เลือก Volume ที่ต้องการ

2. Target (ใช้ที่มีอยู่แล้ว)
   └── IQN: iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8

3. Map LUN → Target
   └── iSCSI Manager → Target → Map LUN → เลือก pg-lun

4. Network Interface
   └── Control Panel → Network → Network Interface
       ├── iSCSI NIC: ตั้ง MTU = 9000 (Jumbo Frame)
       └── IP: 192.168.111.10/24
```

---

### 7.1 ติดตั้ง open-iscsi บน VM1 (Debian 13)

```bash
# SSH เข้า VM1
ssh k3sadmin@192.168.111.42

sudo apt update && sudo apt install -y open-iscsi

sudo systemctl enable --now iscsid
sudo systemctl status iscsid
```

---

### 7.2 ตั้งค่า MTU 9000 บน VM1

> **หมายเหตุ:** LAN และ iSCSI ใช้ subnet `192.168.111.x` เดียวกัน จึงตั้ง MTU บน primary NIC ได้เลย
> ต้องแน่ใจว่า **switch port และ Proxmox bridge (vmbr0) รองรับ jumbo frame** ด้วย

```bash
# Proxmox Web UI → Node → Network → vmbr0 → MTU: 9000
# (ทำก่อนตั้ง MTU ใน VM)

# หา primary interface
ip addr show
# สมมติ interface ชื่อ ens18

# ── ตั้ง MTU ถาวรผ่าน /etc/network/interfaces (Debian 13) ──
sudo sed -i '/iface ens18/a\    mtu 9000' /etc/network/interfaces

sudo systemctl restart networking

# Verify MTU
ip link show ens18
# ... mtu 9000 ...

# ทดสอบ Jumbo Frame จริง (packet 8972 + header 28 = 9000)
ping -M do -s 8972 192.168.111.10
# ถ้าผ่าน: bytes from 192.168.111.10: icmp_seq=1 ...
# ถ้าไม่ผ่าน: Frag needed → switch port ยังไม่ได้ enable jumbo frame
# หากไม่แน่ใจ: ใช้ MTU 1500 ก่อนแล้วค่อย optimize ภายหลัง
```

---

### 7.3 Discover + Login iSCSI Target

```bash
# Discover targets บน Synology
sudo iscsiadm -m discovery -t sendtargets -p 192.168.111.10
# 192.168.111.10:3260,1 iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8

# Login
sudo iscsiadm -m node \
  --targetname "iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8" \
  --portal "192.168.111.10:3260" \
  --login

# ตั้ง auto-login หลัง reboot
sudo iscsiadm -m node \
  --targetname "iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8" \
  --portal "192.168.111.10:3260" \
  -o update -n node.startup -v automatic

# Verify — ดู block device ที่ได้มา
lsblk
# sdb   8:16   0   16G  0 disk    ← iSCSI LUN ใหม่

sudo iscsiadm -m session
# tcp: [1] 192.168.111.10:3260,1 iqn.2000-01.com.synology:...
```

---

### 7.4 Format + Label iSCSI Disk

```bash
# ตรวจสอบ disk ด้วย lsblk ก่อนเสมอ!
ISCSI_DISK="/dev/sdb"

# Format เป็น ext4
sudo mkfs.ext4 -L pg-iscsi -E lazy_itable_init=0,lazy_journal_init=0 $ISCSI_DISK

# Verify
sudo blkid $ISCSI_DISK
# /dev/sdb: LABEL="pg-iscsi" UUID="xxxx-xxxx" TYPE="ext4"

DISK_UUID=$(sudo blkid -s UUID -o value $ISCSI_DISK)
echo "UUID: $DISK_UUID"
```

> **ไม่ mount บน OS host** — ให้ Kubernetes จัดการผ่าน PV โดยตรง

---

### 7.5 สร้าง PersistentVolume + PVC (iSCSI)

```bash
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pg-iscsi-pv
  labels:
    app: postgresql
    type: iscsi
spec:
  capacity:
    storage: 16Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain    # ป้องกันลบข้อมูลอัตโนมัติ
  storageClassName: ""                     # static provisioning
  volumeMode: Filesystem
  iscsi:
    targetPortal: 192.168.111.10:3260
    iqn: iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8
    lun: 0
    fsType: ext4
    readOnly: false
    chapAuthDiscovery: false
    chapAuthSession: false
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pg-iscsi-pvc
  namespace: app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  volumeName: pg-iscsi-pv    # bind ตรงๆ กับ PV นี้
  resources:
    requests:
      storage: 16Gi
EOF

# Verify
kubectl get pv pg-iscsi-pv
# NAME          CAPACITY  ACCESS MODES  RECLAIM POLICY  STATUS
# pg-iscsi-pv   16Gi      RWO           Retain          Available

kubectl get pvc -n app pg-iscsi-pvc
# NAME           STATUS  VOLUME        CAPACITY  ACCESS MODES
# pg-iscsi-pvc   Bound   pg-iscsi-pv   16Gi      RWO
# STATUS ต้องเป็น Bound!
```

---

### 7.6 Deploy PostgreSQL (ใช้ iSCSI PVC)

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
    type: Recreate              # iSCSI RWO → ต้อง stop pod เก่าก่อน start ใหม่
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      nodeSelector:
        role: main              # iSCSI login อยู่ที่ VM1 เท่านั้น
      securityContext:
        fsGroup: 999            # postgres GID ใน container
        fsGroupChangePolicy: "OnRootMismatch"
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
          - "-c"
          - "log_min_duration_statement=1000"
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
            command: [pg_isready, -U, todouser, -d, todoapp]
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          exec:
            command: [pg_isready, -U, todouser, -d, todoapp]
          initialDelaySeconds: 15
          periodSeconds: 20
      volumes:
      - name: pg-data
        persistentVolumeClaim:
          claimName: pg-iscsi-pvc
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

### 7.7 Verify PostgreSQL + iSCSI

```bash
kubectl get pods -n app -l app=postgresql
kubectl logs -n app -l app=postgresql --tail=20

# ทดสอบ connect
kubectl exec -it -n app deployment/postgresql -- \
  psql -U todouser -d todoapp -c "SELECT version();"

# ดู disk usage (บน VM1)
df -h | grep sdb

# ทดสอบ Performance
kubectl exec -it -n app deployment/postgresql -- \
  psql -U todouser -d todoapp -c "
    CREATE TABLE IF NOT EXISTS bench (id serial, data text);
    INSERT INTO bench (data) SELECT md5(random()::text) FROM generate_series(1,10000);
    SELECT count(*) FROM bench;
    DROP TABLE bench;
  "
```

---

### 7.8 iSCSI Troubleshooting

```bash
# ── PVC ค้างที่ Pending ──
kubectl describe pvc pg-iscsi-pvc -n app
# ดู Events: อาจเป็น "no volume plugin matched"
# แก้: ตรวจว่า node มี open-iscsi ติดตั้งแล้ว

# ── Pod ค้างที่ ContainerCreating ──
kubectl describe pod -n app -l app=postgresql | tail -20
# Events: Warning FailedMount "iscsiadm: No records found!"
# แก้: login target ใหม่
sudo iscsiadm -m node \
  --targetname "iqn.2000-01.com.synology:PetchSynologyV2.default-target.98f26b345a8" \
  --portal "192.168.111.10:3260" \
  --login

# ── MTU ทำให้ connection drop ──
ping -M do -s 8972 192.168.111.10   # 9000 bytes total (ควรผ่าน ถ้า jumbo frame เปิด)
ping -M do -s 1472 192.168.111.10   # 1500 bytes total (ต้องผ่านเสมอ)
# ถ้า 1472 ผ่านแต่ 8972 ไม่ผ่าน → switch port ยังไม่ได้ enable jumbo frame

# ── iscsid ไม่ start หลัง reboot ──
sudo systemctl status iscsid open-iscsi
sudo systemctl enable open-iscsi iscsid

# ── ดู iSCSI sessions ──
sudo iscsiadm -m session -P 3
```

---

### 7.9 Backup Strategy สำหรับ iSCSI

```bash
# ── Option 1: pg_dump (Application-level) ──
kubectl apply -f - << 'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: pg-backup
  namespace: app
spec:
  schedule: "0 2 * * *"      # ทุกคืน 02:00
  jobTemplate:
    spec:
      template:
        spec:
          nodeSelector:
            role: main
          restartPolicy: OnFailure
          containers:
          - name: pg-backup
            image: postgres:16-alpine
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: pg-secret
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              BACKUP_FILE="/backup/todoapp-$(date +%Y%m%d-%H%M%S).sql.gz"
              pg_dump -h postgresql -U todouser todoapp | gzip > $BACKUP_FILE
              echo "Backup: $BACKUP_FILE"
              find /backup -name "*.sql.gz" -mtime +7 -delete
            volumeMounts:
            - name: backup-vol
              mountPath: /backup
          volumes:
          - name: backup-vol
            hostPath:
              path: /opt/pg-backup
              type: DirectoryOrCreate
EOF

# ── Option 2: Synology Snapshot (Storage-level) ──
# DSM → Storage Manager → LUN → pg-lun → Snapshot → Schedule
```

---

## Phase 8: Go Backend

### 8.1 โครงสร้าง Project

```
repo/                          ← root ของ repository
├── .woodpecker.yml            ← Woodpecker pipeline (single file)
└── src/phase2-final/
    ├── backend/
    │   ├── cmd/server/main.go
    │   ├── internal/          ← handlers, config, models
    │   ├── go.mod             ← module: github.com/KPS-Enterprise/todoapp/backend
    │   ├── go.sum
    │   └── Dockerfile
    ├── frontend/
    │   ├── app/               ← Next.js App Router (.js files)
    │   ├── public/
    │   ├── Dockerfile
    │   ├── next.config.mjs
    │   └── package.json
    └── k8s/                   ← Kustomize manifests
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── configmap.yaml
        ├── core-deployment.yaml
        ├── web-deployment.yaml
        └── ingress.yaml
```

> **หมายเหตุ:** Backend ใช้ SQLite (ไม่ใช่ PostgreSQL) เก็บใน PVC ที่ `/var/lib/todoapp`
> App มี GitHub OAuth login, CalDAV sync, และ reminder system (ซับซ้อนกว่า tutorial)

### 8.2 โค้ด Backend

> **โค้ดจริงอยู่ที่:** `src/phase2-final/backend/`  
> Entrypoint: `cmd/server/main.go` | Module: `github.com/KPS-Enterprise/todoapp/backend`

โครงสร้างหลักของ API:

```
GET  /healthz              → liveness check
GET  /readyz               → readiness check (DB ping)
GET  /api/v1/tasks         → list tasks
POST /api/v1/tasks         → create task
PUT  /api/v1/tasks/{id}    → update task
DELETE /api/v1/tasks/{id}  → delete task
GET  /api/v1/auth/login    → GitHub OAuth redirect
GET  /api/v1/auth/callback → GitHub OAuth callback
```

**Key env vars (จาก configmap.yaml + secret):**

| Variable | ค่า (default) |
|---|---|
| `SERVER_PORT` | `8080` |
| `DATA_BACKEND` | `sqlite` |
| `SQLITE_PATH` | `/var/lib/todoapp/todoapp.db` |
| `ALLOWED_ORIGIN` | `https://todoapp-kps.akawatmor.com` |
| `GITHUB_OAUTH_CLIENT_ID` | จาก secret |
| `GITHUB_OAUTH_CLIENT_SECRET` | จาก secret |

### 8.3 Dockerfile (Multi-stage)

```dockerfile
# src/phase2-final/backend/Dockerfile

# ── Stage 1: Build ──
FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" \
    -o /out/todoapp-core ./cmd/server

# ── Stage 2: Distroless ──
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/todoapp-core /todoapp-core
EXPOSE 8080
ENTRYPOINT ["/todoapp-core"]
```

> **ทำไม distroless?** เล็กมาก (~6 MB compressed) ไม่มี shell โจมตียาก
> Binary อยู่ที่ `/todoapp-core` รันบน port **8080**

### 8.4 Build & Push (manual ครั้งแรก)

```bash
cd src/phase2-final

docker build -t akawatmor/todoapp-core:latest ./backend/
docker push akawatmor/todoapp-core:latest
```

> Images ที่ push แล้ว: `akawatmor/todoapp-core:latest` (digest `sha256:9c98be1b...`, ~6 MB)

### 8.5 Deploy Backend

> **ใช้ Kustomize** — ไม่ต้อง apply inline manifest ด้วยมือ manifest อยู่ใน `src/phase2-final/k8s/`

```bash
# สร้าง namespace + secret ก่อน
kubectl create namespace todoapp
kubectl create secret generic todoapp-secret \
  --namespace todoapp \
  --from-literal=GITHUB_OAUTH_CLIENT_ID=<GITHUB_CLIENT_ID> \
  --from-literal=GITHUB_OAUTH_CLIENT_SECRET=<GITHUB_CLIENT_SECRET>

# deploy ทุก resource ด้วย kustomize (namespace, configmap, pvc, deployment, service, ingress)
kubectl apply -k src/phase2-final/k8s/
```

**core-deployment.yaml (อ้างอิง):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp-core
  namespace: todoapp
spec:
  replicas: 1
  strategy:
    type: Recreate          # SQLite PVC เป็น ReadWriteOnce — ใช้ Recreate เท่านั้น
  selector:
    matchLabels:
      app: todoapp-core
  template:
    spec:
      containers:
      - name: core
        image: akawatmor/todoapp-core:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: todoapp-config
        - secretRef:
            name: todoapp-secret
        volumeMounts:
        - name: sqlite-data
          mountPath: /var/lib/todoapp
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
```

### 8.6 Verify Backend

```bash
kubectl get pods -n todoapp -l app=todoapp-core
kubectl rollout status deployment/todoapp-core -n todoapp

kubectl port-forward -n todoapp svc/todoapp-core 8080:8080 &
curl http://localhost:8080/healthz
# {"status":"ok"}
curl http://localhost:8080/readyz
# {"status":"ok"}

curl http://localhost:8080/api/v1/tasks
# [] (empty list)
kill %1
```

---

## Phase 9: Next.js Frontend

### 9.1 Dockerfile

```dockerfile
# src/phase2-final/frontend/Dockerfile

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --frozen-lockfile || npm install

FROM node:20-alpine AS builder
WORKDIR /app
ARG NEXT_PUBLIC_API_BASE_URL=""
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
ENV PORT=3000 HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

> **สำคัญ**: `NEXT_PUBLIC_API_BASE_URL` ต้องถูก bake เข้า image ตอน **build** (ไม่ใช่ runtime)
> เพราะ Next.js bundle ค่า `NEXT_PUBLIC_*` ไว้ใน JS bundle ตอน `npm run build`
> ใน K3s ปล่อยเป็น `""` เพื่อให้ browser ใช้ relative path ผ่าน Ingress

### 9.2 next.config.mjs

```javascript
// next.config.mjs  (ไม่ใช่ .ts — project ใช้ JS ไม่ใช่ TS)
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  poweredByHeader: false,
  compress: true,
};

export default nextConfig;
```

### 9.3 Build & Push

```bash
cd src/phase2-final

docker build \
  --build-arg NEXT_PUBLIC_API_BASE_URL="" \
  -t akawatmor/todoapp-web:latest \
  ./frontend/
docker push akawatmor/todoapp-web:latest
```

> Images ที่ push แล้ว: `akawatmor/todoapp-web:latest` (digest `sha256:ff8e9ce8...`, ~53 MB)

### 9.4 Deploy Frontend

> **ใช้ Kustomize เช่นกัน** — `kubectl apply -k src/phase2-final/k8s/` deploy ทั้ง backend และ frontend พร้อมกัน

**web-deployment.yaml (อ้างอิง):**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp-web
  namespace: todoapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todoapp-web
  template:
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: todoapp-web
      containers:
      - name: web
        image: akawatmor/todoapp-web:latest
        ports:
        - containerPort: 3000
        env:
        - name: NEXT_PUBLIC_API_BASE_URL
          value: ""             # ว่าง = ใช้ relative path ผ่าน Ingress
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 8
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 20
```

### 9.5 Verify Frontend

```bash
kubectl get pods -n todoapp -l app=todoapp-web

kubectl port-forward -n todoapp svc/todoapp-web 3000:3000 &
curl -s http://localhost:3000 | head -5
# <!DOCTYPE html>...
kill %1
```

---

## Phase 10: Traefik IngressRoutes

```bash
cat << 'EOF' | kubectl apply -f -
# ── Middlewares ──
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: cors-app
  namespace: app
spec:
  headers:
    accessControlAllowMethods: [GET, POST, PUT, DELETE, OPTIONS]
    accessControlAllowHeaders: [Content-Type, Authorization]
    accessControlAllowOriginList: ["https://todo.yourdomain.com"]
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
  name: rate-limit
  namespace: app
spec:
  rateLimit:
    average: 30
    burst: 60
    period: 1s
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
---
# ── Frontend Route ──
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: frontend
  namespace: app
spec:
  entryPoints: [web]
  routes:
  - match: Host(`todo.yourdomain.com`) && !PathPrefix(`/api`)
    kind: Rule
    priority: 1
    services:
    - name: frontend
      port: 3000
    middlewares:
    - name: security-headers
    - name: compress
---
# ── Backend API Route ──
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: backend-api
  namespace: app
spec:
  entryPoints: [web]
  routes:
  - match: Host(`todo.yourdomain.com`) && Path(`/api/health`)
    kind: Rule
    priority: 60
    services:
    - name: backend
      port: 8000
  - match: Host(`todo.yourdomain.com`) && PathPrefix(`/api`)
    kind: Rule
    priority: 10
    services:
    - name: backend
      port: 8000
    middlewares:
    - name: cors-app
    - name: security-headers
    - name: rate-limit
---
# ── Traefik Dashboard ──
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: kube-system
spec:
  entryPoints: [web]
  routes:
  - match: Host(`traefik.yourdomain.com`)
    kind: Rule
    services:
    - name: api@internal
      kind: TraefikService
---
# ── Woodpecker UI ──
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: woodpecker
  namespace: woodpecker
spec:
  entryPoints: [web]
  routes:
  - match: Host(`ci.yourdomain.com`)
    kind: Rule
    services:
    - name: woodpecker-server
      port: 8000
EOF
```

---

## Phase 11: Woodpecker CI/CD

### 11.1 ติดตั้ง Woodpecker Server (VM1)

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
        role: main
      containers:
      - name: woodpecker-server
        image: woodpeckerci/woodpecker-server:latest
        ports:
        - containerPort: 8000
        - containerPort: 9000
        env:
        - name: WOODPECKER_OPEN
          value: "false"
        - name: WOODPECKER_HOST
          value: "https://ci.yourdomain.com"
        - name: WOODPECKER_GITEA
          value: "true"
        - name: WOODPECKER_GITEA_URL
          value: "https://git.yourdomain.com"
        - name: WOODPECKER_GITEA_CLIENT
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_GITEA_CLIENT
        - name: WOODPECKER_GITEA_SECRET
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_GITEA_SECRET
        - name: WOODPECKER_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: woodpecker-secret
              key: WOODPECKER_AGENT_SECRET
        - name: WOODPECKER_DATABASE_DRIVER
          value: "sqlite3"
        - name: WOODPECKER_DATABASE_DATASOURCE
          value: "/var/lib/woodpecker/woodpecker.sqlite"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 256Mi
        volumeMounts:
        - name: woodpecker-data
          mountPath: /var/lib/woodpecker
      volumes:
      - name: woodpecker-data
        hostPath:
          path: /opt/woodpecker-data
          type: DirectoryOrCreate
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

sudo mkdir -p /opt/woodpecker-data
sudo chown 1000:1000 /opt/woodpecker-data
```

### 11.2 ติดตั้ง Woodpecker Agent (VM3)

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
  replicas: 2
  selector:
    matchLabels:
      app: woodpecker-agent
  template:
    metadata:
      labels:
        app: woodpecker-agent
    spec:
      nodeSelector:
        role: ci                       # ← บังคับให้ไปรันที่ VM3
      tolerations:
      - key: dedicated
        operator: Equal
        value: ci
        effect: NoSchedule
      serviceAccountName: woodpecker-agent
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
        - name: WOODPECKER_BACKEND
          value: "kubernetes"
        - name: WOODPECKER_BACKEND_K8S_NAMESPACE
          value: "woodpecker"
        - name: WOODPECKER_MAX_PROCS
          value: "4"
        - name: WOODPECKER_AGENT_LABELS
          value: "arch=amd64,os=linux"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: "2"
            memory: 1Gi
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: woodpecker-agent
  namespace: woodpecker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: woodpecker-agent
rules:
- apiGroups: [""]
  resources: [pods, pods/log, secrets, persistentvolumeclaims]
  verbs: [get, list, watch, create, update, patch, delete]
- apiGroups: [batch]
  resources: [jobs]
  verbs: [get, list, watch, create, update, patch, delete]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: woodpecker-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: woodpecker-agent
subjects:
- kind: ServiceAccount
  name: woodpecker-agent
  namespace: woodpecker
EOF
```

---

## Phase 12: Pipeline Features (ลูกเล่น Woodpecker)

### 📁 โครงสร้าง Pipeline Files

```
repo/
├── .woodpecker/
│   ├── backend.yaml     ← Build + Test + Deploy Go
│   ├── frontend.yaml    ← Build + Test + Deploy Next.js
│   └── notify.yaml      ← Notification
```

---

### 🔨 Feature 1: Backend Pipeline (Test → Build → Deploy)

```yaml
# .woodpecker/backend.yaml

when:
  - branch: [main, develop]
    path: backend/**

steps:

  - name: test
    image: golang:1.22-bookworm
    commands:
      - cd backend
      - go mod download
      - go test ./... -v -race -coverprofile=coverage.out
      - go tool cover -func=coverage.out | tail -1
    when:
      event: [push, pull_request]

  - name: security-scan
    image: securego/gosec:2.20.0
    commands:
      - cd backend
      - gosec -severity medium -confidence medium ./...
    when:
      branch: main
      event: push

  - name: build-push
    image: woodpeckerci/plugin-docker-buildx
    settings:
      repo: YOUR_DOCKERHUB/kps-backend
      username:
        from_secret: DOCKER_USERNAME
      password:
        from_secret: DOCKER_PASSWORD
      tags:
        - latest
        - ${CI_COMMIT_SHA:0:7}
        - ${CI_COMMIT_BRANCH}
      dockerfile: backend/Dockerfile
      context: backend/
      platforms: linux/amd64
    when:
      branch: main
      event: push

  - name: deploy
    image: bitnami/kubectl:latest
    environment:
      KUBE_CONFIG:
        from_secret: KUBE_CONFIG_BASE64
    commands:
      - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
      - export KUBECONFIG=/tmp/kubeconfig
      - |
        kubectl set image deployment/backend \
          backend=YOUR_DOCKERHUB/kps-backend:${CI_COMMIT_SHA:0:7} \
          -n app
      - kubectl rollout status deployment/backend -n app --timeout=120s
    when:
      branch: main
      event: push
```

---

### 🎨 Feature 2: Frontend Pipeline (Type-check → Build → Deploy)

```yaml
# .woodpecker/frontend.yaml

when:
  - branch: [main, develop]
    path: frontend/**

steps:

  - name: typecheck
    image: node:20-bookworm-slim
    commands:
      - cd frontend
      - npm ci
      - npx tsc --noEmit
    when:
      event: [push, pull_request]

  - name: test
    image: node:20-bookworm-slim
    commands:
      - cd frontend
      - npm ci
      - npm test -- --passWithNoTests
    when:
      event: [push, pull_request]

  - name: lighthouse
    image: patrickhulce/lhci:latest
    commands:
      - cd frontend
      - lhci autorun --upload.target=temporary-public-storage || true
    when:
      branch: main
      event: push

  - name: build-push
    image: woodpeckerci/plugin-docker-buildx
    settings:
      repo: YOUR_DOCKERHUB/kps-frontend
      username:
        from_secret: DOCKER_USERNAME
      password:
        from_secret: DOCKER_PASSWORD
      tags:
        - latest
        - ${CI_COMMIT_SHA:0:7}
      dockerfile: frontend/Dockerfile
      context: frontend/
      build_args:
        - NEXT_PUBLIC_API_URL=https://todo.yourdomain.com/api
    when:
      branch: main
      event: push

  - name: deploy
    image: bitnami/kubectl:latest
    environment:
      KUBE_CONFIG:
        from_secret: KUBE_CONFIG_BASE64
    commands:
      - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
      - export KUBECONFIG=/tmp/kubeconfig
      - |
        kubectl set image deployment/frontend \
          frontend=YOUR_DOCKERHUB/kps-frontend:${CI_COMMIT_SHA:0:7} \
          -n app
      - kubectl rollout status deployment/frontend -n app --timeout=180s
    when:
      branch: main
      event: push
```

---

### 🔔 Feature 3: Notification Pipeline

```yaml
# .woodpecker/notify.yaml

depends_on:
  - backend
  - frontend

steps:

  - name: notify-success
    image: woodpeckerci/plugin-webhook
    settings:
      urls:
        from_secret: DISCORD_WEBHOOK
      content_type: application/json
      template: |
        {
          "embeds": [{
            "title": "✅ Deploy สำเร็จ!",
            "color": 3066993,
            "fields": [
              {"name": "Repo",   "value": "{{ .Repo.Name }}", "inline": true},
              {"name": "Branch", "value": "{{ .Commit.Branch }}", "inline": true},
              {"name": "Commit", "value": "`{{ .Commit.SHA | substring 0 7 }}`", "inline": true},
              {"name": "By",     "value": "{{ .Commit.Author.Name }}", "inline": true}
            ]
          }]
        }
    when:
      status: success

  - name: notify-failure
    image: woodpeckerci/plugin-webhook
    settings:
      urls:
        from_secret: DISCORD_WEBHOOK
      content_type: application/json
      template: |
        {
          "embeds": [{
            "title": "❌ Deploy ล้มเหลว!",
            "color": 15158332,
            "fields": [
              {"name": "Step ที่ fail", "value": "{{ .Step.Name }}", "inline": false},
              {"name": "Branch",        "value": "{{ .Commit.Branch }}", "inline": true},
              {"name": "Commit",        "value": "`{{ .Commit.SHA | substring 0 7 }}`", "inline": true}
            ]
          }]
        }
    when:
      status: failure
```

---

### 🎯 Feature 4: PR Preview Environment

```yaml
# .woodpecker/preview.yaml

when:
  event: pull_request

steps:
  - name: deploy-preview
    image: bitnami/kubectl:latest
    environment:
      KUBE_CONFIG:
        from_secret: KUBE_CONFIG_BASE64
    commands:
      - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
      - export KUBECONFIG=/tmp/kubeconfig
      - PR_NS="preview-pr-${CI_COMMIT_PULL_REQUEST}"
      - |
        kubectl create namespace $PR_NS --dry-run=client -o yaml | kubectl apply -f -
      - |
        kubectl run backend-preview \
          --image=YOUR_DOCKERHUB/kps-backend:${CI_COMMIT_SHA:0:7} \
          --namespace=$PR_NS \
          --port=8000 \
          --env="DATABASE_URL=<preview-db-url>"
      - echo "Preview URL: http://${PR_NS}.yourdomain.com"

  - name: cleanup-old-previews
    image: bitnami/kubectl:latest
    environment:
      KUBE_CONFIG:
        from_secret: KUBE_CONFIG_BASE64
    commands:
      - echo "$KUBE_CONFIG" | base64 -d > /tmp/kubeconfig
      - export KUBECONFIG=/tmp/kubeconfig
      - |
        kubectl get ns -o json | jq -r \
          '.items[] | select(.metadata.name | startswith("preview-pr-")) |
           select((.metadata.creationTimestamp | fromdateiso8601) < (now - 259200)) |
           .metadata.name' | \
        xargs -r -I{} kubectl delete ns {}
```

---

### 📊 Feature 5: Database Migration Pipeline

```yaml
# .woodpecker/migrate.yaml

when:
  branch: main
  event: push
  path: backend/migrations/**

steps:
  - name: migrate
    image: YOUR_DOCKERHUB/kps-backend:${CI_COMMIT_SHA:0:7}
    environment:
      DATABASE_URL:
        from_secret: DATABASE_URL
    commands:
      - /migrate -path /migrations -database "$DATABASE_URL" up
    when:
      event: push
      branch: main
```

---

### 🔐 Feature 6: Image Vulnerability Scan (Trivy)

```yaml
# เพิ่มใน backend.yaml หรือ frontend.yaml

  - name: scan-vulnerabilities
    image: aquasec/trivy:latest
    commands:
      - |
        trivy image \
          --exit-code 1 \
          --severity HIGH,CRITICAL \
          --ignore-unfixed \
          YOUR_DOCKERHUB/kps-backend:${CI_COMMIT_SHA:0:7}
    when:
      branch: main
      event: push
```

---

### 🏷️ Feature 7: Semantic Versioning + Git Tag

```yaml
# .woodpecker/release.yaml

when:
  event: tag
  ref: refs/tags/v*

steps:
  - name: release-build
    image: woodpeckerci/plugin-docker-buildx
    settings:
      repo: YOUR_DOCKERHUB/kps-backend
      username:
        from_secret: DOCKER_USERNAME
      password:
        from_secret: DOCKER_PASSWORD
      tags:
        - ${CI_COMMIT_TAG}
        - latest
      auto_tag: true

  - name: create-github-release
    image: woodpeckerci/plugin-github-release
    settings:
      api_key:
        from_secret: GITHUB_TOKEN
      title: "Release ${CI_COMMIT_TAG}"
      files:
        - CHANGELOG.md
```

---

### 📥 Secret Setup ใน Woodpecker UI

```
Woodpecker → Settings → Secrets

ชื่อ Secret              ค่า
────────────────────────────────────────────────────────
DOCKER_USERNAME          your_dockerhub_username
DOCKER_PASSWORD          your_dockerhub_token
KUBE_CONFIG_BASE64       $(base64 -w0 ~/.kube/config)
DATABASE_URL             postgres://...
DISCORD_WEBHOOK          https://discord.com/api/webhooks/...
GITHUB_TOKEN             ghp_xxxxx
```

---

## Phase 13: ทดสอบ End-to-End

```bash
# ── 1. Cluster Status ──
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes

# ── 2. ทดสอบ Internal (MetalLB) ──
curl -H "Host: todo.yourdomain.com" http://192.168.111.200/api/health

# ── 3. ทดสอบผ่าน Nginx ──
curl -sk https://todo.yourdomain.com:56260/api/health

# ── 4. ทดสอบผ่าน Cloudflare (Internet) ──
curl https://todo.yourdomain.com/api/health

# ── 5. CRUD Test ──
curl -s https://todo.yourdomain.com/api/todos \
  -X POST -H "Content-Type: application/json" \
  -d '{"title":"Hello K3s + Debian!"}' | jq

curl -s https://todo.yourdomain.com/api/todos | jq

# ── 6. ดู Pipeline ──
# push code → check Woodpecker UI
# https://ci.yourdomain.com

# ── 7. Verify Rolling Deploy (ต้องไม่มี downtime) ──
watch kubectl get pods -n app
```

---

## 📊 สรุปสถาปัตยกรรม

```
Internet
  └── Cloudflare (CF Proxy ON)
        └── :56260 Origin Rule
              └── TrueDDNS → public IP บ้าน
                    └── Router NAT → Nginx (192.168.111.171:56260)
                          └── Nginx: TLS termination → MetalLB (192.168.111.200:80)
                                └── Traefik
                                      ├── todo.yourdomain.com     → Frontend (Next.js)
                                      ├── todo.yourdomain.com/api → Backend (Go ×2)
                                      ├── ci.yourdomain.com       → Woodpecker Server
                                      └── traefik.yourdomain.com  → Dashboard

VM1 (k3s-main) Debian 13 — 192.168.111.42 — 4C/12GB/45GB
  ├── K3s Server (control plane)
  ├── Traefik + MetalLB
  ├── PostgreSQL (iSCSI PVC → Synology NAS)
  ├── Go Backend ×2 (RollingUpdate)
  └── Next.js Frontend ×1

VM2 (k3s-worker) Debian 13 — 192.168.111.43 — 3C/8GB/35GB
  └── K3s Agent (role=worker)

VM3 (k3s-ci) Debian 13 — 192.168.111.44 — 3C/8GB/35GB
  ├── K3s Agent (taint: dedicated=ci:NoSchedule)
  └── Woodpecker Agent ×2 (K8s backend)

Synology NAS — 192.168.111.10 (MTU 9000)
  └── iSCSI LUN 16GB → PV pg-iscsi-pv → PVC pg-iscsi-pvc → PostgreSQL

Pipeline Flow:
  git push → Gitea webhook → Woodpecker Server (VM1)
    → Agent (VM3) → [test → scan → build → push → deploy]
    → kubectl rolling update → notify Discord
```

---

## ❓ 10 ข้อที่อาจารย์อาจถาม

### Q1: ทำไมถึงใช้ K3s แทน K8s ปกติ?

**A:** K3s เป็น Kubernetes distribution ที่ lightweight เหมาะกับ home lab และ edge computing เพราะ:
- ใช้ RAM น้อยกว่า (K3s ~512MB vs K8s ~2GB+ สำหรับ control plane)
- Install ง่ายด้วย single binary ไม่ต้องตั้ง etcd แยก (K3s ใช้ SQLite/embedded etcd)
- รวม Traefik, CoreDNS, Flannel ไว้ในตัว ไม่ต้อง install แยก
- เหมาะกับ VM 3 เครื่องที่ resource จำกัด
- Production-grade แต่ setup เร็วกว่า 10x

---

### Q2: MetalLB คืออะไร และทำไมถึงต้องใช้?

**A:** Kubernetes ปกติ Service Type `LoadBalancer` ต้องการ Cloud Provider (AWS/GCP/Azure) เพื่อสร้าง Load Balancer จริง ๆ ใน on-premise / home lab ไม่มี cloud provider → Service จะ stuck ที่ `<pending>` ไม่มี External IP

MetalLB เป็น software load balancer ที่จำลองพฤติกรรมนี้ใน bare metal:
- Layer 2 mode (ที่ใช้): ARP announcement บอก LAN ว่า IP 192.168.111.200 อยู่ที่ node ไหน
- Layer 3 mode: BGP routing (ต้องมี router รองรับ BGP)
- ทำให้ Traefik ได้ External IP จริง ๆ ที่ใช้งานได้ใน LAN

---

### Q3: Traefik ต่างจาก Nginx Ingress อย่างไร?

**A:**

| ด้าน | Traefik | Nginx Ingress |
|------|---------|---------------|
| Config reload | Dynamic, ไม่ต้อง restart | ต้อง reload nginx |
| K8s integration | Native CRD (IngressRoute) | Ingress + Annotations |
| Dashboard | Built-in | ไม่มี (ต้อง add-on) |
| Middleware | Built-in (rate limit, auth, etc.) | ต้อง configure nginx blocks |
| Auto TLS | ACME built-in | ต้องติดตั้ง cert-manager |
| ใน K3s | Default, รวมมาแล้ว | ต้องติดตั้งเอง |

---

### Q4: Rolling Update คืออะไร และ maxUnavailable=0 สำคัญอย่างไร?

**A:** Rolling Update เป็น strategy การ deploy โดย:
1. สร้าง pod ใหม่ขึ้นมาก่อน (maxSurge=1)
2. รอจนกว่า pod ใหม่ ReadinessProbe ผ่าน
3. ค่อยลบ pod เก่าออก

`maxUnavailable=0` = ไม่อนุญาตให้ pod ใดๆ unavailable ระหว่าง deploy → Zero-downtime deployment

เปรียบเทียบ strategies:
- `Recreate`: ลบทั้งหมดก่อน แล้วค่อยสร้างใหม่ → มี downtime แต่เร็ว
- `RollingUpdate`: ทยอย replace → ไม่มี downtime แต่ต้องการ resource เพิ่ม
- `Canary`: ค่อยๆ เพิ่ม traffic ไปยัง version ใหม่

---

### Q5: ทำไมถึงใช้ distroless image แทน alpine?

**A:** distroless คือ container image ที่ไม่มี shell, package manager, หรือ OS utilities ใดๆ เลย ข้อดี:

- **Security**: Attack surface เล็กมาก ถ้า attacker เข้า container มาได้ก็ไม่มีเครื่องมือให้ใช้งาน
- **ขนาด**: เล็กกว่า alpine เล็กน้อย (เพราะไม่มี musl libc, busybox)
- **CVE**: น้อยกว่า เพราะ packages น้อยกว่า

ข้อเสีย: debug ยาก ต้องใช้ `kubectl exec` + ephemeral debug container

ใน Debian ecosystem เหมาะใช้ `gcr.io/distroless/static-debian12` สำหรับ Go (static binary)

---

### Q6: Woodpecker CI เปรียบกับ GitHub Actions / Jenkins อย่างไร?

**A:**

| ด้าน | Woodpecker | GitHub Actions | Jenkins |
|------|-----------|---------------|---------|
| Host | Self-hosted | GitHub Cloud | Self-hosted |
| Privacy | Code ไม่ออกนอก | Code ส่ง GitHub | Code อยู่ใน org |
| Cost | Free | Free (limited) / Paid | Free + Hardware |
| Setup | ง่าย (Docker) | Zero setup | ซับซ้อน |
| Gitea integration | ดีที่สุด | ไม่รองรับ | รองรับ |
| Pipeline syntax | YAML (simple) | YAML (complex) | Groovy/Jenkinsfile |

---

### Q7: ทำไมต้อง taint VM3 (k3s-ci)?

**A:** Taint เป็นกลไกที่บอก K8s scheduler ว่า "node นี้มีข้อจำกัด" pod จะ schedule ไปได้เฉพาะ pod ที่มี **toleration** ตรงกัน

```
kubectl taint nodes k3s-ci dedicated=ci:NoSchedule
```

- App pods (backend, frontend, postgres) ❌ ไม่มี toleration → ไม่ไป VM3
- Woodpecker Agent pods ✅ มี toleration → ไปได้ VM3

เหตุผล: CI/CD pipeline รัน Docker build ใช้ CPU/RAM สูงมาก ถ้าปะปนกับ app pods จะ resource contention → app latency สูงขึ้น

---

### Q8: ถ้า PostgreSQL Pod restart ข้อมูลหายไหม? และทำไมถึงใช้ iSCSI แทน hostPath?

**A:** ไม่หาย เพราะข้อมูลอยู่บน iSCSI LUN ของ Synology NAS แยกออกจาก lifecycle ของ Pod และ VM

**เปรียบเทียบ hostPath vs iSCSI:**

| ด้าน | hostPath | iSCSI Synology |
|------|----------|----------------|
| ข้อมูลอยู่ที่ | Disk บน VM1 | NAS แยกต่างหาก |
| VM1 พังทั้งเครื่อง | ข้อมูลอาจหาย | ข้อมูลปลอดภัยบน NAS |
| Snapshot | ต้อง backup เอง | Synology Snapshot ทำได้ใน click |
| ขยาย storage | ต้องขยาย disk VM | ขยาย LUN ที่ DSM แล้ว resize |

**MTU 9000 (Jumbo Frame) สำคัญอย่างไร:**
- iSCSI ส่งข้อมูลเป็น block ขนาดใหญ่ (8KB-1MB)
- MTU 1500 → ต้อง fragment packet → overhead สูง + latency เพิ่ม
- MTU 9000 → packet ใหญ่ขึ้น 6x → throughput ดีขึ้น, CPU ลดลง
- **ต้องตั้งทั้ง NAS + Switch port + VM NIC ให้ตรงกัน** ไม่งั้นจะ drop
- เนื่องจาก LAN และ iSCSI ใช้ subnet `192.168.111.x` เดียวกัน จึงตั้ง MTU บน primary NIC ได้เลย

**`Reclaim Policy: Retain` สำคัญอย่างไร:**
ถ้า delete PVC โดยบังเอิญ → ข้อมูลบน LUN ยังอยู่ ต้องลบ PV ด้วยมือ เป็น safety net

---

### Q9: CI_COMMIT_SHA ใช้ทำอะไร และทำไมไม่ใช้แค่ `latest` tag?

**A:** `CI_COMMIT_SHA` คือ Git commit hash เช่น `a1b2c3d4e5f6...`

ปัญหาของ `latest` tag:
- `latest` ชี้ไปที่ image เดิมแม้ push ใหม่ → kubernetes `imagePullPolicy: IfNotPresent` จะไม่ pull ใหม่
- Rollback ยาก ไม่รู้ว่า `latest` เมื่อกี้คือ version อะไร
- ทีมหลายคน deploy พร้อมกัน `latest` คือของใคร?

การใช้ commit SHA:
```bash
docker push YOUR_DOCKERHUB/kps-backend:a1b2c3d   # unique ทุก commit
kubectl set image deployment/backend backend=...:a1b2c3d
```

ข้อดี: immutable tag, rollback ง่าย (`kubectl rollout undo`), audit trail ชัดเจน

---

### Q10: อธิบาย Traffic Flow จาก User ถึง Database

**A:**

```
1. User พิมพ์ https://todo.yourdomain.com
   ↓
2. DNS → Cloudflare Edge (CF Proxy ON)
   CF handle TLS termination (CF cert ↔ User)
   ↓
3. CF Origin Rule rewrite port → :56260
   CF → TrueDDNS → public IP บ้าน
   ↓
4. Router NAT forward :56260 → Nginx (192.168.111.171:56260)
   Nginx: TLS termination ครั้งที่ 2 (Origin cert)
   Nginx: set X-Forwarded-For, Host headers
   ↓
5. Nginx proxy_pass → MetalLB (192.168.111.200:80)
   MetalLB: L2 ARP ชี้ไป VM1
   ↓
6. Traefik รับ request บน VM1
   - /api/* → backend:8000
   - /*     → frontend:3000
   ↓
7. Go Backend Pod รับ /api/todos
   Backend: parse request, validate
   ↓
8. Backend → PostgreSQL (postgresql.app.svc.cluster.local:5432)
   Postgres: query iSCSI LUN บน Synology NAS, return rows
   ↓
9. Response กลับ User ตาม path เดิม
   ทั้งหมดใช้เวลา < 100ms
```

---

## 📝 Quick Reference Commands

```bash
# ── Cluster Health ──
kubectl get nodes -o wide
kubectl get pods -A
kubectl top nodes

# ── Pod Status ──
kubectl get pods -n app -o wide
kubectl get pods -n woodpecker -o wide

# ── Logs ──
kubectl logs -n app deployment/backend --tail=50 -f
kubectl logs -n app deployment/frontend --tail=20
kubectl logs -n app -l app=postgresql --tail=30
kubectl logs -n woodpecker deployment/woodpecker-server --tail=50

# ── Resource Usage ──
kubectl top nodes
kubectl top pods -n app

# ── Restart Deployment ──
kubectl rollout restart deployment/backend -n app
kubectl rollout restart deployment/frontend -n app
kubectl rollout status deployment/backend -n app

# ── Rollback ──
kubectl rollout undo deployment/backend -n app
kubectl rollout undo deployment/frontend -n app
kubectl rollout history deployment/backend -n app

# ── Port Forward (debug) ──
kubectl port-forward -n app svc/backend 8000:8000
kubectl port-forward -n app svc/frontend 3000:3000
kubectl port-forward -n woodpecker svc/woodpecker-server 8888:8000

# ── iSCSI ──
sudo iscsiadm -m session                        # ดู sessions
sudo iscsiadm -m session -P 3                   # ดู disk device
sudo systemctl restart open-iscsi iscsid        # restart iscsi
lsblk | grep sd                                 # ดู block devices
df -h | grep sdb                                # ดู disk usage

# ── Secrets ──
kubectl get secret pg-secret -n app -o jsonpath='{.data.url}' | base64 -d
kubectl get secrets -n app
kubectl get secrets -n woodpecker

# ── Describe (troubleshoot) ──
kubectl describe pod -n app -l app=backend | tail -30
kubectl describe pvc pg-iscsi-pvc -n app
kubectl describe node k3s-ci

# ── Shell into Pod (frontend มี shell เพราะใช้ node image) ──
kubectl exec -it -n app deployment/frontend -- /bin/sh
# backend ใช้ distroless → ไม่มี shell
```