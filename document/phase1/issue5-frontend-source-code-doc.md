# Frontend Source Code Documentation (ReactJS)

## Issue #5 — Analyze and Document Frontend Source Code

---

## สารบัญ (Table of Contents)

1. [ภาพรวมของระบบ (System Overview)](#1-ภาพรวมของระบบ)
2. [โครงสร้างไฟล์ (File Structure)](#2-โครงสร้างไฟล์)
3. [React Component Structure](#3-react-component-structure)
4. [Component: Tasks.js — Business Logic Layer](#4-component-tasksjs--business-logic-layer)
5. [Component: App.js — UI/Presentation Layer](#5-component-appjs--uipresentation-layer)
6. [API Service Layer — taskServices.js](#6-api-service-layer--taskservicesjs)
7. [Environment Variables](#7-environment-variables)
8. [Dependencies และ Versions](#8-dependencies-และ-versions)
9. [Dockerfile Build Process](#9-dockerfile-build-process)
10. [Data Flow & State Management](#10-data-flow--state-management)
11. [Sequence Diagrams](#11-sequence-diagrams)
12. [ข้อสังเกตและข้อเสนอแนะ (Notes & Recommendations)](#12-ข้อสังเกตและข้อเสนอแนะ)

---

## 1. ภาพรวมของระบบ

แอปพลิเคชันนี้เป็น **Single Page Application (SPA)** สำหรับจัดการ To-Do List พัฒนาด้วย **React 17** (Class Components) ใช้ **Material-UI** สำหรับ UI components และ **Axios** สำหรับเชื่อมต่อ Backend API

```
┌────────────────────────────────────────────────────────────┐
│                      Browser (Client)                      │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                     App.js                           │  │
│  │              (UI / Presentation Layer)                │  │
│  │                  extends Tasks                        │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │               Tasks.js                         │  │  │
│  │  │          (Business Logic Layer)                 │  │  │
│  │  │  ┌──────────────────────────────────────────┐  │  │  │
│  │  │  │          taskServices.js                  │  │  │  │
│  │  │  │        (API Service Layer)                │  │  │  │
│  │  │  │            Axios HTTP                     │  │  │  │
│  │  │  └──────────────┬───────────────────────────┘  │  │  │
│  │  └────────────────│───────────────────────────────┘  │  │
│  └──────────────────│───────────────────────────────────┘  │
│                      │                                      │
└──────────────────────│──────────────────────────────────────┘
                       │ HTTP (Axios)
                       ▼
              ┌──────────────────┐
              │  Backend API     │
              │  (Port 3500)     │
              │  /api/tasks      │
              └──────────────────┘
```

**เทคโนโลยีหลัก:**

| เทคโนโลยี       | วัตถุประสงค์                                   |
| --------------- | ---------------------------------------------- |
| React 17        | UI Library สำหรับสร้าง SPA                     |
| Material-UI 4   | UI Component Library (TextField, Button, etc.) |
| Axios           | HTTP Client สำหรับเรียก Backend API            |
| react-scripts 4 | Build toolchain (Webpack, Babel, ESLint)       |

---

## 2. โครงสร้างไฟล์

```
Application-Code/frontend/
├── src/
│   ├── App.js                    # Root component — UI/Presentation layer
│   ├── App.css                   # Stylesheet สำหรับ App component
│   ├── Tasks.js                  # Parent class — Business logic layer
│   └── services/
│       └── taskServices.js       # API service layer — Axios HTTP calls
├── public/                       # Static files (index.html, favicon, etc.)
├── Dockerfile                    # Docker image build instructions
├── package.json                  # Project metadata และ dependencies
└── package-lock.json             # Dependency lock file (auto-generated)
```

### Dependency Graph ระหว่างไฟล์

```
App.js
├── extends Tasks.js (inheritance)
│   └── import services/taskServices.js
│       └── axios
├── import @material-ui/core
│   ├── Paper
│   ├── TextField
│   ├── Checkbox
│   └── Button
├── import App.css
└── import React
```

---

## 3. React Component Structure

### Component Hierarchy & Inheritance

```
React.Component
    │
    ▼
Tasks (Class Component)              ← Business Logic Layer
    │   • state management
    │   • event handlers (CRUD)
    │   • lifecycle methods
    │   • ไม่มี render() ของตัวเอง
    │
    ▼
App (Class Component)                ← UI/Presentation Layer
    │   extends Tasks
    │   • render() method
    │   • Material-UI components
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  Rendered UI Tree                                       │
│                                                         │
│  <div className="app">                                  │
│    <header className="app-header">                      │
│      <h1>My To-Do List</h1>                             │
│    </header>                                            │
│    <div className="main-content">                       │
│      <Paper className="todo-container">                 │
│        <form className="task-form">                     │
│          <TextField />          ← input field           │
│          <Button />             ← submit button         │
│        </form>                                          │
│        <div className="tasks-list">                     │
│          {tasks.map(task =>                             │
│            <Paper className="task-item">                │
│              <Checkbox />       ← toggle completed      │
│              <div />            ← task text             │
│              <Button />         ← delete button         │
│            </Paper>                                     │
│          )}                                             │
│        </div>                                           │
│      </Paper>                                           │
│    </div>                                               │
│  </div>                                                 │
└─────────────────────────────────────────────────────────┘
```

### Design Pattern: Inheritance-based Separation

```
┌─────────────────────────────────┐
│         Tasks.js                │
│    (Business Logic Layer)       │
│                                 │
│  • state = {tasks, currentTask} │
│  • componentDidMount()          │
│  • handleChange()               │
│  • handleSubmit()               │
│  • handleUpdate()               │
│  • handleDelete()               │
│  • render() = ไม่ได้กำหนด       │
└──────────────┬──────────────────┘
               │ extends
               ▼
┌─────────────────────────────────┐
│           App.js                │
│     (Presentation Layer)        │
│                                 │
│  • state = {tasks, currentTask} │ ← ประกาศซ้ำ (override)
│  • render()                     │ ← กำหนด UI ที่นี่
│  • สืบทอด handlers ทั้งหมด       │
└─────────────────────────────────┘
```

> ⚠️ **หมายเหตุ:** รูปแบบนี้ใช้ **Class Inheritance** แทน **Composition** ซึ่งไม่ใช่ pattern ที่ React แนะนำ (React เชียร์ "Composition over Inheritance")

---

## 4. Component: `Tasks.js` — Business Logic Layer

### หน้าที่หลัก

เป็น **Parent Class Component** ที่รวบรวม business logic ทั้งหมดเกี่ยวกับการจัดการ tasks ได้แก่:

- State management
- Lifecycle method (data fetching)
- Event handlers สำหรับ CRUD operations

### State Structure

```javascript
state = {
  tasks: [], // Array ของ task objects จาก backend
  currentTask: "", // ค่าปัจจุบันของ input field (controlled component)
};
```

**State Shape:**

```javascript
{
    tasks: [
        {
            _id: "64a1b2c3d4e5f6a7b8c9d0e1",   // MongoDB ObjectId
            task: "Buy groceries",                // task description
            completed: false,                     // completion status
            __v: 0                                // Mongoose version key
        },
        // ...more tasks
    ],
    currentTask: "New task being typed..."
}
```

---

### 4.1 `componentDidMount()` — Initial Data Fetch

```javascript
async componentDidMount() {
    try {
        const { data } = await getTasks();
        this.setState({ tasks: data });
    } catch (error) {
        console.log(error);
    }
}
```

**การทำงาน:**

```
Component Mount
       │
       ▼
┌─────────────────┐
│ getTasks()      │──▶ GET /api/tasks
└─────────────────┘
       │
       ├── สำเร็จ ──▶ setState({ tasks: data })
       │               → re-render แสดงรายการ tasks
       │
       └── ล้มเหลว ──▶ console.log(error)
                        → tasks ยังเป็น [] (empty)
```

| สิ่งที่เกิดขึ้น  | ผลลัพธ์                             |
| ---------------- | ----------------------------------- |
| API สำเร็จ       | tasks state ถูกอัปเดต, UI re-render |
| API ล้มเหลว      | Error ถูก log, UI แสดงรายการว่าง    |
| ไม่มี task ใน DB | tasks = `[]`, UI แสดงรายการว่าง     |

---

### 4.2 `handleChange()` — Input Change Handler

```javascript
handleChange = ({ currentTarget: input }) => {
  this.setState({ currentTask: input.value });
};
```

**การทำงาน:**

```
User พิมพ์ใน TextField
         │
         ▼
   onChange event
         │
         ▼
┌───────────────────────┐
│ Destructure event:    │
│ { currentTarget } →   │
│ input = currentTarget │
└───────────────────────┘
         │
         ▼
┌───────────────────────┐
│ setState({            │
│   currentTask:        │
│     input.value       │
│ })                    │
└───────────────────────┘
         │
         ▼
   TextField re-render
   แสดงค่าที่พิมพ์
```

- **Pattern:** Controlled Component — ค่าของ `TextField` ถูกควบคุมโดย `state.currentTask`
- **Binding:** Arrow function (auto-bind `this`)

---

### 4.3 `handleSubmit()` — Create Task

```javascript
handleSubmit = async (e) => {
  e.preventDefault();
  const originalTasks = this.state.tasks;
  try {
    const { data } = await addTask({ task: this.state.currentTask });
    const tasks = originalTasks;
    tasks.push(data);
    this.setState({ tasks, currentTask: "" });
  } catch (error) {
    console.log(error);
  }
};
```

**การทำงาน:**

```
User กด "Add Task" / Submit form
         │
         ▼
┌──────────────────────┐
│ e.preventDefault()   │──▶ ป้องกัน form reload หน้า
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│ เก็บ originalTasks   │──▶ ไว้สำหรับ rollback (แต่ไม่ได้ใช้ rollback จริง)
└──────────────────────┘
         │
         ▼
┌──────────────────────┐
│ addTask({            │──▶ POST /api/tasks
│   task: currentTask  │    { "task": "..." }
│ })                   │
└──────────────────────┘
         │
         ├── สำเร็จ ──▶ push task ใหม่เข้า array
         │               setState({ tasks, currentTask: "" })
         │               → input field ถูก clear
         │
         └── ล้มเหลว ──▶ console.log(error)
                          → ไม่มี rollback
```

**Update Strategy:** API-first แล้วจึง update UI

> ⚠️ **หมายเหตุ:** `tasks.push(data)` เป็นการ **mutate** array โดยตรง (`originalTasks` กับ `tasks` อ้างอิง reference เดียวกัน) ซึ่งขัดกับหลัก immutability ของ React

---

### 4.4 `handleUpdate()` — Toggle Task Completion

```javascript
handleUpdate = async (currentTask) => {
  const originalTasks = this.state.tasks;
  try {
    const tasks = [...originalTasks];
    const index = tasks.findIndex((task) => task._id === currentTask);
    tasks[index] = { ...tasks[index] };
    tasks[index].completed = !tasks[index].completed;
    this.setState({ tasks });
    await updateTask(currentTask, {
      completed: tasks[index].completed,
    });
  } catch (error) {
    this.setState({ tasks: originalTasks });
    console.log(error);
  }
};
```

**การทำงาน:**

```
User คลิก Checkbox
         │
         ▼
┌───────────────────────────┐
│ เก็บ originalTasks        │──▶ ไว้สำหรับ rollback
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ สร้าง shallow copy:      │
│ [...originalTasks]        │
│ { ...tasks[index] }       │
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ Toggle completed:         │
│ tasks[index].completed =  │
│   !tasks[index].completed │
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ setState({ tasks })       │──▶ UI อัปเดตทันที (Optimistic Update)
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ updateTask(id, {          │──▶ PUT /api/tasks/:id
│   completed: newValue     │
│ })                        │
└───────────────────────────┘
         │
         ├── สำเร็จ ──▶ เสร็จสิ้น (UI อัปเดตแล้ว)
         │
         └── ล้มเหลว ──▶ setState({ tasks: originalTasks })
                          → Rollback UI กลับสู่สถานะเดิม
```

**Update Strategy:** **Optimistic Update** — อัปเดต UI ก่อน แล้วค่อยส่ง API ถ้า API ล้มเหลวจะ rollback

---

### 4.5 `handleDelete()` — Delete Task

```javascript
handleDelete = async (currentTask) => {
  const originalTasks = this.state.tasks;
  try {
    const tasks = originalTasks.filter((task) => task._id !== currentTask);
    this.setState({ tasks });
    await deleteTask(currentTask);
  } catch (error) {
    this.setState({ tasks: originalTasks });
    console.log(error);
  }
};
```

**การทำงาน:**

```
User คลิก "Delete"
         │
         ▼
┌───────────────────────────┐
│ เก็บ originalTasks        │──▶ ไว้สำหรับ rollback
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ filter out task:          │
│ tasks.filter(             │
│   task._id !== currentTask│
│ )                         │
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ setState({ tasks })       │──▶ UI ลบ task ทันที (Optimistic Update)
└───────────────────────────┘
         │
         ▼
┌───────────────────────────┐
│ deleteTask(id)            │──▶ DELETE /api/tasks/:id
└───────────────────────────┘
         │
         ├── สำเร็จ ──▶ เสร็จสิ้น
         │
         └── ล้มเหลว ──▶ setState({ tasks: originalTasks })
                          → Rollback UI กลับ (task กลับมาแสดง)
```

**Update Strategy:** **Optimistic Update** — เหมือน handleUpdate

---

### สรุป Event Handlers

| Method         | Trigger             | API Call | Update Strategy | Rollback |
| -------------- | ------------------- | -------- | --------------- | -------- |
| `handleChange` | TextField onChange  | ไม่มี    | Synchronous     | ไม่มี    |
| `handleSubmit` | Form submit         | POST     | API-first       | ❌ ไม่มี |
| `handleUpdate` | Checkbox click      | PUT      | Optimistic      | ✅ มี    |
| `handleDelete` | Delete button click | DELETE   | Optimistic      | ✅ มี    |

---

## 5. Component: `App.js` — UI/Presentation Layer

### หน้าที่หลัก

เป็น **Root Component** ที่รับผิดชอบการ render UI ทั้งหมด โดยสืบทอด business logic จาก `Tasks.js` ผ่าน class inheritance

### Inheritance Chain

```javascript
class App extends Tasks {
    //        ↑
    //   Tasks extends Component
    //                    ↑
    //              React.Component
```

### State Declaration (Override)

```javascript
state = { tasks: [], currentTask: "" };
```

> ⚠️ **หมายเหตุ:** State ถูกประกาศซ้ำทั้งใน `Tasks.js` และ `App.js` โดย state ใน `App.js` จะ override state ใน `Tasks.js` เนื่องจาก class field ของ subclass จะทับ parent

### UI Structure Breakdown

```
┌─────────────────────────────────────────────────────┐
│  <div className="app">                              │
│  ┌───────────────────────────────────────────────┐  │
│  │  <header className="app-header">              │  │
│  │    <h1>My To-Do List</h1>                     │  │
│  │  </header>                                    │  │
│  └───────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────┐  │
│  │  <div className="main-content">               │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │  <Paper elevation={3}>                  │  │  │
│  │  │  ┌───────────────────────────────────┐  │  │  │
│  │  │  │  <form className="task-form">     │  │  │  │
│  │  │  │  ┌─────────────┐ ┌─────────────┐ │  │  │  │
│  │  │  │  │  TextField  │ │   Button    │ │  │  │  │
│  │  │  │  │  (input)    │ │  "Add Task" │ │  │  │  │
│  │  │  │  └─────────────┘ └─────────────┘ │  │  │  │
│  │  │  │  </form>                          │  │  │  │
│  │  │  └───────────────────────────────────┘  │  │  │
│  │  │  ┌───────────────────────────────────┐  │  │  │
│  │  │  │  <div className="tasks-list">     │  │  │  │
│  │  │  │  ┌─────────────────────────────┐  │  │  │  │
│  │  │  │  │ <Paper className="task-item">│  │  │  │  │
│  │  │  │  │ ☑ Checkbox │ Task Text │ 🗑 │  │  │  │  │
│  │  │  │  └─────────────────────────────┘  │  │  │  │
│  │  │  │  ┌─────────────────────────────┐  │  │  │  │
│  │  │  │  │ <Paper className="task-item">│  │  │  │  │
│  │  │  │  │ ☐ Checkbox │ Task Text │ 🗑 │  │  │  │  │
│  │  │  │  └─────────────────────────────┘  │  │  │  │
│  │  │  │  </div>                           │  │  │  │
│  │  │  └───────────────────────────────────┘  │  │  │
│  │  │  </Paper>                               │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  │  </div>                                       │  │
│  └───────────────────────────────────────────────┘  │
│  </div>                                             │
└─────────────────────────────────────────────────────┘
```

### Material-UI Components ที่ใช้

| Component   | Import From         | Usage                                     | Props ที่ใช้                                                      |
| ----------- | ------------------- | ----------------------------------------- | ----------------------------------------------------------------- |
| `Paper`     | `@material-ui/core` | Container card สำหรับ form และ task items | `elevation={3}`, `className`                                      |
| `TextField` | `@material-ui/core` | Input field สำหรับพิมพ์ task ใหม่         | `variant`, `size`, `value`, `required`, `onChange`, `placeholder` |
| `Checkbox`  | `@material-ui/core` | Toggle สถานะ completed ของ task           | `checked`, `onClick`, `color`                                     |
| `Button`    | `@material-ui/core` | ปุ่ม "Add Task" และ "Delete"              | `color`, `variant`, `type`, `onClick`, `className`                |

### Event Binding ใน render()

| Element           | Event      | Handler                       | Parameter        |
| ----------------- | ---------- | ----------------------------- | ---------------- |
| `<form>`          | `onSubmit` | `this.handleSubmit`           | Event object (e) |
| `<TextField>`     | `onChange` | `this.handleChange`           | Event object     |
| `<Checkbox>`      | `onClick`  | `() => this.handleUpdate(id)` | `task._id`       |
| Delete `<Button>` | `onClick`  | `() => this.handleDelete(id)` | `task._id`       |

### Conditional CSS Classes

```javascript
<div className={task.completed ? "task-text completed" : "task-text"}>
  {task.task}
</div>
```

| สถานะ               | className               | ผลลัพธ์ UI                   |
| ------------------- | ----------------------- | ---------------------------- |
| `completed = false` | `"task-text"`           | ข้อความปกติ                  |
| `completed = true`  | `"task-text completed"` | ข้อความมี style (ขีดฆ่า ฯลฯ) |

### List Rendering

```javascript
{
  tasks.map((task) => (
    <Paper key={task._id} className="task-item">
      {/* ... */}
    </Paper>
  ));
}
```

- **Key:** ใช้ `task._id` (MongoDB ObjectId) เป็น unique key ✅
- **Pattern:** Array.map() สำหรับ render รายการ tasks

---

## 6. API Service Layer — `taskServices.js`

### หน้าที่หลัก

เป็น **Service Layer** ที่แยก HTTP calls ออกจาก components โดยใช้ **Axios** เป็น HTTP client ทำหน้าที่เป็นตัวกลางระหว่าง React components กับ Backend API

### Configuration

```javascript
import axios from "axios";
const apiUrl = process.env.REACT_APP_BACKEND_URL;
console.log(apiUrl); // Debug log — แสดง URL ตอนโหลดโมดูล
```

- **Base URL:** อ่านจาก environment variable `REACT_APP_BACKEND_URL`
- **Debug Log:** `console.log(apiUrl)` จะแสดงค่าใน browser console เมื่อ module ถูก import ครั้งแรก

### API Functions

| Function       | HTTP Method | Endpoint        | Request Body             | Return Value             |
| -------------- | ----------- | --------------- | ------------------------ | ------------------------ |
| `getTasks()`   | GET         | `{apiUrl}`      | —                        | `Promise<AxiosResponse>` |
| `addTask()`    | POST        | `{apiUrl}`      | `{ task: "string" }`     | `Promise<AxiosResponse>` |
| `updateTask()` | PUT         | `{apiUrl}/{id}` | `{ completed: boolean }` | `Promise<AxiosResponse>` |
| `deleteTask()` | DELETE      | `{apiUrl}/{id}` | —                        | `Promise<AxiosResponse>` |

### Function Details

#### `getTasks()` — Fetch All Tasks

```javascript
export function getTasks() {
  return axios.get(apiUrl);
}
```

```
GET {REACT_APP_BACKEND_URL}
         │
         ▼
Response: [{ _id, task, completed, __v }, ...]
```

#### `addTask(task)` — Create New Task

```javascript
export function addTask(task) {
  return axios.post(apiUrl, task);
}
```

```
POST {REACT_APP_BACKEND_URL}
Body: { "task": "Buy groceries" }
         │
         ▼
Response: { _id, task, completed, __v }
```

#### `updateTask(id, task)` — Update Existing Task

```javascript
export function updateTask(id, task) {
  return axios.put(apiUrl + "/" + id, task);
}
```

```
PUT {REACT_APP_BACKEND_URL}/64a1b2c3d4e5f6a7b8c9d0e1
Body: { "completed": true }
         │
         ▼
Response: { _id, task, completed, __v }  (ก่อนอัปเดต)
```

#### `deleteTask(id)` — Delete Task

```javascript
export function deleteTask(id) {
  return axios.delete(apiUrl + "/" + id);
}
```

```
DELETE {REACT_APP_BACKEND_URL}/64a1b2c3d4e5f6a7b8c9d0e1
         │
         ▼
Response: { _id, task, completed, __v }  (task ที่ถูกลบ)
```

### URL Construction Pattern

```
apiUrl = "http://backend:3500/api/tasks"

getTasks()              → GET    http://backend:3500/api/tasks
addTask(body)           → POST   http://backend:3500/api/tasks
updateTask("abc", body) → PUT    http://backend:3500/api/tasks/abc
deleteTask("abc")       → DELETE http://backend:3500/api/tasks/abc
```

### Axios Response Structure

ทุกฟังก์ชัน return `AxiosResponse` ที่มีโครงสร้าง:

```javascript
{
    data: { ... },        // Response body (ใช้ destructure ใน Tasks.js)
    status: 200,          // HTTP status code
    statusText: "OK",     // HTTP status text
    headers: { ... },     // Response headers
    config: { ... },      // Request config
}
```

---

## 7. Environment Variables

### ตารางสรุป Environment Variables

| Variable                | Required | Default | Description                      | ตัวอย่าง                          |
| ----------------------- | -------- | ------- | -------------------------------- | --------------------------------- |
| `REACT_APP_BACKEND_URL` | ✅ Yes   | —       | URL เต็มของ Backend API endpoint | `http://localhost:3500/api/tasks` |

### กลไกของ `REACT_APP_` prefix

React (react-scripts) กำหนดให้ environment variables ที่จะใช้ใน frontend code **ต้อง**ขึ้นต้นด้วย `REACT_APP_` เท่านั้น เพื่อความปลอดภัย

```
┌──────────────────────────────────────────────────────────────┐
│                    Build Time (npm start / npm run build)     │
│                                                              │
│  REACT_APP_BACKEND_URL=http://localhost:3500/api/tasks       │
│         │                                                    │
│         ▼                                                    │
│  process.env.REACT_APP_BACKEND_URL                           │
│         │                                                    │
│         ▼  (Webpack DefinePlugin)                            │
│  ถูกแทนที่ด้วยค่าจริงใน JavaScript bundle                      │
│  apiUrl = "http://localhost:3500/api/tasks"                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

> ⚠️ **สำคัญ:** Environment variable นี้ถูก embed เข้าไปใน JavaScript bundle **ตอน build time** ไม่ใช่ runtime ดังนั้นหลัง build แล้วจะเปลี่ยนค่าไม่ได้

### วิธีการกำหนดค่า

**วิธี 1: ไฟล์ `.env`**

```bash
# .env (ที่ root ของ frontend project)
REACT_APP_BACKEND_URL=http://localhost:3500/api/tasks
```

**วิธี 2: Environment variable ตอนรัน**

```bash
REACT_APP_BACKEND_URL=http://backend:3500/api/tasks npm start
```

**วิธี 3: Docker environment**

```bash
docker run -e REACT_APP_BACKEND_URL=http://backend:3500/api/tasks frontend-app
```

### ตัวอย่างค่าตามสภาพแวดล้อม

| Environment | REACT_APP_BACKEND_URL               |
| ----------- | ----------------------------------- |
| Local Dev   | `http://localhost:3500/api/tasks`   |
| Docker      | `http://backend:3500/api/tasks`     |
| Kubernetes  | `http://backend-svc:3500/api/tasks` |
| Production  | `https://api.example.com/api/tasks` |

---

## 8. Dependencies และ Versions

### Production Dependencies

| Package                       | Version    | Description                                          |
| ----------------------------- | ---------- | ---------------------------------------------------- |
| `react`                       | `^17.0.2`  | Core React library                                   |
| `react-dom`                   | `^17.0.2`  | React DOM renderer สำหรับ browser                    |
| `react-scripts`               | `4.0.3`    | Build toolchain (Webpack, Babel, ESLint, dev server) |
| `@material-ui/core`           | `^4.11.4`  | Material Design UI component library                 |
| `axios`                       | `^=0.30.0` | HTTP client สำหรับเรียก API                          |
| `@testing-library/jest-dom`   | `^5.14.1`  | Jest DOM matchers สำหรับ testing                     |
| `@testing-library/react`      | `^11.2.7`  | React testing utilities                              |
| `@testing-library/user-event` | `^12.8.3`  | User event simulation สำหรับ testing                 |
| `web-vitals`                  | `^1.1.2`   | Web performance metrics                              |

### Dependency Categories

```
┌─────────────────────────────────────────────────────────┐
│                    Dependencies                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Core React:                                            │
│  ├── react ^17.0.2                                      │
│  ├── react-dom ^17.0.2                                  │
│  └── react-scripts 4.0.3                                │
│                                                         │
│  UI Framework:                                          │
│  └── @material-ui/core ^4.11.4                          │
│                                                         │
│  HTTP Client:                                           │
│  └── axios ^=0.30.0  ⚠️ ผิดปกติ (ดูหมายเหตุ)            │
│                                                         │
│  Testing:                                               │
│  ├── @testing-library/jest-dom ^5.14.1                  │
│  ├── @testing-library/react ^11.2.7                     │
│  └── @testing-library/user-event ^12.8.3                │
│                                                         │
│  Performance:                                           │
│  └── web-vitals ^1.1.2                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Version Range Explanation

| Dependency        | Specified  | ช่วงที่อนุญาต                           | หมายเหตุ                       |
| ----------------- | ---------- | --------------------------------------- | ------------------------------ |
| react             | `^17.0.2`  | `>=17.0.2` and `<18.0.0`                | ใช้ React 17                   |
| react-dom         | `^17.0.2`  | `>=17.0.2` and `<18.0.0`                | ต้องตรงกับ react version       |
| react-scripts     | `4.0.3`    | Exact `4.0.3`                           | Pinned version (ไม่มี `^`)     |
| @material-ui/core | `^4.11.4`  | `>=4.11.4` and `<5.0.0`                 | MUI v4 (v5 = `@mui/material`)  |
| axios             | `^=0.30.0` | ⚠️ ผิดปกติ — `^=` ไม่ใช่ semver มาตรฐาน | อาจเป็น typo ควรเป็น `^0.30.0` |
| web-vitals        | `^1.1.2`   | `>=1.1.2` and `<2.0.0`                  | Performance monitoring         |

> ⚠️ **Axios Version Note:** `"^=0.30.0"` ใช้ prefix `^=` ซึ่ง**ไม่ใช่รูปแบบ semver มาตรฐาน** npm อาจตีความเป็น `>=0.30.0 <1.0.0` แต่อาจเกิดปัญหาได้ ควรแก้เป็น `"^0.30.0"` หรือ `"~0.30.0"`

### NPM Scripts

| Script  | Command               | Description                                       |
| ------- | --------------------- | ------------------------------------------------- |
| `start` | `react-scripts start` | เริ่ม development server (port 3000 by default)   |
| `build` | `react-scripts build` | Build production bundle ไปที่ `build/` directory  |
| `test`  | `react-scripts test`  | รัน Jest test runner ในโหมด watch                 |
| `eject` | `react-scripts eject` | Eject config ออกจาก react-scripts (ใช้ครั้งเดียว) |

### Project Metadata

| Field   | Value    |
| ------- | -------- |
| name    | `client` |
| version | `0.1.0`  |
| private | `true`   |

### Browserslist Configuration

| Environment | Targets                                    |
| ----------- | ------------------------------------------ |
| Production  | `>0.2%`, `not dead`, `not op_mini all`     |
| Development | Last 1 version ของ Chrome, Firefox, Safari |

---

## 9. Dockerfile Build Process

### Dockerfile

```dockerfile
FROM node:14
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
CMD [ "npm", "start" ]
```

### Build Process ทีละขั้นตอน

```
Step 1: FROM node:14
┌──────────────────────────────────────────────────────────┐
│ ใช้ Node.js version 14 เป็น base image                   │
│ (Debian-based, full image)                               │
│ ⚠️  Node.js 14 End-of-Life: 30 April 2023                │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
Step 2: WORKDIR /usr/src/app
┌──────────────────────────────────────────────────────────┐
│ กำหนด working directory ภายใน container                   │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
Step 3: COPY package*.json ./
┌──────────────────────────────────────────────────────────┐
│ คัดลอก package.json และ package-lock.json                 │
│ ✅ ใช้ Docker layer caching                               │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
Step 4: RUN npm install
┌──────────────────────────────────────────────────────────┐
│ ติดตั้ง dependencies ทั้งหมด                               │
│ (รวม testing libraries ด้วย)                              │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
Step 5: COPY . .
┌──────────────────────────────────────────────────────────┐
│ คัดลอก source code ทั้งหมดเข้า container                   │
│ ⚠️  ไม่มี .dockerignore                                    │
└──────────────────────────────────────────────────────────┘
                    │
                    ▼
Step 6: CMD ["npm", "start"]
┌──────────────────────────────────────────────────────────┐
│ รัน react-scripts start (Development Server)             │
│ ⚠️  ใช้ dev server ใน container — ไม่ใช่ production build   │
│    Port default: 3000                                    │
└──────────────────────────────────────────────────────────┘
```

### Docker Build & Run Commands

```bash
# Build image
docker build -t frontend-app:latest .

# Run container
docker run -d \
  -p 3000:3000 \
  -e REACT_APP_BACKEND_URL="http://backend:3500/api/tasks" \
  --name frontend \
  frontend-app:latest
```

### Docker Image Characteristics

| Property          | Value                                   |
| ----------------- | --------------------------------------- |
| Base Image        | `node:14` (Debian-based)                |
| Working Directory | `/usr/src/app`                          |
| Startup Command   | `npm start` → `react-scripts start`     |
| Server Type       | Development server (webpack-dev-server) |
| Default Port      | 3000                                    |
| Exposed Port      | ไม่ได้ EXPOSE                           |
| Run as User       | root (default)                          |

### เปรียบเทียบ Development vs Production Dockerfile

```
┌──────────────────────────────────┬────────────────────────────────────┐
│     Current (Development)        │     Recommended (Production)       │
├──────────────────────────────────┼────────────────────────────────────┤
│ FROM node:14                     │ # Stage 1: Build                   │
│ WORKDIR /usr/src/app             │ FROM node:18-alpine AS build       │
│ COPY package*.json ./            │ WORKDIR /usr/src/app               │
│ RUN npm install                  │ COPY package*.json ./              │
│ COPY . .                         │ RUN npm ci                         │
│ CMD ["npm", "start"]             │ COPY . .                           │
│                                  │ ARG REACT_APP_BACKEND_URL          │
│ # ❌ Dev server ใน production    │ RUN npm run build                  │
│ # ❌ Image ขนาดใหญ่              │                                    │
│ # ❌ มี source code ใน image     │ # Stage 2: Serve                   │
│                                  │ FROM nginx:alpine                  │
│                                  │ COPY --from=build                  │
│                                  │   /usr/src/app/build               │
│                                  │   /usr/share/nginx/html            │
│                                  │ EXPOSE 80                          │
│                                  │ CMD ["nginx", "-g",                │
│                                  │      "daemon off;"]                │
│                                  │                                    │
│                                  │ # ✅ Static files only             │
│                                  │ # ✅ Image ขนาดเล็ก (~25MB)        │
│                                  │ # ✅ Production-grade server       │
└──────────────────────────────────┴────────────────────────────────────┘
```

---

## 10. Data Flow & State Management

### Complete Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          App Component                           │
│                                                                  │
│  State: { tasks: [...], currentTask: "" }                        │
│         │                    ▲                                   │
│         │                    │ setState()                        │
│         ▼                    │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    render()                              │    │
│  │                                                         │    │
│  │  ┌──────────────────┐   ┌────────────────────────┐     │    │
│  │  │    TextField      │   │      Button            │     │    │
│  │  │  value={          │   │    "Add Task"           │     │    │
│  │  │   currentTask}    │   │  type="submit"          │     │    │
│  │  │  onChange={       │   └────────────┬───────────┘     │    │
│  │  │   handleChange}   │                │                 │    │
│  │  └──────────────────┘                │                 │    │
│  │                                       │ form onSubmit    │    │
│  │                                       ▼                 │    │
│  │                              handleSubmit()              │    │
│  │                                       │                 │    │
│  │  ┌──────────────────────────────────────────────────┐   │    │
│  │  │            tasks.map() → Task Items              │   │    │
│  │  │  ┌────────┐  ┌──────────┐  ┌──────────────┐    │   │    │
│  │  │  │Checkbox│  │ Task Text│  │ Delete Button │    │   │    │
│  │  │  │onClick │  │          │  │   onClick     │    │   │    │
│  │  │  └───┬────┘  └──────────┘  └──────┬───────┘    │   │    │
│  │  │      │                             │            │   │    │
│  │  │      ▼                             ▼            │   │    │
│  │  │ handleUpdate()              handleDelete()      │   │    │
│  │  └──────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Event Handlers (inherited from Tasks.js):                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ handleChange ──▶ setState({ currentTask })               │   │
│  │ handleSubmit ──▶ addTask() ──▶ setState({ tasks })       │   │
│  │ handleUpdate ──▶ setState() ──▶ updateTask()             │   │
│  │ handleDelete ──▶ setState() ──▶ deleteTask()             │   │
│  └───────────────────────────┬──────────────────────────────┘   │
│                              │                                   │
└──────────────────────────────│───────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  taskServices.js    │
                    │  (Axios HTTP calls) │
                    └─────────┬───────────┘
                              │
                              ▼
                    ┌─────────────────────┐
                    │   Backend API       │
                    │   /api/tasks        │
                    └─────────────────────┘
```

### State Update Patterns Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    State Update Patterns                     │
├────────────┬─────────────┬──────────────┬───────────────────┤
│ Action     │ UI Update   │ API Call     │ On Error          │
├────────────┼─────────────┼──────────────┼───────────────────┤
│ Load       │ After API   │ First        │ Show empty list   │
│ Create     │ After API   │ First        │ Log only          │
│ Update     │ Before API  │ After UI     │ Rollback UI       │
│ Delete     │ Before API  │ After UI     │ Rollback UI       │
├────────────┼─────────────┼──────────────┼───────────────────┤
│            │ Optimistic ◀┘             │ Pessimistic ◀──┘  │
└────────────┴─────────────┴──────────────┴───────────────────┘
```

---

## 11. Sequence Diagrams

### 11.1 Application Load Sequence

```
┌─────────┐      ┌──────────┐      ┌──────────────┐      ┌─────────┐
│ Browser │      │  App.js  │      │taskServices.js│     │ Backend │
└────┬────┘      └────┬─────┘      └──────┬───────┘      └────┬────┘
     │                │                    │                    │
     │  Load App      │                    │                    │
     │───────────────▶│                    │                    │
     │                │                    │                    │
     │                │ componentDidMount()│                    │
     │                │────────┐           │                    │
     │                │◀───────┘           │                    │
     │                │                    │                    │
     │                │ getTasks()         │                    │
     │                │───────────────────▶│                    │
     │                │                    │                    │
     │                │                    │ GET /api/tasks     │
     │                │                    │───────────────────▶│
     │                │                    │                    │
     │                │                    │  [tasks array]     │
     │                │                    │◀───────────────────│
     │                │                    │                    │
     │                │  { data: [...] }   │                    │
     │                │◀───────────────────│                    │
     │                │                    │                    │
     │                │ setState({tasks})  │                    │
     │                │────────┐           │                    │
     │                │◀───────┘           │                    │
     │                │                    │                    │
     │  Render tasks  │                    │                    │
     │◀───────────────│                    │                    │
```

### 11.2 Add Task Sequence

```
┌─────────┐      ┌──────────┐      ┌──────────────┐      ┌─────────┐
│  User   │      │  App.js  │      │taskServices.js│     │ Backend │
└────┬────┘      └────┬─────┘      └──────┬───────┘      └────┬────┘
     │                │                    │                    │
     │ Type "Buy..."  │                    │                    │
     │───────────────▶│                    │                    │
     │                │ handleChange()     │                    │
     │                │ setState({         │                    │
     │                │  currentTask})     │                    │
     │                │                    │                    │
     │ Click "Add"    │                    │                    │
     │───────────────▶│                    │                    │
     │                │ handleSubmit()     │                    │
     │                │                    │                    │
     │                │ addTask({task})    │                    │
     │                │───────────────────▶│                    │
     │                │                    │ POST /api/tasks    │
     │                │                    │───────────────────▶│
     │                │                    │                    │
     │                │                    │  {new task}        │
     │                │                    │◀───────────────────│
     │                │  { data }          │                    │
     │                │◀───────────────────│                    │
     │                │                    │                    │
     │                │ tasks.push(data)   │                    │
     │                │ setState({tasks,   │                    │
     │                │  currentTask:""})  │                    │
     │                │                    │                    │
     │  Re-render     │                    │                    │
     │  (new task +   │                    │                    │
     │   empty input) │                    │                    │
     │◀───────────────│                    │                    │
```

### 11.3 Toggle Completion (Optimistic Update) Sequence

```
┌─────────┐      ┌──────────┐      ┌──────────────┐      ┌─────────┐
│  User   │      │  App.js  │      │taskServices.js│     │ Backend │
└────┬────┘      └────┬─────┘      └──────┬───────┘      └────┬────┘
     │                │                    │                    │
     │ Click Checkbox │                    │                    │
     │───────────────▶│                    │                    │
     │                │ handleUpdate(id)   │                    │
     │                │                    │                    │
     │                │ Toggle completed   │                    │
     │                │ setState({tasks})  │                    │
     │                │────────┐           │                    │
     │                │◀───────┘           │                    │
     │                │                    │                    │
     │  UI อัปเดตทันที │                    │                    │
     │◀───────────────│                    │                    │
     │  (Optimistic)  │                    │                    │
     │                │                    │                    │
     │                │ updateTask(id,body)│                    │
     │                │───────────────────▶│                    │
     │                │                    │ PUT /api/tasks/:id │
     │                │                    │───────────────────▶│
     │                │                    │                    │
     │                │                    │    ┌───────────┐   │
     │                │                    │    │ Success ? │   │
     │                │                    │    └─────┬─────┘   │
     │                │                    │          │         │
     │                │                    │   ┌──Yes─┴──No──┐  │
     │                │                    │   │             │  │
     │                │                    │   ▼             ▼  │
     │                │              Done (UI  │     Rollback   │
     │                │              already   │     setState   │
     │                │              updated)  │    (original)  │
```

---

## 12. ข้อสังเกตและข้อเสนอแนะ

### 🔴 ปัญหาที่ควรแก้ไข (Critical)

| #   | ปัญหา                              | ไฟล์           | รายละเอียด                                                                                                                                     |
| --- | ---------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **Node.js 14 EOL**                 | `Dockerfile`   | Node.js 14 หมดอายุการสนับสนุนแล้ว (30 April 2023) ควรอัปเกรดเป็น Node.js 18+                                                                   |
| 2   | **Dev server ใน Docker**           | `Dockerfile`   | ใช้ `npm start` (webpack-dev-server) ใน container แทนที่จะ build เป็น static files — ไม่เหมาะสำหรับ production, สิ้นเปลืองทรัพยากร, ไม่ปลอดภัย |
| 3   | **Axios version ผิดปกติ**          | `package.json` | `"^=0.30.0"` ไม่ใช่ semver range ที่ถูกต้อง อาจทำให้ npm install ล้มเหลวหรือได้ version ที่ไม่คาดหมาย                                          |
| 4   | **State mutation ใน handleSubmit** | `Tasks.js`     | `tasks.push(data)` เป็นการ mutate `originalTasks` โดยตรง เพราะ `const tasks = originalTasks` เป็นการ copy reference ไม่ใช่ค่า                  |

### 🟡 ข้อควรปรับปรุง (Improvement)

| #   | ข้อเสนอแนะ                      | ไฟล์                  | รายละเอียด                                                                    |
| --- | ------------------------------- | --------------------- | ----------------------------------------------------------------------------- |
| 5   | **Inheritance pattern**         | `App.js` / `Tasks.js` | React แนะนำ Composition over Inheritance ควรเปลี่ยนเป็น custom hooks หรือ HOC |
| 6   | **Class Components**            | ทุกไฟล์               | React สมัยใหม่แนะนำ Functional Components + Hooks แทน Class Components        |
| 7   | **Material-UI v4 deprecated**   | `package.json`        | MUI v4 (`@material-ui/core`) ถูกแทนที่ด้วย MUI v5 (`@mui/material`) แล้ว      |
| 8   | **ไม่มี error UI**              | `Tasks.js`            | ทุก catch block ใช้ `console.log(error)` ไม่มีการแสดงข้อผิดพลาดให้ผู้ใช้เห็น  |
| 9   | **ไม่มี loading state**         | `Tasks.js`            | ไม่มี loading indicator ขณะรอ API response                                    |
| 10  | **ไม่มี `.dockerignore`**       | `Dockerfile`          | อาจคัดลอก `node_modules/`, `.git/`, `build/` เข้า image                       |
| 11  | **console.log ใน production**   | `taskServices.js`     | `console.log(apiUrl)` ไม่ควรอยู่ใน production code                            |
| 12  | **handleSubmit ไม่มี rollback** | `Tasks.js`            | ต่างจาก handleUpdate/handleDelete ที่มี rollback เมื่อ API ล้มเหลว            |
| 13  | **State ประกาศซ้ำ**             | `App.js`              | `state = { tasks: [], currentTask: "" }` ประกาศทั้งใน Tasks.js และ App.js     |
| 14  | **ไม่มี EXPOSE**                | `Dockerfile`          | ควรเพิ่ม `EXPOSE 3000` เพื่อเป็น documentation                                |

### ตัวอย่างการแก้ State Mutation (Issue #4)

```javascript
// ❌ ปัจจุบัน — mutate original array
handleSubmit = async (e) => {
  e.preventDefault();
  const originalTasks = this.state.tasks;
  try {
    const { data } = await addTask({ task: this.state.currentTask });
    const tasks = originalTasks; // ← same reference!
    tasks.push(data); // ← mutates originalTasks
    this.setState({ tasks, currentTask: "" });
  } catch (error) {
    console.log(error);
  }
};

// ✅ แนะนำ — immutable update
handleSubmit = async (e) => {
  e.preventDefault();
  try {
    const { data } = await addTask({ task: this.state.currentTask });
    this.setState((prevState) => ({
      tasks: [...prevState.tasks, data],
      currentTask: "",
    }));
  } catch (error) {
    console.log(error);
  }
};
```

### ตัวอย่าง Production Dockerfile (แนะนำ)

```dockerfile
# Stage 1: Build
FROM node:18-alpine AS build
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci
COPY . .
ARG REACT_APP_BACKEND_URL
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:1.25-alpine
COPY --from=build /usr/src/app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
# Build with backend URL baked in
docker build \
  --build-arg REACT_APP_BACKEND_URL=http://backend:3500/api/tasks \
  -t frontend-app:latest .
```

---
