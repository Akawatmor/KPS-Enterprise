# Phase 1 Week 2: Implementation Guide

## KPS-Enterprise Three-Tier DevSecOps Application

**Document Version**: 1.0  
**Branch**: `phase1-implementation`  
**Last Updated**: March 2026

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Quick Start](#quick-start)
5. [Detailed Deployment Guide](#detailed-deployment-guide)
6. [Verification Procedures](#verification-procedures)
7. [Jenkins Pipeline Configuration](#jenkins-pipeline-configuration)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Cost Considerations](#cost-considerations)
10. [Security Considerations](#security-considerations)
11. [Cleanup Procedures](#cleanup-procedures)

---

## Executive Summary

This document provides comprehensive instructions for deploying the KPS-Enterprise three-tier DevSecOps application to AWS Learner Lab. The implementation covers:

- **Infrastructure**: Jenkins EC2 server with CI/CD tools (Terraform)
- **Container Orchestration**: EKS cluster with 3 worker nodes
- **Application**: MongoDB + Node.js Backend + React Frontend
- **CI/CD Pipeline**: Jenkins with SonarQube, OWASP, Trivy integration
- **Container Registry**: Docker Hub (ECR is read-only in Learner Lab)

### Key Adaptations for Learner Lab

| Component | Original | Learner Lab Adaptation |
|-----------|----------|----------------------|
| Instance Type | t2.2xlarge | t3.large (max allowed) |
| IAM Roles | Custom roles | LabRole, LabInstanceProfile |
| Container Registry | AWS ECR | Docker Hub |
| EKS Cluster Role | Custom role | LabEksClusterRole |

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| AWS CLI | v2.x | AWS resource management | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip && unzip awscliv2.zip && sudo ./aws/install` |
| Terraform | v1.0+ | Infrastructure as Code | `sudo apt install terraform` |
| kubectl | v1.28+ | Kubernetes CLI | `curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"` |
| eksctl | latest | EKS cluster management | `curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \| tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin` |
| Helm | v3.x | Kubernetes package manager | `sudo snap install helm --classic` |
| Docker | 20.x+ | Container runtime | `sudo apt install docker.io` |

### AWS Learner Lab Requirements

1. **Active Learner Lab Session**
   - Session duration: 4 hours (can be extended)
   - Budget: $100 (sufficient for this deployment)

2. **AWS Credentials**
   - Copy credentials from Learner Lab: AWS Details → AWS CLI
   - Update `~/.aws/credentials`:
     ```ini
     [default]
     aws_access_key_id=YOUR_ACCESS_KEY
     aws_secret_access_key=YOUR_SECRET_KEY
     aws_session_token=YOUR_SESSION_TOKEN
     ```

3. **SSH Key Pair**
   - Create in AWS Console: EC2 → Key Pairs → Create key pair
   - Download `.pem` file to `~/.ssh/`
   - Set permissions: `chmod 400 ~/.ssh/your-key.pem`

### External Accounts

1. **Docker Hub Account**
   - Sign up at: https://hub.docker.com/
   - Create access token: Account Settings → Security → Access Tokens

2. **GitHub Account** (for pipeline)
   - Create Personal Access Token: Settings → Developer Settings → Personal Access Tokens
   - Scopes needed: `repo`, `workflow`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Learner Lab                                 │
│                                                                             │
│  ┌────────────────────────┐      ┌────────────────────────────────────────┐ │
│  │   Jenkins EC2 (t3.large)│      │          EKS Cluster                   │ │
│  │                        │      │                                        │ │
│  │  ┌────────────────┐   │      │  ┌─────────────────────────────────┐  │ │
│  │  │    Jenkins     │   │      │  │    Worker Nodes (3x t3.large)   │  │ │
│  │  │    :8080       │   │      │  │                                 │  │ │
│  │  └────────────────┘   │      │  │  ┌─────┐  ┌─────┐  ┌─────┐     │  │ │
│  │  ┌────────────────┐   │      │  │  │Front│  │Back │  │Mongo│     │  │ │
│  │  │   SonarQube    │   │      │  │  │end  │  │end  │  │DB   │     │  │ │
│  │  │    :9000       │   │      │  │  │:3000│  │:3500│  │:2701│     │  │ │
│  │  └────────────────┘   │      │  │  └─────┘  └─────┘  └─────┘     │  │ │
│  │  ┌────────────────┐   │      │  └─────────────────────────────────┘  │ │
│  │  │    Docker      │   │      │                                        │ │
│  │  └────────────────┘   │      │  ┌─────────────────────────────────┐  │ │
│  └────────────────────────┘      │  │    ALB (Application LB)         │  │ │
│                                  │  │    Internet-facing              │  │ │
│                                  │  └─────────────────────────────────┘  │ │
│                                  └────────────────────────────────────────┘ │
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │   Docker Hub    │  ← Images pushed from Jenkins                          │
│  │ (External)      │  → Images pulled by EKS                                │
│  └─────────────────┘                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Resource Allocation

| Component | Instance Type | Count | vCPU | RAM |
|-----------|--------------|-------|------|-----|
| Jenkins Server | t3.large | 1 | 2 | 8 GB |
| EKS Control Plane | Managed | 1 | - | - |
| EKS Worker Nodes | t3.large | 3 | 6 | 24 GB |
| **Total** | - | **4** | **8** | **32 GB** |

**Within Learner Lab limits**: ✅ 4/9 instances, ✅ 8/32 vCPUs

---

## Quick Start

### One-Command Deployment

```bash
# Navigate to implementation directory
cd implementation/phase1

# Make scripts executable
chmod +x start.sh destroy.sh
chmod +x scripts/**/*.sh

# Start deployment (interactive)
./start.sh
```

### Manual Step-by-Step

```bash
# 1. Deploy Jenkins EC2
./scripts/terraform/start-terraform.sh

# 2. Create EKS Cluster (15-20 min)
./scripts/eks/start-eks.sh

# 3. Install Controllers
./scripts/eks/install-controllers.sh

# 4. Build & Push Images
./scripts/app/build-images.sh

# 5. Deploy Application
./scripts/app/deploy-app.sh
```

---

## Detailed Deployment Guide

### Issue #16: Remove IAM Resources from Terraform

**Status**: ✅ Already completed in Week 1

The following files have been removed from `src/Jenkins-Server-TF/`:
- ❌ `iam-role.tf` (deleted)
- ❌ `iam-policy.tf` (deleted)
- ❌ `iam-instance-profile.tf` (deleted)

The `ec2.tf` file has been updated to use `LabInstanceProfile`.

**Verification**:
```bash
cd src/Jenkins-Server-TF
ls iam*.tf  # Should return "No such file or directory"
grep "LabInstanceProfile" ec2.tf  # Should show the reference
```

---

### Issue #17: Fix Terraform Configuration

**Status**: ✅ Completed

**Changes Made**:
- Instance type: `t3.large` (from `t2.2xlarge`)
- Key pair: Placeholder `YOUR_KEY_PAIR_NAME` (must be updated)
- Resource naming: Prefixed with `KPS-`
- Backend: Option for local or S3 backend

**Before Deployment**:
1. Edit `src/Jenkins-Server-TF/variables.tfvars`
2. Change `key-name = "YOUR_KEY_PAIR_NAME"` to your actual key pair name

**Verification**:
```bash
cd src/Jenkins-Server-TF
terraform validate
```

---

### Issue #18: Provision Jenkins EC2 Server

**Estimated Time**: 3-5 minutes

**Steps**:
```bash
# Run the Terraform deployment script
./scripts/terraform/start-terraform.sh
```

**What Gets Created**:
- VPC: `KPS-Jenkins-vpc` (10.0.0.0/16)
- Subnet: `KPS-Jenkins-subnet` (public)
- Internet Gateway: `KPS-Jenkins-igw`
- Security Group: Ports 22, 80, 8080, 9000, 9090
- EC2 Instance: `KPS-Jenkins-server` (t3.large, Ubuntu 22.04)

**Verification**:
```bash
# Check EC2 is running
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=KPS-Jenkins-server" \
  --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,IP:PublicIpAddress}'

# SSH into server
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Check installed tools
docker --version
jenkins --version
kubectl version --client
eksctl version
trivy --version
```

---

### Issue #19: Configure Jenkins Server

**Estimated Time**: 15-20 minutes (manual configuration)

**Steps**:

1. **Get Initial Admin Password**
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```

2. **Access Jenkins UI**
   - URL: `http://<EC2_PUBLIC_IP>:8080`
   - Enter initial admin password
   - Select "Install suggested plugins"
   - Create admin user

3. **Install Additional Plugins**
   Navigate to: Manage Jenkins → Plugins → Available plugins
   
   Install:
   - Docker, Docker Pipeline
   - Kubernetes CLI, Kubernetes
   - SonarQube Scanner
   - OWASP Dependency-Check
   - NodeJS

4. **Configure Global Tools**
   Navigate to: Manage Jenkins → Tools
   
   | Tool | Name | Version |
   |------|------|---------|
   | JDK | jdk | OpenJDK 17 |
   | NodeJS | nodejs | 18.x |
   | SonarQube Scanner | sonar-scanner | Latest |
   | OWASP Dependency-Check | DP-Check | Latest |

5. **Add Credentials**
   Navigate to: Manage Jenkins → Credentials → (global)
   
   | ID | Type | Description |
   |----|------|-------------|
   | github-token | Secret text | GitHub Personal Access Token |
   | GITHUB | Username/Password | GitHub username + PAT |
   | dockerhub-credentials | Username/Password | Docker Hub username + access token |
   | sonar-token | Secret text | SonarQube authentication token |

**Verification**:
- Jenkins UI accessible ✅
- All plugins installed ✅
- Tools configured ✅
- Credentials added ✅

---

### Issue #20: Configure SonarQube Server

**Steps**:

1. **Access SonarQube**
   - URL: `http://<EC2_PUBLIC_IP>:9000`
   - Default credentials: `admin` / `admin`
   - Change password immediately

2. **Create Projects**
   - Administration → Projects → Management
   - Create Project: `kps-backend`
   - Create Project: `kps-frontend`

3. **Generate Token**
   - My Account → Security → Generate Tokens
   - Name: `jenkins-token`
   - Copy the token

4. **Configure Jenkins Integration**
   - In Jenkins: Manage Jenkins → System → SonarQube servers
   - Add SonarQube installation:
     - Name: `sonar-server`
     - Server URL: `http://localhost:9000`
     - Server authentication token: `sonar-token` (credential)

**Verification**:
```bash
# Test SonarQube API
curl http://<EC2_PUBLIC_IP>:9000/api/system/status
# Should return: {"status":"UP"}
```

---

### Issue #21: Create EKS Cluster

**Estimated Time**: 15-20 minutes

**Steps**:
```bash
./scripts/eks/start-eks.sh
```

**Configuration**:
- Cluster Name: `kps-three-tier-cluster`
- Region: `us-east-1`
- Kubernetes Version: `1.28`
- Node Group: `3x t3.large`
- IAM: Uses `LabEksClusterRole` and `LabRole`

**Verification**:
```bash
# Check cluster
eksctl get cluster --name kps-three-tier-cluster --region us-east-1

# Check nodes
kubectl get nodes -o wide

# Check namespaces
kubectl get namespaces
```

---

### Issue #22: Install EKS Controllers

**Estimated Time**: 5-10 minutes

**Steps**:
```bash
./scripts/eks/install-controllers.sh
```

**Components Installed**:
1. **AWS Load Balancer Controller**: Manages ALB for Kubernetes Ingress
2. **AWS EBS CSI Driver**: Enables EBS volumes for PersistentVolumes

**Verification**:
```bash
# Check Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Check EBS CSI Driver
kubectl get daemonset -n kube-system ebs-csi-node

# Check CSI Drivers
kubectl get csidriver

# Check Storage Classes
kubectl get storageclass
```

---

### Issue #23: Set Up Docker Hub Repositories

**Note**: We use Docker Hub instead of ECR because ECR is read-only in Learner Lab.

**Steps**:

1. **Create Docker Hub Account** (if not already done)
   - Sign up at https://hub.docker.com/

2. **Create Repositories**
   - Repository 1: `<username>/kps-backend`
   - Repository 2: `<username>/kps-frontend`
   - Visibility: Public (or Private with access token)

3. **Generate Access Token**
   - Account Settings → Security → Access Tokens
   - Generate new token with Read/Write permissions

**Verification**:
```bash
# Test Docker Hub login
echo "YOUR_TOKEN" | docker login -u YOUR_USERNAME --password-stdin
```

---

### Issue #24-25: Build and Push Docker Images

**Steps**:
```bash
./scripts/app/build-images.sh
```

The script will:
1. Prompt for Docker Hub username
2. Prompt for Docker Hub access token
3. Build backend image: `<username>/kps-backend:v1.0`
4. Build frontend image: `<username>/kps-frontend:v1.0`
5. Push both images to Docker Hub

**Verification**:
```bash
# Test pull images
docker pull <username>/kps-backend:v1.0
docker pull <username>/kps-frontend:v1.0

# Check Docker Hub web UI
# https://hub.docker.com/u/<username>
```

---

### Issue #26-27: Update Jenkinsfiles and K8s Manifests

**Status**: ✅ Completed in Week 1 (src/ already updated)

The manifests use placeholder `DOCKERHUB_USER` which is automatically replaced by:
- The deployment script (`deploy-app.sh`)
- The Jenkins pipeline

**Files Updated**:
- `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend`
- `src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend`
- `src/Kubernetes-Manifests-file/Backend/deployment.yaml`
- `src/Kubernetes-Manifests-file/Frontend/deployment.yaml`
- `src/Kubernetes-Manifests-file/ingress.yaml`

---

### Issue #28: Deploy MongoDB

**Steps**:
```bash
# Included in deploy-app.sh, or manually:
kubectl apply -f src/Kubernetes-Manifests-file/namespace.yaml
kubectl apply -f src/Kubernetes-Manifests-file/Database/
```

**Verification**:
```bash
# Check MongoDB pod
kubectl get pods -n three-tier -l app=mongodb

# Check PVC
kubectl get pvc -n three-tier

# Check logs
kubectl logs -n three-tier -l app=mongodb
```

---

### Issue #29: Deploy Backend and Frontend

**Steps**:
```bash
./scripts/app/deploy-app.sh
```

The script deploys in order:
1. Namespace (three-tier)
2. MongoDB (secrets, pvc, deployment, service)
3. Backend (deployment, service)
4. Frontend (deployment, service)
5. Ingress (ALB)

**Verification**:
```bash
# Check all pods
kubectl get pods -n three-tier

# Expected output:
# NAME                        READY   STATUS    RESTARTS
# api-xxxxxxxxxx-xxxxx        1/1     Running   0
# api-xxxxxxxxxx-xxxxx        1/1     Running   0
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   0
# frontend-xxxxxxxxxx-xxxxx   1/1     Running   0
# mongodb-xxxxxxxxxx-xxxxx    1/1     Running   0
```

---

### Issue #30: Deploy Ingress and Verify End-to-End

**Estimated Time**: 3-5 minutes for ALB provisioning

**Steps**:
```bash
# Get ALB DNS
kubectl get ingress -n three-tier

# Test endpoints
curl http://<ALB_DNS>/                    # Frontend
curl http://<ALB_DNS>/api/tasks           # Backend API
curl http://<ALB_DNS>/api/healthz         # Health check
```

**Full E2E Test**:
1. Open browser to `http://<ALB_DNS>/`
2. Create a new task
3. Verify task appears in the list
4. Mark task as complete
5. Delete the task
6. Verify task is removed

---

### Issue #31-32: Run Jenkins Pipelines

**Steps**:

1. **Create Pipeline Jobs in Jenkins**

   **Backend Pipeline**:
   - New Item → Pipeline
   - Name: `kps-backend-pipeline`
   - Pipeline from SCM: Git
   - Repository: `https://github.com/Akawatmor/KPS-Enterprise.git`
   - Branch: `*/phase1-implementation`
   - Script Path: `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend`

   **Frontend Pipeline**:
   - Same as above with:
   - Name: `kps-frontend-pipeline`
   - Script Path: `src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend`

2. **Run Pipelines**
   - Click "Build Now" on each pipeline
   - Monitor the build stages

**Pipeline Stages**:
1. Cleaning Workspace
2. Checkout from Git
3. SonarQube Analysis
4. Quality Check
5. OWASP Dependency-Check
6. Trivy File Scan
7. Docker Image Build
8. Docker Hub Image Push
9. Trivy Image Scan
10. Update Deployment File

**Verification**:
- All stages green ✅
- SonarQube shows analysis results
- Docker Hub has new image tags
- Kubernetes deployment updated

---

## Verification Procedures

### Infrastructure Verification

```bash
# AWS Resources
aws ec2 describe-instances --filters "Name=tag:Name,Values=KPS-*"
aws eks list-clusters --region us-east-1

# Kubernetes
kubectl get nodes
kubectl get pods -n three-tier
kubectl get svc -n three-tier
kubectl get ingress -n three-tier
```

### Application Verification

```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress -n three-tier -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')

# Test endpoints
curl -s http://$ALB_DNS/api/healthz | jq
curl -s http://$ALB_DNS/api/tasks | jq

# Create a task
curl -X POST http://$ALB_DNS/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"Test task","completed":false}'
```

### Jenkins Pipeline Verification

```bash
# Check latest build
curl -s http://<JENKINS_IP>:8080/job/kps-backend-pipeline/lastBuild/api/json | jq '.result'

# Check SonarQube analysis
curl -s http://<JENKINS_IP>:9000/api/qualitygates/project_status?projectKey=kps-backend
```

---

## Troubleshooting Guide

### Common Issues

#### 1. Terraform: "Error: Forbidden"

**Cause**: AWS Learner Lab session expired or credentials invalid.

**Solution**:
```bash
# Refresh credentials from Learner Lab
# AWS Details → AWS CLI → Copy credentials to ~/.aws/credentials
aws sts get-caller-identity  # Verify
```

#### 2. EKS: Cluster creation fails

**Cause**: IAM role not found or incorrect permissions.

**Solution**:
```bash
# Verify LabEksClusterRole exists
aws iam get-role --role-name LabEksClusterRole

# If not found, the Learner Lab may not support EKS
# Check with instructor
```

#### 3. ALB: Ingress stuck in "pending"

**Cause**: AWS Load Balancer Controller not working properly.

**Solution**:
```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify IAM permissions
kubectl describe serviceaccount -n kube-system aws-load-balancer-controller
```

#### 4. Pods: ImagePullBackOff

**Cause**: Cannot pull image from Docker Hub.

**Solution**:
```bash
# Check image name
kubectl describe pod -n three-tier <pod-name>

# Verify image exists
docker pull <username>/kps-backend:v1.0

# If private repo, create imagePullSecret
kubectl create secret docker-registry dockerhub-secret \
  -n three-tier \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<username> \
  --docker-password=<token>
```

#### 5. MongoDB: CrashLoopBackOff

**Cause**: PVC not bound or permissions issue.

**Solution**:
```bash
# Check PVC status
kubectl get pvc -n three-tier

# Check events
kubectl describe pod -n three-tier mongodb-xxxxx

# If PVC pending, verify EBS CSI driver
kubectl get csidriver | grep ebs
```

#### 6. Jenkins: Pipeline fails at Docker stage

**Cause**: Docker daemon not running or permissions.

**Solution**:
```bash
# SSH into Jenkins server
ssh -i ~/.ssh/key.pem ubuntu@<JENKINS_IP>

# Check Docker
sudo systemctl status docker

# Add Jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

---

## Cost Considerations

### AWS Learner Lab Budget

| Resource | Est. Cost/Hour | Usage | Daily Est. |
|----------|---------------|-------|------------|
| EC2 t3.large (Jenkins) | $0.0832 | 8 hours | $0.67 |
| EKS Cluster | $0.10 | 8 hours | $0.80 |
| EC2 t3.large (3 nodes) | $0.2496 | 8 hours | $2.00 |
| EBS (50 GB) | $0.02 | 8 hours | $0.01 |
| ALB | $0.0225 | 8 hours | $0.18 |
| **Total** | - | - | **~$3.66** |

**Monthly Budget**: $100 (sufficient for ~27 days of 8-hour usage)

### Cost Optimization

1. **Stop resources when not in use**
   ```bash
   ./destroy.sh --component app  # Keep EKS, remove app
   ```

2. **Use smaller instance types for testing**
   - Modify `eks-cluster-config.yaml` to use `t3.medium`

3. **Delete unused EBS volumes**
   ```bash
   aws ec2 describe-volumes --filters "Name=status,Values=available"
   ```

---

## Security Considerations

### Implemented Security Measures

1. **SAST**: SonarQube code analysis
2. **SCA**: OWASP Dependency-Check
3. **Container Scanning**: Trivy filesystem and image scan
4. **Secrets Management**: Kubernetes Secrets (base64 encoded)
5. **Network Security**: Security Groups with minimal ports

### Recommended Improvements (Phase 2)

1. **HTTPS**: Add TLS termination on ALB
2. **Network Policies**: Restrict pod-to-pod traffic
3. **Pod Security**: Add security contexts
4. **Secrets**: Use AWS Secrets Manager
5. **RBAC**: Configure Kubernetes RBAC policies

---

## Cleanup Procedures

### Full Cleanup

```bash
./destroy.sh
```

This will remove:
1. Application from EKS (pods, services, ingress)
2. EKS cluster and node groups
3. Jenkins EC2 and VPC resources
4. Local state files

### Partial Cleanup

```bash
# Remove only application
./destroy.sh --component app

# Remove EKS but keep Jenkins
./destroy.sh --component eks

# Remove only Jenkins infrastructure
./destroy.sh --component terraform
```

### Manual Cleanup

If scripts fail, manually delete in this order:

1. **Kubernetes Resources**
   ```bash
   kubectl delete namespace three-tier
   ```

2. **EKS Cluster**
   ```bash
   eksctl delete cluster --name kps-three-tier-cluster --region us-east-1
   ```

3. **Terraform Resources**
   ```bash
   cd src/Jenkins-Server-TF
   terraform destroy -var-file=variables.tfvars
   ```

4. **Check AWS Console**
   - EC2 Instances
   - Load Balancers
   - CloudFormation Stacks
   - VPCs

---

## References

- [AWS Learner Lab Guide](https://aws.amazon.com/training/digital/aws-learner-lab/)
- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Original Project Repository](https://github.com/AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project)
- [Phase 1 Week 1 Analysis](../../document/phase1/)

---

**Document maintained by**: KPS-Enterprise Team  
**Issues**: https://github.com/Akawatmor/KPS-Enterprise/issues

---

## Deployment Results (Verified)

### Learner Lab Constraints Found During Deployment

During actual deployment, the following Learner Lab constraints were discovered:

1. **OIDC Provider Cannot Be Created**
   - AWS Learner Lab does not allow creating OIDC identity providers
   - This affects AWS Load Balancer Controller (cannot use ALB Ingress)
   - This affects AWS EBS CSI Driver (cannot provision EBS volumes)

2. **Workarounds Applied**:
   - **LoadBalancer**: Use Classic ELB via `type: LoadBalancer` services instead of ALB Ingress
   - **Storage**: Use `emptyDir` for MongoDB instead of PersistentVolumeClaim
   - **ECR**: ECR repositories CAN be created (contrary to initial analysis)

### Successful Deployment Configuration

#### EKS Cluster
- **Name**: kps-three-tier-cluster
- **Region**: us-east-1
- **K8s Version**: 1.30
- **Nodes**: 3x t3.large (Amazon Linux 2023)
- **Namespace**: three-tier

#### Container Images (ECR)
- Backend: `533267353075.dkr.ecr.us-east-1.amazonaws.com/kps-backend:latest`
- Frontend: `533267353075.dkr.ecr.us-east-1.amazonaws.com/kps-frontend:latest`

#### Services
| Service | Type | Port | Notes |
|---------|------|------|-------|
| mongodb-svc | ClusterIP | 27017 | Internal MongoDB |
| api | ClusterIP | 3500 | Internal Backend API |
| frontend | ClusterIP | 3000 | Internal Frontend |
| api-lb | LoadBalancer | 80 | External API access |
| frontend-lb | LoadBalancer | 80 | External Frontend access |

#### MongoDB Configuration
- Uses `emptyDir` storage (data is NOT persistent across pod restarts)
- Authentication disabled for simplicity
- For production: consider managed MongoDB (Atlas) or external database

### Access URLs
```
Frontend: http://af36b63cfae984318adf8e74c84c1287-678915922.us-east-1.elb.amazonaws.com
API:      http://ae4dae8809faf41849ac8e6b1e7df5e7-567901827.us-east-1.elb.amazonaws.com/api/tasks
Jenkins:  http://44.192.88.178:8080
```

### Key Changes from Original Plan

| Original Plan | Actual Implementation | Reason |
|---------------|----------------------|--------|
| K8s 1.28 | K8s 1.30 | 1.28 deprecated |
| ALB Ingress | Classic ELB | OIDC not available |
| EBS PVC | emptyDir | EBS CSI requires OIDC |
| Docker Hub | ECR | ECR works in this Lab |
| MongoDB with auth | MongoDB no auth | Simpler demo setup |

### Verification Commands

```bash
# Check all pods
kubectl get pods -n three-tier

# Check services
kubectl get svc -n three-tier

# Test API
curl http://<api-lb>/api/tasks

# Create task
curl -X POST http://<api-lb>/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"My Task"}'

# Check nodes
kubectl get nodes
```

