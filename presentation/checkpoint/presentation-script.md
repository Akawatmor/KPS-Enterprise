# 📝 Presentation Script
## KPS-Enterprise Checkpoint (6 Slides, ~10 นาที)

---

## Timing Overview

| Slide | Duration | Content |
|-------|----------|---------|
| หน้าปก | 0:30 | แนะนำกลุ่ม |
| Slide 1 | 2:00 | Application Overview |
| Slide 2 | 2:00 | Design & Tools |
| Slide 3 | 2:00 | CI/CD Pipeline |
| Slide 4 | 2:00 | Progress & Evaluation |
| Slide 5 | 1:30 | Demo & Summary |
| **Total** | **10:00** | |

---

## หน้าปก (0:30)

> สวัสดีครับ/ค่ะ วันนี้กลุ่ม **KPS-Enterprise Team** จะมานำเสนอ Checkpoint Phase 1 Week 2 ครับ/ค่ะ
>
> สมาชิก: นายรัฐธรรมนูญ โกศาสังข์ และ นายเอกวัส มรสาเทียน
> ระบบของเราชื่อ **Three-Tier DevSecOps on Kubernetes** ครับ/ค่ะ

---

## Slide 1: Application Overview (2:00)

> แอปพลิเคชันที่เลือกคือ **Three-Tier To-Do List** ระบบจัดการงาน
>
> มี 3 layers: React Frontend, Node.js Backend, MongoDB Database
>
> **สิ่งที่ทำได้:** CRUD tasks, mark completed, health check endpoints
>
> **ข้อจำกัด Learner Lab:**
> - สร้าง IAM ไม่ได้ → ใช้ LabInstanceProfile
> - ECR read-only → ใช้ Docker Hub แทน
> - Instance สูงสุด t2.large
>
> Phase 2 จะเพิ่ม Authentication และ Features อื่นๆ ครับ/ค่ะ

---

## Slide 2: Design & Tools (2:00)

> **Technology Stack:**
> - Application: React, Node.js, MongoDB
> - Infrastructure: Docker, Kubernetes (EKS), Terraform
> - Registry: Docker Hub (เพราะ ECR read-only)
>
> **DevSecOps Security (Shift-Left):**
> - SonarQube - ตรวจ code quality
> - OWASP - ตรวจ dependencies vulnerabilities
> - Trivy - scan container images
>
> **Bug ที่เจอใน Original Code:**
> 1. db.js: Boolean parsing ผิด - "false" เป็น truthy
> 2. package.json: semver format ผิด
>
> แก้ไขทั้ง 2 bugs แล้วครับ/ค่ะ

---

## Slide 3: CI/CD Pipeline (2:00)

> Pipeline มี **10 stages** ครับ/ค่ะ:
>
> 1-2: Checkout และ Install dependencies
> 3-4: SonarQube Analysis และ Quality Gate
> 5-6: OWASP Dep-Check และ Trivy FS Scan
> 7-8: Docker Build และ Trivy Image Scan
> 9-10: Push Docker Hub และ Update K8s Manifests
>
> **Key Features:**
> - **Fail-Fast:** ถ้า security scan ไม่ผ่าน pipeline หยุดทันที
> - **GitOps:** Update image tag ใน Git
> - **3-Layer Security:** SAST + SCA + Container Scan
>
> เราปรับ pipeline จาก ECR เป็น Docker Hub เพราะ Learner Lab จำกัดครับ/ค่ะ

---

## Slide 4: Progress & Evaluation (2:00)

> **สิ่งที่ทำเสร็จแล้ว:**
> - วิเคราะห์ source code ทั้งหมด
> - แก้ 2 bugs, ปรับ 15+ files สำหรับ Learner Lab
> - ออกแบบ pipeline 10 stages
> - **ทดสอบ local ผ่านแล้ว**
>
> **การประเมินว่าถูกต้อง:**
> - Health endpoints ตอบ 200 OK ✅
> - CRUD operations ทำงานครบ ✅
> - DB disconnect → ระบบ self-heal ได้ ✅
>
> **Next Plan:**
> - Week 2: AWS Infrastructure
> - Week 3: Full pipeline test
> - Final: Complete demo with Phase 2 features

---

## Slide 5: Demo & Summary (1:30)

> **[Demo - ถ้ามีเวลา]**
> ```bash
> curl localhost:3500/healthz  # → "Healthy"
> curl localhost:3500/api/tasks
> ```
>
> **สรุป:**
> ✅ วิเคราะห์และ document ครบ
> ✅ แก้ bugs และปรับ 15+ files
> ✅ ออกแบบ DevSecOps pipeline
> ✅ ทดสอบ local ผ่าน
>
> **พร้อม deploy บน AWS!**
>
> ขอบคุณครับ/ค่ะ รับคำถามได้เลย
>
> **GitHub:** github.com/Akawatmor/KPS-Enterprise

---

## 💡 Tips

- ถ้า demo fail → อธิบายจาก documentation แทน
- เน้นสิ่งที่ทำเสร็จ ไม่ใช่สิ่งที่ยังไม่ได้ทำ
- Highlight: DevSecOps 10 stages, Shift-Left Security, Fail-Fast

*Script Version: 3.0 | 6 Slides | ~10 minutes*
