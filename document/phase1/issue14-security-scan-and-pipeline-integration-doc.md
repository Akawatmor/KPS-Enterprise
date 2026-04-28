# Security Scanning Tools & Pipeline Integration Documentation

## Issue #14 — Analyze Security Scanning Tools and Their Pipeline Integration

---

## สารบัญ (Table of Contents)

1. [ภาพรวม Security Pipeline (Overview)](#1-ภาพรวม-security-pipeline)
2. [Tool Installation & Versions](#2-tool-installation--versions)
3. [Backend vs Frontend Pipeline Comparison](#3-backend-vs-frontend-pipeline-comparison)
4. [SonarQube — SAST (Static Application Security Testing)](#4-sonarqube--sast)
5. [OWASP Dependency-Check — SCA (Software Composition Analysis)](#5-owasp-dependency-check--sca)
6. [Trivy FS — Filesystem Vulnerability Scan](#6-trivy-fs--filesystem-vulnerability-scan)
7. [Trivy Image — Container Image Vulnerability Scan](#7-trivy-image--container-image-vulnerability-scan)
8. [Quality Gate Mechanism & Failure Behavior](#8-quality-gate-mechanism--failure-behavior)
9. [Security Scan Coverage Matrix](#9-security-scan-coverage-matrix)
10. [Pipeline Configuration & Credentials](#10-pipeline-configuration--credentials)
11. [ข้อสังเกตและข้อเสนอแนะ (Notes & Recommendations)](#11-ข้อสังเกตและข้อเสนอแนะ)

---

## 1. ภาพรวม Security Pipeline

### Security Tools ใน CI/CD Pipeline

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        Jenkins Pipeline Stages                           │
│                                                                          │
│  ┌───────────┐  ┌───────────┐  ┌─────────┐  ┌────────┐  ┌───────────┐  │
│  │1.Clean    │─▶│2.Checkout │─▶│3.Sonar  │─▶│4.QGate │─▶│5.OWASP DC │  │
│  │ Workspace │  │  Git      │  │ Analysis│  │ Check  │  │   Scan    │  │
│  │           │  │           │  │ (SAST)  │  │        │  │   (SCA)   │  │
│  └───────────┘  └───────────┘  └─────────┘  └────────┘  └─────┬─────┘  │
│                                                                │        │
│  ┌───────────┐  ┌───────────┐  ┌─────────┐  ┌────────┐  ┌─────┴─────┐  │
│  │11.Update  │◀─│10.Checkout│◀─│9.Trivy  │◀─│8.ECR   │◀─│6.Trivy FS │  │
│  │ K8s YAML  │  │  Code     │  │ Image   │  │ Push   │  │   Scan    │  │
│  │           │  │           │  │ Scan    │  │        │  │           │  │
│  └───────────┘  └───────────┘  └─────────┘  └────────┘  └───────────┘  │
│                                     ▲                         │         │
│                                     │        ┌────────┐       │         │
│                                     └────────│7.Docker │◀──────┘         │
│                                              │ Build   │                │
│                                              └────────┘                 │
│  Security Scan Points:                                                  │
│  ① SAST (SonarQube)        — Source code quality & vulnerabilities      │
│  ② Quality Gate            — Pass/Fail threshold check                  │
│  ③ SCA (OWASP DC)          — Dependency vulnerabilities                │
│  ④ Trivy FS                — Filesystem/config vulnerabilities         │
│  ⑤ Trivy Image             — Container image vulnerabilities           │
└──────────────────────────────────────────────────────────────────────────┘
```

### Security Scanning Timeline

```
  Source Code Phase          Build Phase              Post-Build Phase
─────────────────────────────────────────────────────────────────────▶ Time
  │                           │                         │
  ▼                           ▼                         ▼
┌─────────┐ ┌──────────┐ ┌────────┐ ┌─────────┐ ┌────────────┐
│SonarQube│ │Quality   │ │OWASP DC│ │Trivy FS │ │Trivy Image │
│ (SAST)  │ │Gate      │ │(SCA)   │ │         │ │            │
│         │ │Check     │ │        │ │         │ │            │
│Scans:   │ │          │ │Scans:  │ │Scans:   │ │Scans:      │
│• Bugs   │ │Evaluates:│ │• npm   │ │• Files  │ │• OS pkgs   │
│• Vulns  │ │• Metrics │ │  deps  │ │• Config │ │• App deps  │
│• Smells │ │• Ratings │ │• CVEs  │ │• IaC    │ │• All layers│
│• Dups   │ │          │ │        │ │• Secrets│ │            │
└────┬────┘ └────┬─────┘ └────┬───┘ └────┬────┘ └────────────┘
     │           │            │          │
 Stage 3     Stage 4      Stage 5    Stage 6       Stage 9
```

---

## 2. Tool Installation & Versions

### Source: `tools-install.sh`

```
┌──────────────────────────────────────────────────────────────────┐
│                  Jenkins Server (Ubuntu 22.04)                    │
│                                                                  │
│  Base Infrastructure:                                            │
│  ├── Java OpenJDK 17 (JRE + JDK)                                │
│  ├── Jenkins (latest from official apt repo)                     │
│  └── Docker (docker.io from Ubuntu apt)                          │
│                                                                  │
│  Security Scanning Tools:                                        │
│  ├── SonarQube Server                                            │
│  │   └── Docker: sonarqube:lts-community (:9000)                 │
│  ├── Trivy                                                       │
│  │   └── APT: aquasecurity repo (latest at install time)         │
│  └── OWASP Dependency-Check                                      │
│      └── Jenkins Plugin: "DP-Check" (auto-installed)             │
│                                                                  │
│  Jenkins Plugins Required:                                       │
│  ├── SonarQube Scanner plugin                                    │
│  ├── OWASP Dependency-Check plugin                               │
│  ├── NodeJS plugin                                               │
│  └── Pipeline plugin (core)                                      │
│                                                                  │
│  Other Tools:                                                    │
│  ├── AWS CLI v2           (ECR authentication)                   │
│  ├── kubectl v1.28.4      (K8s management)                       │
│  ├── eksctl latest        (EKS cluster management)               │
│  ├── Terraform latest     (Infrastructure provisioning)          │
│  └── Helm latest          (K8s package management)               │
└──────────────────────────────────────────────────────────────────┘
```

### Installation Details

#### SonarQube Server

```bash
# จาก tools-install.sh
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
```

| Property       | Value                      |
| -------------- | -------------------------- |
| Image          | `sonarqube:lts-community`  |
| Container Name | `sonar`                    |
| Port           | `9000`                     |
| Access URL     | `http://<jenkins-ip>:9000` |
| Default Login  | `admin` / `admin`          |
| Edition        | Community (free)           |

#### Trivy

```bash
# จาก tools-install.sh
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | \
  sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy -y
```

| Property       | Value                            |
| -------------- | -------------------------------- |
| Install Method | APT repository (Aqua Security)   |
| Version        | Latest from repo at install time |
| Binary Path    | `/usr/bin/trivy`                 |
| Vuln DB        | Auto-download on first scan      |

#### OWASP Dependency-Check

```
ไม่ได้ติดตั้งใน tools-install.sh
→ ติดตั้งผ่าน Jenkins Plugin: "OWASP Dependency-Check"
→ Tool name "DP-Check" กำหนดใน Jenkins → Global Tool Configuration
→ Auto-download เมื่อรัน pipeline ครั้งแรก
```

---

## 3. Backend vs Frontend Pipeline Comparison

### ทั้งสอง Pipeline มีโครงสร้าง 11 stages เหมือนกัน

```
┌─────┬──────────────────────────┬────────────────────────┬────────────────────────┐
│Stage│ Name                     │ Backend                │ Frontend               │
├─────┼──────────────────────────┼────────────────────────┼────────────────────────┤
│  1  │ Cleaning Workspace       │ cleanWs()              │ cleanWs()              │
│  2  │ Checkout from Git        │ same repo              │ same repo              │
│  3  │ Sonarqube Analysis       │ three-tier-backend     │ three-tier-frontend    │
│  4  │ Quality Check            │ abortPipeline: false   │ abortPipeline: false   │
│  5  │ OWASP DC Scan            │ backend dir            │ frontend dir           │
│  6  │ Trivy File Scan          │ backend dir            │ frontend dir           │
│  7  │ Docker Image Build       │ backend Dockerfile     │ frontend Dockerfile    │
│  8  │ ECR Image Pushing        │ ECR_REPO2              │ ECR_REPO1              │
│  9  │ TRIVY Image Scan         │ backend image          │ frontend image         │
│ 10  │ Checkout Code            │ same repo              │ same repo              │
│ 11  │ Update Deployment file   │ Backend/deployment.yaml│ Frontend/deployment.yaml│
└─────┴──────────────────────────┴────────────────────────┴────────────────────────┘
```

### Key Differences

| Config Item               | Jenkinsfile-Backend                  | Jenkinsfile-Frontend                 |
| ------------------------- | ------------------------------------ | ------------------------------------ |
| **ECR Repo Credential**   | `credentials('ECR_REPO2')`           | `credentials('ECR_REPO1')`           |
| **SonarQube projectName** | `three-tier-backend`                 | `three-tier-frontend`                |
| **SonarQube projectKey**  | `three-tier-backend`                 | `three-tier-frontend`                |
| **Working Dir (scan)**    | `Application-Code/backend`           | `Application-Code/frontend`          |
| **K8s Manifest Dir**      | `Kubernetes-Manifests-file/Backend`  | `Kubernetes-Manifests-file/Frontend` |
| **Image Tag Grep**        | `(?<=backend:)[^ ]+`                 | `(?<=frontend:)[^ ]+`                |
| **Quality Gate**          | `abortPipeline: false`               | `abortPipeline: false`               |
| **Trivy FS command**      | `trivy fs . > trivyfs.txt`           | `trivy fs . > trivyfs.txt`           |
| **Trivy Image command**   | `trivy image <img> > trivyimage.txt` | `trivy image <img> > trivyimage.txt` |

### Shared Configuration (เหมือนกันทุกประการ)

```groovy
// ทั้งสอง Jenkinsfile ใช้ tools เหมือนกัน
tools {
    jdk 'jdk'
    nodejs 'nodejs'
}

// ทั้งสอง Jenkinsfile ใช้ environment เหมือนกัน (ยกเว้น ECR_REPO)
environment {
    SCANNER_HOME = tool 'sonar-scanner'
    AWS_ACCOUNT_ID = credentials('ACCOUNT_ID')
    AWS_DEFAULT_REGION = 'us-east-1'
    REPOSITORY_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/"
}
```

---

## 4. SonarQube — SAST

### 4.1 Pipeline Stage (ทั้ง Backend & Frontend)

**Backend:**

```groovy
stage('Sonarqube Analysis') {
    steps {
        dir('Application-Code/backend') {
            withSonarQubeEnv('sonar-server') {
                sh ''' $SCANNER_HOME/bin/sonar-scanner \
                -Dsonar.projectName=three-tier-backend \
                -Dsonar.projectKey=three-tier-backend '''
            }
        }
    }
}
```

**Frontend:**

```groovy
stage('Sonarqube Analysis') {
    steps {
        dir('Application-Code/frontend') {
            withSonarQubeEnv('sonar-server') {
                sh ''' $SCANNER_HOME/bin/sonar-scanner \
                -Dsonar.projectName=three-tier-frontend \
                -Dsonar.projectKey=three-tier-frontend '''
            }
        }
    }
}
```

### 4.2 Configuration Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                    SonarQube Configuration                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Jenkins Global Tool Configuration:                                  │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ SonarQube Scanner:                                             │  │
│  │   Name: "sonar-scanner"                                        │  │
│  │   Referenced as: SCANNER_HOME = tool 'sonar-scanner'           │  │
│  │   Binary: $SCANNER_HOME/bin/sonar-scanner                      │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Jenkins System Configuration:                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ SonarQube Server:                                              │  │
│  │   Name: "sonar-server"                                         │  │
│  │   URL:  http://<jenkins-server-ip>:9000                        │  │
│  │   Token: (configured via Jenkins credential)                   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Quality Gate Credential:                                            │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ ID: "sonar-token"                                              │  │
│  │ Type: Secret text                                              │  │
│  │ Used in: waitForQualityGate()                                  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 4.3 Scanner Parameters

| Parameter           | Backend Value              | Frontend Value              | Description                     |
| ------------------- | -------------------------- | --------------------------- | ------------------------------- |
| `sonar.projectName` | `three-tier-backend`       | `three-tier-frontend`       | ชื่อแสดงใน SonarQube Dashboard  |
| `sonar.projectKey`  | `three-tier-backend`       | `three-tier-frontend`       | Unique identifier ของ project   |
| Working Directory   | `Application-Code/backend` | `Application-Code/frontend` | Directory ที่สแกน               |
| Server Env          | `sonar-server`             | `sonar-server`              | Jenkins SonarQube server config |

### 4.4 Analysis Flow

```
withSonarQubeEnv('sonar-server')
         │
         │  Injects environment variables:
         │  ├── SONAR_HOST_URL = http://<ip>:9000
         │  ├── SONAR_AUTH_TOKEN = <token>
         │  └── SONAR_CONFIG_NAME = sonar-server
         │
         ▼
┌─────────────────────────────┐
│ $SCANNER_HOME/bin/           │
│   sonar-scanner              │
│   -Dsonar.projectName=...   │
│   -Dsonar.projectKey=...    │
└──────────────┬──────────────┘
               │
               ├── 1. Scans source files in working directory
               │      Backend: *.js (index.js, db.js, task.js, tasks.js)
               │      Frontend: *.js, *.jsx, *.css (App.js, Tasks.js, etc.)
               │
               ├── 2. Analyzes:
               │      ├── Bugs (logic errors, null references)
               │      ├── Vulnerabilities (security flaws in code)
               │      ├── Security Hotspots (code needing security review)
               │      ├── Code Smells (maintainability issues)
               │      └── Duplications (copy-paste code)
               │
               ├── 3. Sends results to SonarQube server
               │
               ▼
┌─────────────────────────────┐
│ SonarQube Server (:9000)    │
│                             │
│ ├── Stores analysis results │
│ ├── Computes Quality Gate   │
│ ├── Generates dashboard     │
│ └── Sends webhook to Jenkins│
│     (for Quality Gate check)│
└─────────────────────────────┘
```

### 4.5 SonarQube สแกนอะไรบ้างในแต่ละ Project

**Backend (Node.js/Express):**

| Category              | ตัวอย่างที่อาจพบ                                     |
| --------------------- | ---------------------------------------------------- |
| **Bugs**              | `==` แทน `===`, unreachable code                     |
| **Vulnerabilities**   | Hard-coded credentials, SQL/NoSQL injection patterns |
| **Security Hotspots** | ใช้ `cors()` แบบ open, ไม่มี rate limiting           |
| **Code Smells**       | `console.log` ใน production, unused variables        |
| **Duplications**      | try-catch pattern ซ้ำใน routes/tasks.js              |

**Frontend (React):**

| Category              | ตัวอย่างที่อาจพบ                                            |
| --------------------- | ----------------------------------------------------------- |
| **Bugs**              | State mutation (`tasks.push(data)`), missing key prop       |
| **Vulnerabilities**   | XSS via `innerHTML`, unsafe `dangerouslySetInnerHTML`       |
| **Security Hotspots** | `console.log(apiUrl)` อาจ leak sensitive URL                |
| **Code Smells**       | Class component แทน functional, duplicate state declaration |
| **Duplications**      | Error handling pattern ซ้ำใน Tasks.js                       |

---

## 5. OWASP Dependency-Check — SCA

### 5.1 Pipeline Stage (ทั้ง Backend & Frontend)

**Backend:**

```groovy
stage('OWASP Dependency-Check Scan') {
    steps {
        dir('Application-Code/backend') {
            dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit',
                            odcInstallation: 'DP-Check'
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        }
    }
}
```

**Frontend:**

```groovy
stage('OWASP Dependency-Check Scan') {
    steps {
        dir('Application-Code/frontend') {
            dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit',
                            odcInstallation: 'DP-Check'
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        }
    }
}
```

> ทั้งสอง pipeline ใช้ arguments **เหมือนกันทุกประการ** ต่างกันเฉพาะ working directory

### 5.2 Arguments Breakdown

```
┌──────────────────────────────────────────────────────────────────────┐
│                OWASP Dependency-Check Arguments                       │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  dependencyCheck additionalArguments:                                │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                                                                │  │
│  │  --scan ./              Scan Target                            │  │
│  │  │                      สแกนทุกไฟล์ใน current directory         │  │
│  │  │                      Backend: package.json, package-lock,   │  │
│  │  │                               node_modules/ (if present)   │  │
│  │  │                      Frontend: package.json, package-lock,  │  │
│  │  │                                node_modules/ (if present)  │  │
│  │  │                                                            │  │
│  │  --disableYarnAudit     Disable Yarn Analyzer                 │  │
│  │  │                      ปิด Yarn-specific vulnerability check │  │
│  │  │                      (project ใช้ npm ไม่ใช่ Yarn)          │  │
│  │  │                                                            │  │
│  │  --disableNodeAudit     Disable npm audit Analyzer            │  │
│  │                         ปิด npm audit (ใช้ NVD database แทน)  │  │
│  │                         หลีกเลี่ยงซ้ำซ้อนกับ NVD check         │  │
│  │                                                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  odcInstallation: 'DP-Check'                                        │
│  → Jenkins tool installation name                                    │
│  → กำหนดใน Jenkins → Global Tool Configuration                       │
│                                                                      │
│  dependencyCheckPublisher:                                           │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  pattern: '**/dependency-check-report.xml'                     │  │
│  │  → Publish XML report to Jenkins build page                   │  │
│  │  → แสดงเป็น "Dependency-Check" tab ใน build results            │  │
│  │  → แสดง vulnerability count by severity                       │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Arguments ที่ไม่ได้กำหนด (ใช้ค่า default):                            │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  --format        default: XML + HTML                          │  │
│  │  --failOnCVSS    default: 11 (ไม่มี fail — max CVSS = 10.0)  │  │
│  │  --out           default: ./                                  │  │
│  │  --suppression   default: none                                │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### 5.3 Analysis Flow

```
dependencyCheck --scan ./
         │
         ├── 1. Download/Update NVD Database
         │      (National Vulnerability Database)
         │      ⚠️ ครั้งแรกอาจใช้เวลา ~10-30 นาที
         │      Cache ถูกเก็บบน Jenkins server
         │
         ├── 2. Identify Dependencies
         │      ├── อ่าน package.json → declared dependencies
         │      ├── อ่าน package-lock.json → locked versions + transitive deps
         │      └── สแกน node_modules/ (ถ้ามี) → actual installed packages
         │
         ├── 3. Match against NVD
         │      ├── แต่ละ dependency ถูก match กับ CPE (Common Platform Enumeration)
         │      └── ค้นหา CVE ที่เกี่ยวข้องกับแต่ละ version
         │
         ▼
┌──────────────────────────┐
│ Generate Reports:        │
│ ├── dependency-check-    │
│ │   report.xml           │──▶ Jenkins plugin อ่าน → แสดงใน UI
│ ├── dependency-check-    │
│ │   report.html          │──▶ Human-readable report
│ └── dependency-check-    │
│     report.json          │──▶ Machine-readable (ถ้า enabled)
└──────────────────────────┘
```

### 5.4 Report Format & Severity Levels

**CVSS v3 Severity Mapping:**

| CVSS Score | Severity | สี  | ตัวอย่าง                              |
| ---------- | -------- | --- | ------------------------------------- |
| 0.0        | None     | ⚪  | Informational                         |
| 0.1 – 3.9  | Low      | 🟢  | Minor information disclosure          |
| 4.0 – 6.9  | Medium   | 🟡  | XSS in non-critical component         |
| 7.0 – 8.9  | High     | 🟠  | Remote code execution (conditional)   |
| 9.0 – 10.0 | Critical | 🔴  | Unauthenticated remote code execution |

**ตัวอย่าง Dependencies ที่อาจพบ Vulnerabilities:**

| Pipeline | Dependency                  | ปัญหาที่อาจพบ                                 |
| -------- | --------------------------- | --------------------------------------------- |
| Backend  | `mongoose ^6.13.6`          | Prototype pollution CVEs                      |
| Backend  | `express ^4.17.1`           | Various HTTP parsing CVEs                     |
| Frontend | `axios ^=0.30.0`            | CVE-2023-45857 (CSRF), CVE-2023-26159 (SSRF)  |
| Frontend | `react-scripts 4.0.3`       | Transitive dependency CVEs (webpack, postcss) |
| Frontend | `@material-ui/core ^4.11.4` | Transitive dependency CVEs                    |

### 5.5 Jenkins Plugin Configuration

```
Jenkins → Manage Jenkins → Global Tool Configuration:
┌──────────────────────────────────────────────────────┐
│ Dependency-Check installations:                      │
│   Name: "DP-Check"                                   │
│   Install automatically: ✅                           │
│   Add Installer: "Install from github.com"           │
│   Version: latest (or specific version)              │
│                                                      │
│ NVD Database:                                        │
│   Location: Jenkins home directory (cached)          │
│   Update: Every scan (incremental update)            │
│   First download: ~10-30 minutes                     │
└──────────────────────────────────────────────────────┘
```

---

## 6. Trivy FS — Filesystem Vulnerability Scan

### 6.1 Pipeline Stage (ทั้ง Backend & Frontend)

**Backend:**

```groovy
stage('Trivy File Scan') {
    steps {
        dir('Application-Code/backend') {
            sh 'trivy fs . > trivyfs.txt'
        }
    }
}
```

**Frontend:**

```groovy
stage('Trivy File Scan') {
    steps {
        dir('Application-Code/frontend') {
            sh 'trivy fs . > trivyfs.txt'
        }
    }
}
```

### 6.2 Command Breakdown

```
trivy  fs  .  >  trivyfs.txt
  │    │   │  │       │
  │    │   │  │       └── Output file (plain text report)
  │    │   │  └── Shell redirect stdout
  │    │   └── "." = current directory
  │    │        Backend: Application-Code/backend
  │    │        Frontend: Application-Code/frontend
  │    └── "fs" = filesystem scan mode
  └── Trivy binary (/usr/bin/trivy)
```

### 6.3 Trivy FS สแกนอะไรบ้าง

```
trivy fs .
    │
    ├── 1. Vulnerability Scanning (dependency CVEs)
    │   ├── package.json         → Declared dependencies
    │   ├── package-lock.json    → Locked versions + all transitive deps
    │   └── yarn.lock            → (ถ้ามี)
    │
    ├── 2. Misconfiguration Scanning
    │   ├── Dockerfile           → Best practice violations
    │   │   ├── Running as root?
    │   │   ├── Using :latest tag?
    │   │   ├── COPY before RUN npm install?
    │   │   ├── Sensitive data in ENV?
    │   │   └── No HEALTHCHECK?
    │   └── *.yaml / *.json      → IaC misconfigurations
    │
    └── 3. Secret Detection
        ├── Hard-coded passwords
        ├── API keys / tokens
        ├── Private keys (*.pem, *.key)
        └── Connection strings with credentials
```

### 6.4 สิ่งที่ต่างกันระหว่าง Backend vs Frontend Scan

| Aspect                | Backend Scan                   | Frontend Scan                                 |
| --------------------- | ------------------------------ | --------------------------------------------- |
| **Files สแกน**        | `package.json` (3 deps)        | `package.json` (9 deps)                       |
| **Dep ทั้งหมด**       | น้อย (express, mongoose, cors) | มาก (react, MUI, axios, testing libs)         |
| **Transitive Deps**   | น้อยกว่า                       | มากกว่ามาก (react-scripts เพิ่มหลายร้อย deps) |
| **Dockerfile Issues** | `FROM node:14` (EOL)           | `FROM node:14` (EOL), no multi-stage          |
| **Expected Vulns**    | น้อยกว่า                       | มากกว่า (react-scripts มี vuln เยอะ)          |
| **Report File**       | `trivyfs.txt`                  | `trivyfs.txt`                                 |

### 6.5 Severity Levels & Default Behavior

```
┌────────────────────────────────────────────────────────────────┐
│              Trivy FS — Default Configuration                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Command: trivy fs . > trivyfs.txt                             │
│                                                                │
│  Severity Filter: ❌ ไม่ได้กำหนด (default = ALL)               │
│  ┌──────────┬──────────────────────────────┐                   │
│  │ Severity │ Reported?                    │                   │
│  ├──────────┼──────────────────────────────┤                   │
│  │ CRITICAL │ ✅ Yes                       │                   │
│  │ HIGH     │ ✅ Yes                       │                   │
│  │ MEDIUM   │ ✅ Yes                       │                   │
│  │ LOW      │ ✅ Yes                       │                   │
│  │ UNKNOWN  │ ✅ Yes                       │                   │
│  └──────────┴──────────────────────────────┘                   │
│                                                                │
│  Exit Code: ❌ ไม่ได้กำหนด --exit-code                         │
│  ┌──────────────────────┬──────────┐                           │
│  │ Scenario             │ Exit Code│                           │
│  ├──────────────────────┼──────────┤                           │
│  │ Vulns found          │ 0 ✅     │ → Pipeline continues     │
│  │ No vulns found       │ 0 ✅     │ → Pipeline continues     │
│  │ Scan error           │ 1 ❌     │ → Pipeline fails         │
│  └──────────────────────┴──────────┘                           │
│                                                                │
│  Result: Pipeline จะไม่ fail แม้พบ vulnerabilities              │
│  Report ถูกเก็บใน trivyfs.txt เพื่อ review ภายหลังเท่านั้น       │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 6.6 ตัวอย่าง Output (trivyfs.txt)

```
2024-01-15T10:30:00.000Z  INFO  Vulnerability scanning is enabled
2024-01-15T10:30:00.000Z  INFO  Secret scanning is enabled
2024-01-15T10:30:02.000Z  INFO  Number of language-specific files: 1
2024-01-15T10:30:02.000Z  INFO  Detecting npm vulnerabilities...

Application-Code/backend (npm)
===============================
Total: 8 (UNKNOWN: 0, LOW: 1, MEDIUM: 4, HIGH: 2, CRITICAL: 1)

┌───────────────┬────────────────┬──────────┬────────┬───────────────┐
│    Library    │ Vulnerability  │ Severity │Installed│ Fixed Version │
├───────────────┼────────────────┼──────────┼────────┼───────────────┤
│ express       │ CVE-2024-29041 │ MEDIUM   │ 4.17.1 │ 4.19.2        │
│ mongoose      │ CVE-2023-3696  │ HIGH     │ 6.13.6 │ 7.3.4         │
│ semver        │ CVE-2022-25883 │ MEDIUM   │ 5.7.1  │ 5.7.2, 6.3.1  │
│ ...           │ ...            │ ...      │ ...    │ ...           │
└───────────────┴────────────────┴──────────┴────────┴───────────────┘
```

---

## 7. Trivy Image — Container Image Vulnerability Scan

### 7.1 Pipeline Stage (ทั้ง Backend & Frontend)

**Backend:**

```groovy
stage("TRIVY Image Scan") {
    steps {
        sh 'trivy image ${REPOSITORY_URI}${AWS_ECR_REPO_NAME}:${BUILD_NUMBER} > trivyimage.txt'
    }
}
```

**Frontend:**

```groovy
stage("TRIVY Image Scan") {
    steps {
        sh 'trivy image ${REPOSITORY_URI}${AWS_ECR_REPO_NAME}:${BUILD_NUMBER} > trivyimage.txt'
    }
}
```

### 7.2 Command Breakdown

```bash
trivy image ${REPOSITORY_URI}${AWS_ECR_REPO_NAME}:${BUILD_NUMBER} > trivyimage.txt

# Resolved example (Backend):
trivy image 407622020962.dkr.ecr.us-east-1.amazonaws.com/backend:42 > trivyimage.txt

# Resolved example (Frontend):
trivy image 407622020962.dkr.ecr.us-east-1.amazonaws.com/frontend:42 > trivyimage.txt
```

```
trivy  image  <full-ecr-image-uri>:<tag>  >  trivyimage.txt
  │      │           │                │    │       │
  │      │           │                │    │       └── Report output file
  │      │           │                │    └── Shell redirect stdout
  │      │           │                └── BUILD_NUMBER (Jenkins auto-increment)
  │      │           └── ECR repository URI
  │      └── "image" = container image scan mode
  └── Trivy binary
```

### 7.3 Trivy Image สแกนอะไรบ้าง

```
trivy image <ecr-image>
    │
    ├── Image: node:14 (Base Layer — Debian Buster/Bullseye)
    │   ├── OS Packages (dpkg)
    │   │   ├── openssl         → CVE-xxxx (CRITICAL)
    │   │   ├── libssl1.1       → CVE-xxxx (HIGH)
    │   │   ├── libgnutls30     → CVE-xxxx (MEDIUM)
    │   │   ├── libc6           → CVE-xxxx (LOW)
    │   │   └── ... (hundreds of Debian packages)
    │   │
    │   └── Node.js 14 Runtime
    │       └── Node.js 14 EOL → multiple known CVEs
    │           ├── CVE-2023-xxxx (HTTP request smuggling)
    │           ├── CVE-2023-xxxx (OpenSSL vulnerability)
    │           └── ...
    │
    ├── Layer: RUN npm install (Application Dependencies)
    │   └── node_modules/
    │       ├── Backend: express, mongoose, cors + transitive deps
    │       └── Frontend: react, axios, MUI + transitive deps
    │
    └── Layer: COPY . . (Application Source)
        └── Secret detection in source files
```

### 7.4 Image Scan Position ใน Pipeline (Critical Issue)

```
┌─────────────────────────────────────────────────────────────────────┐
│              PIPELINE ORDERING — CRITICAL OBSERVATION                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Stage 7:  Docker Image Build                                       │
│       │    docker build -t ${AWS_ECR_REPO_NAME} .                   │
│       ▼                                                             │
│  Stage 8:  ECR Image Pushing ⚠️                                     │
│       │    docker push ... (IMAGE IS NOW IN ECR)                    │
│       ▼                                                             │
│  Stage 9:  TRIVY Image Scan ← สแกน "หลัง" push                     │
│            trivy image <ecr-image> > trivyimage.txt                 │
│                                                                     │
│  ⚠️ ปัญหา:                                                          │
│  ├── Image ถูก push ไป ECR ก่อนที่จะถูกสแกน                          │
│  ├── ถ้าพบ CRITICAL vulnerability → image ก็อยู่ใน registry แล้ว     │
│  ├── Pipeline ไม่ fail (ไม่มี --exit-code)                           │
│  └── Stage 11 ยังอัปเดต K8s YAML → deploy image ที่มี vuln          │
│                                                                     │
│  ✅ ควรจะเป็น:                                                       │
│  Stage 7: Docker Build                                              │
│  Stage 8: Trivy Image Scan (scan local image)                       │
│  Stage 9: ECR Push (push เฉพาะเมื่อ scan ผ่าน)                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 7.5 Exit Code Behavior

```
┌────────────────────────────────────────────────────────────────┐
│              Trivy Image — Exit Code Analysis                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Command: trivy image <image> > trivyimage.txt                 │
│                                                                │
│  ❌ ไม่มี --exit-code flag                                     │
│                                                                │
│  ┌──────────────────────┬──────────┬────────────────────────┐  │
│  │ Scenario             │ Exit Code│ Pipeline Result         │  │
│  ├──────────────────────┼──────────┼────────────────────────┤  │
│  │ CRITICAL vulns found │ 0        │ ✅ Continue (ไม่ fail)  │  │
│  │ HIGH vulns found     │ 0        │ ✅ Continue (ไม่ fail)  │  │
│  │ No vulns found       │ 0        │ ✅ Continue             │  │
│  │ Scan error / timeout │ 1        │ ❌ Pipeline fails       │  │
│  └──────────────────────┴──────────┴────────────────────────┘  │
│                                                                │
│  ผลลัพธ์: เหมือน Trivy FS — report-only mode                   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 7.6 Trivy FS vs Trivy Image Comparison

```
┌─────────────────────┬───────────────────────┬───────────────────────────┐
│                     │    Trivy FS (Stage 6) │  Trivy Image (Stage 9)    │
├─────────────────────┼───────────────────────┼───────────────────────────┤
│ Scan Target         │ Source directory       │ Built Docker image        │
│ OS Packages         │ ❌ ไม่สแกน             │ ✅ สแกน (Debian pkgs)     │
│ Node.js Runtime     │ ❌ ไม่สแกน             │ ✅ สแกน (node:14 CVEs)    │
│ App Dependencies    │ ✅ จาก package-lock    │ ✅ จาก node_modules ใน image│
│ Dockerfile Issues   │ ✅ Misconfiguration    │ ❌ ไม่สแกน                │
│ Secrets             │ ✅ ใน source files      │ ✅ ใน image layers         │
│ IaC Misconfig       │ ✅ YAML, JSON          │ ❌ ไม่สแกน                │
│ ตรงกับ Production?  │ ❌ ไม่ 100%             │ ✅ exact image             │
│ Pipeline Position   │ Before Docker build    │ After ECR push            │
│ Expected Vuln Count │ น้อย (app deps only)   │ มาก (OS + runtime + app)  │
│ Scan Time           │ เร็ว (~30s)            │ ช้ากว่า (~2-5min)          │
│ Output File         │ trivyfs.txt            │ trivyimage.txt             │
│ Blocks Pipeline?    │ ❌ No                  │ ❌ No                      │
└─────────────────────┴───────────────────────┴───────────────────────────┘
```

---

## 8. Quality Gate Mechanism & Failure Behavior

### 8.1 Pipeline Stage (ทั้ง Backend & Frontend — เหมือนกัน)

```groovy
stage('Quality Check') {
    steps {
        script {
            waitForQualityGate abortPipeline: false, credentialsId: 'sonar-token'
        }
    }
}
```

### 8.2 Quality Gate Flow

```
Stage 3: SonarQube Analysis
         │
         │  ส่ง analysis results ไปยัง SonarQube server
         │
         ▼
┌──────────────────────┐
│   SonarQube Server   │
│   (:9000)            │
│                      │
│   Processes analysis │
│   Computes metrics   │
│   Evaluates QGate    │
│   conditions         │
└──────────┬───────────┘
           │
           │  Webhook / Polling
           │
           ▼
Stage 4: Quality Check
┌──────────────────────┐
│ waitForQualityGate   │
│                      │
│ abortPipeline: false │
│ credentialsId:       │
│   'sonar-token'      │
└──────────┬───────────┘
           │
           ├── QGate = PASSED ──▶ Log: "Quality Gate passed" ── Continue ✅
           │
           └── QGate = FAILED ──▶ Log: "Quality Gate failed" ── Continue ⚠️
                                  (abortPipeline: false)
                                  Pipeline ดำเนินต่อ!
                                        │
                                        ▼
                                  Stage 5: OWASP DC (ยังทำงานต่อ)
                                  Stage 6: Trivy FS (ยังทำงานต่อ)
                                  Stage 7: Docker Build (ยังทำงานต่อ)
                                  Stage 8: ECR Push (ยังทำงานต่อ)
                                        ...
                                  Stage 11: Update K8s YAML (ยัง deploy!)
```

### 8.3 SonarQube Default Quality Gate ("Sonar way")

```
┌────────────────────────────────────┬──────────────┬───────────┐
│ Metric                             │ Operator     │ Threshold │
├────────────────────────────────────┼──────────────┼───────────┤
│ Coverage on New Code               │ is less than │ 80%       │
│ Duplicated Lines on New Code       │ is greater   │ 3%        │
│                                    │ than         │           │
│ Maintainability Rating (New Code)  │ is worse than│ A         │
│ Reliability Rating (New Code)      │ is worse than│ A         │
│ Security Hotspots Reviewed         │ is less than │ 100%      │
│ (New Code)                         │              │           │
│ Security Rating (New Code)         │ is worse than│ A         │
└────────────────────────────────────┴──────────────┴───────────┘
```

### 8.4 Overall Pipeline Failure Behavior

```
┌──────────────────────┬───────────────┬──────────────────────────────────────┐
│ Security Tool        │ Blocks Build? │ Why?                                 │
├──────────────────────┼───────────────┼──────────────────────────────────────┤
│ SonarQube Analysis   │ ❌ No         │ Scan & report only, no threshold     │
│                      │               │                                      │
│ Quality Gate Check   │ ❌ No         │ abortPipeline: false                 │
│                      │               │ Pipeline continues regardless        │
│                      │               │                                      │
│ OWASP DC Scan        │ ❌ No         │ No --failOnCVSS configured           │
│                      │               │ Report published only                │
│                      │               │                                      │
│ Trivy FS Scan        │ ❌ No         │ No --exit-code flag                  │
│                      │               │ Always exits 0                       │
│                      │               │                                      │
│ Trivy Image Scan     │ ❌ No         │ No --exit-code flag                  │
│                      │               │ Always exits 0                       │
│                      │               │ Also runs AFTER ECR push             │
├──────────────────────┼───────────────┼──────────────────────────────────────┤
│                      │               │                                      │
│ ⚠️ OVERALL           │ ❌ NONE       │ ไม่มี security tool ใดที่ block       │
│                      │ BLOCKS        │ pipeline ทั้ง Backend และ Frontend    │
│                      │ PIPELINE      │ ทุก scan เป็น "report-only" mode     │
│                      │               │                                      │
│                      │               │ Code ที่มี CRITICAL vulnerabilities  │
│                      │               │ ยังถูก build, push, และ deploy ได้   │
│                      │               │                                      │
└──────────────────────┴───────────────┴──────────────────────────────────────┘
```

---

## 9. Security Scan Coverage Matrix

### What Each Tool Covers

```
┌──────────────────────────┬──────────┬──────────┬──────────┬──────────┐
│ Vulnerability Type       │SonarQube │ OWASP DC │ Trivy FS │ Trivy    │
│                          │ (SAST)   │ (SCA)    │          │ Image    │
├──────────────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Code Bugs                │ ✅       │ ❌       │ ❌       │ ❌       │
│ Code Smells              │ ✅       │ ❌       │ ❌       │ ❌       │
│ Code Vulnerabilities     │ ✅       │ ❌       │ ❌       │ ❌       │
│ Security Hotspots        │ ✅       │ ❌       │ ❌       │ ❌       │
│ Code Duplication         │ ✅       │ ❌       │ ❌       │ ❌       │
│ Dependency CVEs (npm)    │ ❌       │ ✅       │ ✅       │ ✅       │
│ Transitive Dep CVEs      │ ❌       │ ✅       │ ✅       │ ✅       │
│ License Compliance       │ ❌       │ ✅       │ ❌       │ ✅       │
│ OS Package CVEs          │ ❌       │ ❌       │ ❌       │ ✅       │
│ Node.js Runtime CVEs     │ ❌       │ ❌       │ ❌       │ ✅       │
│ Dockerfile Misconfig     │ ❌       │ ❌       │ ✅       │ ❌       │
│ Secrets in Code          │ ⚠️ partial│ ❌      │ ✅       │ ✅       │
│ IaC Misconfig            │ ❌       │ ❌       │ ✅       │ ❌       │
│ Container Base Image     │ ❌       │ ❌       │ ❌       │ ✅       │
├──────────────────────────┼──────────┼──────────┼──────────┼──────────┤
│ Pipeline Stage (BE/FE)   │ 3 / 3    │ 5 / 5    │ 6 / 6    │ 9 / 9   │
│ Blocks Pipeline?         │ ❌       │ ❌       │ ❌       │ ❌       │
│ Report Format            │Dashboard │ XML/HTML │ Text     │ Text     │
│ Report Location          │SonarQube │ Jenkins  │trivyfs   │trivyimage│
│                          │ Server   │ UI       │.txt      │.txt      │
└──────────────────────────┴──────────┴──────────┴──────────┴──────────┘
```

### Scan Overlap (Dependency CVEs ถูกสแกนซ้ำ 3 ครั้ง)

```
                    npm dependency CVEs
        ┌──────────────────────────────────────┐
        │                                      │
        │     ┌──────────────────┐             │
        │     │    OWASP DC      │             │
        │     │    (NVD data)    │             │
        │     └────────┬─────────┘             │
        │              │                       │
        │     ┌────────┴─────────┐             │
        │     │    Trivy FS      │             │
        │     │    (Trivy DB)    │             │
        │     └────────┬─────────┘             │
        │              │                       │
        │     ┌────────┴─────────┐             │
        │     │   Trivy Image    │             │
        │     │   (Trivy DB)     │             │
        │     │   + OS packages  │ ← unique    │
        │     │   + Runtime CVEs │ ← unique    │
        │     └──────────────────┘             │
        │                                      │
        └──────────────────────────────────────┘

   npm dependency CVEs ถูกสแกน 3 ครั้งด้วย 3 tools
   แต่ใช้ vulnerability database ต่างกัน:
   • OWASP DC → NVD (NIST)
   • Trivy    → Trivy DB (GitHub Advisory + NVD + อื่นๆ)
```

### Security Coverage Gaps

```
┌──────────────────────────────────────────────────────────────┐
│                    Identified Gaps                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ ❌ DAST (Dynamic Application Security Testing)               │
│    → ไม่มีการทดสอบ running application                        │
│    → ไม่ตรวจ runtime vulnerabilities เช่น XSS, CSRF          │
│    → เช่น OWASP ZAP, Burp Suite                             │
│                                                              │
│ ❌ K8s Manifest Scanning                                     │
│    → ไม่มีการสแกน Kubernetes YAML files                      │
│    → secrets.yaml มี credentials ใน base64                   │
│    → ไม่ตรวจ security context, RBAC                          │
│    → เช่น kubesec, Checkov, kube-bench                       │
│                                                              │
│ ❌ Git Secret Scanning                                       │
│    → ไม่มีการตรวจ secrets ที่ถูก commit ลง Git               │
│    → secrets.yaml อยู่ใน repo                                │
│    → เช่น gitleaks, detect-secrets, git-secrets              │
│                                                              │
│ ❌ Container Runtime Security                                │
│    → ไม่มีการ monitor ขณะ runtime                             │
│    → เช่น Falco, Aqua Security                               │
│                                                              │
│ ❌ Image Signing / Verification                              │
│    → ไม่มีการ sign image เพื่อ verify integrity                │
│    → เช่น Cosign, Notary                                     │
│                                                              │
│ ❌ Network Policy Scanning                                   │
│    → ไม่มี NetworkPolicy ใน K8s manifests                     │
│    → ทุก Pod สามารถสื่อสารกันได้หมด                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 10. Pipeline Configuration & Credentials

### Jenkins Tools Configuration

```groovy
// ทั้ง Jenkinsfile-Backend และ Jenkinsfile-Frontend ใช้เหมือนกัน
tools {
    jdk 'jdk'                           // Java 17 — required for SonarQube Scanner
    nodejs 'nodejs'                     // Node.js — required for npm projects
}

environment {
    SCANNER_HOME = tool 'sonar-scanner' // SonarQube Scanner installation path
}
```

### All Jenkins Tool Installations Required

```
Jenkins → Manage Jenkins → Global Tool Configuration:

┌────────────────────┬──────────────────┬──────────────────────────────┐
│ Tool Type          │ Name             │ Used For                     │
├────────────────────┼──────────────────┼──────────────────────────────┤
│ JDK                │ "jdk"            │ SonarQube Scanner runtime    │
│ NodeJS             │ "nodejs"         │ npm / Node.js support        │
│ SonarQube Scanner  │ "sonar-scanner"  │ SAST analysis                │
│ Dependency-Check   │ "DP-Check"       │ SCA dependency scanning      │
└────────────────────┴──────────────────┴──────────────────────────────┘

Jenkins → Manage Jenkins → Configure System:

┌────────────────────┬─────────────────────────────────────────────────┐
│ Section            │ Configuration                                   │
├────────────────────┼─────────────────────────────────────────────────┤
│ SonarQube Servers  │ Name: "sonar-server"                            │
│                    │ URL: http://<jenkins-server-ip>:9000             │
│                    │ Token: (via Jenkins credential)                  │
└────────────────────┴─────────────────────────────────────────────────┘
```

### All Jenkins Credentials Required

```
┌────────────────┬───────────────┬─────────────────────┬──────────────────────┐
│ Credential ID  │ Type          │ Used In             │ Purpose              │
├────────────────┼───────────────┼─────────────────────┼──────────────────────┤
│ sonar-token    │ Secret text   │ waitForQualityGate  │ SonarQube API auth   │
│ ACCOUNT_ID     │ Secret text   │ REPOSITORY_URI      │ AWS Account ID       │
│ ECR_REPO1      │ Secret text   │ Frontend pipeline   │ Frontend ECR repo    │
│ ECR_REPO2      │ Secret text   │ Backend pipeline    │ Backend ECR repo     │
│ GITHUB         │ Username/Pwd  │ Git checkout        │ GitHub repo access   │
│ github (lower) │ Secret text   │ Git push (K8s YAML) │ GitHub token (push)  │
└────────────────┴───────────────┴─────────────────────┴──────────────────────┘
```

### Complete Pipeline Stage Map

```
┌─────┬──────────────────────────┬──────────────┬───────────────────┬───────────────────┐
│Stage│ Name                     │Security Tool │ Backend Specifics │ Frontend Specifics│
├─────┼──────────────────────────┼──────────────┼───────────────────┼───────────────────┤
│  1  │ Cleaning Workspace       │ —            │ cleanWs()         │ cleanWs()         │
│  2  │ Checkout from Git        │ —            │ same repo         │ same repo         │
│  3  │ Sonarqube Analysis       │ ✅ SAST      │ three-tier-backend│ three-tier-frontend│
│  4  │ Quality Check            │ ✅ QGate     │ abort: false      │ abort: false      │
│  5  │ OWASP DC Scan            │ ✅ SCA       │ backend dir       │ frontend dir      │
│  6  │ Trivy File Scan          │ ✅ Trivy FS  │ → trivyfs.txt     │ → trivyfs.txt     │
│  7  │ Docker Image Build       │ —            │ —                 │ —                 │
└───────────────────────────────────────────────────────────────────────────────────────┘
```
