# 📝 Small Changes Log — KPS-Enterprise Phase 2

> **เอกสารนี้:** บันทึก small changes (การแก้ไขเล็ก ๆ น้อย ๆ) ที่เกิดขึ้นหลัง pipeline หลักถูกสร้างขึ้นมาแล้ว  
> แต่ละ change มีบริบท สาเหตุ วิธีแก้ และบทเรียนที่ได้รับ

> **วิธีใช้ในวันเดโม:** ถ้าต้องการยกตัวอย่างว่า Phase 2 Final ไม่ได้มีแค่ big-picture improvement แต่ยังมีงานเก็บรายละเอียดที่ทำให้ระบบนิ่งขึ้น ให้เลือกหยิบจากไฟล์นี้ 2-3 ข้อที่มีหลักฐานชัดและผูกกับ runtime/pipeline จริง

## จุดที่แนะนำให้หยิบไปเล่า

| Change | ทำไมควรเล่า | สิ่งที่ควรโชว์ |
|---|---|---|
| Canary pod label fix | อธิบายว่า canary + NetworkPolicy ต้องไปด้วยกัน | `traefik-weighted.yaml` และผล 0/40 error |
| PHP `%%` escape ใน email | อธิบายว่า notification path ก็มีรายละเอียดที่ต้อง harden | email evidence / template snippet |
| k6 load test | ช่วยแสดงว่า post-deploy analysis ไม่ได้มีแค่ smoke test | `k6-load-test` result |
| AlertmanagerConfig | เชื่อมกับ observability และ notification story | monitoring manifests |
| DAST ZAP baseline | ช่วยเสริม DevOpsSec ว่ามี runtime scan หลัง deploy | `dast-zap` step |

---

## สารบัญ

1. [Fix: Canary Pod ขาด label ทำให้ 502](#1-fix-canary-pod-ขาด-label-ทำให้-502)
2. [Fix: PHP sprintf error จาก % ใน CSS](#2-fix-php-sprintf-error-จาก--ใน-css)
3. [Fix: CI_BUILD_LINK ว่างเปล่า ปุ่ม Open Pipeline ใช้งานไม่ได้](#3-fix-ci_build_link-ว่างเปล่า-ปุ่ม-open-pipeline-ใช้งานไม่ได้)
4. [Fix: release-plan.sh ไม่สร้าง tag จาก PR merge commit](#4-fix-release-plansh-ไม่สร้าง-tag-จาก-pr-merge-commit)
5. [Fix: skopeo image ไม่มีใน registry](#5-fix-skopeo-image-ไม่มีใน-registry)
6. [Add: k6 Load Test step](#6-add-k6-load-test-step)
7. [Add: Feature Flags ผ่าน ConfigMap](#7-add-feature-flags-ผ่าน-configmap)
8. [Add: AlertmanagerConfig สำหรับ email alert](#8-add-alertmanagerconfig-สำหรับ-email-alert)
9. [Add: DAST ZAP Baseline Scan](#9-add-dast-zap-baseline-scan)

---

## 1. Fix: Canary Pod ขาด label ทำให้ 502

### บริบท
canary deploy ทำงานได้ pod ขึ้น Running แต่ทุก request ที่ผ่าน weighted route กลับ 502

### สาเหตุ
`NetworkPolicy` ชื่อ `todoapp-allow-from-ingress` กำหนดว่า Traefik (kube-system) จะเข้าถึงได้เฉพาะ pod ที่มี label `app.kubernetes.io/part-of: todoapp` เท่านั้น

Pod template ของ `todoapp-core-**stable**` มี label นี้ครบ แต่ `todoapp-core-**canary**` ขาด label นี้ไป

### วิธีแก้
เพิ่ม `app.kubernetes.io/part-of: todoapp` ใน pod template labels ของ canary deployment ใน `src/phase2-final/k8s/traefik-weighted.yaml`

### ผลลัพธ์
ตรวจสอบบน K3s จริง: 0/40 error ที่ weight 90/10 ✅

### บทเรียน
> NetworkPolicy ตรวจจาก **pod template labels** ไม่ใช่ deployment labels  
> การมี NetworkPolicy ที่เข้มงวดช่วยความปลอดภัย แต่ต้องระวังว่า resource ใหม่ทุกตัวต้องมี label ครบตามที่ policy กำหนด  
> **ตรวจสอบ NetworkPolicy ทุกครั้งที่เพิ่ม pod ใหม่เข้า namespace**

---

## 2. Fix: PHP sprintf error จาก % ใน CSS

### บริบท
email-success/rollback/failure step crash ด้วย error:
```
ValueError: Unknown format specifier ";"
```

### สาเหตุ
email plugin ใช้ `deblan/woodpecker-email:latest` ที่รัน PHP `sprintf()` เพื่อ interpolate ค่าลงใน HTML body  
CSS ที่เขียน `width:100%` ทำให้ PHP ตีความ `%;` ว่าเป็น format specifier ที่ไม่ถูกต้อง

### วิธีแก้
escape `%` ทั้งหมดใน CSS เป็น `%%` เช่น `width:100%` → `width:100%%`  
ต้องทำทุก template (email-success, email-rollback, email-failure)

### ผลลัพธ์
Email ส่งสำเร็จพร้อม HTML table และปุ่ม ✅

### บทเรียน
> PHP `sprintf()` ใช้ `%` เป็น prefix ของ format specifier → ถ้าต้องการ `%` literal ต้องเขียน `%%`  
> **ระวังเป็นพิเศษเมื่อใช้ heredoc/nowdoc HTML ที่มี CSS อยู่ภายใน sprintf call**  
> ห้ามเปลี่ยน email image จาก `deblan/woodpecker-email:latest` เพราะเป็น image เดียวที่ทำงานได้กับ Woodpecker บน cluster นี้

---

## 3. Fix: CI_BUILD_LINK ว่างเปล่า ปุ่ม Open Pipeline ใช้งานไม่ได้

### บริบท
ปุ่ม "Open Pipeline" ใน email คลิกแล้วไม่ได้ไปไหน หรือ link เสีย

### สาเหตุ
Woodpecker บางเวอร์ชันหรือบาง event ไม่ inject `CI_BUILD_LINK` environment variable (ค่าเป็น empty string)  
PHP `sprintf()` เอาค่าว่างใส่ใน `href=""` ทำให้ปุ่มไม่ทำงาน

### วิธีแก้
ใช้ PHP ternary fallback:
```php
getenv('CI_BUILD_LINK') ?: 'https://woodpecker-kps.akawatmor.com'
```
ทำซ้ำทั้ง 3 email template

### ผลลัพธ์
ปุ่มชี้ไป Woodpecker homepage เสมอแม้ไม่มี build link ✅

### บทเรียน
> **อย่า assume ว่า CI environment variables จะมีค่าเสมอ** โดยเฉพาะ variables ที่ขึ้นกับ event type  
> ป้องกันด้วย fallback value สำหรับ URL ทุกตัวที่ใช้ใน notification

---

## 4. Fix: release-plan.sh ไม่สร้าง tag จาก PR merge commit

### บริบท
merge PR จาก develop → main แล้ว pipeline ทำงานปกติ แต่ไม่มี release tag ถูกสร้าง

### สาเหตุ
GitHub merge commit message มีรูปแบบ `"Merge pull request #N from owner/branch"` ซึ่งไม่ match กับ conventional commit patterns (`feat:`, `fix:`, `chore:`)  
`release-plan.sh` ตรวจเฉพาะ commit subject (บรรทัดแรก) ทำให้ classify ว่า "skip"

### วิธีแก้
เพิ่ม 2 fallback mechanisms:

1. **Body scan:** อ่าน commit body (บรรทัดถัดไป) หาก subject เป็น merge commit ตรวจ body หา `feat:` / `fix:` patterns แทน
2. **Branch name fallback:** parse branch name จาก merge commit message เช่น `feat/*` → minor bump, `fix|hotfix|bugfix|patch/*` → patch bump

### ผลลัพธ์
PR merge commit จาก `feat/some-feature` branch สร้าง minor version tag ได้ถูกต้อง ✅

### บทเรียน
> GitHub pull request merge commits ไม่ใช่ conventional commits โดย default  
> **อย่า rely เฉพาะ commit subject สำหรับ versioning** — ต้องมี fallback ที่ตรวจ body และ branch name ด้วย  
> ทางออกที่ดีกว่าในระยะยาวคือ squash merge + enforce conventional commit ใน PR title

---

## 5. Fix: skopeo image ไม่มีใน registry

### บริบท
`tag-release.yml` pipeline fail ด้วย error:
```
Error response from daemon: No such image: quay.io/skopeo/stable:latest
```

### สาเหตุ
`quay.io/skopeo/stable:latest` ไม่ accessible จาก K3s node ในเครือข่ายนี้ (registry timeout หรือ pull error)

### วิธีแก้
เปลี่ยน `&skopeo_image` จาก `quay.io/skopeo/stable:latest` เป็น `alpine:3.20`  
เพิ่ม `apk add --no-cache skopeo` เป็นบรรทัดแรกของ commands

ตรวจสอบก่อน apply:
```bash
docker run --rm alpine:3.20 sh -c "apk add --no-cache skopeo && skopeo --version"
# skopeo version 1.16.1 ✅
```

### ผลลัพธ์
`tag-release.yml` ใช้ alpine:3.20 + apk install skopeo แทน ทำงานได้ ✅

### บทเรียน
> **อย่าใช้ specialized image โดยไม่ตรวจว่า registry accessible จาก pipeline node**  
> `alpine + apk install` เป็น fallback ที่ reliable กว่าสำหรับ tool ที่ไม่ใช่ core pipeline image  
> ทดสอบ `docker pull <image>` บน node ก่อนใส่ใน pipeline

---

## 6. Add: k6 Load Test step

### บริบท
ต้องการตรวจสอบว่า production หลัง promote สามารถรับ traffic จริงได้โดยไม่ timeout หรือ error สูง

### สิ่งที่ทำ
- สร้าง `src/phase2-final/scripts/k6/load-test.js` — 3 stages: ramp 10VU/15s → 20VU/30s → down/15s
- test endpoints: `/healthz`, `/readyz`, `/api/v1/meta` (random)
- thresholds: `http_req_failed < 5%`, `p95 < 2000ms`, custom `errors < 5%`
- เพิ่ม `k6-load-test` step ใน Stage 9b, depends on `smoke-test`, `failure: ignore`

### ผลการทดสอบ
```
✓ status 200        1246 requests, 100% checks
✓ duration < 2000ms p95 = 44ms
http_req_failed:    0.00%
```

### การวิเคราะห์
| ด้าน | ผล |
|------|-----|
| **Baseline performance** | p95 = 44ms — เร็วมากสำหรับ Go backend บน single-node K3s |
| **Capacity** | 20 VUs concurrent ไม่ทำให้ latency พุ่ง แสดงว่า backend healthy |
| **Evidence** | มี numeric metric ยืนยัน production stability หลัง canary promote |
| **ข้อจำกัด** | test เฉพาะ read-only endpoints; write paths (POST /api/v1/tasks) ยังไม่ test |

### บทเรียน
> `failure: ignore` ทำให้ k6 threshold fail ไม่หยุด pipeline (เหมาะสำหรับ "warn but don't block")  
> ถ้าต้องการ gate ที่เข้มข้นกว่านี้ ให้เอา `failure: ignore` ออก และปรับ threshold ให้เหมาะสม

---

## 7. Add: Feature Flags ผ่าน ConfigMap

### บริบท
ต้องการ toggle feature ใหม่โดยไม่ต้อง rebuild/redeploy image

### สิ่งที่ทำ
เพิ่ม 3 feature flag ใน `src/phase2-final/k8s/configmap.yaml`:
```yaml
FEATURE_DARK_MODE: "false"
FEATURE_CALDAV_SYNC: "true"
FEATURE_MULTI_ASSIGN: "false"
```

### วิธีใช้งาน
```bash
# Toggle feature (no rebuild needed)
kubectl edit cm todoapp-config -n todoapp
# แก้ FEATURE_DARK_MODE: "false" → "true"

# Rolling restart ให้ pod รับค่าใหม่
kubectl rollout restart deployment -n todoapp
```

### การวิเคราะห์
| ด้าน | ผล |
|------|-----|
| **Deployment flexibility** | เปลี่ยน feature state ใน seconds แทนที่จะ rebuild |
| **Environment parity** | ค่าเดียวกันทุก pod เพราะมาจาก ConfigMap เดียวกัน |
| **ข้อจำกัด** | ยัง hot-reload ไม่ได้ — ต้อง rollout restart; backend ต้องอ่าน env var จริงถึงจะมีผล |
| **ความเสี่ยง** | toggle ConfigMap โดยไม่มี pipeline gate → อาจเปิด feature ที่ยังไม่พร้อม |

### บทเรียน
> ConfigMap-based feature flags เหมาะสำหรับ "operational toggle" ไม่ใช่ "A/B testing"  
> ถ้าต้องการ dynamic flag โดยไม่ restart ให้ใช้ feature flag service เช่น Unleash, Flagd หรือ LaunchDarkly

---

## 8. Add: AlertmanagerConfig สำหรับ email alert

### บริบท
ต้องการ alert อัตโนมัติเมื่อ metric ผิดปกติ เช่น error rate สูง, latency พุ่ง, pod crash

### สิ่งที่ทำ
1. สร้าง `src/phase2-final/monitoring/alertmanager-config.yaml` — AlertmanagerConfig CR (monitoring.coreos.com/v1alpha1)
   - receiver `email-kps` ส่ง HTML email
   - SMTP credentials จาก K8s Secret `kps-alertmanager-smtp`
   - placeholders ใน YAML แทนด้วย `sed` ใน pipeline
2. อัปเดต `src/phase2-final/monitoring/kube-prometheus-stack.yaml`:
   ```yaml
   alertmanagerConfigMatcherStrategy:
     type: None          # ← จำเป็น: ให้ AlertmanagerConfig ทำงาน cross-namespace
   alertmanagerConfigNamespaceSelector: {}
   alertmanagerConfigSelector: {}
   ```
3. เพิ่มใน `monitoring-sync` step: สร้าง SMTP secret + apply AlertmanagerConfig

### การวิเคราะห์
| ด้าน | ผล |
|------|-----|
| **Alert coverage** | รับ alert จาก PrometheusRule ที่กำหนดไว้ใน todoapp-prometheusrule.yaml |
| **Secret management** | SMTP password อยู่ใน K8s Secret ไม่ hardcode ใน YAML |
| **Pipeline integration** | AlertmanagerConfig apply อัตโนมัติทุก main push |
| **ข้อจำกัด** | ต้อง verify ว่า Alertmanager UI รับ config แล้วบน live cluster |

### บทเรียน
> `alertmanagerConfigMatcherStrategy: type: None` เป็น **required** สำหรับ AlertmanagerConfig ที่อยู่ต่าง namespace กับ Alertmanager  
> หากไม่ตั้งค่านี้ Alertmanager จะ ignore config โดยไม่มี error ชัดเจน — debug ยากมาก  
> ใช้ `sed` substitution ใน pipeline แทนการ hardcode email/SMTP ใน YAML เพื่อให้ repository ปลอดภัย

---

## 9. Add: DAST ZAP Baseline Scan

### บริบท
ต้องการตรวจหา vulnerability เชิง runtime ของ web application หลัง deploy จริง (DAST = Dynamic Application Security Testing)

### สิ่งที่ทำ
เพิ่ม `dast-zap` step ใน Stage 9b:
```yaml
- name: dast-zap
  image: ghcr.io/zaproxy/zaproxy:stable
  depends_on: [smoke-test]
  when: { status: [success] }
  failure: ignore
  commands:
    - zap-baseline.py -t https://todoapp-kps.akawatmor.com -l WARN -I 2>&1 | tee /tmp/zap-report.txt || true
    - echo "✅ ZAP baseline scan complete"
```

### การวิเคราะห์
| ด้าน | ผล |
|------|-----|
| **Coverage** | Passive scan: ตรวจ HTTP headers, cookies, information leakage, missing security headers |
| **Non-blocking** | `failure: ignore` → ZAP fail ไม่หยุด pipeline (เหมาะกับ baseline) |
| **Integration** | รัน post-deploy บน production URL จริง — เหมือน external attacker |
| **ข้อจำกัด** | Baseline scan เป็นแค่ passive; active scan (เจาะจริง) ต้องทำใน staging environment แยก |
| **Report** | log ไว้ใน `/tmp/zap-report.txt` ภายใน container (หายหลัง step จบ) — ถ้าต้องการ persist ต้อง upload artifact |

### บทเรียน
> DAST ต้องรันบน **environment ที่รู้ว่าเป็น target** ไม่ใช่ production จริงที่มี user — baseline scan ปลอดภัยพอ แต่ active scan ไม่ควรรันบน production  
> `-l WARN` = รายงานเฉพาะ WARNING ขึ้นไป, `-I` = ignore rules ที่ไม่ relate (prevent false positive block)  
> ถ้าต้องการ gate: เอา `failure: ignore` ออก และ parse `/tmp/zap-report.txt` หา HIGH alerts แทน

---

## สรุปการวิเคราะห์ภาพรวม

| Change | ประเภท | ผลกระทบ | Risk |
|--------|--------|---------|------|
| Canary label fix | Bug fix | High — แก้ 502 production | ต่ำ (แก้ YAML label) |
| PHP `%%` escape | Bug fix | High — email ส่งได้ | ต่ำ (แก้ string) |
| CI_BUILD_LINK fallback | Bug fix | Medium — UX email ดีขึ้น | ต่ำ |
| release-plan.sh PR fix | Bug fix | Medium — versioning ถูกต้อง | ต่ำ |
| skopeo → alpine+apk | Bug fix | High — tag-release.yml ทำงานได้ | ต่ำ |
| k6 load test | Feature | Medium — performance evidence | ต่ำ (`failure: ignore`) |
| Feature flags | Feature | Low–Medium — operational flexibility | ต่ำ–ปานกลาง (ต้องควบคุม toggle) |
| AlertmanagerConfig | Feature | High — proactive monitoring | ปานกลาง (ต้อง verify SMTP) |
| DAST ZAP | Feature | Medium — security coverage | ต่ำ (passive only + `failure: ignore`) |

### Pattern ที่สังเกตได้
1. **Label consistency** เป็นจุดอ่อนซ่อนเร้นของ NetworkPolicy — ทุก resource ใหม่ต้องตรวจ label ให้ครบ
2. **Environment variable assumptions** ทำให้ feature ที่ดูใช้ได้พังเงียบ ๆ ควรมี fallback เสมอ
3. **PHP template rendering** ต้องระวัง format specifier conflicts เมื่อใช้ `sprintf()` กับ CSS/HTML
4. **Registry availability** ควรทดสอบ `docker pull` ก่อนใส่ image ใน pipeline โดยเฉพาะ external registry
5. **`failure: ignore`** เป็น pattern ที่ถูกต้องสำหรับ "warn but don't block" tools (k6, ZAP) ที่ไม่ควรหยุด deployment
