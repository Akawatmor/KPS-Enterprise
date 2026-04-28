# 🚀 แผนปรับปรุง Pipeline ให้ว้าวขึ้น

> **เอกสารนี้คือ:** รายการสิ่งที่ควรเพิ่ม/เปลี่ยน จาก Pipeline เดิม เพื่อให้ดูเป็น production-grade มากขึ้น
> เอาไปพัฒนาต่อเองได้เลย

---

## 1. เปลี่ยน SQLite → PostgreSQL

**ปัญหาของ SQLite ใน Pipeline ปัจจุบัน:**
```
SQLite = single writer → PVC = ReadWriteOnce
→ backend ได้แค่ 1 replica
→ deploy strategy ต้องเป็น Recreate (มี downtime 5 วินาที)
→ backup = copy file ทั้งก้อน (ไม่ granular)
```

**เปลี่ยนแล้วได้อะไร:**
```
PostgreSQL แยก pod (StatefulSet + iSCSI PVC)
→ backend scale เป็น 2+ replicas ได้
→ strategy กลับเป็น RollingUpdate (zero downtime)
→ backup ด้วย pg_dump (restore ระดับ table/row ได้)
→ data อยู่บน Synology NAS (hardware RAID)
```

**สิ่งที่ต้องทำ:**
```
1. สร้าง K8s Secret เก็บ DB credentials + connection string
2. สร้าง PostgreSQL StatefulSet + Headless Service
   - image: postgres:16-alpine
   - mount iSCSI PVC ที่มีอยู่แล้ว
   - probe: pg_isready
3. แก้ Go backend
   - เปลี่ยน driver: sqlite → lib/pq
   - เปลี่ยน placeholder: ? → $1, $2
   - อ่าน DSN จาก env (DATABASE_DSN) แทน file path
4. แก้ deployment.yaml
   - replicas: 1 → 2
   - strategy: Recreate → RollingUpdate
   - เพิ่ม env DATABASE_DSN from secret
   - ลบ PVC mount ออกจาก backend pod
5. Migrate data
   - sqlite3 .dump → แปลง syntax → psql import
6. ทดสอบว่า /readyz ping DB ได้
```

---

## 2. เพิ่ม Trivy Security Scan ใน Pipeline

**ตอนนี้ไม่มี:**
```
build image → push → deploy เลย
→ ไม่รู้ว่า image มี CVE ร้ายแรงหรือเปล่า
```

**เพิ่มแล้วได้อะไร:**
```
build image → Trivy scan → CRITICAL พบ? → ❌ block deploy (production ปลอดภัย)
                         → ไม่พบ?       → ✅ deploy ต่อ

= "Security Gate" ใน pipeline
= shift-left security — จับ vulnerability ก่อนถึง production
```

**สิ่งที่ต้องทำ:**
```
1. เพิ่ม step ใน .woodpecker.yml หลัง build-push
   - image: aquasec/trivy
   - scan image ที่เพิ่ง push
   - --exit-code 1 --severity CRITICAL → fail pipeline ถ้าเจอ
   - --exit-code 0 --severity HIGH → report แต่ไม่ block
2. scan ทั้ง backend + frontend image (parallel ได้)
3. depends_on: build-push-core / build-push-web
```

---

## 3. เพิ่ม Smoke Test หลัง Deploy

**ตอนนี้:**
```
deploy เสร็จ → จบ pipeline → หวังว่าใช้ได้
→ pod อาจ Running แต่ API return 500 ก็ได้
```

**เพิ่มแล้วได้อะไร:**
```
deploy เสร็จ → curl /healthz → POST /api/todos → GET → DELETE
→ พิสูจน์ว่า app ทำงานได้จริงบน production
→ ถ้า fail = email แจ้งทันที + rollback ได้เลย
```

**สิ่งที่ต้องทำ:**
```
1. เพิ่ม step ใน .woodpecker.yml หลัง deploy-k3s
   - image: bitnami/kubectl (มี curl ด้วย) หรือ curlimages/curl
   - kubectl run --rm pod ชั่วคราวใน cluster
   - curl ยิง 5 requests:
     a. GET  /healthz         → expect 200
     b. GET  /readyz          → expect 200
     c. POST /api/todos       → expect 201 → จำ id
     d. GET  /api/todos/:id   → expect 200
     e. DELETE /api/todos/:id → expect 200
   - ถ้า step ไหน fail → exit 1 → pipeline fail
2. depends_on: deploy-k3s
```

---

## 4. ปรับ Email Notification ให้เป็น HTML สวย

**ตอนนี้ (ถ้ามี):**
```
plain text → "Deploy สำเร็จ" → ดูธรรมดา
```

**ปรับแล้วได้อะไร:**
```
HTML email → มี table แสดง commit/branch/author/duration
→ มี pipeline status: test ✅ → build ✅ → scan ✅ → deploy ✅ → smoke ✅
→ มี link ไป Woodpecker UI + Production URL
→ forward ให้อาจารย์/ทีมดูได้ทันที — ดู professional
```

**สิ่งที่ต้องทำ:**
```
1. ใช้ drillster/drone-email plugin
2. Setup Gmail App Password → เก็บใน Woodpecker Secrets
   - SMTP_USERNAME, SMTP_PASSWORD
3. สร้าง 2 steps:
   a. email-success (when: status: success)
      - subject มี commit SHA + branch
      - body เป็น HTML table: repo, branch, commit, author, duration, images
      - แสดง pipeline flow: test ✅ → build ✅ → scan ✅ → deploy ✅ → smoke ✅
      - link ไป pipeline log + production URL
   b. email-failure (when: status: failure)
      - subject บอก FAILED + commit SHA
      - body บอก step ที่ fail
      - เน้นว่า "Production ยังใช้ version เดิม — ไม่มีผลกระทบ"
```

---

## 5. เพิ่ม PostgreSQL Backup CronJob

**ตอนนี้:**
```
SQLite backup = kubectl cp file ออกมา (manual)
→ ลืมทำ = ข้อมูลหาย
```

**เพิ่มแล้วได้อะไร:**
```
CronJob ทุกคืน ตี 2 → pg_dump → gzip → เก็บบน host
→ retention 7 วัน (ลบเก่าอัตโนมัติ)
→ restore ได้ระดับ table/row
→ เป็น Layer 1 backup, Synology Snapshot เป็น Layer 2
```

**สิ่งที่ต้องทำ:**
```
1. สร้าง CronJob YAML ใน k8s/
   - schedule: "0 2 * * *"
   - image: postgres:16-alpine
   - command: pg_dump → gzip → /backup/todoapp-$(date).sql.gz
   - mount hostPath /var/backups/postgres
   - env PGPASSWORD from secret
2. เพิ่ม cleanup command: find /backup -mtime +7 -delete
3. kubectl apply ใน deploy step ของ pipeline
```

---

## 6. ปรับ Pipeline Flow เป็น 7 Stages (จากเดิม 4)

**ตอนนี้:**
```
test → build → deploy → email (4 stages)
```

**ปรับแล้ว:**
```
test → build (parallel) → scan (parallel) → deploy → smoke test → email (7 stages)
      ├─ core ──────────── ├─ core
      └─ web  ──────────── └─ web

จุดว้าว:
- parallel build ทั้ง 2 images พร้อมกัน (เร็วขึ้น)
- parallel scan ทั้ง 2 images พร้อมกัน
- 3 quality gates: code → security → runtime
- ทุก gate ต้องผ่าน → ถึงจะถึง production
```

**สิ่งที่ต้องทำ:**
```
1. แยก build-push เป็น 2 steps: build-push-core + build-push-web
   - depends_on: test-backend
   - (Woodpecker รัน parallel อัตโนมัติเมื่อ depends_on เหมือนกัน)
2. เพิ่ม scan-core + scan-web
   - depends_on: build-push-core / build-push-web ตามลำดับ
3. deploy-k3s depends_on: scan-core + scan-web (ต้องผ่านทั้งคู่)
4. smoke-test depends_on: deploy-k3s
5. email-success/failure depends_on: smoke-test
```

---

## 📊 สรุป: ก่อน vs หลังปรับปรุง

```
                    ก่อน                          หลัง
                    ────                          ────
Stages:             4                             7
Database:           SQLite (1 replica)            PostgreSQL (multi-replica)
Deploy strategy:    Recreate (downtime)           RollingUpdate (zero downtime)
Security scan:      ❌ ไม่มี                      ✅ Trivy block CRITICAL
Post-deploy check:  ❌ ไม่มี                      ✅ Smoke test CRUD
Email:              plain text                    HTML table + links
Backup:             ❌ manual                     ✅ CronJob ทุกคืน
Quality gates:      1 (test)                      3 (test → scan → smoke)
Parallel steps:     ❌ ไม่มี                      ✅ build + scan parallel
Tool เพิ่ม:         ไม่มี                         ไม่มี (Woodpecker ตัวเดียว)
```

---

## 🎯 ลำดับที่แนะนำ

| # | งาน | เวลาประมาณ | ว้าวจากอะไร |
|:-:|------|:----------:|------------|
| 1 | SQLite → PostgreSQL | 3–4 ชม. | zero downtime deploy + scale ได้ |
| 2 | เพิ่ม Trivy scan | 30 นาที | มี security gate ใน pipeline |
| 3 | เพิ่ม smoke test | 30 นาที | พิสูจน์ว่า deploy แล้วใช้ได้จริง |
| 4 | ปรับ email เป็น HTML | 30 นาที | ดู professional เวลา forward ให้คนอื่น |
| 5 | PG backup CronJob | 1 ชม. | automated disaster recovery |
| 6 | ปรับ flow เป็น parallel | 30 นาที | เร็วขึ้น + แสดง dependency graph สวย |

**รวม ~6 ชั่วโมง** — ไม่มี tool เพิ่ม, Woodpecker ตัวเดียวจัดการทั้งหมด
