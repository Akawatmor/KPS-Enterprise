# Frontend Refactor Plan: Next.js + Bun + TypeScript

## ภาพรวม (Overview)

แปลง frontend จาก Next.js (JavaScript + npm + Node.js) ไปเป็น Next.js (TypeScript + Bun)
โดยคง logic และ UI เดิมทั้งหมดไว้ ไม่เพิ่ม feature ใหม่

**สถานะปัจจุบัน (`src/phase2-final/frontend`):**

| หัวข้อ | ค่าปัจจุบัน |
|--------|------------|
| Framework | Next.js 14 + React 18 |
| ภาษา | JavaScript (`.js`) |
| Package manager | npm |
| Runtime (Docker) | `node:20-alpine` |
| ไฟล์หลัก | `page.js`, `layout.js`, `modules/api.js` |
| Lock file | `package-lock.json` |

**เป้าหมายหลังการ refactor:**

| หัวข้อ | ค่าใหม่ |
|--------|--------|
| Framework | Next.js 15 + React 19 |
| ภาษา | TypeScript (`.tsx` / `.ts`) |
| Package manager | Bun |
| Runtime (Docker) | `oven/bun:1.2-alpine` |
| ไฟล์หลัก | `page.tsx`, `layout.tsx`, `modules/api.ts` |
| Lock file | `bun.lock` |

---

## ขั้นตอนที่ 1 — เตรียมก่อนเริ่ม

### 1.1 Commit สถานะปัจจุบันก่อน (Safety Checkpoint)

```bash
git add -A
git commit -m "chore: snapshot before frontend refactor to Bun + TypeScript"
```

### 1.2 ตรวจสอบ Bun ใน local machine

```bash
bun --version
# ต้องการ >= 1.2.0
# ถ้าไม่มีให้ติดตั้ง: curl -fsSL https://bun.sh/install | bash
```

### 1.3 ลบ artifacts เดิมใน directory ที่จะแก้ไข

```bash
cd src/phase2-final/frontend
rm -rf node_modules .next package-lock.json
```

---

## ขั้นตอนที่ 2 — อัปเดต `package.json`

แทนที่เนื้อหา `package.json` ทั้งหมด:

```json
{
  "name": "todoapp-web",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start -p 3000",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "date-fns": "^4.1.0",
    "lucide-react": "^0.511.0",
    "next": "^15.3.1",
    "react": "^19.1.0",
    "react-dom": "^19.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.15.3",
    "@types/react": "^19.1.2",
    "@types/react-dom": "^19.1.2",
    "typescript": "^5.8.3"
  }
}
```

**ความแตกต่างจากเดิม:**

- อัปเดต `next` → 15.x, `react`/`react-dom` → 19.x
- `lucide-react` ปรับ version ให้ตรง semver จริง (เดิม `^1.8.0` ไม่มีในตลาด)
- เพิ่ม `@types/node`, `@types/react`, `@types/react-dom` ใน devDependencies
- เพิ่ม script `type-check` สำหรับ CI

ติดตั้ง dependencies ด้วย Bun:

```bash
bun install
# จะสร้าง bun.lock และ node_modules
```

---

## ขั้นตอนที่ 3 — สร้าง `tsconfig.json`

สร้างไฟล์ใหม่ `tsconfig.json` ที่ root ของ frontend directory:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "ESNext"],
    "allowJs": false,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

**หมายเหตุการตั้งค่าที่สำคัญ:**

| Option | ค่า | เหตุผล |
|--------|-----|--------|
| `strict` | `true` | บังคับ type safety เต็มรูปแบบ |
| `allowJs` | `false` | ไม่อนุญาต `.js` — บังคับ TypeScript ทั้งหมด |
| `moduleResolution` | `"bundler"` | รองรับ Next.js 15 + Bun/Turbopack |
| `jsx` | `"preserve"` | ให้ Next.js จัดการ JSX transform เอง |
| `paths` | `@/*` | alias สำหรับ import สะดวก |

---

## ขั้นตอนที่ 4 — ตรวจสอบ `next.config.mjs`

ไฟล์นี้ไม่ต้องเปลี่ยน ยังคงเนื้อหาเดิม:

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: "standalone",  // จำเป็นสำหรับ Docker multi-stage build
};

export default nextConfig;
```

---

## ขั้นตอนที่ 5 — แปลงไฟล์ JavaScript → TypeScript

### 5.1 `app/modules/api.js` → `app/modules/api.ts`

ลบ `api.js` แล้วสร้าง `api.ts` ด้วยเนื้อหาต่อไปนี้:

```typescript
// app/modules/api.ts

export const API_BASE: string = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// ── Domain Types ──────────────────────────────────────────────────────────────
export interface StoredUser {
  id: string;
  username: string;
  email?: string;
}

interface AuthExchangeResponse {
  session?: { access_token: string };
  user?: StoredUser;
}

// ── Token / User storage ──────────────────────────────────────────────────────
export function getStoredToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("todoapp.access_token");
}

export function setStoredToken(token: string | null): void {
  if (typeof window === "undefined") return;
  if (token) localStorage.setItem("todoapp.access_token", token);
  else localStorage.removeItem("todoapp.access_token");
}

export function getStoredUser(): StoredUser | null {
  if (typeof window === "undefined") return null;
  try {
    return JSON.parse(localStorage.getItem("todoapp.user") || "null") as StoredUser | null;
  } catch {
    return null;
  }
}

export function setStoredUser(user: StoredUser | null): void {
  if (typeof window === "undefined") return;
  if (user) localStorage.setItem("todoapp.user", JSON.stringify(user));
  else localStorage.removeItem("todoapp.user");
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────
function buildURL(endpoint: string): string {
  const path = endpoint.startsWith("/api/v1")
    ? endpoint
    : `/api/v1${endpoint.startsWith("/") ? endpoint : `/${endpoint}`}`;
  return `${API_BASE}${path}`;
}

export async function fetchAPI<T = unknown>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getStoredToken();
  const authHeader: Record<string, string> = token
    ? { Authorization: `Bearer ${token}` }
    : { "X-User-ID": "local-dev-user" };

  const res = await fetch(buildURL(endpoint), {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...authHeader,
      ...(options.headers as Record<string, string>),
    },
  });

  if (res.status === 401) {
    setStoredToken(null);
    setStoredUser(null);
    throw new Error("Unauthorized");
  }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `HTTP ${res.status}`);
  }
  return res.json() as Promise<T>;
}

export async function loginGitHub(code = "demo-code"): Promise<AuthExchangeResponse> {
  const data = await fetchAPI<AuthExchangeResponse>("/auth/github/exchange", {
    method: "POST",
    body: JSON.stringify({ code }),
  });
  if (data?.session?.access_token) setStoredToken(data.session.access_token);
  if (data?.user) setStoredUser(data.user);
  return data;
}

export function logout(): void {
  setStoredToken(null);
  setStoredUser(null);
}
```

**จุดที่เปลี่ยนจากเดิม:**
- `fetchAPI` เป็น generic function `fetchAPI<T>` เพื่อให้ผู้เรียก specify return type ได้
- เพิ่ม `StoredUser` interface แทนการใช้ `any`
- `catch` block ใช้ implicit `unknown` type (TypeScript 4+ default)
- ทุก function มี explicit return type

---

### 5.2 `app/layout.js` → `app/layout.tsx`

ลบ `layout.js` แล้วสร้าง `layout.tsx`:

```typescript
// app/layout.tsx
import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TodoApp — Big Calendar",
  description: "Todo app with a huge calendar view — Phase 2 on K3s + Woodpecker CI/CD",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element {
  return (
    <html lang="th">
      <head />
      <body>{children}</body>
    </html>
  );
}
```

**จุดที่เปลี่ยน:**
- import `Metadata` type จาก `"next"`
- เพิ่ม type annotation ให้ `children` prop: `React.ReactNode`
- เพิ่ม return type: `React.JSX.Element`

---

### 5.3 `app/page.js` → `app/page.tsx`

นี่คือไฟล์ที่ใหญ่และซับซ้อนที่สุด ต้องเพิ่ม type ให้ครบทุกจุด

#### 5.3.1 Domain Types (เพิ่มที่ต้น file หลัง imports)

```typescript
// ── Domain Types ──────────────────────────────────────────────────────────────
type Priority = "high" | "normal" | "low";

interface Task {
  id: number;
  title: string;
  description?: string;
  priority: Priority;
  due_at: string;       // ISO 8601 string จาก backend
  status: "open" | "done";
  created_at?: string;
  updated_at?: string;
}

interface PriorityConfig {
  value: Priority;
  label: string;
  cls: string;
}
```

#### 5.3.2 Constants — เพิ่ม type annotation

```typescript
const WEEKDAYS: string[] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

const PRIORITIES: PriorityConfig[] = [
  { value: "high",   label: "🔴 High",   cls: "badge-high" },
  { value: "normal", label: "🔵 Normal", cls: "badge-normal" },
  { value: "low",    label: "🟣 Low",    cls: "badge-low" },
];
```

#### 5.3.3 Helper function — เพิ่ม return type

```typescript
function buildCalendarDays(monthDate: Date): Date[] {
  // ... เนื้อหาเดิม
}
```

#### 5.3.4 Component Props Interfaces

```typescript
// TaskModal
interface TaskModalProps {
  defaultDate: Date | null;
  editTask: Task | null;
  onClose: () => void;
  onSaved: () => void;
}

// TaskCard
interface TaskCardProps {
  task: Task;
  onToggle: (task: Task) => void;
  onEdit: (task: Task) => void;
  onDelete: (task: Task) => void;
}

// DayColumn (ถ้ามี component แยก)
interface DayColumnProps {
  day: Date;
  tasks: Task[];
  onOpenNew: (date: Date) => void;
  onOpenEdit: (task: Task) => void;
}
```

#### 5.3.5 Component Signatures

```typescript
// แทนที่ function TaskModal({ defaultDate, editTask, onClose, onSaved })
function TaskModal({ defaultDate, editTask, onClose, onSaved }: TaskModalProps): React.JSX.Element

// แทนที่ function TaskCard({ task, onToggle, onEdit, onDelete })
function TaskCard({ task, onToggle, onEdit, onDelete }: TaskCardProps): React.JSX.Element
```

#### 5.3.6 useState — ระบุ generic type

```typescript
// แทนที่ useState([])
const [tasks, setTasks] = useState<Task[]>([]);

// แทนที่ useState(null)
const [editTask, setEditTask] = useState<Task | null>(null);
const [selectedDate, setSelectedDate] = useState<Date | null>(null);

// แทนที่ useState(false)
const [loading, setLoading] = useState<boolean>(false);

// แทนที่ useState("")
const [error, setError] = useState<string>("");
const [title, setTitle] = useState<string>("");
```

#### 5.3.7 Event Handlers — ระบุ event type

```typescript
// form submit handler
const handleSubmit = async (e: React.FormEvent<HTMLFormElement>): Promise<void> => { ... }

// input onChange
onChange={(e: React.ChangeEvent<HTMLInputElement>) => setTitle(e.target.value)}

// select onChange
onChange={(e: React.ChangeEvent<HTMLSelectElement>) => setPri(e.target.value as Priority)}

// textarea onChange
onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setDesc(e.target.value)}

// button onClick
onClick={(e: React.MouseEvent<HTMLButtonElement>) => ...}
```

#### 5.3.8 fetchAPI calls — ระบุ generic type

```typescript
// ดึง list tasks
const data = await fetchAPI<Task[]>("/tasks");

// ดึง single task หลัง toggle
const updated = await fetchAPI<Task>(`/tasks/${task.id}`, { method: "PATCH", ... });
```

---

## ขั้นตอนที่ 6 — อัปเดต `Dockerfile`

แทนที่ `Dockerfile` ทั้งหมด:

```dockerfile
# syntax=docker/dockerfile:1

# ── deps: install dependencies ────────────────────────────────────────────────
FROM oven/bun:1.2-alpine AS deps
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# ── builder: build Next.js standalone ────────────────────────────────────────
FROM oven/bun:1.2-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Accept at build time so NEXT_PUBLIC_ var is embedded in the JS bundle.
# Leave empty (default) for same-domain K3s deployments (relative /api paths).
ARG NEXT_PUBLIC_API_BASE_URL=""
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_TELEMETRY_DISABLED=1

RUN bun run build

# ── runner: minimal production image ─────────────────────────────────────────
FROM oven/bun:1.2-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

EXPOSE 3000
# Next.js standalone output (server.js) รันได้โดยตรงบน Bun runtime
CMD ["bun", "server.js"]
```

**ความแตกต่างจากเดิม:**

| จุด | เดิม | ใหม่ |
|-----|------|------|
| Base image | `node:20-alpine` | `oven/bun:1.2-alpine` |
| Install | `npm install --frozen-lockfile` | `bun install --frozen-lockfile` |
| Lock file | `package-lock.json*` | `bun.lock*` |
| Build | `npm run build` | `bun run build` |
| Run | `node server.js` | `bun server.js` |
| เพิ่ม | — | `NEXT_TELEMETRY_DISABLED=1` |

---

## ขั้นตอนที่ 7 — อัปเดต `.dockerignore`

ตรวจสอบให้ `.dockerignore` มีรายการต่อไปนี้:

```
node_modules
.next
.git
*.log
bun.lockb
```

> **หมายเหตุ:** `bun.lock` (text, ควร commit เข้า git) และ `bun.lockb` (binary เดิมของ Bun < 1.2) ควร **exclude เฉพาะ `bun.lockb`** ออกจาก Docker context แต่ `bun.lock` ต้อง **ไม่** อยู่ใน `.dockerignore` เพื่อให้ `--frozen-lockfile` ทำงานได้

---

## ขั้นตอนที่ 8 — ลำดับการดำเนินงาน (Execution Order)

ทำตามลำดับนี้เพื่อลด type errors cascade:

```
1. git commit snapshot (ขั้นตอน 1.1)
2. rm -rf node_modules .next package-lock.json
3. แก้ไข package.json (ขั้นตอน 2)
4. สร้าง tsconfig.json (ขั้นตอน 3)
5. bun install  →  สร้าง bun.lock
6. สร้าง app/modules/api.ts  (ไม่มี import ภายใน project)
7. สร้าง app/layout.tsx      (import เฉพาะ globals.css)
8. สร้าง app/page.tsx        (import จาก api.ts)
9. ลบไฟล์ .js เดิมทั้งสาม (api.js, layout.js, page.js)
10. bun run type-check       (แก้ type errors จนสะอาด)
11. bun run build            (ทดสอบ build จริง)
12. อัปเดต Dockerfile (ขั้นตอน 6)
13. docker build + docker run (ขั้นตอน 9.4)
```

---

## ขั้นตอนที่ 9 — ตรวจสอบและทดสอบ

### 9.1 Type Check

```bash
bun run type-check
# output ที่ถูกต้อง: ไม่มีข้อความใดๆ (exit code 0)
```

### 9.2 Development Mode

```bash
bun run dev
# เปิด http://localhost:3000
```

ทดสอบ manual:
- [ ] สร้าง task ใหม่
- [ ] แก้ไข task
- [ ] ลบ task
- [ ] เปลี่ยน priority (high / normal / low)
- [ ] Toggle done/open
- [ ] Calendar navigation (prev/next month)

### 9.3 Production Build

```bash
bun run build
bun run start
# ทดสอบซ้ำกับ checklist ข้างบน
```

### 9.4 Docker Build & Run

```bash
docker build \
  --build-arg NEXT_PUBLIC_API_BASE_URL="" \
  -t todoapp-frontend:bun-ts \
  .

docker run --rm -p 3000:3000 todoapp-frontend:bun-ts
```

---

## ขั้นตอนที่ 10 — ประเด็นที่ต้องระวัง

| ประเด็น | รายละเอียด | วิธีแก้ |
|---------|-----------|---------|
| `"use client"` directive | ทุก component ที่ใช้ `useState`/`useEffect`/event handlers ต้องมี directive นี้บรรทัดแรกสุด | ตรวจสอบ `page.tsx` ว่ามี `"use client";` บรรทัดที่ 1 |
| `select` onChange type | `e.target.value` เป็น `string` แต่ `setPri` ต้องการ `Priority` | cast: `e.target.value as Priority` |
| `catch (err)` typing | TypeScript strict ถือว่า `err` เป็น `unknown` | ใช้ `err instanceof Error ? err.message : String(err)` |
| `task.status` vs `task.done` | backend อาจส่ง field ชื่อ `done: boolean` หรือ `status: "open"/"done"` | ตรวจ API response จริงแล้วกำหนด `Task` interface ให้ตรง |
| `lucide-react` version | ต้องตรวจสอบ icon names ที่เปลี่ยนระหว่าง minor versions | รัน `bun info lucide-react` ก่อน install |
| `React.FC` | ไม่แนะนำใน TypeScript 5.x เพราะ implicit `children` prop ถูกเอาออกไปแล้ว | ใช้ `function Comp(props: Props): React.JSX.Element` แทน |
| `bun.lock` ใน git | ต้อง commit เข้า git เหมือน `package-lock.json` | `git add bun.lock` ตามปกติ |
| `bun.lockb` (binary) | Bun < 1.2 สร้าง binary lockfile — ไม่ควรเกิดถ้าใช้ image `oven/bun:1.2-alpine` | ถ้าเจอให้อัปเกรด Bun local |
| Next.js standalone + Bun | `server.js` ที่ build ออกมาจาก Next.js standalone รันบน Bun runtime ได้โดยตรง | ทดสอบด้วย `bun server.js` ใน runner stage ก่อน deploy |

---

## โครงสร้างไฟล์หลังการ refactor

```
frontend/
├── .dockerignore
├── Dockerfile                   # ใช้ oven/bun:1.2-alpine
├── next.config.mjs              # ไม่เปลี่ยน
├── package.json                 # Bun + TypeScript dependencies
├── bun.lock                     # Bun lockfile (commit เข้า git)
├── tsconfig.json                # สร้างใหม่
├── next-env.d.ts                # Auto-generated โดย Next.js (อย่าแก้มือ)
├── app/
│   ├── globals.css              # ไม่เปลี่ยน
│   ├── layout.tsx               # แปลงจาก layout.js
│   ├── page.tsx                 # แปลงจาก page.js (ไฟล์ใหญ่สุด)
│   └── modules/
│       └── api.ts               # แปลงจาก api.js
└── public/
    └── .gitkeep
```

---

## สรุปการเปลี่ยนแปลงทั้งหมด

| ไฟล์ | สถานะ | การเปลี่ยนแปลงหลัก |
|------|--------|-------------------|
| `package.json` | แก้ไข | เพิ่ม @types/*, อัปเดต next/react, เพิ่ม type-check script |
| `tsconfig.json` | สร้างใหม่ | TypeScript config สำหรับ Next.js 15 + strict mode |
| `Dockerfile` | แก้ไข | node:20-alpine → oven/bun:1.2-alpine, npm → bun |
| `app/modules/api.js` → `api.ts` | แปลง | Generic fetchAPI, StoredUser interface, explicit return types |
| `app/layout.js` → `layout.tsx` | แปลง | Metadata type, React.ReactNode children type |
| `app/page.js` → `page.tsx` | แปลง | Task/Priority interfaces, typed props/state/events |
| `app/globals.css` | ไม่เปลี่ยน | — |
| `.dockerignore` | ตรวจสอบ | ให้แน่ใจว่า bun.lockb อยู่ใน list |
