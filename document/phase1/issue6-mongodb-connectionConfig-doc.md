# MongoDB Schema and Connection Configuration Documentation

## Issue #6 — Analyze and Document MongoDB Schema and Connection Config

---

## สารบัญ (Table of Contents)

1. [ภาพรวมของระบบ (System Overview)](#1-ภาพรวมของระบบ)
2. [Task Schema — Fields and Validations](#2-task-schema--fields-and-validations)
3. [Connection Logic — db.js](#3-connection-logic--dbjs)
4. [Environment Variables](#4-environment-variables)
5. [Kubernetes Secrets](#5-kubernetes-secrets)
6. [PV/PVC Configuration for Data Persistence](#6-pvpvc-configuration-for-data-persistence)
7. [MongoDB Deployment on Kubernetes](#7-mongodb-deployment-on-kubernetes)
8. [End-to-End Connection Flow](#8-end-to-end-connection-flow)
9. [Full Kubernetes Resource Map](#9-full-kubernetes-resource-map)
10. [ข้อสังเกตและข้อเสนอแนะ (Notes & Recommendations)](#10-ข้อสังเกตและข้อเสนอแนะ)

---

## 1. ภาพรวมของระบบ

MongoDB ทำหน้าที่เป็น **persistence layer** ของระบบ Three-Tier Application โดยถูก deploy บน Kubernetes และเชื่อมต่อกับ Backend (Node.js/Express) ผ่าน Mongoose ODM

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                               │
│                         Namespace: three-tier                            │
│                                                                          │
│  ┌───────────────┐       ┌────────────────┐       ┌───────────────────┐ │
│  │  Backend Pod   │       │  MongoDB Pod   │       │ PersistentVolume  │ │
│  │  (api)         │       │  (mongodb)     │       │ (mongo-pv)        │ │
│  │               ├───────▶│               ├──────▶│                   │ │
│  │  Mongoose     │ :27017 │  mongo:4.4.6   │ mount │ hostPath:         │ │
│  │  ODM          │        │                │       │ /data/db          │ │
│  └───────┬───────┘       └───────┬────────┘       └───────────────────┘ │
│          │                       │                          ▲            │
│          ▼                       ▼                          │            │
│  ┌───────────────┐       ┌────────────────┐       ┌────────┴──────────┐ │
│  │  Service       │       │  Service       │       │  PVC              │ │
│  │  api:3500      │       │  mongodb-svc   │       │  mongo-volume-    │ │
│  │  (ClusterIP)   │       │  :27017        │       │  claim (1Gi)      │ │
│  └───────────────┘       │  (ClusterIP)   │       └───────────────────┘ │
│                           └────────────────┘                             │
│                                  ▲                                       │
│                    ┌─────────────┴─────────────────┐                     │
│                    │      Secret: mongo-sec         │                     │
│                    │  username: YWRtaW4= (admin)    │                     │
│                    │  password: cGFzc3dvcmQxMjM=    │                     │
│                    │           (password123)        │                     │
│                    └───────────────────────────────┘                     │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Task Schema — Fields and Validations

### Source File: `models/task.js`

```javascript
const mongoose = require("mongoose");
const Schema = mongoose.Schema;

const taskSchema = new Schema({
  task: {
    type: String,
    required: true,
  },
  completed: {
    type: Boolean,
    default: false,
  },
});

module.exports = mongoose.model("task", taskSchema);
```

### Schema Fields Detail

```
Collection: "tasks" (auto-pluralized by Mongoose)
Database:   "todo"  (กำหนดใน MONGO_CONN_STR)

┌────────────┬───────────┬──────────┬─────────┬─────────────────────┐
│ Field      │ Type      │ Required │ Default │ Description         │
├────────────┼───────────┼──────────┼─────────┼─────────────────────┤
│ _id        │ ObjectId  │ Auto     │ Auto    │ Primary key         │
│            │           │          │         │ (MongoDB generated) │
├────────────┼───────────┼──────────┼─────────┼─────────────────────┤
│ task       │ String    │ ✅ Yes   │ —       │ Task description    │
│            │           │          │         │ ห้ามเป็นค่าว่าง      │
├────────────┼───────────┼──────────┼─────────┼─────────────────────┤
│ completed  │ Boolean   │ ❌ No    │ false   │ Completion status   │
│            │           │          │         │ true = เสร็จแล้ว     │
├────────────┼───────────┼──────────┼─────────┼─────────────────────┤
│ __v        │ Number    │ Auto     │ 0       │ Version key         │
│            │           │          │         │ (Mongoose internal) │
└────────────┴───────────┴──────────┴─────────┴─────────────────────┘
```

### Validation Rules

| Field       | Validation       | Error เมื่อ Fail                                | Trigger |
| ----------- | ---------------- | ----------------------------------------------- | ------- |
| `task`      | `required: true` | `"Path 'task' is required."` (ValidationError)  | save()  |
| `task`      | `type: String`   | CastError ถ้าค่าไม่สามารถ cast เป็น String ได้  | save()  |
| `completed` | `type: Boolean`  | CastError ถ้าค่าไม่สามารถ cast เป็น Boolean ได้ | save()  |

### Validation ที่ไม่ได้กำหนด (ข้อสังเกต)

```
❌ ไม่มี  minlength / maxlength       → task string ยาวไม่จำกัด
❌ ไม่มี  trim: true                   → อาจมี whitespace นำหน้า/ตามหลัง
❌ ไม่มี  unique                       → task ซ้ำกันได้
❌ ไม่มี  timestamps: true             → ไม่มี createdAt / updatedAt
❌ ไม่มี  index                        → ไม่มี index เพิ่มเติม (นอกจาก _id)
```

### ตัวอย่าง Documents ใน MongoDB

```javascript
// ✅ Valid document
{
    "_id": ObjectId("64a1b2c3d4e5f6a7b8c9d0e1"),
    "task": "Buy groceries",
    "completed": false,
    "__v": 0
}

// ✅ Valid — completed omitted (ใช้ default: false)
{
    "_id": ObjectId("64a1b2c3d4e5f6a7b8c9d0e2"),
    "task": "Clean the house",
    "__v": 0
}

// ❌ Invalid — task missing (required field)
{
    "completed": true
}
// → ValidationError: Path `task` is required.
```

### Mongoose Model Mapping

```
Model Name:       "task"
                    │
                    ▼ (Mongoose auto-pluralize)
Collection Name:  "tasks"
                    │
                    ▼ (กำหนดใน connection string)
Database Name:    "todo"
                    │
                    ▼
Full Path:        todo.tasks
```

---

## 3. Connection Logic — `db.js`

### Source File: `db.js`

```javascript
const mongoose = require("mongoose");

module.exports = async () => {
  try {
    const connectionParams = {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    };
    const useDBAuth = process.env.USE_DB_AUTH || false;
    if (useDBAuth) {
      connectionParams.user = process.env.MONGO_USERNAME;
      connectionParams.pass = process.env.MONGO_PASSWORD;
    }
    await mongoose.connect(process.env.MONGO_CONN_STR, connectionParams);
    console.log("Connected to database.");
  } catch (error) {
    console.log("Could not connect to database.", error);
  }
};
```

### Connection Flow Diagram

```
db.js called (from index.js)
         │
         ▼
┌─────────────────────────────────┐
│ กำหนด Base Connection Params    │
│ {                               │
│   useNewUrlParser: true,        │  ⚠️ Deprecated ใน Mongoose 6+
│   useUnifiedTopology: true      │  ⚠️ Deprecated ใน Mongoose 6+
│ }                               │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ อ่าน USE_DB_AUTH                │
│ process.env.USE_DB_AUTH || false │
└─────────────────────────────────┘
         │
         ├── Truthy ──────────────────────────────────┐
         │                                            ▼
         │                             ┌──────────────────────────────┐
         │                             │ เพิ่ม Auth Params:            │
         │                             │ connectionParams.user =       │
         │                             │   process.env.MONGO_USERNAME  │
         │                             │ connectionParams.pass =       │
         │                             │   process.env.MONGO_PASSWORD  │
         │                             └──────────────┬───────────────┘
         │                                            │
         ▼◀───────────────────────────────────────────┘
┌─────────────────────────────────┐
│ mongoose.connect(               │
│   MONGO_CONN_STR,               │
│   connectionParams              │
│ )                               │
└─────────────────────────────────┘
         │
         ├── Success ──▶ console.log("Connected to database.")
         │                Server ทำงานต่อปกติ
         │
         └── Error ────▶ console.log("Could not connect to database.", error)
                         ⚠️ Server ยังทำงานต่อ (ไม่มี process.exit)
                         ⚠️ /ready endpoint จะตอบ 503
```

### Connection Modes

#### Mode 1: Without Authentication (`USE_DB_AUTH` = falsy)

```
mongoose.connect(
  "mongodb://mongodb-svc:27017/todo?directConnection=true",
  {
    useNewUrlParser: true,
    useUnifiedTopology: true
  }
)

✅ ใช้ได้กับ MongoDB ที่ไม่ได้เปิด authentication
❌ ไม่ปลอดภัยสำหรับ production
```

#### Mode 2: With Authentication (`USE_DB_AUTH` = truthy)

```
mongoose.connect(
  "mongodb://mongodb-svc:27017/todo?directConnection=true",
  {
    useNewUrlParser: true,
    useUnifiedTopology: true,
    user: "admin",           ← จาก MONGO_USERNAME
    pass: "password123"      ← จาก MONGO_PASSWORD
  }
)

✅ ปลอดภัย — ใช้ credentials จาก K8s Secrets
⚠️ Auth DB default = "admin" (Mongoose default)
```

### Connection String Anatomy

```
mongodb://mongodb-svc:27017/todo?directConnection=true
│          │              │  │    │
│          │              │  │    └── Query Parameter:
│          │              │  │        บังคับเชื่อมต่อตรง
│          │              │  │        (ไม่ผ่าน replica set discovery)
│          │              │  │
│          │              │  └── Database Name: "todo"
│          │              │      → Collection "tasks" อยู่ใน DB นี้
│          │              │
│          │              └── Port: 27017 (MongoDB default)
│          │
│          └── Host: "mongodb-svc"
│              → K8s Service name ใน namespace "three-tier"
│
└── Protocol: mongodb:// (standard)
```

### Connection Parameters ทั้งหมด

| Parameter            | Value   | Description                             | Status                      |
| -------------------- | ------- | --------------------------------------- | --------------------------- |
| `useNewUrlParser`    | `true`  | ใช้ MongoDB URL parser ตัวใหม่          | ⚠️ Deprecated (Mongoose 6+) |
| `useUnifiedTopology` | `true`  | ใช้ Server Discovery engine ตัวใหม่     | ⚠️ Deprecated (Mongoose 6+) |
| `user`               | dynamic | ชื่อผู้ใช้ (เมื่อ `USE_DB_AUTH` = true) | Conditional                 |
| `pass`               | dynamic | รหัสผ่าน (เมื่อ `USE_DB_AUTH` = true)   | Conditional                 |

### Mongoose Connection States (ใช้ใน `/ready` endpoint)

| Value | State         | Description                              | `/ready` Response |
| ----- | ------------- | ---------------------------------------- | ----------------- |
| 0     | disconnected  | ยังไม่ได้เชื่อมต่อ / ตัดการเชื่อมต่อแล้ว | `503 Not Ready`   |
| 1     | connected     | เชื่อมต่อสำเร็จ ✅                       | `200 Ready`       |
| 2     | connecting    | กำลังเชื่อมต่อ                           | `503 Not Ready`   |
| 3     | disconnecting | กำลังตัดการเชื่อมต่อ                     | `503 Not Ready`   |

---

## 4. Environment Variables

### ตารางสรุป Environment Variables ทั้งหมด

| Variable         | ใช้ใน   | Required    | K8s Source                          | ค่าจริง                                                  |
| ---------------- | ------- | ----------- | ----------------------------------- | -------------------------------------------------------- |
| `MONGO_CONN_STR` | `db.js` | ✅ Yes      | Deployment env (hardcoded value)    | `mongodb://mongodb-svc:27017/todo?directConnection=true` |
| `MONGO_USERNAME` | `db.js` | Conditional | Secret `mongo-sec` → key `username` | `admin` (base64: `YWRtaW4=`)                             |
| `MONGO_PASSWORD` | `db.js` | Conditional | Secret `mongo-sec` → key `password` | `password123` (base64: `cGFzc3dvcmQxMjM=`)               |
| `USE_DB_AUTH`    | `db.js` | ❌ No       | ❌ **ไม่ได้กำหนดใน K8s YAML**       | `undefined` → ถูกประเมินเป็น `false`                     |

### Environment Variable Mapping: K8s → Application

```
┌─────────────────────────────────────────────────────────────────────┐
│                Backend Deployment YAML (env section)                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  env:                                                               │
│    ┌─────────────────────────────────────────────────────────────┐  │
│    │ - name: MONGO_CONN_STR                                      │  │
│    │   value: mongodb://mongodb-svc:27017/todo?directConnection= │  │
│    │          true                                               │  │
│    │   Source: Hardcoded ──────────────▶ db.js: mongoose.connect()│  │
│    └─────────────────────────────────────────────────────────────┘  │
│    ┌─────────────────────────────────────────────────────────────┐  │
│    │ - name: MONGO_USERNAME                                      │  │
│    │   valueFrom:                                                │  │
│    │     secretKeyRef:                                           │  │
│    │       name: mongo-sec ─┐                                    │  │
│    │       key: username    │                                    │  │
│    │   Source: Secret ──────┴────────▶ db.js: connectionParams   │  │
│    │          YWRtaW4= → "admin"       .user (if USE_DB_AUTH)    │  │
│    └─────────────────────────────────────────────────────────────┘  │
│    ┌─────────────────────────────────────────────────────────────┐  │
│    │ - name: MONGO_PASSWORD                                      │  │
│    │   valueFrom:                                                │  │
│    │     secretKeyRef:                                           │  │
│    │       name: mongo-sec ─┐                                    │  │
│    │       key: password    │                                    │  │
│    │   Source: Secret ──────┴────────▶ db.js: connectionParams   │  │
│    │          cGFzc3dvcmQxMjM=         .pass (if USE_DB_AUTH)    │  │
│    │          → "password123"                                    │  │
│    └─────────────────────────────────────────────────────────────┘  │
│    ┌─────────────────────────────────────────────────────────────┐  │
│    │ - name: USE_DB_AUTH                                         │  │
│    │   ❌ NOT DEFINED IN YAML                                    │  │
│    │   Result: process.env.USE_DB_AUTH = undefined → false       │  │
│    │   Impact: MONGO_USERNAME / MONGO_PASSWORD จะไม่ถูกใช้งาน     │  │
│    └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### ⚠️ ปัญหาสำคัญ: `USE_DB_AUTH` ไม่ได้ถูกตั้งค่า

```
┌──────────────────────────────────────────────────────────────────┐
│                      CRITICAL FINDING                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  สถานการณ์ปัจจุบัน:                                                │
│                                                                  │
│  1. MongoDB Pod ถูกตั้งค่าด้วย:                                    │
│     MONGO_INITDB_ROOT_USERNAME = "admin"                         │
│     MONGO_INITDB_ROOT_PASSWORD = "password123"                   │
│     → MongoDB เปิด Authentication ✅                              │
│                                                                  │
│  2. Backend Pod มี env vars:                                     │
│     MONGO_CONN_STR  = "mongodb://mongodb-svc:27017/todo?..."    │
│     MONGO_USERNAME  = "admin"      (จาก Secret)                  │
│     MONGO_PASSWORD  = "password123" (จาก Secret)                 │
│     USE_DB_AUTH     = undefined ❌ ← ไม่ได้กำหนด!                 │
│                                                                  │
│  3. ผลลัพธ์ใน db.js:                                              │
│     const useDBAuth = process.env.USE_DB_AUTH || false;          │
│     // useDBAuth = undefined || false = false                    │
│     // → ข้าม authentication block                               │
│     // → MONGO_USERNAME, MONGO_PASSWORD ไม่ถูกใช้งาน              │
│                                                                  │
│  4. ผลกระทบ:                                                      │
│     → mongoose.connect() พยายามเชื่อมต่อ MongoDB โดยไม่มี auth   │
│     → MongoDB ปฏิเสธการเชื่อมต่อ (authentication required)       │
│     → Backend ไม่สามารถเชื่อมต่อ DB ได้                           │
│     → /ready endpoint ตอบ 503                                    │
│     → Kubernetes readinessProbe fail                             │
│     → Pod ไม่ได้รับ traffic                                       │
│                                                                  │
│  แก้ไข: เพิ่มใน Backend deployment.yaml:                          │
│     - name: USE_DB_AUTH                                          │
│       value: "true"                                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 5. Kubernetes Secrets

### Source File: `secrets.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  namespace: three-tier
  name: mongo-sec
type: Opaque
data:
  password: cGFzc3dvcmQxMjM= #password123
  username: YWRtaW4= #admin
```

### Secret Structure

```
┌──────────────────────────────────────────────────────────┐
│                   Secret: mongo-sec                       │
│                   Namespace: three-tier                    │
│                   Type: Opaque                             │
├──────────┬──────────────────┬────────────────────────────┤
│ Key      │ Base64 Value     │ Decoded Value              │
├──────────┼──────────────────┼────────────────────────────┤
│ username │ YWRtaW4=         │ admin                      │
│ password │ cGFzc3dvcmQxMjM= │ password123                │
└──────────┴──────────────────┴────────────────────────────┘
```

### Base64 Encoding/Decoding

```bash
# Encoding
$ echo -n "admin" | base64
YWRtaW4=

$ echo -n "password123" | base64
cGFzc3dvcmQxMjM=

# Decoding (สำหรับตรวจสอบ)
$ echo "YWRtaW4=" | base64 -d
admin

$ echo "cGFzc3dvcmQxMjM=" | base64 -d
password123
```

### Secret ถูกใช้โดย Pods ใดบ้าง

```
                    Secret: mongo-sec
                    ┌────────────────┐
                    │ username: admin │
                    │ password: ***   │
                    └───────┬────────┘
                            │
              ┌─────────────┴──────────────┐
              │                            │
              ▼                            ▼
    ┌─────────────────┐          ┌─────────────────┐
    │  Backend Pod     │          │  MongoDB Pod     │
    │  (api)           │          │  (mongodb)       │
    ├─────────────────┤          ├─────────────────┤
    │ MONGO_USERNAME   │          │ MONGO_INITDB_   │
    │  ← username key  │          │ ROOT_USERNAME    │
    │ MONGO_PASSWORD   │          │  ← username key  │
    │  ← password key  │          │ MONGO_INITDB_   │
    │                  │          │ ROOT_PASSWORD    │
    │ ⚠️ ใช้จริงหรือไม่ │          │  ← password key  │
    │ ขึ้นกับ           │          │                  │
    │ USE_DB_AUTH      │          │ ✅ ใช้เสมอ        │
    └─────────────────┘          └─────────────────┘
```

### Secret ถูก Reference อย่างไรใน Deployment YAML

**Backend Deployment:**

```yaml
env:
  - name: MONGO_USERNAME
    valueFrom:
      secretKeyRef:
        name: mongo-sec # ← ชื่อ Secret
        key: username # ← key ภายใน Secret
  - name: MONGO_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mongo-sec
        key: password
```

**MongoDB Deployment:**

```yaml
env:
  - name: MONGO_INITDB_ROOT_USERNAME
    valueFrom:
      secretKeyRef:
        name: mongo-sec # ← Secret เดียวกัน
        key: username
  - name: MONGO_INITDB_ROOT_PASSWORD
    valueFrom:
      secretKeyRef:
        name: mongo-sec
        key: password
```

### Security Considerations

| ข้อพิจารณา          | สถานะ | รายละเอียด                                                   |
| ------------------- | ----- | ------------------------------------------------------------ |
| Base64 ≠ Encryption | ⚠️    | Base64 เป็นเพียง encoding ไม่ใช่ encryption ใครก็ decode ได้ |
| Secret ใน Git       | 🔴    | `secrets.yaml` อยู่ใน repo — credentials ถูก expose          |
| Password Complexity | 🔴    | `password123` เป็นรหัสผ่านที่อ่อนแอมาก                       |
| RBAC Access Control | ⚠️    | ไม่มีข้อมูล RBAC ว่าใครเข้าถึง Secret ได้บ้าง                |
| Encryption at Rest  | ⚠️    | ขึ้นกับ K8s cluster config (EncryptionConfiguration)         |

---

## 6. PV/PVC Configuration for Data Persistence

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Node                          │
│                                                             │
│  ┌───────────────┐     ┌──────────────┐     ┌────────────┐ │
│  │  MongoDB Pod   │     │     PVC      │     │     PV     │ │
│  │               │     │              │     │            │ │
│  │  Container:    │     │ mongo-volume │     │ mongo-pv   │ │
│  │  /data/db ─────┼────▶│ -claim       ├────▶│            │ │
│  │  (mountPath)   │     │              │     │ hostPath:  │ │
│  │               │     │ Request: 1Gi │     │ /data/db   │ │
│  │               │     │ RWO          │     │ Cap: 1Gi   │ │
│  └───────────────┘     └──────────────┘     │ RWO        │ │
│                                             │            │ │
│                                             └──────┬─────┘ │
│                                                    │       │
│                                                    ▼       │
│                                             ┌────────────┐ │
│                                             │ Host Node  │ │
│                                             │ Filesystem │ │
│                                             │ /data/db   │ │
│                                             └────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 6.1 PersistentVolume (PV) — `pv.yaml`

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
  namespace: three-tier
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data/db
```

**PV Specifications:**

| Property      | Value           | Description                                       |
| ------------- | --------------- | ------------------------------------------------- |
| name          | `mongo-pv`      | ชื่อ PV resource                                  |
| namespace     | `three-tier`    | ⚠️ PV เป็น cluster-scoped — namespace ไม่มีผลจริง |
| capacity      | `1Gi`           | ขนาดพื้นที่จัดเก็บสูงสุด                          |
| volumeMode    | `Filesystem`    | Mount เป็น filesystem (ไม่ใช่ block device)       |
| accessModes   | `ReadWriteOnce` | อ่านเขียนได้จาก Node เดียวเท่านั้น                |
| hostPath.path | `/data/db`      | Path บน Node จริงที่เก็บข้อมูล                    |

### 6.2 PersistentVolumeClaim (PVC) — `pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-volume-claim
  namespace: three-tier
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 1Gi
```

**PVC Specifications:**

| Property         | Value                | Description                                                       |
| ---------------- | -------------------- | ----------------------------------------------------------------- |
| name             | `mongo-volume-claim` | ชื่อ PVC resource                                                 |
| namespace        | `three-tier`         | Namespace ที่ PVC อยู่                                            |
| accessModes      | `ReadWriteOnce`      | ต้องตรงกับ PV                                                     |
| storageClassName | `""`                 | Empty string = ไม่ใช้ dynamic provisioning, bind กับ PV ที่มีอยู่ |
| storage request  | `1Gi`                | ขอพื้นที่ 1Gi (ตรงกับ PV capacity)                                |

### 6.3 Volume Mount ใน MongoDB Deployment

```yaml
# MongoDB Deployment (ส่วนที่เกี่ยวกับ volume)
spec:
  template:
    spec:
      containers:
        - name: mon
          volumeMounts:
            - name: mongo-volume # ← ชื่อ volume reference
              mountPath: /data/db # ← path ภายใน container
      volumes:
        - name: mongo-volume # ← ชื่อ volume
          persistentVolumeClaim:
            claimName: mongo-volume-claim # ← อ้างอิง PVC
```

### PV ↔ PVC ↔ Pod Binding Flow

```
┌─────────────────┐     Bind      ┌──────────────────┐     Mount     ┌─────────────────┐
│ PersistentVolume │◀─────────────│ PersistentVolume  │◀─────────────│  MongoDB Pod     │
│ (mongo-pv)       │              │ Claim             │              │                  │
├─────────────────┤              │ (mongo-volume-    │              │  Container:      │
│ Cap: 1Gi         │  Matched by: │  claim)           │  Referenced  │  mountPath:      │
│ Access: RWO      │  • capacity  ├──────────────────┤  by name:    │  /data/db        │
│ hostPath:        │  • accessMode│ Request: 1Gi      │  "mongo-     │                  │
│  /data/db        │  • className │ Access: RWO       │   volume"    │  volumes:        │
│ className: ""    │  (both "")   │ className: ""     │              │  - mongo-volume  │
└─────────────────┘              └──────────────────┘              └─────────────────┘
```

### Data Persistence Scenario

```
┌──────────────────────────────────────────────────────────────────┐
│                   Data Lifecycle                                  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MongoDB เขียนข้อมูล                                              │
│       │                                                          │
│       ▼                                                          │
│  Container: /data/db  (volumeMount)                              │
│       │                                                          │
│       ▼                                                          │
│  PVC: mongo-volume-claim                                         │
│       │                                                          │
│       ▼                                                          │
│  PV: mongo-pv                                                    │
│       │                                                          │
│       ▼                                                          │
│  Node Filesystem: /data/db  (hostPath)                           │
│                                                                  │
│  ✅ Pod ถูก restart    → ข้อมูลยังอยู่ (mount path เดิม)          │
│  ✅ Pod ถูก delete     → ข้อมูลยังอยู่ (PV ยังอยู่)               │
│  ⚠️ Pod ย้าย Node     → ข้อมูลหาย! (hostPath อยู่บน Node เดิม)   │
│  ⚠️ Node ถูก delete   → ข้อมูลหาย! (hostPath อยู่บน Node เดิม)   │
│  ❌ PV ถูก delete      → ข้อมูลอาจหาย (ขึ้นกับ reclaimPolicy)    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 7. MongoDB Deployment on Kubernetes

### Source File: `Database/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: three-tier
  name: mongodb
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
      containers:
        - name: mon
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
      volumes:
        - name: mongo-volume
          persistentVolumeClaim:
            claimName: mongo-volume-claim
```

### Deployment Specifications

| Property       | Value         | Description                      |
| -------------- | ------------- | -------------------------------- |
| name           | `mongodb`     | ชื่อ Deployment                  |
| namespace      | `three-tier`  | Namespace ที่ deploy             |
| replicas       | `1`           | จำนวน Pod (single instance)      |
| image          | `mongo:4.4.6` | MongoDB Community Edition v4.4.6 |
| containerPort  | `27017`       | MongoDB default port             |
| container name | `mon`         | ชื่อ container ภายใน Pod         |

### Custom Command Analysis

```yaml
command:
  - "numactl" # NUMA memory allocation control
  - "--interleave=all" # กระจาย memory allocation ทุก NUMA nodes
  - "mongod" # MongoDB daemon process
  - "--wiredTigerCacheSizeGB" # จำกัดขนาด WiredTiger cache
  - "0.1" # 0.1 GB (100 MB) — ประหยัด memory
  - "--bind_ip" # กำหนด IP ที่ MongoDB listen
  - "0.0.0.0" # Listen ทุก network interfaces
```

**Command Breakdown:**

```
numactl --interleave=all mongod --wiredTigerCacheSizeGB 0.1 --bind_ip 0.0.0.0
│                        │       │                           │
│                        │       │                           └── Listen ทุก IP
│                        │       │                               (จำเป็นสำหรับ K8s)
│                        │       │
│                        │       └── จำกัด cache เหลือ 100MB
│                        │           (default = 50% of RAM - 1GB)
│                        │           เหมาะกับ resource-constrained environment
│                        │
│                        └── MongoDB server process
│
└── NUMA optimization
    กระจาย memory allocation เท่าเทียมกันทุก NUMA nodes
    ช่วยเพิ่ม performance บน multi-socket servers
```

### MongoDB Environment Variables

| Variable                     | Source             | Value         | Description                        |
| ---------------------------- | ------------------ | ------------- | ---------------------------------- |
| `MONGO_INITDB_ROOT_USERNAME` | Secret `mongo-sec` | `admin`       | Root username สำหรับ initial setup |
| `MONGO_INITDB_ROOT_PASSWORD` | Secret `mongo-sec` | `password123` | Root password สำหรับ initial setup |

> **หมายเหตุ:** `MONGO_INITDB_*` variables จะถูกใช้เฉพาะ **ครั้งแรก** ที่ MongoDB start กับ empty data directory เท่านั้น ถ้า `/data/db` มีข้อมูลอยู่แล้ว (จาก PV) ตัวแปรเหล่านี้จะถูกข้ามไป

### MongoDB Service — `service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  namespace: three-tier
  name: mongodb-svc
spec:
  selector:
    app: mongodb
  ports:
    - name: mongodb-svc
      protocol: TCP
      port: 27017
      targetPort: 27017
```

**Service Specifications:**

| Property   | Value          | Description                                  |
| ---------- | -------------- | -------------------------------------------- |
| name       | `mongodb-svc`  | ชื่อ Service — ตรงกับ host ใน MONGO_CONN_STR |
| namespace  | `three-tier`   | Namespace เดียวกับ Deployment                |
| type       | `ClusterIP`    | (default) เข้าถึงได้เฉพาะภายใน cluster       |
| port       | `27017`        | Port ที่ Service expose                      |
| targetPort | `27017`        | Port ของ container ที่ forward ไป            |
| selector   | `app: mongodb` | เลือก Pod ที่มี label `app: mongodb`         |

### DNS Resolution ภายใน Cluster

```
Backend Pod เชื่อมต่อ:
  mongodb://mongodb-svc:27017/todo?directConnection=true
             │
             ▼
  K8s DNS resolves "mongodb-svc" to:
  mongodb-svc.three-tier.svc.cluster.local
             │
             ▼
  ClusterIP Service forwards to:
  MongoDB Pod (app: mongodb) port 27017
```

---

## 8. End-to-End Connection Flow

### Complete Flow: Backend → MongoDB

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  Step 1: Backend Pod Starts                                             │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ index.js                                                          │ │
│  │   │                                                               │ │
│  │   ├── connection()  ──▶  db.js                                    │ │
│  │   │                       │                                       │ │
│  │   │                       ├── Read env vars:                      │ │
│  │   │                       │   MONGO_CONN_STR = "mongodb://        │ │
│  │   │                       │     mongodb-svc:27017/todo?           │ │
│  │   │                       │     directConnection=true"            │ │
│  │   │                       │   USE_DB_AUTH = undefined → false     │ │
│  │   │                       │   (MONGO_USERNAME = "admin" — unused) │ │
│  │   │                       │   (MONGO_PASSWORD = "***" — unused)   │ │
│  │   │                       │                                       │ │
│  │   │                       ├── mongoose.connect(                   │ │
│  │   │                       │     MONGO_CONN_STR,                   │ │
│  │   │                       │     { useNewUrlParser: true,          │ │
│  │   │                       │       useUnifiedTopology: true }      │ │
│  │   │                       │   )                                   │ │
│  │   │                       │                                       │ │
│  └───┼───────────────────────┼───────────────────────────────────────┘ │
│      │                       │                                         │
│      │                       ▼                                         │
│  Step 2: DNS Resolution                                                │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ "mongodb-svc" → mongodb-svc.three-tier.svc.cluster.local          │ │
│  │                 → ClusterIP (e.g., 10.96.x.x)                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                       │                                                 │
│                       ▼                                                 │
│  Step 3: Service Routing                                                │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ Service: mongodb-svc (ClusterIP)                                  │ │
│  │   port: 27017 → targetPort: 27017                                 │ │
│  │   selector: app=mongodb → MongoDB Pod                             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                       │                                                 │
│                       ▼                                                 │
│  Step 4: MongoDB Connection                                             │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ MongoDB Pod (mongo:4.4.6)                                         │ │
│  │   ├── Listening on 0.0.0.0:27017                                  │ │
│  │   ├── Auth enabled (MONGO_INITDB_ROOT_USERNAME/PASSWORD set)      │ │
│  │   ├── WiredTiger cache: 100MB                                     │ │
│  │   └── Data stored at: /data/db → PVC → PV → Node:/data/db        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                       │                                                 │
│                       ▼                                                 │
│  Step 5: Database & Collection                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │ Database: "todo"                                                  │ │
│  │   └── Collection: "tasks"                                         │ │
│  │         └── Documents: { _id, task, completed, __v }              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Health Check Integration

```
Kubernetes                    Backend Pod                    MongoDB
    │                              │                            │
    │  GET /started                │                            │
    │─────────────────────────────▶│                            │
    │  200 "Started"               │                            │
    │◀─────────────────────────────│                            │
    │                              │                            │
    │  GET /healthz                │                            │
    │─────────────────────────────▶│                            │
    │  200 "Healthy"               │                            │
    │◀─────────────────────────────│                            │
    │                              │                            │
    │  GET /ready                  │                            │
    │─────────────────────────────▶│                            │
    │                              │ mongoose.connection        │
    │                              │ .readyState === 1 ?        │
    │                              │────────────────────────────│
    │                              │                            │
    │                              │◀───── (check state) ──────│
    │                              │                            │
    │  200 "Ready"                 │  (if connected)            │
    │◀─────────────────────────────│                            │
    │        OR                    │                            │
    │  503 "Not Ready"            │  (if disconnected)         │
    │◀─────────────────────────────│                            │
    │                              │                            │
    │  If 503 repeatedly:          │                            │
    │  → Remove Pod from           │                            │
    │    Service endpoints         │                            │
    │  → No traffic routed         │                            │
    │    to this Pod               │                            │
```

---

## 9. Full Kubernetes Resource Map

### All Resources in `three-tier` Namespace

```
Namespace: three-tier
│
├── Secrets
│   └── mongo-sec                          (Opaque)
│       ├── username: YWRtaW4= (admin)
│       └── password: cGFzc3dvcmQxMjM= (password123)
│
├── PersistentVolume (cluster-scoped)
│   └── mongo-pv                           (1Gi, RWO, hostPath:/data/db)
│
├── PersistentVolumeClaim
│   └── mongo-volume-claim                 (1Gi, RWO, bound to mongo-pv)
│
├── Deployments
│   ├── mongodb                            (1 replica)
│   │   └── Pod: mongo:4.4.6
│   │       ├── Port: 27017
│   │       ├── Env: MONGO_INITDB_ROOT_USERNAME (from secret)
│   │       ├── Env: MONGO_INITDB_ROOT_PASSWORD (from secret)
│   │       └── Volume: mongo-volume → PVC: mongo-volume-claim
│   │
│   ├── api                                (2 replicas)
│   │   └── Pod: backend:1 (ECR image)
│   │       ├── Port: 3500
│   │       ├── Env: MONGO_CONN_STR (hardcoded)
│   │       ├── Env: MONGO_USERNAME (from secret)
│   │       ├── Env: MONGO_PASSWORD (from secret)
│   │       ├── Env: USE_DB_AUTH ❌ MISSING
│   │       ├── livenessProbe: /healthz
│   │       ├── readinessProbe: /ready
│   │       └── startupProbe: /started
│   │
│   └── frontend                           (1 replica)
│       └── Pod: frontend:3 (ECR image)
│           ├── Port: 3000
│           └── Env: REACT_APP_BACKEND_URL
│
├── Services
│   ├── mongodb-svc                        (ClusterIP, 27017)
│   │   └── selector: app=mongodb
│   ├── api                                (ClusterIP, 3500)
│   │   └── selector: role=api
│   └── frontend                           (ClusterIP, 3000)
│       └── selector: role=frontend
│
└── Ingress
    └── mainlb                             (ALB, internet-facing)
        └── Host: amanpathakdevops.study
            ├── /api/*     → api:3500
            ├── /healthz   → api:3500
            ├── /ready     → api:3500
            ├── /started   → api:3500
            └── /*         → frontend:3000
```

### Resource Dependency Graph

```
                         ┌──────────────┐
                         │   Ingress    │
                         │   mainlb     │
                         └──────┬───────┘
                                │
                 ┌──────────────┼───────────────┐
                 │              │               │
                 ▼              ▼               ▼
          ┌────────────┐ ┌───────────┐  ┌──────────────┐
          │ Service    │ │ Service   │  │ Service      │
          │ frontend   │ │ api       │  │ mongodb-svc  │
          │ :3000      │ │ :3500     │  │ :27017       │
          └─────┬──────┘ └─────┬─────┘  └──────┬───────┘
                │              │               │
                ▼              ▼               ▼
          ┌────────────┐ ┌───────────┐  ┌──────────────┐
          │ Deployment │ │Deployment │  │ Deployment   │
          │ frontend   │ │ api       │  │ mongodb      │
          │ (1 replica)│ │(2 replica)│  │ (1 replica)  │
          └────────────┘ └─────┬─────┘  └──────┬───────┘
                               │               │
                               │               ├────▶ PVC: mongo-volume-claim
                               │               │           │
                               │               │           ▼
                               │               │     PV: mongo-pv
                               │               │           │
                               ▼               ▼           ▼
                         ┌───────────────────────────┐ ┌────────┐
                         │    Secret: mongo-sec      │ │hostPath│
                         │    (shared by both)       │ │/data/db│
                         └───────────────────────────┘ └────────┘
```

---

## 10. ข้อสังเกตและข้อเสนอแนะ

### 🔴 Critical — ต้องแก้ไขทันที

| #   | ปัญหา                         | ไฟล์                      | รายละเอียด                                                                                                     | วิธีแก้ไข                                                  |
| --- | ----------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 1   | **`USE_DB_AUTH` ไม่ได้กำหนด** | Backend `deployment.yaml` | MongoDB เปิด auth แต่ Backend ไม่ส่ง credentials เพราะ `USE_DB_AUTH` = undefined → Backend เชื่อมต่อ DB ไม่ได้ | เพิ่ม `- name: USE_DB_AUTH` `value: "true"` ใน env section |
| 2   | **Secret อยู่ใน Git**         | `secrets.yaml`            | Credentials ถูก commit ลง repository (base64 ≠ encryption)                                                     | ใช้ Sealed Secrets, External Secrets Operator, หรือ Vault  |
| 3   | **Password อ่อนแอ**           | `secrets.yaml`            | `password123` สามารถถูก brute-force ได้ง่าย                                                                    | ใช้ strong password (>16 chars, mixed characters)          |

### แก้ไข Issue #1 — เพิ่ม `USE_DB_AUTH`:

```yaml
# Backend deployment.yaml — env section
env:
  - name: MONGO_CONN_STR
    value: mongodb://mongodb-svc:27017/todo?directConnection=true
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
  # ✅ เพิ่มบรรทัดนี้
  - name: USE_DB_AUTH
    value: "true"
```

### 🟡 Improvement — ควรปรับปรุง

| #   | ปัญหา                                  | ไฟล์                       | รายละเอียด                                                        | วิธีแก้ไข                                                   |
| --- | -------------------------------------- | -------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------- |
| 4   | **hostPath PV**                        | `pv.yaml`                  | ข้อมูลผูกกับ Node เดียว — Pod ย้าย Node = ข้อมูลหาย               | ใช้ EBS CSI Driver (AWS), หรือ cloud-native StorageClass    |
| 5   | **Deployment แทน StatefulSet**         | Database `deployment.yaml` | MongoDB เป็น stateful workload ควรใช้ StatefulSet                 | เปลี่ยนเป็น StatefulSet พร้อม volumeClaimTemplates          |
| 6   | **ไม่มี Health Probes สำหรับ MongoDB** | Database `deployment.yaml` | ไม่มี liveness/readiness probe — K8s ไม่รู้ว่า MongoDB ล้มหรือไม่ | เพิ่ม probe ด้วย `mongosh --eval "db.adminCommand('ping')"` |
| 7   | **ไม่มี Resource Limits**              | Database `deployment.yaml` | MongoDB อาจใช้ memory/CPU เกินจนกระทบ Pod อื่น                    | เพิ่ม `resources.requests` และ `resources.limits`           |
| 8   | **Deprecated Mongoose options**        | `db.js`                    | `useNewUrlParser`, `useUnifiedTopology` ไม่จำเป็นใน Mongoose 6+   | ลบ options ทั้งสองออก                                       |
| 9   | **PV namespace**                       | `pv.yaml`                  | PV เป็น cluster-scoped resource — `namespace` field ไม่มีผล       | ลบ `namespace` ออก เพื่อไม่ให้สับสน                         |
| 10  | **Single replica MongoDB**             | Database `deployment.yaml` | ไม่มี High Availability — ถ้า Pod ตาย = downtime                  | พิจารณา MongoDB Replica Set (3 nodes)                       |
| 11  | **WiredTiger cache 0.1GB**             | Database `deployment.yaml` | 100MB cache อาจน้อยเกินไปสำหรับ production                        | ปรับตาม workload จริง (default: 50% RAM - 1GB)              |
| 12  | **DB connection ไม่มี retry**          | `db.js`                    | ถ้าเชื่อมต่อไม่ได้ จะไม่ลอง retry server ยังทำงานต่อโดยไม่มี DB   | เพิ่ม retry logic หรือ `process.exit(1)`                    |
| 13  | **ไม่มี Schema validation เพิ่มเติม**  | `models/task.js`           | ไม่มี `trim`, `maxlength`, `timestamps`                           | เพิ่ม validation ตาม business requirements                  |

### ตัวอย่างการปรับปรุง MongoDB Deployment (StatefulSet + Probes + Resources)

```yaml
apiVersion: apps/v1
kind: StatefulSet # ← เปลี่ยนจาก Deployment
metadata:
  namespace: three-tier
  name: mongodb
spec:
  serviceName: mongodb-svc # ← จำเป็นสำหรับ StatefulSet
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
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
          # ✅ เพิ่ม Health Probes
          livenessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - mongo
                - --eval
                - "db.adminCommand('ping')"
            initialDelaySeconds: 5
            periodSeconds: 5
          # ✅ เพิ่ม Resource Limits
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: mongo-data
              mountPath: /data/db
  # ✅ ใช้ volumeClaimTemplates แทน PV/PVC แยก
  volumeClaimTemplates:
    - metadata:
        name: mongo-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

### ตัวอย่างการปรับปรุง db.js (Retry Logic)

```javascript
const mongoose = require("mongoose");

const MAX_RETRIES = 5;
const RETRY_DELAY = 5000; // 5 seconds

module.exports = async () => {
  const connectionParams = {};

  const useDBAuth = process.env.USE_DB_AUTH || false;
  if (useDBAuth) {
    connectionParams.user = process.env.MONGO_USERNAME;
    connectionParams.pass = process.env.MONGO_PASSWORD;
  }

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      await mongoose.connect(process.env.MONGO_CONN_STR, connectionParams);
      console.log("Connected to database.");
      return; // สำเร็จ — ออกจากฟังก์ชัน
    } catch (error) {
      console.log(
        `Database connection attempt ${attempt}/${MAX_RETRIES} failed:`,
        error.message,
      );
      if (attempt === MAX_RETRIES) {
        console.log("Max retries reached. Exiting...");
        process.exit(1);
      }
      await new Promise((res) => setTimeout(res, RETRY_DELAY));
    }
  }
};
```

### ตัวอย่างการปรับปรุง Task Schema

```javascript
const taskSchema = new Schema(
  {
    task: {
      type: String,
      required: [true, "Task description is required"],
      trim: true,
      maxlength: [500, "Task cannot exceed 500 characters"],
    },
    completed: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true, // เพิ่ม createdAt, updatedAt อัตโนมัติ
  },
);

// เพิ่ม index สำหรับ query ที่ใช้บ่อย
taskSchema.index({ completed: 1 });
```

---

> **เอกสารนี้จัดทำตาม Acceptance Criteria ของ Issue #6:**
>
> - ✅ Document Task schema fields and validations
> - ✅ Document db.js connection logic (with/without auth)
> - ✅ Document env vars (MONGO_CONN_STR, MONGO_USERNAME, MONGO_PASSWORD, USE_DB_AUTH)
> - ✅ Document K8s secrets.yaml (base64 encoded creds)
