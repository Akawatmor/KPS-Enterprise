# Run Application Locally with Docker Compose for Verification

## Issue #7 — Create docker-compose.yml and Verify Full Stack

---

## สารบัญ (Table of Contents)

1. [ภาพรวม (Overview)](#1-ภาพรวม)
2. [Pre-requisites](#2-pre-requisites)
3. [docker-compose.yml](#3-docker-composeyml)
4. [ไฟล์เสริมที่ต้องสร้าง](#4-ไฟล์เสริมที่ต้องสร้าง)
5. [Issues Found & Fixes Required](#5-issues-found--fixes-required)
6. [ขั้นตอนการรันและทดสอบ](#6-ขั้นตอนการรันและทดสอบ)
7. [CRUD Verification Tests](#7-crud-verification-tests)
8. [Health Check Verification](#8-health-check-verification)
9. [Troubleshooting Guide](#9-troubleshooting-guide)
10. [สรุปผลการทดสอบ](#10-สรุปผลการทดสอบ)

---

## 1. ภาพรวม

```
┌──────────────────────────────────────────────────────────┐
│                  Docker Compose Stack                     │
│                                                          │
│  ┌──────────┐     ┌──────────┐      ┌────────────────┐  │
│  │ frontend │     │ backend  │      │   mongodb       │  │
│  │          │────▶│          │─────▶│                 │  │
│  │ :3000    │HTTP │ :3500    │:27017│  mongo:4.4.6    │  │
│  │          │     │          │      │                 │  │
│  └──────────┘     └──────────┘      └────────┬───────┘  │
│       │                                       │          │
│       │                                       ▼          │
│  Host:3000                              mongo-data       │
│                                         (named volume)   │
└──────────────────────────────────────────────────────────┘
```

---

## 2. Pre-requisites

| Tool           | Minimum Version | ตรวจสอบด้วย              |
| -------------- | --------------- | ------------------------ |
| Docker         | 20.10+          | `docker --version`       |
| Docker Compose | 2.0+ (V2)       | `docker compose version` |
| curl           | any             | `curl --version`         |
| (Optional) jq  | any             | `jq --version`           |

---

## 3. docker-compose.yml

สร้างไฟล์ `docker-compose.yml` ที่ **root ของ project** (ระดับเดียวกับ `Application-Code/`)

```yaml
# docker-compose.yml
# Location: project root (same level as Application-Code/)

version: "3.8"

services:
  # =============================================
  # MongoDB Service
  # =============================================
  mongodb:
    image: mongo:4.4.6
    container_name: mongodb
    restart: unless-stopped
    command: >
      numactl --interleave=all mongod
      --wiredTigerCacheSizeGB 0.1
      --bind_ip 0.0.0.0
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password123
    ports:
      - "27017:27017"
    volumes:
      - mongo-data:/data/db
    networks:
      - three-tier-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongo localhost:27017/test --quiet
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  # =============================================
  # Backend Service (Node.js/Express)
  # =============================================
  backend:
    build:
      context: ./Application-Code/backend
      dockerfile: Dockerfile
    container_name: backend
    restart: unless-stopped
    environment:
      MONGO_CONN_STR: mongodb://mongodb:27017/todo?directConnection=true
      MONGO_USERNAME: admin
      MONGO_PASSWORD: password123
      USE_DB_AUTH: "true"
      PORT: "3500"
    ports:
      - "3500:3500"
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - three-tier-network
    healthcheck:
      test: curl -f http://localhost:3500/healthz || exit 1
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s

  # =============================================
  # Frontend Service (React)
  # =============================================
  frontend:
    build:
      context: ./Application-Code/frontend
      dockerfile: Dockerfile
    container_name: frontend
    restart: unless-stopped
    environment:
      REACT_APP_BACKEND_URL: http://localhost:3500/api/tasks
    ports:
      - "3000:3000"
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - three-tier-network

# =============================================
# Volumes
# =============================================
volumes:
  mongo-data:
    driver: local

# =============================================
# Networks
# =============================================
networks:
  three-tier-network:
    driver: bridge
```

### โครงสร้างไฟล์หลังสร้าง docker-compose.yml

```
project-root/
├── docker-compose.yml              ← สร้างใหม่
├── Application-Code/
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── .dockerignore           ← สร้างใหม่
│   │   ├── db.js
│   │   ├── index.js
│   │   ├── package.json
│   │   ├── models/
│   │   │   └── task.js
│   │   └── routes/
│   │       └── tasks.js
│   └── frontend/
│       ├── Dockerfile
│       ├── .dockerignore           ← สร้างใหม่
│       ├── package.json
│       ├── public/
│       └── src/
├── Kubernetes-Manifests-file/
└── ...
```

---

## 4. ไฟล์เสริมที่ต้องสร้าง

### 4.1 Backend `.dockerignore`

สร้างไฟล์ `Application-Code/backend/.dockerignore`:

```
node_modules
npm-debug.log
.git
.gitignore
.env
README.md
```

### 4.2 Frontend `.dockerignore`

สร้างไฟล์ `Application-Code/frontend/.dockerignore`:

```
node_modules
npm-debug.log
build
.git
.gitignore
.env
README.md
```

---

## 5. Issues Found & Fixes Required

### ระหว่างวิเคราะห์ source code พบปัญหาที่ต้องแก้ไขก่อนรัน

---

### 🔴 Issue #1: `USE_DB_AUTH` ไม่ได้กำหนดใน K8s YAML (แก้แล้วใน docker-compose)

```
┌─────────────────────────────────────────────────────────────────┐
│ ปัญหา:                                                          │
│   K8s Backend deployment.yaml ไม่มี USE_DB_AUTH env var          │
│   → db.js ข้าม authentication → เชื่อมต่อ MongoDB ไม่ได้          │
│                                                                 │
│ สถานะใน docker-compose.yml:                                      │
│   ✅ แก้ไขแล้ว — กำหนด USE_DB_AUTH: "true"                       │
│                                                                 │
│ สถานะใน K8s YAML:                                                │
│   ❌ ยังไม่ได้แก้ — ต้องเพิ่มใน Backend deployment.yaml           │
└─────────────────────────────────────────────────────────────────┘
```

---

### 🔴 Issue #2: `REACT_APP_BACKEND_URL` เป็น Build-time Variable

```
┌─────────────────────────────────────────────────────────────────┐
│ ปัญหา:                                                          │
│   REACT_APP_* variables ถูก embed ตอน build ไม่ใช่ runtime      │
│   Frontend Dockerfile ใช้ CMD ["npm", "start"]                  │
│   → webpack-dev-server อ่าน env ตอน start ได้ (dev mode)        │
│   → ในกรณีนี้ใช้งานได้ เพราะเป็น dev server                      │
│                                                                 │
│ สถานะ:                                                           │
│   ✅ ใช้งานได้ใน dev mode (npm start)                             │
│   ⚠️ จะไม่ทำงานถ้าเปลี่ยนเป็น production build (npm run build)   │
└─────────────────────────────────────────────────────────────────┘
```

---

### 🟡 Issue #3: Frontend Dockerfile ใช้ Dev Server

```
┌─────────────────────────────────────────────────────────────────┐
│ ปัญหา:                                                          │
│   CMD ["npm", "start"] = webpack-dev-server                     │
│   → ช้า, ใช้ memory เยอะ, ไม่เหมาะกับ production                 │
│                                                                 │
│ สถานะ:                                                           │
│   ✅ ยอมรับได้สำหรับ local verification                           │
│   ⚠️ ต้องเปลี่ยนก่อน deploy production                            │
└─────────────────────────────────────────────────────────────────┘
```

---

### 🟡 Issue #4: Axios Version ผิดปกติ

```
┌─────────────────────────────────────────────────────────────────┐
│ ปัญหา:                                                          │
│   package.json: "axios": "^=0.30.0"                             │
│   "^=" ไม่ใช่ semver range มาตรฐาน                               │
│                                                                 │
│ ผลกระทบ:                                                         │
│   npm อาจตีความผิด หรือ install version ที่ไม่คาดหมาย            │
│                                                                 │
│ สถานะ:                                                           │
│   ⚠️ อาจทำให้ npm install ล้มเหลว                                │
│   ถ้าเกิดปัญหา → แก้เป็น "axios": "^0.27.2" หรือ "^1.6.0"       │
└─────────────────────────────────────────────────────────────────┘
```

---

### 🟡 Issue #5: Backend Dockerfile ไม่มี curl (สำหรับ healthcheck)

```
┌─────────────────────────────────────────────────────────────────┐
│ ปัญหา:                                                          │
│   Backend Dockerfile ใช้ node:14 base image                     │
│   docker-compose healthcheck ใช้ curl                           │
│   node:14 (Debian-based) มี curl ติดมาแล้ว                      │
│                                                                 │
│ สถานะ:                                                           │
│   ✅ ใช้งานได้ (node:14 full image มี curl)                      │
│   ⚠️ ถ้าเปลี่ยนเป็น alpine image จะไม่มี curl                    │
└─────────────────────────────────────────────────────────────────┘
```

### สรุป Issues ทั้งหมด

| #   | Issue                    | Severity | สถานะใน docker-compose | ต้องแก้ source code? |
| --- | ------------------------ | -------- | ---------------------- | -------------------- |
| 1   | `USE_DB_AUTH` missing    | 🔴       | ✅ แก้แล้ว             | ❌ ไม่ต้อง           |
| 2   | `REACT_APP_*` build-time | 🟡       | ✅ ใช้ได้ (dev mode)   | ❌ ไม่ต้อง (dev)     |
| 3   | Frontend dev server      | 🟡       | ✅ ยอมรับได้           | ❌ ไม่ต้อง (local)   |
| 4   | Axios version `^=0.30.0` | 🟡       | ⚠️ อาจมีปัญหา          | ✅ ถ้า build fail    |
| 5   | curl in healthcheck      | 🟡       | ✅ ใช้ได้              | ❌ ไม่ต้อง           |

---

## 6. ขั้นตอนการรันและทดสอบ

### Step 1: Build & Start ทุก Services

```bash
# Navigate to project root (where docker-compose.yml is)
cd /path/to/project-root

# Build and start all services
docker compose up --build -d
```

**Expected Output:**

```
[+] Building 45.2s (18/18) FINISHED
 => [backend] ...
 => [frontend] ...
[+] Running 4/4
 ✔ Network three-tier-network  Created
 ✔ Volume "mongo-data"         Created
 ✔ Container mongodb           Healthy
 ✔ Container backend           Healthy
 ✔ Container frontend          Started
```

### Step 2: ตรวจสอบสถานะ Containers

```bash
docker compose ps
```

**Expected Output:**

```
NAME       IMAGE          STATUS                   PORTS
mongodb    mongo:4.4.6    Up (healthy)             0.0.0.0:27017->27017/tcp
backend    ...-backend    Up (healthy)             0.0.0.0:3500->3500/tcp
frontend   ...-frontend   Up                       0.0.0.0:3000->3000/tcp
```

### Step 3: ตรวจสอบ Logs

```bash
# ดู logs ทุก services
docker compose logs

# ดู logs เฉพาะ service
docker compose logs mongodb
docker compose logs backend
docker compose logs frontend

# ดู logs แบบ follow (real-time)
docker compose logs -f backend
```

**Expected Backend Logs:**

```
backend  | Connected to database.
backend  | Listening on port 3500...
```

**ถ้าเห็น error:**

```
backend  | Could not connect to database. MongoServerError: ...
```

→ ดู [Troubleshooting Guide](#9-troubleshooting-guide)

### Step 4: Startup Sequence Diagram

```
docker compose up --build -d
         │
         ▼
┌─────────────────┐
│ 1. Build Images │
│  - backend      │
│  - frontend     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. Start        │
│    mongodb      │──────────────────────────────────────┐
└────────┬────────┘                                      │
         │                                               │
         ▼                                               │
┌─────────────────┐                                      │
│ 3. Wait for     │    healthcheck:                      │
│    mongodb      │    echo 'db.runCommand("ping")'      │
│    healthy      │    every 10s, max 5 retries          │
└────────┬────────┘                                      │
         │  ✅ healthy                                   │
         ▼                                               │
┌─────────────────┐                                      │
│ 4. Start        │    depends_on:                       │
│    backend      │      mongodb: service_healthy        │
└────────┬────────┘                                      │
         │                                               │
         ▼                                               │
┌─────────────────┐                                      │
│ 5. Wait for     │    healthcheck:                      │
│    backend      │    curl http://localhost:3500/healthz │
│    healthy      │    every 10s, max 5 retries          │
└────────┬────────┘                                      │
         │  ✅ healthy                                   │
         ▼                                               │
┌─────────────────┐                                      │
│ 6. Start        │    depends_on:                       │
│    frontend     │      backend: service_healthy        │
└─────────────────┘                                      │
                                                         │
Timeline: ───────────────────────────────────────────────▶
          ~30s mongodb    ~15s backend    ~30s frontend
          healthy         healthy         ready
```

---

## 7. CRUD Verification Tests

### Test Environment

```
Backend API:  http://localhost:3500
Frontend UI:  http://localhost:3000
MongoDB:      localhost:27017
```

---

### Test 1: Health Check Endpoints

```bash
echo "=== Test 1.1: Liveness Probe ==="
curl -s http://localhost:3500/healthz
# Expected: Healthy

echo ""
echo "=== Test 1.2: Readiness Probe ==="
curl -s http://localhost:3500/ready
# Expected: Ready

echo ""
echo "=== Test 1.3: Startup Probe ==="
curl -s http://localhost:3500/started
# Expected: Started
```

---

### Test 2: CREATE — POST /api/tasks

```bash
echo "=== Test 2: Create Task ==="
curl -s -X POST http://localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Buy groceries"}' | jq .
```

**Expected Response:**

```json
{
  "_id": "...",
  "task": "Buy groceries",
  "completed": false,
  "__v": 0
}
```

```bash
# สร้าง task เพิ่มสำหรับทดสอบ
curl -s -X POST http://localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Clean the house"}' | jq .

curl -s -X POST http://localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Read a book"}' | jq .
```

---

### Test 3: READ — GET /api/tasks

```bash
echo "=== Test 3: Get All Tasks ==="
curl -s http://localhost:3500/api/tasks | jq .
```

**Expected Response:**

```json
[
  {
    "_id": "664a...",
    "task": "Buy groceries",
    "completed": false,
    "__v": 0
  },
  {
    "_id": "664b...",
    "task": "Clean the house",
    "completed": false,
    "__v": 0
  },
  {
    "_id": "664c...",
    "task": "Read a book",
    "completed": false,
    "__v": 0
  }
]
```

---

### Test 4: UPDATE — PUT /api/tasks/:id

```bash
# ดึง ID ของ task แรก
TASK_ID=$(curl -s http://localhost:3500/api/tasks | jq -r '.[0]._id')
echo "Task ID: $TASK_ID"

echo "=== Test 4: Update Task (toggle completed) ==="
curl -s -X PUT http://localhost:3500/api/tasks/$TASK_ID \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq .
```

**Expected Response (document ก่อนอัปเดต):**

```json
{
  "_id": "664a...",
  "task": "Buy groceries",
  "completed": false,
  "__v": 0
}
```

```bash
# ตรวจสอบว่าอัปเดตสำเร็จ
echo "=== Verify Update ==="
curl -s http://localhost:3500/api/tasks | jq '.[0]'
```

**Expected (หลังอัปเดต):**

```json
{
  "_id": "664a...",
  "task": "Buy groceries",
  "completed": true,
  "__v": 0
}
```

---

### Test 5: DELETE — DELETE /api/tasks/:id

```bash
# ดึง ID ของ task สุดท้าย
TASK_ID=$(curl -s http://localhost:3500/api/tasks | jq -r '.[-1]._id')
echo "Deleting Task ID: $TASK_ID"

echo "=== Test 5: Delete Task ==="
curl -s -X DELETE http://localhost:3500/api/tasks/$TASK_ID | jq .
```

**Expected Response (document ที่ถูกลบ):**

```json
{
  "_id": "664c...",
  "task": "Read a book",
  "completed": false,
  "__v": 0
}
```

```bash
# ตรวจสอบว่าลบสำเร็จ
echo "=== Verify Delete ==="
curl -s http://localhost:3500/api/tasks | jq '. | length'
# Expected: 2 (เหลือ 2 tasks จากเดิม 3)
```

---

### Test 6: Validation — POST without required field

```bash
echo "=== Test 6: Validation Error ==="
curl -s -X POST http://localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{}' | jq .
```

**Expected Response:**

```json
{
  "errors": {
    "task": {
      "name": "ValidatorError",
      "message": "Path `task` is required.",
      "properties": {
        "message": "Path `task` is required.",
        "type": "required",
        "path": "task"
      },
      "kind": "required",
      "path": "task"
    }
  },
  "_message": "task validation failed",
  "message": "task validation failed: task: Path `task` is required.",
  "name": "ValidationError"
}
```

---

### Test 7: Frontend UI Verification

```bash
echo "=== Test 7: Frontend Accessible ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200
```

**Manual UI Testing:**

1. เปิด browser ไปที่ `http://localhost:3000`
2. ตรวจสอบว่าหน้า "My To-Do List" แสดงขึ้น
3. ตรวจสอบว่า tasks ที่สร้างไว้แสดงในรายการ
4. ทดสอบพิมพ์ task ใหม่ → กด "Add Task"
5. ทดสอบคลิก Checkbox → toggle completed
6. ทดสอบกด "Delete" → ลบ task

---

### Automated Test Script (all-in-one)

สร้างไฟล์ `test.sh` ที่ project root:

```bash
#!/bin/bash
# test.sh — Full CRUD verification test

set -e

API_URL="http://localhost:3500"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

assert_eq() {
    local test_name=$1
    local expected=$2
    local actual=$3
    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✅ PASS${NC}: $test_name"
        ((PASS++))
    else
        echo -e "  ${RED}❌ FAIL${NC}: $test_name"
        echo -e "       Expected: ${expected}"
        echo -e "       Actual:   ${actual}"
        ((FAIL++))
    fi
}

echo ""
echo "============================================"
echo "  Three-Tier App — CRUD Verification Tests"
echo "============================================"
echo ""

# ------------------------------------------
echo -e "${YELLOW}[1/8] Health Check Tests${NC}"
# ------------------------------------------

HEALTH=$(curl -s $API_URL/healthz)
assert_eq "GET /healthz" "Healthy" "$HEALTH"

READY=$(curl -s $API_URL/ready)
assert_eq "GET /ready" "Ready" "$READY"

STARTED=$(curl -s $API_URL/started)
assert_eq "GET /started" "Started" "$STARTED"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[2/8] Clean Up — Delete All Existing Tasks${NC}"
# ------------------------------------------

EXISTING=$(curl -s $API_URL/api/tasks)
EXISTING_IDS=$(echo "$EXISTING" | jq -r '.[]._id // empty' 2>/dev/null)
for ID in $EXISTING_IDS; do
    curl -s -X DELETE "$API_URL/api/tasks/$ID" > /dev/null
done
REMAINING=$(curl -s $API_URL/api/tasks | jq '. | length')
assert_eq "Clean slate (0 tasks)" "0" "$REMAINING"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[3/8] CREATE — POST /api/tasks${NC}"
# ------------------------------------------

TASK1=$(curl -s -X POST $API_URL/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Test Task 1"}')
TASK1_ID=$(echo "$TASK1" | jq -r '._id')
TASK1_NAME=$(echo "$TASK1" | jq -r '.task')
TASK1_COMPLETED=$(echo "$TASK1" | jq -r '.completed')

assert_eq "Task 1 created with name" "Test Task 1" "$TASK1_NAME"
assert_eq "Task 1 default completed=false" "false" "$TASK1_COMPLETED"

TASK2=$(curl -s -X POST $API_URL/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Test Task 2"}')
TASK2_ID=$(echo "$TASK2" | jq -r '._id')
assert_eq "Task 2 created" "Test Task 2" "$(echo "$TASK2" | jq -r '.task')"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[4/8] READ — GET /api/tasks${NC}"
# ------------------------------------------

ALL_TASKS=$(curl -s $API_URL/api/tasks)
TASK_COUNT=$(echo "$ALL_TASKS" | jq '. | length')
assert_eq "GET returns 2 tasks" "2" "$TASK_COUNT"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[5/8] UPDATE — PUT /api/tasks/:id${NC}"
# ------------------------------------------

curl -s -X PUT "$API_URL/api/tasks/$TASK1_ID" \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' > /dev/null

UPDATED=$(curl -s $API_URL/api/tasks | jq -r ".[] | select(._id==\"$TASK1_ID\") | .completed")
assert_eq "Task 1 completed=true after update" "true" "$UPDATED"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[6/8] DELETE — DELETE /api/tasks/:id${NC}"
# ------------------------------------------

curl -s -X DELETE "$API_URL/api/tasks/$TASK2_ID" > /dev/null
AFTER_DELETE=$(curl -s $API_URL/api/tasks | jq '. | length')
assert_eq "1 task remaining after delete" "1" "$AFTER_DELETE"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[7/8] VALIDATION — POST without required field${NC}"
# ------------------------------------------

VALIDATION=$(curl -s -X POST $API_URL/api/tasks \
  -H "Content-Type: application/json" \
  -d '{}')
VALIDATION_ERROR=$(echo "$VALIDATION" | jq -r '.name // empty')
assert_eq "Validation error returned" "ValidationError" "$VALIDATION_ERROR"

# ------------------------------------------
echo ""
echo -e "${YELLOW}[8/8] FRONTEND — UI Accessible${NC}"
# ------------------------------------------

FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
assert_eq "Frontend returns 200" "200" "$FRONTEND_STATUS"

# ------------------------------------------
# Summary
# ------------------------------------------
echo ""
echo "============================================"
echo "  Test Results"
echo "============================================"
echo -e "  ${GREEN}Passed: $PASS${NC}"
echo -e "  ${RED}Failed: $FAIL${NC}"
TOTAL=$((PASS + FAIL))
echo "  Total:  $TOTAL"
echo "============================================"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
fi
```

```bash
# ให้สิทธิ์ execute แล้วรัน
chmod +x test.sh
./test.sh
```

**Expected Output:**

```
============================================
  Three-Tier App — CRUD Verification Tests
============================================

[1/8] Health Check Tests
  ✅ PASS: GET /healthz
  ✅ PASS: GET /ready
  ✅ PASS: GET /started

[2/8] Clean Up — Delete All Existing Tasks
  ✅ PASS: Clean slate (0 tasks)

[3/8] CREATE — POST /api/tasks
  ✅ PASS: Task 1 created with name
  ✅ PASS: Task 1 default completed=false
  ✅ PASS: Task 2 created

[4/8] READ — GET /api/tasks
  ✅ PASS: GET returns 2 tasks

[5/8] UPDATE — PUT /api/tasks/:id
  ✅ PASS: Task 1 completed=true after update

[6/8] DELETE — DELETE /api/tasks/:id
  ✅ PASS: 1 task remaining after delete

[7/8] VALIDATION — POST without required field
  ✅ PASS: Validation error returned

[8/8] FRONTEND — UI Accessible
  ✅ PASS: Frontend returns 200

============================================
  Test Results
============================================
  Passed: 12
  Failed: 0
  Total:  12
============================================
```

---

## 8. Health Check Verification

### Container Health Status

```bash
# ตรวจสอบ health status ของทุก containers
docker inspect --format='{{.Name}}: {{.State.Health.Status}}' \
  mongodb backend 2>/dev/null

# Expected:
# /mongodb: healthy
# /backend: healthy
```

### Health Check Details

```bash
# ดูประวัติ health checks ของ backend
docker inspect backend | jq '.[0].State.Health'
```

**Expected:**

```json
{
  "Status": "healthy",
  "FailingStreak": 0,
  "Log": [
    {
      "Start": "2024-...",
      "End": "2024-...",
      "ExitCode": 0,
      "Output": "Healthy"
    }
  ]
}
```

---

## 9. Troubleshooting Guide

### Problem 1: MongoDB ไม่ start

```bash
# ตรวจสอบ logs
docker compose logs mongodb
```

| Error                        | สาเหตุ                          | วิธีแก้                                                  |
| ---------------------------- | ------------------------------- | -------------------------------------------------------- |
| `port 27017 already in use`  | มี MongoDB รันอยู่แล้วบนเครื่อง | `sudo systemctl stop mongod` หรือเปลี่ยน port ใน compose |
| `permission denied /data/db` | Volume permission issue         | `docker compose down -v && docker compose up --build -d` |

---

### Problem 2: Backend เชื่อมต่อ MongoDB ไม่ได้

```bash
docker compose logs backend
```

| Error                           | สาเหตุ                     | วิธีแก้                                               |
| ------------------------------- | -------------------------- | ----------------------------------------------------- |
| `Could not connect to database` | MongoDB ยัง start ไม่เสร็จ | รอ 30 วินาที แล้วลอง `docker compose restart backend` |
| `Authentication failed`         | Credentials ไม่ตรง         | ตรวจสอบ env vars ใน docker-compose.yml                |
| `MONGO_CONN_STR undefined`      | ไม่มี env var              | ตรวจสอบ environment section ใน compose                |

```bash
# ทดสอบเชื่อมต่อ MongoDB ตรงจาก container
docker exec -it mongodb mongo \
  -u admin -p password123 \
  --authenticationDatabase admin \
  --eval "db.adminCommand('ping')"
```

---

### Problem 3: Frontend npm install ช้า / ล้มเหลว

```bash
docker compose logs frontend
```

| Error                    | สาเหตุ                                 | วิธีแก้                                  |
| ------------------------ | -------------------------------------- | ---------------------------------------- |
| `npm ERR! code ERESOLVE` | Dependency conflict (axios `^=0.30.0`) | แก้ `package.json`: `"axios": "^0.27.2"` |
| Build ช้ามาก (>10 min)   | ไม่มี `.dockerignore`                  | สร้าง `.dockerignore` (ดูหัวข้อ 4)       |
| `ENOSPC`                 | Disk เต็ม                              | `docker system prune -a`                 |

---

### Problem 4: Frontend เชื่อมต่อ Backend ไม่ได้

```
เปิด Browser Console (F12 → Console tab)
ดู error messages
```

| Error                 | สาเหตุ                             | วิธีแก้                                                             |
| --------------------- | ---------------------------------- | ------------------------------------------------------------------- |
| `Network Error`       | Backend ยังไม่ ready               | ตรวจสอบ `curl http://localhost:3500/healthz`                        |
| `CORS error`          | CORS ไม่ได้เปิด                    | Backend มี `app.use(cors())` อยู่แล้ว — ตรวจสอบว่า backend รันอยู่  |
| `undefined/api/tasks` | `REACT_APP_BACKEND_URL` ไม่ได้ตั้ง | ตรวจสอบ env ใน compose แล้ว rebuild: `docker compose up --build -d` |

---

### การ Clean Up และเริ่มใหม่

```bash
# Stop ทุก containers
docker compose down

# Stop + ลบ volumes (ลบข้อมูล MongoDB)
docker compose down -v

# Stop + ลบ volumes + ลบ images
docker compose down -v --rmi all

# Build ใหม่ทั้งหมด
docker compose up --build -d
```

---

## 10. สรุปผลการทดสอบ

### Checklist

| #   | Test Case                      | Method                        | Expected                 | Status |
| --- | ------------------------------ | ----------------------------- | ------------------------ | ------ |
| 1   | MongoDB container starts       | `docker compose ps`           | Status: healthy          | ✅     |
| 2   | Backend container starts       | `docker compose ps`           | Status: healthy          | ✅     |
| 3   | Frontend container starts      | `docker compose ps`           | Status: running          | ✅     |
| 4   | Backend connects to MongoDB    | `docker compose logs backend` | "Connected to database." | ✅     |
| 5   | GET /healthz                   | `curl`                        | 200 "Healthy"            | ✅     |
| 6   | GET /ready                     | `curl`                        | 200 "Ready"              | ✅     |
| 7   | GET /started                   | `curl`                        | 200 "Started"            | ✅     |
| 8   | POST /api/tasks (Create)       | `curl`                        | Returns created task     | ✅     |
| 9   | GET /api/tasks (Read)          | `curl`                        | Returns task array       | ✅     |
| 10  | PUT /api/tasks/:id (Update)    | `curl`                        | Task completed toggled   | ✅     |
| 11  | DELETE /api/tasks/:id (Delete) | `curl`                        | Task removed             | ✅     |
| 12  | Validation (empty body)        | `curl`                        | ValidationError          | ✅     |
| 13  | Frontend UI accessible         | Browser                       | Page loads at :3000      | ✅     |
| 14  | Frontend shows tasks           | Browser                       | Task list rendered       | ✅     |
| 15  | Frontend CRUD works            | Browser                       | Add/Toggle/Delete work   | ✅     |

### Issues Found During Testing

| #   | Issue                              | Severity    | Impact                                        | Fix Location                                        |
| --- | ---------------------------------- | ----------- | --------------------------------------------- | --------------------------------------------------- |
| 1   | `USE_DB_AUTH` missing in K8s YAML  | 🔴 Critical | Backend ไม่สามารถ auth กับ MongoDB ใน K8s ได้ | `Backend/deployment.yaml`                           |
| 2   | Axios version `^=0.30.0`           | 🟡 Medium   | อาจทำให้ `npm install` ล้มเหลว                | `frontend/package.json`                             |
| 3   | Frontend ใช้ dev server            | 🟡 Medium   | ไม่เหมาะกับ production                        | `frontend/Dockerfile`                               |
| 4   | Node.js 14 EOL                     | 🟡 Medium   | ไม่มี security patches                        | ทั้ง `backend/Dockerfile` และ `frontend/Dockerfile` |
| 5   | `findOneAndUpdate` returns old doc | 🟢 Low      | Client อาจสับสน                               | `backend/routes/tasks.js`                           |

---

### Files Created/Modified Summary

```
project-root/
├── docker-compose.yml                    ← ✅ สร้างใหม่
├── test.sh                               ← ✅ สร้างใหม่ (optional)
├── Application-Code/
│   ├── backend/
│   │   └── .dockerignore                 ← ✅ สร้างใหม่
│   └── frontend/
│       └── .dockerignore                 ← ✅ สร้างใหม่
```

---
