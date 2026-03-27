# Phase 1 Implementation Result

## Document Information
- **Issue Reference**: Phase 1 - Week 1 & Week 2 (Issues #4-15)
- **Implementation Date**: March 27, 2026
- **Branch**: `phase1-implementation`
- **Status**: ✅ Completed

---

## Executive Summary

This document records all code modifications made to adapt the original project for AWS Learner Lab constraints and local development. The original project source code was copied to a new `src/` directory and modified according to the Phase 1 documentation analysis.

**Key Achievements:**
- ✅ Code copied from original-project submodule to `src/` directory
- ✅ Backend db.js fixed for proper boolean parsing
- ✅ Frontend package.json fixed for correct axios version
- ✅ Terraform IAM resources removed (not allowed in Learner Lab)
- ✅ EC2 instance type changed to t2.large
- ✅ Jenkins pipelines updated for Docker Hub (ECR is read-only)
- ✅ Kubernetes manifests updated for Docker Hub images
- ✅ Local Docker test verified working

---

## Directory Structure Created

```
KPS-Enterprise/
├── src/                              # NEW - Modified source code
│   ├── Application-Code/
│   │   ├── backend/                  # Modified backend
│   │   └── frontend/                 # Modified frontend
│   ├── Jenkins-Pipeline-Code/        # Modified Jenkinsfiles
│   ├── Jenkins-Server-TF/            # Modified Terraform (IAM files removed)
│   └── Kubernetes-Manifests-file/    # Modified K8s manifests
├── docker/
│   ├── docker-compose.yml            # Existing (from Issue #7)
│   └── docker-compose.src.yml        # NEW - Uses src/ code
├── document/
│   └── phase1/
│       └── implement-result.md       # THIS FILE
└── original-project/                 # UNCHANGED (submodule)
```

---

## Detailed Changes

### 1. Backend Modifications (`src/Application-Code/backend/`)

#### 1.1 db.js - USE_DB_AUTH Boolean Fix

**File**: `src/Application-Code/backend/db.js`

**Problem**: Environment variables are always strings in Node.js. The original code `const useDBAuth = process.env.USE_DB_AUTH || false;` would evaluate any non-empty string (including "false") as truthy.

**Before**:
```javascript
const useDBAuth = process.env.USE_DB_AUTH || false;
if(useDBAuth){
    connectionParams.user = process.env.MONGO_USERNAME;
    connectionParams.pass = process.env.MONGO_PASSWORD;
}
```

**After**:
```javascript
// Fix: Parse USE_DB_AUTH as boolean (env vars are always strings)
const useDBAuthEnv = process.env.USE_DB_AUTH;
const useDBAuth = useDBAuthEnv === "true" || useDBAuthEnv === "1";

if(useDBAuth){
    connectionParams.user = process.env.MONGO_USERNAME;
    connectionParams.pass = process.env.MONGO_PASSWORD;
}
```

**Reference**: Issue #6, Issue #7 documents

---

### 2. Frontend Modifications (`src/Application-Code/frontend/`)

#### 2.1 package.json - Axios Version Fix

**File**: `src/Application-Code/frontend/package.json`

**Problem**: Invalid semver format `^=0.30.0` caused npm install to fail.

**Before**:
```json
"axios": "^=0.30.0"
```

**After**:
```json
"axios": "^0.30.0"
```

**Reference**: Issue #5, Issue #7 documents

---

### 3. Terraform Modifications (`src/Jenkins-Server-TF/`)

Based on Issue #8, #11 - AWS Learner Lab does not allow IAM resource creation.

#### 3.1 Files Deleted

| File | Reason |
|------|--------|
| `iam-role.tf` | Cannot create IAM roles in Learner Lab |
| `iam-policy.tf` | Cannot attach IAM policies in Learner Lab |
| `iam-instance-profile.tf` | Cannot create instance profiles in Learner Lab |

#### 3.2 ec2.tf - Instance Profile and Type

**File**: `src/Jenkins-Server-TF/ec2.tf`

| Setting | Before | After | Reason |
|---------|--------|-------|--------|
| `instance_type` | `t2.2xlarge` | `t2.large` | Learner Lab limit: max *.large |
| `iam_instance_profile` | `aws_iam_instance_profile.instance-profile.name` | `"LabInstanceProfile"` | Use pre-existing Learner Lab profile |

**Full Change**:
```terraform
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t2.large"  # Changed from t2.2xlarge
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = "LabInstanceProfile"  # Use Learner Lab profile
  ...
}
```

#### 3.3 variables.tf - Removed IAM Role Variable

Removed `iam-role` variable declaration (no longer needed).

#### 3.4 variables.tfvars - Updated Defaults

| Variable | Before | After |
|----------|--------|-------|
| `vpc-name` | `Jenkins-vpc` | `KPS-Jenkins-vpc` |
| `igw-name` | `Jenkins-igw` | `KPS-Jenkins-igw` |
| `subnet-name` | `Jenkins-subnet` | `KPS-Jenkins-subnet` |
| `rt-name` | `Jenkins-route-table` | `KPS-Jenkins-route-table` |
| `sg-name` | `Jenkins-sg` | `KPS-Jenkins-sg` |
| `instance-name` | `Jenkins-server` | `KPS-Jenkins-server` |
| `key-name` | `Aman-Pathak` | `YOUR_KEY_PAIR_NAME` (placeholder) |
| `iam-role` | `Jenkins-iam-role` | **REMOVED** |

#### 3.5 backend.tf - Local Backend Option

Added local backend option and updated S3 bucket naming:

```terraform
# OPTION 1: Local backend (recommended for Learner Lab)
# backend "local" {}

# OPTION 2: S3 backend (requires manual creation first)
backend "s3" {
  bucket         = "kps-terraform-state-CHANGE_TO_YOUR_ACCOUNT_ID"
  region         = "us-east-1"
  key            = "KPS-Enterprise/Jenkins-Server-TF/terraform.tfstate"
  dynamodb_table = "kps-terraform-lock"
  encrypt        = true
}
```

---

### 4. Jenkins Pipeline Modifications (`src/Jenkins-Pipeline-Code/`)

Based on Issue #9, #11 - ECR is read-only in Learner Lab.

#### 4.1 Jenkinsfile-Backend

| Setting | Before | After |
|---------|--------|-------|
| Git URL | `AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project` | `Akawatmor/KPS-Enterprise` |
| Branch | `master` | `develop` |
| Source path | `Application-Code/backend` | `src/Application-Code/backend` |
| Image registry | ECR | Docker Hub |
| K8s manifests path | `Kubernetes-Manifests-file/Backend` | `src/Kubernetes-Manifests-file/Backend` |
| Git user | `AmanPathak-DevOps` | `Akawatmor` |

**New Environment Variables**:
```groovy
DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
DOCKERHUB_REPO = 'kps-backend'
GIT_REPO_NAME = "KPS-Enterprise"
GIT_USER_NAME = "Akawatmor"
```

#### 4.2 Jenkinsfile-Frontend

Same changes as Backend, with:
- `DOCKERHUB_REPO = 'kps-frontend'`
- Source path: `src/Application-Code/frontend`

---

### 5. Kubernetes Manifests Modifications (`src/Kubernetes-Manifests-file/`)

Based on Issue #10, #11 - ECR images replaced with Docker Hub.

#### 5.1 Backend/deployment.yaml

| Setting | Before | After |
|---------|--------|-------|
| Image | `407622020962.dkr.ecr.us-east-1.amazonaws.com/backend:1` | `DOCKERHUB_USER/kps-backend:latest` |
| imagePullSecrets | `ecr-registry-secret` | Commented out (public Docker Hub) |
| USE_DB_AUTH env | Not set | `"true"` |

#### 5.2 Frontend/deployment.yaml

| Setting | Before | After |
|---------|--------|-------|
| Image | `407622020962.dkr.ecr.us-east-1.amazonaws.com/frontend:3` | `DOCKERHUB_USER/kps-frontend:latest` |
| imagePullSecrets | `ecr-registry-secret` | Commented out |
| REACT_APP_BACKEND_URL | `http://amanpathakdevops.study/api/tasks` | `http://YOUR_ALB_DNS_OR_DOMAIN/api/tasks` |

#### 5.3 ingress.yaml

| Setting | Before | After |
|---------|--------|-------|
| Host | `amanpathakdevops.study` | Removed (use ALB DNS directly) |
| Health check annotations | Not set | Added healthcheck-path, interval, timeout |
| Tags annotation | Not set | Added Environment=demo,Project=KPS-Enterprise |

#### 5.4 Database/deployment.yaml

Added:
- Labels: `app: mongodb`, `component: database`
- Resource limits: 256Mi-512Mi memory, 100m-500m CPU
- Container name changed from `mon` to `mongodb`

#### 5.5 Database/secrets.yaml

Added documentation comments explaining:
- How to encode/decode base64 values
- Warning to change credentials in production

#### 5.6 namespace.yaml (NEW)

Created new file for easy namespace creation:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: three-tier
  labels:
    name: three-tier
    project: kps-enterprise
```

---

### 6. Docker Compose for Local Testing

#### 6.1 docker-compose.src.yml (NEW)

Created `docker/docker-compose.src.yml` to test the `src/` code:

```yaml
services:
  mongodb:
    image: mongo:4.4.6
    container_name: kps-mongodb
    ...
  backend:
    build:
      context: ../src/Application-Code/backend
    container_name: kps-backend
    ...
  frontend:
    build:
      context: ../src/Application-Code/frontend
    container_name: kps-frontend
    ...
```

---

## Local Test Results

Tested on: March 27, 2026

```bash
cd docker
docker compose -f docker-compose.src.yml up -d --build
```

### Container Status
| Container | Status | Port |
|-----------|--------|------|
| kps-mongodb | Up (healthy) | 27017 |
| kps-backend | Up | 3500 |
| kps-frontend | Up | 3000 |

### API Verification
```bash
$ curl http://localhost:3500/healthz
Healthy

$ curl http://localhost:3500/ready
Ready

$ curl -X POST http://localhost:3500/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"Phase 1 implementation test","completed":false}'
{"task":"Phase 1 implementation test","completed":false,"_id":"...","__v":0}

$ curl http://localhost:3500/api/tasks
[{"_id":"...","task":"Phase 1 implementation test","completed":false,"__v":0}]
```

**Result**: ✅ All tests passed

---

## Files Changed Summary

| Action | File | Reference |
|--------|------|-----------|
| CREATED | `src/` directory structure | Plan |
| MODIFIED | `src/Application-Code/backend/db.js` | Issue #6, #7 |
| MODIFIED | `src/Application-Code/frontend/package.json` | Issue #5, #7 |
| DELETED | `src/Jenkins-Server-TF/iam-role.tf` | Issue #8, #11 |
| DELETED | `src/Jenkins-Server-TF/iam-policy.tf` | Issue #8, #11 |
| DELETED | `src/Jenkins-Server-TF/iam-instance-profile.tf` | Issue #8, #11 |
| MODIFIED | `src/Jenkins-Server-TF/ec2.tf` | Issue #8, #11 |
| MODIFIED | `src/Jenkins-Server-TF/variables.tf` | Issue #8, #11 |
| MODIFIED | `src/Jenkins-Server-TF/variables.tfvars` | Issue #8, #11 |
| MODIFIED | `src/Jenkins-Server-TF/backend.tf` | Issue #8, #11 |
| MODIFIED | `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend` | Issue #9, #11 |
| MODIFIED | `src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend` | Issue #9, #11 |
| MODIFIED | `src/Kubernetes-Manifests-file/Backend/deployment.yaml` | Issue #10, #11 |
| MODIFIED | `src/Kubernetes-Manifests-file/Frontend/deployment.yaml` | Issue #10, #11 |
| MODIFIED | `src/Kubernetes-Manifests-file/ingress.yaml` | Issue #10, #11 |
| MODIFIED | `src/Kubernetes-Manifests-file/Database/deployment.yaml` | Issue #10 |
| MODIFIED | `src/Kubernetes-Manifests-file/Database/secrets.yaml` | Issue #10 |
| CREATED | `src/Kubernetes-Manifests-file/namespace.yaml` | Issue #10 |
| CREATED | `docker/docker-compose.src.yml` | Local testing |
| CREATED | `document/phase1/implement-result.md` | This document |

---

## Next Steps (Not Done Yet)

The following items require AWS credentials and manual configuration:

1. **Create SSH Key Pair** in AWS Console
2. **Update `variables.tfvars`** with actual key pair name
3. **Create S3 Bucket & DynamoDB Table** for Terraform state (or use local backend)
4. **Create Docker Hub Account** and add credentials to Jenkins
5. **Run Terraform** to provision Jenkins server
6. **Configure Jenkins** plugins, credentials, and tools
7. **Create EKS Cluster** using eksctl with LabEksClusterRole
8. **Deploy Application** to EKS

---

## References

- Issue #4: Backend Source Code Documentation
- Issue #5: Frontend Source Code Documentation
- Issue #6: MongoDB Schema and Connection Configuration
- Issue #7: Local Docker Test Report
- Issue #8: Terraform Files Analysis
- Issue #9: Jenkins Pipeline Analysis
- Issue #10: Kubernetes Manifests Analysis
- Issue #11: AWS Learner Lab Limitations and Required Modifications

---

*Document created: March 27, 2026*
*Branch: phase1-implementation*
*Status: Ready for review*
