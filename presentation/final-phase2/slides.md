---
marp: true
theme: default
paginate: true
backgroundColor: #f7f1e3
style: |
  section {
    font-family: 'Sarabun', 'Noto Sans Thai', sans-serif;
    color: #102a43;
    background: linear-gradient(180deg, #f7f1e3 0%, #fffaf1 100%);
  }
  h1, h2, h3 {
    color: #8c2f1c;
  }
  strong {
    color: #0f766e;
  }
  table {
    font-size: 0.78em;
  }
  code {
    font-size: 0.8em;
  }
  .small {
    font-size: 0.75em;
  }
  .tiny {
    font-size: 0.66em;
  }
  .accent {
    color: #7c2d12;
    font-weight: 700;
  }
  .cols {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }
  .cols3 {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 0.8rem;
  }
  .box {
    border: 2px solid #d8c3a5;
    border-radius: 14px;
    padding: 0.7rem 0.9rem;
    background: rgba(255,255,255,0.55);
  }
---

<!-- _paginate: false -->
<!-- _backgroundColor: #8c2f1c -->
<!-- _color: white -->

# KPS-Enterprise Phase 2
## TodoApp Big Calendar on K3s + Woodpecker CI/CD

**Evidence-Driven Delivery · DevSecOps Baseline · Canary Deployment**

กลุ่ม KPS-Enterprise Team · 2026


---

# ทำไมต้อง Phase 2?

<div class="cols">
<div class="box">

## Phase 1: Jenkins + EKS
- ✕ EKS ค่าใช้จ่ายสูง vendor lock-in
- ✕ Jenkins ซับซ้อนเกินทีมเล็ก
- ✕ ยาก reproduce ใน local
- ✕ Deploy แล้วเงียบ ไม่มี feedback loop

</div>
<div class="box">

## Phase 2: K3s + Woodpecker
- ✓ Self-hosted ลด cost และ dependency
- ✓ YAML-native pipeline เข้าใจง่าย
- ✓ Evidence ทุกขั้น ไม่ใช่แค่ deploy สำเร็จ
- ✓ Canary + rollback อยู่ใน flow ปกติ

</div>
</div>

> **แกนของ Phase 2:** เปลี่ยน "deploy ได้" ให้เป็น **"deploy ได้อย่างพิสูจน์ได้, observe ได้ และ rollback ได้"**

---

# เลือก Tool อะไร และทำไม?

| Tool | ที่ไม่เลือก | เหตุผลที่เลือก |
|---|---|---|
| **K3s** | full K8s, EKS | เบา, self-hosted, Traefik built-in, เหมาะ home lab |
| **Woodpecker** | Jenkins, GitHub Actions | YAML-native, Git-native, ง่าย debug, สอดกับ K3s |
| **Traefik** | nginx Ingress | default K3s, รองรับ `TraefikService` weighted route |
| **PostgreSQL 16** | SQLite, MySQL | StatefulSet สมบูรณ์, multi-replica, iSCSI storage |
| **Go 1.25** | Python, Node backend | compile-time safety, single binary, fast |
| **Next.js 15.5** | Vite/CRA | SSR + CSR, TypeScript-first, ecosystem ดี |
| **Cosign + Trivy** | manual scan | supply chain trust, shift-left security ใน pipeline |

---

# Runtime Architecture

```text
  User Browser
      │  HTTPS / todoapp-kps.akawatmor.com
      ▼
  [Nginx edge] ──► [Traefik K3s]
                        │               │
             path /     │               │  /api  /healthz  /readyz
                        ▼               ▼
               [todoapp-web]    [todoapp-core-weighted]
               Next.js 15.5 x2    ├─ stable  (100% / 90%)
                                  └─ canary  (  0% / 10%)
                                        │
                                [todoapp-postgres]
                              PostgreSQL 16 StatefulSet
```

routing ควบคุมด้วย `IngressRoute` + `TraefikService` — ไม่ใช่แค่ Deployment replicas split

---

# ทำไมถึงออกแบบ Architecture แบบนี้?

<div class="cols">
<div class="box">

## Weighted Backend Route
- `TraefikService` patch weight ได้แบบ zero-downtime
- stable 90 / canary 10 ระหว่าง analysis
- promote → 100/0, rollback → 100/0
- canary อยู่บน **route จริง** ไม่ใช่ feature flag

</div>
<div class="box">

## PostgreSQL StatefulSet
- `PersistentVolumeClaim` ต่อเนื่องแม้ restart
- ป้องกัน data loss ระหว่าง rolling update
- iSCSI-backed storage บน K3s
- probes 3 ชั้น: startup → readiness → liveness

</div>
</div>

> **หลักคิด:** routing logic และ data layer ต้องพิสูจน์ได้จาก YAML จริง ไม่ใช่แค่เชื่อจากคำพูด

---

# Cluster Topology: ทำไมต้องแยก Node?

```text
┌────────────────────────────────────────────────┐
│  K3s Server (Main)                              │
│  control plane · Traefik · Woodpecker server    │
│  PostgreSQL · Prometheus · Grafana · Alertmgr   │
└──────────────┬─────────────────────────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
┌──────────────┐  ┌──────────────────────────────┐
│  Worker-App  │  │  Worker-CI                   │
│ todoapp-web  │  │  Woodpecker agent             │
│ core-stable  │  │  pipeline pods               │
│ core-canary  │  │  (Trivy, ZAP, k6, cosign...) │
└──────────────┘  └──────────────────────────────┘
```

**เหตุผล:** pipeline งาน heavy จะไม่แย่ง CPU/memory กับ production traffic

---

# K8s Design: ทุก Decision มีเหตุผล

| Object | ที่เลือก | ทำไม |
|---|---|---|
| Routing | Ingress + IngressRoute + TraefikService | frontend ง่าย, backend รองรับ canary weight |
| Database | StatefulSet + iSCSI PVC | volume ต่อเนื่อง, pod name ไม่เปลี่ยน |
| Health | startup + readiness + liveness | startup รอ init, readiness ควบ traffic, liveness restart |
| Security | `runAsNonRoot`, `readOnlyRootFilesystem`, ResourceQuota | ลด privilege, จำกัด blast radius |
| Resilience | PodDisruptionBudget, NetworkPolicy | maintenance ไม่กระทบ service, จำกัด lateral move |
| Monitoring | ServiceMonitor, PodMonitor, PrometheusRule | metrics จริงสำหรับ canary analysis |

---

# Pipeline Design Philosophy

```text
PUSH ──► [ลดความเสี่ยง] ──► [สร้าง Artifact] ──► [ส่งมอบควบคุม] ──► [ยืนยันผล]
          Stage 0–2              Stage 3–5             Stage 6–8          Stage 9–10
```

<div class="cols">
<div class="box">

## Fail Fast, Fail Cheap
- ปัญหา secret/policy → Stage 0 (ก่อน build เลย)
- ปัญหา quality/type → Stage 1 (ก่อน push image)
- ปัญหา runtime → Stage 7 (canary buffer ก่อนรับ traffic เต็ม)

</div>
<div class="box">

## Fail Visibly
- ทุก failure มี log ชัดเจนระบุ stage
- canary fail → auto-rollback + email ทันที
- smoke fail → tag ไม่ถูกสร้าง
- ทีมรู้ก่อน user รู้

</div>
</div>

---

# Pipeline: Stage 0–5 (ก่อน Deploy)

| Stage | ชื่อกลุ่ม | เครื่องมือ | ผ่านเมื่อ |
|---|---|---|---|
| **0** | Pre-flight | Gitleaks, Hadolint, kube-score, OPA | ไม่มี secret รั่ว, YAML valid, policy pass |
| **1** | Quality *(parallel)* | gosec, govulncheck, `tsc --noEmit`, `jest --ci` | test pass, types clean, coverage OK |
| **2** | Integration | PostgreSQL container, Go API test | endpoint ตอบถูกต้อง |
| **3** | Build & Push | Docker buildx, commit SHA tag | image อยู่ใน registry |
| **4** | Sign & Scan | Cosign sign, CycloneDX SBOM, Trivy | signed, SBOM generated, no critical CVE |
| **5** | Data Safety | `pg_dump`, migration dry-run | backup ได้, schema upgrade ปลอดภัย |

> **ถ้า fail ที่ Stage ใดก็ตาม → หยุดทันที, production ไม่เปลี่ยน**

---

# Pipeline: Stage 6–10 (Deploy + Verify)

| Stage | ชื่อกลุ่ม | สิ่งที่เกิด | หลักฐาน |
|---|---|---|---|
| **6** | Canary Deploy | apply manifests, monitoring sync, weight 90/10 | TraefikService weight |
| **7** | Canary Analysis | ยิง 160 requests, อ่าน Prometheus | 5xx=0, p95≤1.5s |
| **8a** | Promote | weight 100/0, deploy web image ต่อ | full traffic on new version |
| **8b** | Auto-Rollback | weight 100/0 (กลับ stable), หยุด pipeline | email rollback |
| **9** | Smoke Test | curl `/healthz`, curl public root, git tag | URL 200 OK, tag exists |
| **9b** | Post-Deploy *(non-block)* | k6 load test, ZAP baseline DAST | analysis report |
| **10** | Notification | HTML email: success / rollback / failure | inbox ทีม |

---

# Canary: ทำไม 10% และ 160 Requests?

<div class="cols">
<div class="box">

## ทำไม 10%?
- จำกัด blast radius ถ้า canary มีปัญหา
- ผู้ใช้ส่วนใหญ่ยังใช้ stable path
- Prometheus มี signal เพียงพอ
- rollback ด้วย patch 1 command เท่านั้น

</div>
<div class="box">

## ทำไม 160 requests?
- p95 มีนัยสำคัญทางสถิติ
- ไม่หนักเกินสมเหตุสมผลสำหรับ pipeline
- pass threshold → promote ทันที
- fail → stop + rollback + email ทันที

</div>
</div>

```text
 PASS: 5xx=0 AND p95≤1.5s  →  promote 100/0  →  smoke test  →  tag
 FAIL: 5xx>0  OR p95>1.5s  →  rollback 100/0  →  email team  →  stop
```

---

# DevSecOps: Security ฝังอยู่ทุก Stage

```text
Stage 0     Stage 1      Stage 4      Stage 6-8    Runtime
   │            │            │             │           │
Gitleaks     gosec        Cosign        canary     NetworkPolicy
Hadolint   govulncheck    SBOM         analysis    PDB, non-root
kube-score    tsc          Trivy        rollback    readOnlyFS
OPA/policy    Jest                    smoke test   Prometheus
   │            │            │             │           │
[secret]    [code]       [image]      [delivery]  [runtime]
 hygiene    quality       trust         safety     hardening
```

> **ไม่มี stage ไหนที่ security เป็น "add-on"** — อยู่ใน flow ปกติทุกอัน

---

# DevSecOps: ครอบคลุมอะไรบ้าง?

| Layer | Tool / Practice | ป้องกันอะไร |
|---|---|---|
| Secret hygiene | Gitleaks, K8s Secret, `from_secret` | credential leak ใน git |
| Config quality | Hadolint, kube-score, OPA | Dockerfile / YAML misconfiguration |
| Code security | gosec, govulncheck | Go vulnerability ก่อน build |
| Supply chain | SHA tag, Cosign, SBOM, Trivy | image tampering, unknown CVE |
| Container runtime | non-root, read-only FS, ResourceQuota | container escape, resource abuse |
| Deployment safety | canary 10% + metric analysis + rollback | bad version reaching all users |
| Network isolation | NetworkPolicy | lateral movement ใน cluster |
| Observability | Prometheus, Grafana, Alertmanager | blind operation, slow incident response |

---

# Delivered Improvements: ก่อน vs หลัง

| มิติ | ก่อน | Phase 2 Final |
|---|---|---|
| **Quality gate** | backend test เท่านั้น | backend + frontend + integration test |
| **Image security** | ไม่มี scan | Cosign sign + SBOM + Trivy scan |
| **Deployment** | kubectl apply ตรง ๆ | canary 10% + metric + promote/rollback |
| **Database** | SQLite (local path) | PostgreSQL StatefulSet + pre-deploy backup |
| **Post-deploy verify** | รอ user แจ้ง | smoke test URL + k6 load + ZAP DAST |
| **Feedback** | ดู log เอง | HTML email: success / rollback / failure |
| **Runtime security** | minimal | non-root, read-only FS, NetworkPolicy, PDB |
| **Monitoring** | ไม่มี | Prometheus + Grafana + AlertmanagerConfig |

> **การปรับปรุงไม่ใช่จุดเดียว — เป็น chain ของ gates และ evidence ทั้งระบบ**

---

# Pipeline Success Path

```text
git push main
  ├─ Stage 0  ✓  no secret leak, valid YAML, policy pass
  ├─ Stage 1  ✓  all tests pass, types clean, coverage met
  ├─ Stage 2  ✓  API + DB integration correct
  ├─ Stage 3  ✓  images built & pushed w/ commit SHA tag
  ├─ Stage 4  ✓  signed, SBOM generated, no critical CVE
  ├─ Stage 5  ✓  backup done, migration safe
  ├─ Stage 6  ✓  canary 10% live, monitoring synced
  ├─ Stage 7  ✓  160 req → 0 errors, p95 < 1.5s
  ├─ Stage 8  ✓  promote 100%, full traffic on new version
  ├─ Stage 9  ✓  /healthz OK, root page OK, release tag created
  ├─ Stage 9b ✓  k6 load pass, ZAP baseline clean
  └─ Stage 10 ✓  team notified via HTML email ✅
```

> **"Success ที่ดีไม่ใช่แค่ pipeline เขียว — คือ pipeline เขียวที่พิสูจน์ได้ทุกขั้น"**

---

# Pipeline Failure: "Fail ที่ดี" คืออะไร?

<div class="cols">
<div class="box">

## Fail Early = Fail Cheap ✓
**Stage 0**: Gitleaks จับ secret ใน code
→ หยุดก่อน build เลย — ถูกที่สุด

**Stage 1**: TypeScript error / test fail
→ image ไม่ถูกสร้าง
→ production **ไม่เปลี่ยนเลย**

**Stage 4**: Trivy พบ critical CVE
→ image ไม่ถูก promote
→ supply chain safe

</div>
<div class="box">

## Fail with Evidence ✓
**Stage 7**: 5xx spike หรือ p95 สูง
→ weight กลับ 100/0 ทันที
→ email แจ้งทีมพร้อม log

**Stage 9**: smoke test ล้ม
→ tag ไม่ถูกสร้าง
→ ทีมรู้ก่อน user รู้

</div>
</div>

> **"pipeline แดงไม่ใช่ความล้มเหลว — pipeline แดงที่ไม่บอกเหตุผลต่างหากที่เป็นปัญหา"**

---

# Demo: Small Safe Changes

| Change | แตะไฟล์ | สิ่งที่เห็น | ปลอดภัยเพราะ |
|---|---|---|---|
| เพิ่ม version label / microcopy ใน UI | `frontend/src/...` | UI เปลี่ยนหลัง pipeline pass | แตะ UI layer เท่านั้น |
| ปรับ email subject / CTA link | `.woodpecker/main-push.yml` | email diff ชัดเจน | ไม่กระทบ runtime data path |
| ปรับ docs evidence / reasoning | `document/phase2/...` | reviewer เห็น reasoning ชัด | zero runtime risk |

`quality-frontend`, Trivy, SBOM, Cosign, canary 10% — **ทำเสร็จแล้วทั้งหมด เป็น baseline ไม่ใช่ new feature**

---

# สิ่งที่ควรปรับปรุงและเพิ่มเติม

| ประเด็น | สิ่งที่ควรเพิ่ม | เหตุผล |
|---|---|---|
| **Signature verification** | verify Cosign ก่อน promote | ปิดลูป supply chain trust ให้ครบ |
| **Secret lifecycle** | external secret manager, rotation | ลด blast radius ถ้า secret รั่ว |
| **Data recovery** | restore drill + retention policy | พิสูจน์ว่า backup ใช้งานได้จริง |
| **Observability** | Loki log aggregation, alert tuning | debug incident ได้เร็วขึ้น |
| **Test maturity** | E2E + synthetic CRUD path | ครอบคลุม user behavior มากขึ้น |
| **Resilience** | chaos drill, failover rehearsal | วัดความทนทาน ไม่ใช่แค่ assume ว่าดี |

**สิ่งเหล่านี้ไม่ใช่ "ทำไม่ได้" — คือ next iteration ที่ชัดเจนและต่อยอดได้ทันที**

---

# Key Takeaways

<div class="cols3">
<div class="box">

## 🏗️ Design
- K3s + Traefik + Woodpecker = self-hosted, reproducible
- PostgreSQL StatefulSet = production-grade data layer
- Weighted route = canary native baked-in

</div>
<div class="box">

## 🔒 Security
- Shift left: security ทุก stage
- secret → policy → supply chain → runtime
- ไม่มี stage ไหนที่ security เป็น optional

</div>
<div class="box">

## 📊 Evidence
- ทุก improvement มีหลักฐานชี้ได้
- fail fast, fail visibly
- rollback ชัดเจน อัตโนมัติ
- team ได้รับ notification ทันที

</div>
</div>

---

<!-- _class: tiny -->

# Pre-Q 1/5 — Infrastructure & Tool Selection

**Q1: ทำไมเลือก K3s แทน EKS หรือ full Kubernetes?**
K3s เป็น CNCF-certified lightweight K8s distribution รัน single binary <100 MB, built-in Traefik + CoreDNS + Flannel, ไม่มีค่า managed cluster, reproduce ได้บน VM ทั่วไป EKS ผูก vendor และมีค่า control plane $0.10/hr ขึ้นไป
*แหล่งที่มา: k3s.io, `src/phase2-final/k8s/`, Phase 2 Architecture Decision*

**Q2: Woodpecker CI ต่างจาก GitHub Actions หรือ Jenkins ยังไง?**
Woodpecker เป็น Git-native pipeline: YAML อยู่ใน repo, run บน K8s pod จริง, ไม่มี plugin marketplace ที่ซับซ้อน, secret inject จาก Woodpecker server ไม่ผ่าน env ตรง ต่างกับ Jenkins ที่ต้องดูแล Groovy และ plugin ecosystem
*แหล่งที่มา: woodpecker-ci.org docs, `.woodpecker/main-push.yml`*

**Q3: ทำไมต้องแยก Worker-CI ออกจาก Worker-App?**
Pipeline stage หนัก (Trivy full scan, ZAP DAST, k6 load) ใช้ CPU/memory burst สูง ถ้ารันบน node เดียวกับ production pod อาจทำให้ readiness probe fail หรือ latency spike กระทบ canary analysis metric
*แหล่งที่มา: K3s node labeling docs, `src/phase2-final/k8s/core-deployment.yaml` nodeSelector*

**Q4: Traefik IngressRoute ต่างจาก nginx Ingress ยังไง?**
Traefik รองรับ `TraefikService` CRD ซึ่ง patch weighted route ได้แบบ runtime โดยไม่ต้อง reload config และไม่ต้อง restart pod ขณะที่ nginx Ingress split traffic ผ่าน annotation และ Deployment replica count ซึ่งไม่ precise เท่า
*แหล่งที่มา: doc.traefik.io/traefik/routing/services/#weighted-round-robin, `src/phase2-final/k8s/traefik-weighted.yaml`*

---

<!-- _class: tiny -->

# Pre-Q 2/5 — Pipeline Design

**Q5: Pipeline มี 10+ stage มากไปไหม? ช้าไหม?**
Stage 0–1 รัน parallel (pre-flight + quality พร้อมกัน) Stage 9b (k6+ZAP) รัน non-blocking trade-off คือ build time นานขึ้นแต่ไม่ต้องตาม up production incident ที่แก้ยากกว่า pipeline ที่เร็วแต่ไม่มี gate
*แหล่งที่มา: `.woodpecker/main-push.yml` stage dependency graph*

**Q6: ทำไม Stage 1 (quality) ถึงรัน parallel backend กับ frontend ได้?**
Woodpecker รองรับ `depends_on` ระดับ step ทำให้ `quality-backend` และ `quality-frontend` รันพร้อมกันบน pod แยกได้ เงื่อนไขคือทั้งสองต้องไม่มี shared mutable state ซึ่งเป็นจริงเพราะแต่ละ step ใช้ working directory ของตัวเอง
*แหล่งที่มา: `.woodpecker/main-push.yml` step `quality-backend`, `quality-frontend`*

**Q7: ถ้า pre-flight Stage 0 ล้ม production เปลี่ยนไหม?**
ไม่เปลี่ยนเลย Woodpecker หยุด pipeline ทันทีเมื่อ step ใด fail และไม่ promote stage ถัดไป image ยังไม่ถูกสร้าง, manifest ยังไม่ถูก apply, canary ยังไม่ถูก activate ทุกอย่างอยู่ที่ commit เก่า
*แหล่งที่มา: Woodpecker CI pipeline execution model docs, `.woodpecker/main-push.yml`*

**Q8: ทำไม Stage 5 ต้อง `pg_dump` ก่อน deploy ไม่ใช่หลัง?**
ถ้า migration schema ใหม่ fail กลางคัน data อาจอยู่ใน inconsistent state การ backup ก่อน deploy ทำให้มี snapshot ที่ clean สำหรับ restore ถ้าจำเป็น การ backup หลัง deploy อาจได้ schema ที่ partially migrated แล้ว
*แหล่งที่มา: PostgreSQL migration best practices, `.woodpecker/main-push.yml` step `db-prep`*

---

<!-- _class: tiny -->

# Pre-Q 3/5 — Security & Supply Chain

**Q9: Cosign ป้องกันอะไรได้บ้าง?**
Cosign สร้าง cryptographic signature ผูกกับ image digest (SHA256) ทำให้พิสูจน์ได้ว่า image ที่ deploy ตรงกับที่ pipeline สร้างจริง ป้องกัน image tampering หลัง push และ supply chain attack ที่มีคนแทรก image ใน registry
*แหล่งที่มา: sigstore.dev/cosign, CNCF Supply Chain Security Whitepaper, `.woodpecker/main-push.yml` step `sign-and-scan`*

**Q10: SBOM คืออะไร ใครใช้ประโยชน์?**
Software Bill of Materials คือ inventory ของ package, library และ dependency ทั้งหมดใน image ใน format CycloneDX/SPDX ทีมรักษาความปลอดภัยใช้ audit dependency, compliance team ใช้ license check และใช้ตรวจสอบ CVE ใหม่ที่เกิดขึ้นหลัง deploy
*แหล่งที่มา: CISA SBOM Guidelines, cyclonedx.org, `.woodpecker/main-push.yml` step `sign-and-scan`*

**Q11: Trivy scan อะไรบ้าง นอกจาก OS vulnerability?**
Trivy scan: OS packages, language dependencies (Go modules, npm), config file misconfig, Dockerfile misconfig, secret ใน layer, license compliance และ SBOM export ใน pipeline นี้ใช้ `--exit-code 1 --severity CRITICAL` หยุด pipeline ถ้าเจอ critical CVE
*แหล่งที่มา: aquasecurity.github.io/trivy, `.woodpecker/main-push.yml` step `sign-and-scan`*

**Q12: Gitleaks ทำงานยังไง จับอะไรบ้าง?**
Gitleaks scan git history และ staged file ด้วย regex pattern สำหรับ entropy-based secret detection: API key, private key, JWT, connection string, password pattern รองรับ custom rule ใน `.gitleaks.toml` ถ้าพบใน commit ใดก็ตาม pipeline หยุดทันที
*แหล่งที่มา: github.com/gitleaks/gitleaks, `.woodpecker/main-push.yml` step `secret-scan`*

---

<!-- _class: tiny -->

# Pre-Q 4/5 — Canary & Deployment Strategy

**Q13: Canary 10% เลือกตัวเลขนี้เพราะอะไร ไม่ใช่ 5% หรือ 20%?**
5% ให้ signal น้อยเกินไปสำหรับ statistical significance ใน 160 requests (เพียง 8 req ไปที่ canary) 20% เสี่ยงกับ user จริงมากเกินไปในกรณีที่ canary มีปัญหา 10% เป็น industry standard ที่ให้ signal เพียงพอและ blast radius ที่รับได้
*แหล่งที่มา: Google SRE Book ch.22, Netflix Canary Analysis docs, `src/phase2-final/k8s/traefik-weighted.yaml`*

**Q14: 160 requests เพียงพอทางสถิติสำหรับ p95 measurement ไหม?**
p95 ต้องการ minimum ~20 sample ใน tail (5% ของ 160 = 8 sample) สำหรับ latency estimation เบื้องต้น ใน production จริงควรใช้ 1,000+ request แต่สำหรับ CI pipeline environment และ stage duration constraint 160 req คือ balance ระหว่าง confidence กับ pipeline time
*แหล่งที่มา: Brendan Gregg "Systems Performance" p95 percentile methodology, `.woodpecker/main-push.yml` step `canary-analyze`*

**Q15: ถ้า canary fail user ที่โดน 10% traffic จะเป็นยังไง?**
user กลุ่ม 10% อาจเจอ error หรือ slow response ระหว่าง analysis window (~2-3 นาที) หลังจากนั้น weight patch กลับ 100/0 ทันทีโดย step `auto-rollback` อีก request ถัดมาทั้งหมดไปที่ stable เท่านั้น ไม่มี data loss เพราะ read/write ยังผ่าน PostgreSQL เดิม
*แหล่งที่มา: `.woodpecker/main-push.yml` step `auto-rollback`, `src/phase2-final/k8s/traefik-weighted.yaml`*

**Q16: PostgreSQL StatefulSet ต่างจาก Deployment ยังไง?**
StatefulSet ให้ pod identity คงที่ (`todoapp-postgres-0`) และ `VolumeClaimTemplate` สร้าง PVC เฉพาะของ pod นั้น ถ้า pod restart volume เดิมกลับมา Deployment จะ reschedule pod ใหม่โดยไม่ guarantee volume เดิม ทำให้ data หาย
*แหล่งที่มา: K8s docs StatefulSets, `src/phase2-final/k8s/postgres-statefulset.yaml`*

---

<!-- _class: tiny -->

# Pre-Q 5/5 — Observability, Operations & DevSecOps

**Q17: Prometheus metric อะไรที่ใช้วัด canary analysis จริง?**
pipeline ใช้ Prometheus query: `rate(http_requests_total{status=~"5.."}[2m])` สำหรับ error rate และ `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[2m]))` สำหรับ p95 latency เทียบกับ threshold `5xx=0` และ `p95≤1.5s`
*แหล่งที่มา: `.woodpecker/main-push.yml` step `canary-analyze`, `src/phase2-final/k8s/traefik-weighted.yaml` ServiceMonitor*

**Q18: PodDisruptionBudget ทำงานยังไง ป้องกันอะไร?**
PDB กำหนด `minAvailable` หรือ `maxUnavailable` ให้ K8s scheduler รับรองว่าระหว่าง voluntary disruption (node drain, rolling update) จะมี pod พร้อมรับ traffic ตาม threshold เสมอ ป้องกันสถานการณ์ที่ node maintenance ทำให้ replicas ทั้งหมด down พร้อมกัน
*แหล่งที่มา: K8s docs PodDisruptionBudget, `src/phase2-final/k8s/pdb.yaml`*

**Q19: NetworkPolicy ใน K3s ใช้ CNI อะไร รองรับ policy ได้ไหม?**
K3s ใช้ Flannel เป็น default CNI ซึ่ง **ไม่รองรับ** NetworkPolicy โดยตรง ต้องเพิ่ม CNI plugin ที่รองรับ เช่น Calico หรือ Cilium ถ้า NetworkPolicy ต้องการ enforce จริง ใน project นี้ NetworkPolicy manifest เขียนไว้เป็น declarative intent และ documentation
*แหล่งที่มา: K3s networking docs, `src/phase2-final/k8s/networkpolicy.yaml`, Flannel limitation docs*

**Q20: ถ้าต้องทำต่อ Next Iteration อะไรสำคัญที่สุด?**
อันดับ 1 คือ **Cosign verification ก่อน promote** เพราะปัจจุบัน sign แต่ไม่มี verify step ทำให้ supply chain trust loop ยังไม่ปิด อันดับ 2 คือ **restore drill สำหรับ PostgreSQL backup** เพราะ backup ที่ไม่เคย test restore ไม่นับว่าเป็น backup จริง
*แหล่งที่มา: sigstore.dev verify docs, `document/phase2/report.md` section Next Improvements*

---

<!-- _backgroundColor: #0f766e -->
<!-- _color: white -->

# Q&A — Live Discussion

**Phase 2 Final Baseline:**

```
TodoApp Big Calendar
K3s · Traefik · PostgreSQL 16 · Prometheus/Grafana
.woodpecker/main-push.yml  (Stage 0–10 + 9b)
Canary 10% · Cosign · SBOM · Trivy · HTML Email
```

> เราไม่ได้สร้างแค่ Todo application
> เราสร้าง **ระบบส่งมอบที่พิสูจน์ได้**

กลุ่ม KPS-Enterprise Team · 2026
