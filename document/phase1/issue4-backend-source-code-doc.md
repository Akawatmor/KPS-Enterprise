# Backend Source Code Documentation (NodeJS/Express)

## Issue #4 — Analyze and Document Backend Source Code

---

## สารบัญ (Table of Contents)

1. [ภาพรวมของระบบ (System Overview)](#1-ภาพรวมของระบบ)
2. [โครงสร้างไฟล์ (File Structure)](#2-โครงสร้างไฟล์)
3. [Entry Point — index.js](#3-entry-point--indexjs)
4. [Database Connection — db.js](#4-database-connection--dbjs)
5. [Mongoose Schema — models/task.js](#5-mongoose-schema--modelstaskjs)
6. [CRUD API Routes — routes/tasks.js](#6-crud-api-routes--routestasksjs)
7. [Health Check Endpoints](#7-health-check-endpoints)
8. [Environment Variables](#8-environment-variables)
9. [Dependencies และ Versions](#9-dependencies-และ-versions)
10. [Dockerfile Build Process](#10-dockerfile-build-process)
11. [API Reference Summary](#11-api-reference-summary)
12. [Sequence Diagrams](#12-sequence-diagrams)
13. [ข้อสังเกตและข้อเสนอแนะ (Notes & Recommendations)](#13-ข้อสังเกตและข้อเสนอแนะ)

---

## 1. ภาพรวมของระบบ

แอปพลิเคชันนี้เป็น **REST API Backend** สำหรับระบบจัดการ Task (To-Do) ที่พัฒนาด้วย **Node.js** และ **Express.js** โดยใช้ **MongoDB** เป็นฐานข้อมูลผ่าน **Mongoose ODM**

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│   Client /   │ HTTP  │   Express.js     │  TCP  │  MongoDB    │
│   Frontend   │──────▶│   Backend        │──────▶│  Database   │
│              │◀──────│   (Port 3500)    │◀──────│             │
└─────────────┘       └──────────────────┘       └─────────────┘
```

**เทคโนโลยีหลัก:**

| เทคโนโลยี  | วัตถุประสงค์                         |
| ---------- | ------------------------------------ |
| Node.js 14 | JavaScript Runtime                   |
| Express.js | Web Framework สำหรับสร้าง REST API   |
| Mongoose   | ODM สำหรับเชื่อมต่อ MongoDB          |
| CORS       | จัดการ Cross-Origin Resource Sharing |

---

## 2. โครงสร้างไฟล์

```
Application-Code/backend/
├── index.js            # Entry point — เริ่มต้น server, กำหนด middleware และ routes
├── db.js               # Database connection — เชื่อมต่อ MongoDB
├── models/
│   └── task.js         # Mongoose schema — กำหนดโครงสร้างข้อมูล Task
├── routes/
│   └── tasks.js        # CRUD API routes — จัดการ endpoints สำหรับ Task
├── Dockerfile          # Docker image build instructions
├── package.json        # Project metadata และ dependencies
└── package-lock.json   # Dependency lock file (auto-generated)
```

### Dependency Graph ระหว่างไฟล์

```
index.js
├── require("./routes/tasks")    → routes/tasks.js
│   └── require("../models/task") → models/task.js
│       └── mongoose
├── require("./db")              → db.js
│   └── mongoose
├── require("cors")
├── require("express")
└── require("mongoose")
```

---

## 3. Entry Point — `index.js`

### หน้าที่หลัก

ไฟล์นี้เป็นจุดเริ่มต้นของแอปพลิเคชัน ทำหน้าที่:

1. **เริ่มต้นการเชื่อมต่อ Database** โดยเรียก `connection()`
2. **กำหนด Middleware** ได้แก่ `express.json()` และ `cors()`
3. **ลงทะเบียน Health Check Endpoints** (`/healthz`, `/ready`, `/started`)
4. **ลงทะเบียน API Routes** (`/api/tasks`)
5. **เริ่มต้น HTTP Server** บน port ที่กำหนด

### Flow การทำงาน

```
Application Start
       │
       ▼
┌─────────────────┐
│ connection()    │──▶ เชื่อมต่อ MongoDB (async, ไม่ await)
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ app.use()       │──▶ ลงทะเบียน middleware (JSON parser, CORS)
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ app.get()       │──▶ ลงทะเบียน Health Check endpoints x3
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ app.use()       │──▶ ลงทะเบียน /api/tasks routes
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ app.listen()    │──▶ เริ่ม server บน port 3500 (default)
└─────────────────┘
```

### รายละเอียด Code

```javascript
// Import dependencies
const tasks = require("./routes/tasks"); // CRUD routes สำหรับ tasks
const connection = require("./db"); // ฟังก์ชันเชื่อมต่อ DB
const cors = require("cors"); // CORS middleware
const express = require("express"); // Express framework
const mongoose = require("mongoose"); // Mongoose (ใช้ตรวจสอบ readyState)

// สร้าง Express application instance
const app = express();

// เรียกเชื่อมต่อ Database (fire-and-forget — ไม่มี await)
connection();

// Middleware
app.use(express.json()); // Parse JSON request bodies
app.use(cors()); // เปิดใช้ CORS สำหรับทุก origins

// Health check endpoints (ดูรายละเอียดในหัวข้อที่ 7)

// Task API routes
app.use("/api/tasks", tasks); // Mount CRUD routes ที่ prefix /api/tasks

// Start server
const port = process.env.PORT || 3500;
app.listen(port, () => console.log(`Listening on port ${port}...`));
```

### Middleware Stack (ลำดับการทำงาน)

```
Request เข้ามา
    │
    ▼
┌──────────────────┐
│ express.json()   │  ──▶ แปลง JSON body เป็น JavaScript object
└──────────────────┘
    │
    ▼
┌──────────────────┐
│ cors()           │  ──▶ เพิ่ม CORS headers ใน response
└──────────────────┘
    │
    ▼
┌──────────────────┐
│ Route Matching   │  ──▶ จับคู่ URL กับ route ที่ลงทะเบียนไว้
└──────────────────┘
```

---

## 4. Database Connection — `db.js`

### หน้าที่หลัก

ไฟล์นี้ export **async function** ที่ทำหน้าที่เชื่อมต่อไปยัง MongoDB โดยใช้ Mongoose

### รายละเอียด Code

```javascript
const mongoose = require("mongoose");

module.exports = async () => {
  try {
    // กำหนด connection parameters พื้นฐาน
    const connectionParams = {
      useNewUrlParser: true, // ใช้ MongoDB URL parser ตัวใหม่
      useUnifiedTopology: true, // ใช้ Server Discovery and Monitoring engine ตัวใหม่
    };

    // ตรวจสอบว่าต้องใช้ Authentication หรือไม่
    const useDBAuth = process.env.USE_DB_AUTH || false;
    if (useDBAuth) {
      connectionParams.user = process.env.MONGO_USERNAME; // ชื่อผู้ใช้ DB
      connectionParams.pass = process.env.MONGO_PASSWORD; // รหัสผ่าน DB
    }

    // เชื่อมต่อ MongoDB
    await mongoose.connect(
      process.env.MONGO_CONN_STR, // Connection string จาก environment variable
      connectionParams,
    );
    console.log("Connected to database.");
  } catch (error) {
    console.log("Could not connect to database.", error);
    // หมายเหตุ: ไม่มี process.exit() — server ยังทำงานต่อแม้ DB เชื่อมต่อไม่ได้
  }
};
```

### Connection Flow

```
db.js เริ่มทำงาน
       │
       ▼
  ┌─────────────────────┐
  │ กำหนด connectionParams │
  │ (useNewUrlParser,       │
  │  useUnifiedTopology)    │
  └─────────────────────┘
       │
       ▼
  ┌─────────────────────┐     Yes    ┌──────────────────────┐
  │ USE_DB_AUTH === true │───────────▶│ เพิ่ม user/pass ใน   │
  │ ?                    │            │ connectionParams     │
  └─────────────────────┘            └──────────────────────┘
       │ No                                    │
       ▼◀──────────────────────────────────────┘
  ┌─────────────────────┐
  │ mongoose.connect()  │
  │ ใช้ MONGO_CONN_STR  │
  └─────────────────────┘
       │
       ├── สำเร็จ ──▶ log "Connected to database."
       │
       └── ล้มเหลว ──▶ log "Could not connect to database." + error
                        (server ยังทำงานต่อ)
```

### รูปแบบ Authentication

| โหมด       | เงื่อนไข                 | Parameters ที่ใช้                       |
| ---------- | ------------------------ | --------------------------------------- |
| ไม่มี Auth | `USE_DB_AUTH` ไม่ได้ตั้ง | `useNewUrlParser`, `useUnifiedTopology` |
| มี Auth    | `USE_DB_AUTH` = truthy   | เพิ่ม `user`, `pass` จาก env vars       |

---

## 5. Mongoose Schema — `models/task.js`

### หน้าที่หลัก

กำหนดโครงสร้างข้อมูล (Schema) ของ Task document ใน MongoDB

### Schema Definition

```javascript
const taskSchema = new Schema({
  task: {
    type: String, // ข้อความอธิบาย task
    required: true, // บังคับต้องมีค่า
  },
  completed: {
    type: Boolean, // สถานะเสร็จสิ้น
    default: false, // ค่าเริ่มต้น = false (ยังไม่เสร็จ)
  },
});
```

### โครงสร้าง Document ใน MongoDB

| Field       | Type     | Required | Default | Description                              |
| ----------- | -------- | -------- | ------- | ---------------------------------------- |
| `_id`       | ObjectId | Auto     | Auto    | Primary key (สร้างอัตโนมัติโดย MongoDB)  |
| `task`      | String   | ✅ Yes   | —       | ชื่อหรือรายละเอียดของ task               |
| `completed` | Boolean  | ❌ No    | `false` | สถานะการเสร็จสิ้นของ task                |
| `__v`       | Number   | Auto     | `0`     | Version key (สร้างอัตโนมัติโดย Mongoose) |

### ตัวอย่าง Document

```json
{
  "_id": "64a1b2c3d4e5f6a7b8c9d0e1",
  "task": "Complete project documentation",
  "completed": false,
  "__v": 0
}
```

### Model Export

```javascript
module.exports = mongoose.model("task", taskSchema);
```

- **Model Name:** `"task"`
- **Collection Name ใน MongoDB:** `"tasks"` (Mongoose จะ pluralize อัตโนมัติ)

---

## 6. CRUD API Routes — `routes/tasks.js`

### หน้าที่หลัก

จัดการ HTTP endpoints ทั้งหมดสำหรับ Task resource ตาม RESTful pattern

### สรุป Endpoints

| Method   | Endpoint         | Description        | Request Body                | Response               |
| -------- | ---------------- | ------------------ | --------------------------- | ---------------------- |
| `POST`   | `/api/tasks`     | สร้าง task ใหม่    | `{ "task": "string" }`      | Task object ที่สร้าง   |
| `GET`    | `/api/tasks`     | ดึง tasks ทั้งหมด  | —                           | Array ของ Task objects |
| `PUT`    | `/api/tasks/:id` | อัปเดต task ตาม ID | `{ "task": "string", ... }` | Task object ก่อนอัปเดต |
| `DELETE` | `/api/tasks/:id` | ลบ task ตาม ID     | —                           | Task object ที่ถูกลบ   |

---

### 6.1 POST `/api/tasks` — Create Task

**Description:** สร้าง Task document ใหม่ในฐานข้อมูล

```javascript
router.post("/", async (req, res) => {
  try {
    const task = await new Task(req.body).save();
    res.send(task);
  } catch (error) {
    res.send(error);
  }
});
```

**Request:**

```http
POST /api/tasks
Content-Type: application/json

{
    "task": "Buy groceries",
    "completed": false
}
```

**Response (Success):**

```json
{
  "_id": "64a1b2c3d4e5f6a7b8c9d0e1",
  "task": "Buy groceries",
  "completed": false,
  "__v": 0
}
```

**Response (Error — missing required field):**

```json
{
  "errors": {
    "task": {
      "message": "Path `task` is required.",
      "name": "ValidatorError",
      "kind": "required"
    }
  }
}
```

---

### 6.2 GET `/api/tasks` — Get All Tasks

**Description:** ดึง Task documents ทั้งหมดจากฐานข้อมูล

```javascript
router.get("/", async (req, res) => {
  try {
    const tasks = await Task.find();
    res.send(tasks);
  } catch (error) {
    res.send(error);
  }
});
```

**Request:**

```http
GET /api/tasks
```

**Response (Success):**

```json
[
  {
    "_id": "64a1b2c3d4e5f6a7b8c9d0e1",
    "task": "Buy groceries",
    "completed": false,
    "__v": 0
  },
  {
    "_id": "64a1b2c3d4e5f6a7b8c9d0e2",
    "task": "Clean the house",
    "completed": true,
    "__v": 0
  }
]
```

**Response (Empty):**

```json
[]
```

---

### 6.3 PUT `/api/tasks/:id` — Update Task

**Description:** อัปเดต Task document ตาม ID ที่ระบุ

```javascript
router.put("/:id", async (req, res) => {
  try {
    const task = await Task.findOneAndUpdate({ _id: req.params.id }, req.body);
    res.send(task);
  } catch (error) {
    res.send(error);
  }
});
```

**Request:**

```http
PUT /api/tasks/64a1b2c3d4e5f6a7b8c9d0e1
Content-Type: application/json

{
    "completed": true
}
```

**Response (Success):**

```json
{
  "_id": "64a1b2c3d4e5f6a7b8c9d0e1",
  "task": "Buy groceries",
  "completed": false,
  "__v": 0
}
```

> ⚠️ **หมายเหตุ:** `findOneAndUpdate` โดย default จะ return document **ก่อน** อัปเดต ไม่ใช่หลังอัปเดต หากต้องการ document หลังอัปเดต ต้องเพิ่ม option `{ new: true }`

**Response (Not Found):**

```json
null
```

---

### 6.4 DELETE `/api/tasks/:id` — Delete Task

**Description:** ลบ Task document ตาม ID ที่ระบุ

```javascript
router.delete("/:id", async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);
    res.send(task);
  } catch (error) {
    res.send(error);
  }
});
```

**Request:**

```http
DELETE /api/tasks/64a1b2c3d4e5f6a7b8c9d0e1
```

**Response (Success):**

```json
{
  "_id": "64a1b2c3d4e5f6a7b8c9d0e1",
  "task": "Buy groceries",
  "completed": false,
  "__v": 0
}
```

**Response (Not Found):**

```json
null
```

---

## 7. Health Check Endpoints

Health check endpoints ถูกออกแบบมาสำหรับใช้กับ **Kubernetes Probes** (หรือ load balancer health checks)

### สรุป Health Check Endpoints

| Endpoint   | Method | Purpose                      | Kubernetes Probe | Response (OK)   | Response (Fail)             |
| ---------- | ------ | ---------------------------- | ---------------- | --------------- | --------------------------- |
| `/healthz` | GET    | Server ทำงานอยู่หรือไม่      | Liveness Probe   | `200 "Healthy"` | — (ถ้าไม่ตอบ = ตาย)         |
| `/ready`   | GET    | พร้อมรับ traffic หรือไม่     | Readiness Probe  | `200 "Ready"`   | `503 "Not Ready"`           |
| `/started` | GET    | Server เริ่มต้นสำเร็จหรือไม่ | Startup Probe    | `200 "Started"` | — (ถ้าไม่ตอบ = ยังไม่เริ่ม) |

### 7.1 `/healthz` — Liveness Probe

```javascript
app.get("/healthz", (req, res) => {
  res.status(200).send("Healthy");
});
```

- **วัตถุประสงค์:** ตรวจสอบว่า process ของ server ยังทำงานอยู่
- **Logic:** ตอบ `200` เสมอถ้า server ยังรันอยู่
- **Kubernetes ใช้:** ถ้าไม่ตอบ Kubernetes จะ restart pod

### 7.2 `/ready` — Readiness Probe

```javascript
let lastReadyState = null;
app.get("/ready", (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;
  if (isDbConnected !== lastReadyState) {
    console.log(`Database readyState: ${mongoose.connection.readyState}`);
    lastReadyState = isDbConnected;
  }
  if (isDbConnected) {
    res.status(200).send("Ready");
  } else {
    res.status(503).send("Not Ready");
  }
});
```

- **วัตถุประสงค์:** ตรวจสอบว่า server พร้อมรับ requests (DB เชื่อมต่อได้)
- **Logic:** ตรวจสอบ `mongoose.connection.readyState`
- **State Logging:** Log เฉพาะเมื่อ state เปลี่ยนแปลง (ป้องกัน log ท่วม)
- **Kubernetes ใช้:** ถ้าตอบ `503` Kubernetes จะไม่ส่ง traffic มาที่ pod นี้

**Mongoose readyState values:**

| Value | State         | Description          |
| ----- | ------------- | -------------------- |
| 0     | disconnected  | ยังไม่ได้เชื่อมต่อ   |
| 1     | connected     | เชื่อมต่อสำเร็จ ✅   |
| 2     | connecting    | กำลังเชื่อมต่อ       |
| 3     | disconnecting | กำลังตัดการเชื่อมต่อ |

### 7.3 `/started` — Startup Probe

```javascript
app.get("/started", (req, res) => {
  res.status(200).send("Started");
});
```

- **วัตถุประสงค์:** ตรวจสอบว่า server เริ่มต้นสำเร็จแล้ว
- **Logic:** ตอบ `200` เสมอถ้า endpoint สามารถเข้าถึงได้
- **Kubernetes ใช้:** ป้องกันไม่ให้ liveness probe ทำงานก่อนที่ app จะเริ่มเสร็จ

---

## 8. Environment Variables

### ตารางสรุป Environment Variables

| Variable         | Required    | Default | Description                                      | ตัวอย่าง                           |
| ---------------- | ----------- | ------- | ------------------------------------------------ | ---------------------------------- |
| `MONGO_CONN_STR` | ✅ Yes      | —       | MongoDB connection string                        | `mongodb://mongo-svc:27017/taskdb` |
| `PORT`           | ❌ No       | `3500`  | Port ที่ server จะ listen                        | `3500`                             |
| `USE_DB_AUTH`    | ❌ No       | `false` | เปิดใช้ MongoDB authentication                   | `true`                             |
| `MONGO_USERNAME` | Conditional | —       | ชื่อผู้ใช้ MongoDB (ใช้เมื่อ `USE_DB_AUTH`=true) | `admin`                            |
| `MONGO_PASSWORD` | Conditional | —       | รหัสผ่าน MongoDB (ใช้เมื่อ `USE_DB_AUTH`=true)   | `password123`                      |

### Dependency ระหว่าง Variables

```
USE_DB_AUTH = true
    ├── MONGO_USERNAME  (จำเป็น)
    └── MONGO_PASSWORD  (จำเป็น)

USE_DB_AUTH = false (หรือไม่ได้ตั้ง)
    ├── MONGO_USERNAME  (ไม่ใช้)
    └── MONGO_PASSWORD  (ไม่ใช้)
```

### ตัวอย่างการตั้งค่า

**แบบไม่มี Authentication:**

```bash
export MONGO_CONN_STR="mongodb://localhost:27017/taskdb"
export PORT=3500
```

**แบบมี Authentication:**

```bash
export MONGO_CONN_STR="mongodb://mongo-svc:27017/taskdb"
export PORT=3500
export USE_DB_AUTH=true
export MONGO_USERNAME="admin"
export MONGO_PASSWORD="secretpassword"
```

---

## 9. Dependencies และ Versions

### Production Dependencies

| Package    | Version   | Description                                             | License |
| ---------- | --------- | ------------------------------------------------------- | ------- |
| `cors`     | `^2.8.5`  | Express middleware สำหรับ Cross-Origin Resource Sharing | MIT     |
| `express`  | `^4.17.1` | Web framework สำหรับ Node.js                            | MIT     |
| `mongoose` | `^6.13.6` | MongoDB ODM (Object Document Mapper)                    | MIT     |

### Version Range Explanation (Semver `^`)

| Dependency | Specified | ช่วงที่อนุญาต           | หมายเหตุ                     |
| ---------- | --------- | ----------------------- | ---------------------------- |
| cors       | `^2.8.5`  | `>=2.8.5` and `<3.0.0`  | ยอมรับ minor + patch updates |
| express    | `^4.17.1` | `>=4.17.1` and `<5.0.0` | ยอมรับ minor + patch updates |
| mongoose   | `^6.13.6` | `>=6.13.6` and `<7.0.0` | ยอมรับ minor + patch updates |

### Dev Dependencies

ไม่มี dev dependencies ที่กำหนดไว้ใน `package.json`

### Project Metadata

| Field       | Value                        |
| ----------- | ---------------------------- |
| name        | `server`                     |
| version     | `1.0.0`                      |
| main        | `index.js`                   |
| license     | ISC                          |
| test script | ไม่มี (placeholder เท่านั้น) |

---

## 10. Dockerfile Build Process

### Dockerfile

```dockerfile
FROM node:14
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "index.js"]
```

### Build Process ทีละขั้นตอน

```
Step 1: FROM node:14
┌──────────────────────────────────────────────────┐
│ ใช้ Node.js version 14 เป็น base image           │
│ (Debian-based, full image — ไม่ใช่ alpine/slim)   │
│ ⚠️  Node.js 14 End-of-Life: 30 April 2023        │
└──────────────────────────────────────────────────┘
                    │
                    ▼
Step 2: WORKDIR /usr/src/app
┌──────────────────────────────────────────────────┐
│ กำหนด working directory ภายใน container           │
│ คำสั่งถัดไปจะทำงานใน /usr/src/app                 │
└──────────────────────────────────────────────────┘
                    │
                    ▼
Step 3: COPY package*.json ./
┌──────────────────────────────────────────────────┐
│ คัดลอก package.json และ package-lock.json         │
│ (ถ้ามี) เข้าไปใน container ก่อน                    │
│ ✅ ใช้ Docker layer caching — ถ้า package.json    │
│    ไม่เปลี่ยน จะไม่ต้อง npm install ใหม่           │
└──────────────────────────────────────────────────┘
                    │
                    ▼
Step 4: RUN npm install
┌──────────────────────────────────────────────────┐
│ ติดตั้ง dependencies ทั้งหมดจาก package.json       │
│ (รวม devDependencies ด้วย เพราะไม่ได้ใช้          │
│  --only=production)                               │
└──────────────────────────────────────────────────┘
                    │
                    ▼
Step 5: COPY . .
┌──────────────────────────────────────────────────┐
│ คัดลอก source code ที่เหลือทั้งหมดเข้า container   │
│ ⚠️  ไม่มี .dockerignore — อาจคัดลอก                │
│    node_modules/ ที่ไม่จำเป็นเข้าไปด้วย            │
└──────────────────────────────────────────────────┘
                    │
                    ▼
Step 6: CMD ["node", "index.js"]
┌──────────────────────────────────────────────────┐
│ กำหนดคำสั่งเริ่มต้นเมื่อ container ทำงาน           │
│ รัน Node.js application จาก index.js              │
└──────────────────────────────────────────────────┘
```

### Docker Build & Run Commands

```bash
# Build image
docker build -t backend-app:latest .

# Run container
docker run -d \
  -p 3500:3500 \
  -e MONGO_CONN_STR="mongodb://mongo:27017/taskdb" \
  -e PORT=3500 \
  --name backend \
  backend-app:latest
```

### Docker Image Characteristics

| Property          | Value                            |
| ----------------- | -------------------------------- |
| Base Image        | `node:14` (Debian-based)         |
| Working Directory | `/usr/src/app`                   |
| Exposed Port      | ไม่ได้ EXPOSE (ใช้ `-p` ตอน run) |
| Run as User       | root (default)                   |
| Startup Command   | `node index.js`                  |

---

## 11. API Reference Summary

### Complete Endpoint Map

```
Server (Port 3500)
│
├── GET    /healthz              → 200 "Healthy"
├── GET    /ready                → 200 "Ready" | 503 "Not Ready"
├── GET    /started              → 200 "Started"
│
└── /api/tasks
    ├── POST   /                 → สร้าง Task ใหม่
    ├── GET    /                 → ดึง Tasks ทั้งหมด
    ├── PUT    /:id              → อัปเดต Task ตาม ID
    └── DELETE /:id              → ลบ Task ตาม ID
```

### Request/Response Quick Reference

| Endpoint         | Method | Content-Type       | Request Body                         | Success Status | Response Body             |
| ---------------- | ------ | ------------------ | ------------------------------------ | -------------- | ------------------------- |
| `/healthz`       | GET    | —                  | —                                    | 200            | `"Healthy"`               |
| `/ready`         | GET    | —                  | —                                    | 200 / 503      | `"Ready"` / `"Not Ready"` |
| `/started`       | GET    | —                  | —                                    | 200            | `"Started"`               |
| `/api/tasks`     | POST   | `application/json` | `{"task":"string","completed":bool}` | 200            | Created Task object       |
| `/api/tasks`     | GET    | —                  | —                                    | 200            | Array of Task objects     |
| `/api/tasks/:id` | PUT    | `application/json` | `{"task":"string","completed":bool}` | 200            | Task object (ก่อนอัปเดต)  |
| `/api/tasks/:id` | DELETE | —                  | —                                    | 200            | Deleted Task object       |

---

## 12. Sequence Diagrams

### 12.1 Application Startup Sequence

```
┌────────┐      ┌────────┐      ┌──────────┐      ┌─────────┐
│  Node  │      │index.js│      │  db.js   │      │ MongoDB │
└───┬────┘      └───┬────┘      └────┬─────┘      └────┬────┘
    │               │                │                  │
    │  run index.js │                │                  │
    │──────────────▶│                │                  │
    │               │                │                  │
    │               │ connection()   │                  │
    │               │───────────────▶│                  │
    │               │                │                  │
    │               │                │ mongoose.connect()│
    │               │                │─────────────────▶│
    │               │                │                  │
    │               │                │   Connected      │
    │               │                │◀─────────────────│
    │               │                │                  │
    │               │ Register middleware               │
    │               │ (json, cors)   │                  │
    │               │────────┐       │                  │
    │               │◀───────┘       │                  │
    │               │                │                  │
    │               │ Register routes│                  │
    │               │────────┐       │                  │
    │               │◀───────┘       │                  │
    │               │                │                  │
    │               │ app.listen(3500)                  │
    │               │────────┐       │                  │
    │               │◀───────┘       │                  │
    │               │                │                  │
    │  "Listening   │                │                  │
    │   on port     │                │                  │
    │   3500..."    │                │                  │
    │◀──────────────│                │                  │
```

### 12.2 Create Task (POST) Sequence

```
┌────────┐      ┌──────────┐      ┌──────────┐      ┌─────────┐
│ Client │      │routes/   │      │models/   │      │ MongoDB │
│        │      │tasks.js  │      │task.js   │      │         │
└───┬────┘      └────┬─────┘      └────┬─────┘      └────┬────┘
    │                │                  │                  │
    │ POST /api/tasks│                  │                  │
    │ {"task":"..."}│                  │                  │
    │───────────────▶│                  │                  │
    │                │                  │                  │
    │                │ new Task(body)   │                  │
    │                │─────────────────▶│                  │
    │                │                  │                  │
    │                │ task.save()      │                  │
    │                │─────────────────▶│                  │
    │                │                  │                  │
    │                │                  │ insertOne()      │
    │                │                  │─────────────────▶│
    │                │                  │                  │
    │                │                  │ Document saved   │
    │                │                  │◀─────────────────│
    │                │                  │                  │
    │                │ Saved task object│                  │
    │                │◀─────────────────│                  │
    │                │                  │                  │
    │  200 OK        │                  │                  │
    │  {task object} │                  │                  │
    │◀───────────────│                  │                  │
```

---

## 13. ข้อสังเกตและข้อเสนอแนะ

### 🔴 ปัญหาที่ควรแก้ไข (Critical)

| #   | ปัญหา                                     | ไฟล์              | รายละเอียด                                                                                                                         |
| --- | ----------------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Node.js 14 EOL**                        | `Dockerfile`      | Node.js 14 หมดอายุการสนับสนุนตั้งแต่ 30 April 2023 ควรอัปเกรดเป็น Node.js 18 LTS หรือ 20 LTS                                       |
| 2   | **Error handling ไม่มี HTTP status code** | `routes/tasks.js` | ทุก catch block ใช้ `res.send(error)` โดยไม่มี status code ที่เหมาะสม (เช่น 400, 500) ทำให้ client ได้รับ status 200 แม้เกิด error |
| 3   | **DB connection ไม่มี retry/exit**        | `db.js`           | เมื่อเชื่อมต่อ DB ไม่ได้ server ยังทำงานต่อโดยไม่มี DB — ควรมี retry mechanism หรือ `process.exit(1)`                              |

### 🟡 ข้อควรปรับปรุง (Improvement)

| #   | ข้อเสนอแนะ                       | ไฟล์              | รายละเอียด                                                              |
| --- | -------------------------------- | ----------------- | ----------------------------------------------------------------------- |
| 4   | **ไม่มี `.dockerignore`**        | `Dockerfile`      | อาจคัดลอก `node_modules/`, `.git/` เข้า image โดยไม่จำเป็น              |
| 5   | **ไม่มี `EXPOSE` ใน Dockerfile** | `Dockerfile`      | ควรเพิ่ม `EXPOSE 3500` เพื่อเป็น documentation                          |
| 6   | **ไม่มี `{ new: true }` ใน PUT** | `routes/tasks.js` | `findOneAndUpdate` return document ก่อนอัปเดต ซึ่งอาจทำให้ client สับสน |
| 7   | **ไม่มี input validation**       | `routes/tasks.js` | `req.body` ถูกส่งตรงไป save/update โดยไม่มีการ validate                 |
| 8   | **ไม่มี `--only=production`**    | `Dockerfile`      | `npm install` จะติดตั้ง devDependencies ด้วย (แม้ปัจจุบันจะไม่มี)       |
| 9   | **Running as root**              | `Dockerfile`      | Container ทำงานด้วย root user ควรเพิ่ม `USER node`                      |
| 10  | **Deprecated Mongoose options**  | `db.js`           | `useNewUrlParser` และ `useUnifiedTopology` ไม่จำเป็นใน Mongoose 6+      |

### ตัวอย่างการปรับปรุง Dockerfile

```dockerfile
# แนะนำ
FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3500
USER node
CMD ["node", "index.js"]
```

### ตัวอย่างการปรับปรุง Error Handling

```javascript
// แนะนำ
router.post("/", async (req, res) => {
  try {
    const task = await new Task(req.body).save();
    res.status(201).send(task);
  } catch (error) {
    res.status(400).send({ message: error.message });
  }
});
```

---
