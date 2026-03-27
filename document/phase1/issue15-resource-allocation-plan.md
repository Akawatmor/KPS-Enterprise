# Issue #15: AWS Learner Lab Resource Allocation Plan

**Issue**: [#15 - Plan resource allocation for AWS Learner Lab deployment](https://github.com/Akawatmor/KPS-Enterprise/issues/15)  
**Milestone**: Phase 1 - Week 1  
**Date**: March 26, 2026  
**Status**: ✅ COMPLETED

---

## Executive Summary

This document provides a detailed resource allocation plan for deploying the KPS-Enterprise three-tier DevSecOps application within AWS Learner Lab constraints. All decisions have been carefully calculated to stay within the strict limits while maximizing performance and reliability.

---

## 📋 AWS Learner Lab Constraints

### Hard Limits (Cannot Exceed)

| Constraint | Limit | Notes |
|-----------|-------|-------|
| **Max Concurrent EC2 Instances** | 9 instances | Across all services (EC2, EKS nodes, etc.) |
| **Max Total vCPUs** | 32 vCPUs | Concurrent running instances only |
| **Max Instance Types** | nano, micro, small, medium, **large** | ✅ Large is the maximum (exception: Cloud9 can use c4.xlarge) |
| **Max EBS Volume Size** | 100 GB | Per volume |
| **Supported Regions** | us-east-1, us-west-2 | Only these two regions |

### Instance Type Specifications

| Instance Type | vCPUs | RAM | Network | Use Case | Allowed? |
|--------------|-------|-----|---------|----------|----------|
| **t3.nano** | 2 | 0.5 GB | Up to 5 Gbps | Minimal workloads | ✅ Yes |
| **t3.micro** | 2 | 1 GB | Up to 5 Gbps | Light workloads | ✅ Yes |
| **t3.small** | 2 | 2 GB | Up to 5 Gbps | Development | ✅ Yes |
| **t3.medium** | 2 | 4 GB | Up to 5 Gbps | Small apps | ✅ Yes |
| **t3.large** | 2 | 8 GB | Up to 5 Gbps | **Production apps** | ✅ Yes (Recommended) |
| **t3.xlarge** | 4 | 16 GB | Up to 5 Gbps | Heavy workloads | ❌ **NO** |
| **t2.large** | 2 | 8 GB | Moderate | **Alternative to t3.large** | ✅ Yes |
| **t2.xlarge** | 4 | 16 GB | Moderate | Heavy workloads | ❌ **NO** |
| **t2.2xlarge** | 8 | 32 GB | Moderate | Very heavy | ❌ **NO** |

**Key Finding**: Maximum usable instance type is **`*.large`** (2 vCPU, 8 GB RAM)

---

## 🎯 Resource Allocation Decisions

### Decision 1: Jenkins EC2 Instance Type

**Requirement**: Run Jenkins + SonarQube + Docker + CI/CD tools

**Options Evaluated**:

| Option | vCPUs | RAM | Status | Reasoning |
|--------|-------|-----|--------|-----------|
| t3.xlarge | 4 | 16 GB | ❌ **NOT ALLOWED** | Exceeds "large" limit |
| t2.xlarge | 4 | 16 GB | ❌ **NOT ALLOWED** | Exceeds "large" limit |
| **t3.large** | **2** | **8 GB** | ✅ **SELECTED** | Maximum allowed, modern architecture |
| t2.large | 2 | 8 GB | ✅ Alternative | Older generation, same specs |
| t3.medium | 2 | 4 GB | ⚠️ Insufficient | Not enough RAM for Jenkins + SonarQube |

**Final Decision**: **`t3.large`** (2 vCPU, 8 GB RAM)

**Rationale**:
- ✅ Maximum allowed instance type in Learner Lab
- ✅ t3 generation is newer and more efficient than t2
- ✅ Burstable performance for CI/CD workloads
- ✅ 8 GB RAM sufficient for Jenkins + SonarQube (with optimization)
- ⚠️ Will require careful resource optimization (Docker layer caching, limited concurrent builds)

**Performance Considerations**:
- **Original Design**: t2.2xlarge (8 vCPU, 32 GB) - **75% reduction in resources**
- **Impact**: 
  - Longer build times (expected 2-3x slower)
  - Limit to 1-2 concurrent pipeline executions
  - SonarQube analysis will be slower
  - Requires aggressive Docker layer caching
- **Mitigation**:
  - Optimize Jenkins heap size (max 4 GB)
  - Run SonarQube in container with 2 GB limit
  - Use Docker layer caching extensively
  - Minimize concurrent builds
  - Consider using Jenkins agents if needed (adds more instances)

---

### Decision 2: EKS Node Count and Instance Type

**Requirement**: Run 3-tier application (Frontend + Backend + MongoDB) with high availability

**Options Evaluated**:

#### Option A: Minimal (2 nodes)
```
Node Count: 2x t3.large
vCPUs: 2 x 2 = 4 vCPUs
Total RAM: 2 x 8 GB = 16 GB
```
- ✅ Minimal resource usage
- ❌ No high availability (need 3+ for quorum)
- ❌ Insufficient for 3-tier app with replicas
- **Verdict**: ❌ Not recommended

#### Option B: Standard (3 nodes) - **RECOMMENDED**
```
Node Count: 3x t3.large
vCPUs: 3 x 2 = 6 vCPUs
Total RAM: 3 x 8 GB = 24 GB
```
- ✅ High availability (3 nodes)
- ✅ Sufficient for 3-tier app with 2 replicas for backend
- ✅ Good balance of resources and limits
- ✅ Allows for pod distribution and redundancy
- **Verdict**: ✅ **SELECTED**

#### Option C: Extended (4 nodes)
```
Node Count: 4x t3.large
vCPUs: 4 x 2 = 8 vCPUs
Total RAM: 4 x 8 GB = 32 GB
```
- ✅ More capacity
- ✅ Better distribution
- ⚠️ Uses more of instance quota
- **Verdict**: ⚠️ Reserved as scaling option

#### Option D: Alternative (4x t3.medium)
```
Node Count: 4x t3.medium
vCPUs: 4 x 2 = 8 vCPUs
Total RAM: 4 x 4 GB = 16 GB
```
- ⚠️ Same vCPU, less RAM
- ❌ Only 4 GB per node may cause OOMKilled issues
- **Verdict**: ❌ Not recommended

**Final Decision**: **3x t3.large** (6 vCPUs total, 24 GB RAM total)

**Rationale**:
- ✅ Provides high availability (3-node quorum)
- ✅ Sufficient RAM for 3-tier application workload
- ✅ 8 GB per node allows for multiple pods without memory pressure
- ✅ Leaves room in instance quota for scaling (6/9 instances used with Jenkins)
- ✅ Leaves room in vCPU quota for additional resources (8/32 vCPUs used with Jenkins)

**Workload Distribution**:
```
Node 1: Frontend (1 replica), Backend (1 replica)
Node 2: Backend (1 replica), MongoDB
Node 3: Frontend (spare), Backend (spare), system pods
```

---

### Decision 3: Total Resource Allocation

#### Final Infrastructure Layout

| Component | Count | Instance Type | vCPU/Instance | Total vCPU | RAM/Instance | Total RAM | Notes |
|-----------|-------|--------------|---------------|-----------|--------------|-----------|-------|
| **Jenkins Server** | 1 | t3.large | 2 | 2 | 8 GB | 8 GB | CI/CD + SonarQube |
| **EKS Control Plane** | 1 | (AWS Managed) | - | 0 | - | - | No vCPU charge |
| **EKS Worker Nodes** | 3 | t3.large | 2 | 6 | 8 GB | 24 GB | Application workload |
| **Reserved/Buffer** | - | - | - | - | - | - | For scaling/testing |
| **TOTAL USED** | **4** | - | - | **8** | - | **32 GB** | - |

#### Resource Utilization

| Metric | Used | Limit | Available | Utilization |
|--------|------|-------|-----------|-------------|
| **EC2 Instances** | 4 | 9 | 5 | 44% |
| **vCPUs** | 8 | 32 | 24 | 25% |

**Status**: ✅ **WELL WITHIN LIMITS** with significant buffer for scaling

---

### Decision 4: Terraform Backend Strategy

**Options Evaluated**:

#### Option A: Local State (terraform.tfstate file)
- ✅ Simple setup, no prerequisites
- ✅ No S3 bucket required
- ❌ Not suitable for team collaboration
- ❌ No state locking
- ❌ State file can be lost if machine fails
- ❌ Cannot share state between team members
- **Use Case**: Single developer, testing only

#### Option B: S3 Backend with DynamoDB Locking - **RECOMMENDED**
- ✅ Team collaboration (shared state)
- ✅ State locking prevents concurrent modifications
- ✅ State versioning for rollback
- ✅ Encrypted storage
- ⚠️ Requires manual creation of S3 bucket and DynamoDB table first
- **Use Case**: Production, team collaboration

**Final Decision**: **S3 Backend with DynamoDB Locking**

**Implementation**:

1. **Pre-requisites** (Manual creation required):
```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://kps-enterprise-terraform-state --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket kps-enterprise-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name kps-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

2. **Terraform Backend Configuration** (`backend.tf`):
```hcl
terraform {
  backend "s3" {
    bucket         = "kps-enterprise-terraform-state"
    key            = "jenkins-server/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "kps-terraform-state-lock"
  }
}
```

**Rationale**:
- ✅ Supports team collaboration (multiple team members)
- ✅ State locking prevents conflicts
- ✅ State versioning allows rollback if needed
- ✅ Industry best practice for production deployments
- ⚠️ Requires one-time manual setup before running Terraform

---

### Decision 5: Container Registry Strategy

**Options Evaluated**:

#### Option A: AWS ECR (Elastic Container Registry)
- ✅ Native AWS integration
- ✅ Private, secure
- ✅ No rate limits
- ❌ **LabRole has READ-ONLY access** (cannot push images)
- ❌ Cannot create new repositories
- **Verdict**: ❌ **NOT USABLE** for CI/CD pipeline

#### Option B: Docker Hub (Public Repository) - **COST EFFECTIVE**
- ✅ Free for public repositories
- ✅ Easy integration with Jenkins
- ✅ No AWS permissions required
- ⚠️ Rate limits: 100 pulls/6hrs (anonymous), 200 pulls/6hrs (authenticated)
- ⚠️ Images are publicly visible
- ❌ Not suitable for proprietary code
- **Use Case**: Open source projects, demos, learning

#### Option C: Docker Hub (Private Repository) - **RECOMMENDED**
- ✅ Private images (secure)
- ✅ 200 pulls/6hrs with authentication
- ✅ Easy Jenkins integration
- ✅ No AWS permissions required
- ✅ Works across AWS sessions (persistent)
- ⚠️ Cost: $5/month for 1 private repository (Pro plan) or $0 with free tier (1 private repo)
- **Use Case**: Private projects, production

#### Option D: GitHub Container Registry (ghcr.io)
- ✅ Free for public repositories
- ✅ Private repositories included with GitHub account
- ✅ Good integration with GitHub Actions
- ⚠️ Requires GitHub Personal Access Token
- ⚠️ Less familiar to team (Docker Hub more common)
- **Use Case**: GitHub-centric workflows

**Final Decision**: **Docker Hub Private Repository** (Free tier: 1 private repo)

**Rationale**:
- ✅ Free tier includes 1 private repository (sufficient for this project)
- ✅ Images remain private and secure
- ✅ Simple Jenkins integration (username + access token)
- ✅ Persistent across Learner Lab sessions (state survives session expiry)
- ✅ Well-documented, widely used
- ✅ 200 pulls/6hrs with authentication (sufficient for CI/CD)

**Docker Hub Organization**:
```
Repository Structure:
- akawatmor/kps-frontend:latest
- akawatmor/kps-frontend:<BUILD_NUMBER>
- akawatmor/kps-backend:latest
- akawatmor/kps-backend:<BUILD_NUMBER>

Note: Use 1 repository with tags, or 2 separate repos (both work with free tier)
```

**Jenkins Integration**:
- Credential: Docker Hub username
- Token: Docker Hub Access Token (not password)
- Environment variables: `DOCKER_USER`, `DOCKER_TOKEN`

---

## 📊 Application Workload Resource Planning

### Pod Resource Requests and Limits

Based on 3x t3.large nodes (8 GB RAM, 2 vCPU each):

#### Frontend (React)
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
replicas: 1-2
```
**Total**: 256-512 MB per replica, ~200m CPU

#### Backend (Node.js API)
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "1Gi"
    cpu: "1000m"
replicas: 2
```
**Total**: 1-2 GB total (2 replicas), ~400m CPU

#### MongoDB (Database)
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
replicas: 1 (StatefulSet)
```
**Total**: 1-2 GB, ~500m CPU

#### System Pods (kube-system)
```
CoreDNS: ~70 MB x 2 = 140 MB
AWS Node (CNI): ~100 MB x 3 = 300 MB
kube-proxy: ~50 MB x 3 = 150 MB
AWS LB Controller: ~200 MB
Total: ~800 MB, ~300m CPU
```

### Total Resource Usage per Node

| Node | Pods | Memory Requested | Memory Limit | CPU Requested | CPU Limit |
|------|------|-----------------|--------------|---------------|-----------|
| Node 1 | Frontend, Backend, System | ~1.8 GB | ~3.5 GB | ~800m | ~2000m |
| Node 2 | Backend, MongoDB, System | ~2.5 GB | ~5 GB | ~1200m | ~3000m |
| Node 3 | System, Spare capacity | ~1 GB | ~2 GB | ~300m | ~500m |

**Total Cluster**: 5.3 GB requested / 24 GB available = **22% utilization** ✅

**Buffer**: 18.7 GB available for scaling, burst, and additional workloads

---

## 🔄 Scaling Strategies

### Vertical Scaling (Limited)

**Not Available**: Cannot scale instance types beyond `*.large`

**Alternative**: Optimize application resource usage
- Reduce Docker image sizes
- Optimize Java/Node.js heap settings
- Use multi-stage builds
- Implement resource limits correctly

### Horizontal Scaling (Available)

#### Option 1: Add More EKS Nodes
```
Current: 3 nodes (6 vCPUs)
Scale to: 4-5 nodes (8-10 vCPUs)
Limit: Max 8 nodes total (with Jenkins = 9 instances)
```
✅ Recommended for production load

#### Option 2: Increase Pod Replicas
```
Frontend: 1 → 2 replicas
Backend: 2 → 3 replicas
```
✅ Improves availability within existing nodes

#### Option 3: Add Jenkins Agents
```
Current: 1 Jenkins server
Add: 1-2 Jenkins agents (t3.medium)
```
⚠️ Uses more instance quota, but parallelizes builds

---

## 📝 Infrastructure as Code Updates Required

### File: `Jenkins-Server-TF/ec2.tf`

**Current (NOT ALLOWED)**:
```hcl
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t2.2xlarge"  # ❌ NOT ALLOWED
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name  # ❌ NOT ALLOWED
  
  root_block_device {
    volume_size = 30
  }
  
  user_data = templatefile("./tools-install.sh", {})
  
  tags = {
    Name = var.instance-name
  }
}
```

**Updated (COMPLIANT)**:
```hcl
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t3.large"              # ✅ CHANGED: Maximum allowed
  key_name               = "vockey"                # ✅ CHANGED: Learner Lab key
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = "LabInstanceProfile"   # ✅ CHANGED: Use Learner Lab profile
  
  root_block_device {
    volume_size = 30  # ✅ Within 100 GB limit
  }
  
  user_data = templatefile("./tools-install.sh", {})
  
  tags = {
    Name = var.instance-name
  }
}
```

### File: `Jenkins-Server-TF/variables.tfvars`

**Updates**:
```hcl
# Original
instance-type = "t2.2xlarge"  # ❌ Change this

# Updated
instance-type = "t3.large"    # ✅ Maximum allowed
```

### File: `Jenkins-Server-TF/backend.tf`

**Create/Update**:
```hcl
terraform {
  backend "s3" {
    bucket         = "kps-enterprise-terraform-state"
    key            = "jenkins-server/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "kps-terraform-state-lock"
  }
}
```

### EKS Cluster Configuration (eksctl or Terraform)

**eksctl config.yaml**:
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: kps-enterprise-cluster
  region: us-east-1

iam:
  serviceRoleARN: arn:aws:iam::ACCOUNT_ID:role/LabEksClusterRole

nodeGroups:
  - name: kps-workers
    instanceType: t3.large              # ✅ Maximum allowed
    desiredCapacity: 3                  # ✅ Standard HA setup
    minSize: 2
    maxSize: 5                          # ✅ Can scale within limits
    volumeSize: 30                      # ✅ Within 100 GB limit
    iam:
      instanceRoleARN: arn:aws:iam::ACCOUNT_ID:role/LabRole
    labels:
      role: worker
    tags:
      Environment: learner-lab
      Project: kps-enterprise
```

---

## 📋 Pre-Deployment Checklist

### AWS Learner Lab Setup
- [ ] Start AWS Learner Lab session
- [ ] Verify region is set to `us-east-1`
- [ ] Note AWS Account ID (needed for IAM ARNs)
- [ ] Verify `vockey` key pair exists
- [ ] Verify `LabRole` and `LabInstanceProfile` exist
- [ ] Check remaining budget (if applicable)

### Container Registry Setup
- [ ] Create Docker Hub account (if not exists)
- [ ] Create access token in Docker Hub
- [ ] Decide on repository naming convention
- [ ] Test docker login with credentials
- [ ] Add Docker Hub credentials to Jenkins

### Terraform Backend Setup
- [ ] Create S3 bucket: `kps-enterprise-terraform-state`
- [ ] Enable S3 bucket versioning
- [ ] Create DynamoDB table: `kps-terraform-state-lock`
- [ ] Update `backend.tf` with bucket name
- [ ] Test Terraform init with backend

### Infrastructure Modifications
- [ ] Delete `iam-role.tf`
- [ ] Delete `iam-policy.tf`
- [ ] Delete `iam-instance-profile.tf`
- [ ] Update `ec2.tf`: instance type → `t3.large`
- [ ] Update `ec2.tf`: iam_instance_profile → `"LabInstanceProfile"`
- [ ] Update `ec2.tf`: key_name → `"vockey"`
- [ ] Update `variables.tfvars`: instance-type → `"t3.large"`
- [ ] Create/update `backend.tf` for S3 backend

### CI/CD Pipeline Updates
- [ ] Update Jenkinsfile-Backend: ECR → Docker Hub
- [ ] Update Jenkinsfile-Frontend: ECR → Docker Hub
- [ ] Add Docker Hub credentials to Jenkins
- [ ] Test Docker build and push

### Kubernetes Manifests Updates
- [ ] Update Frontend deployment: image → Docker Hub
- [ ] Update Backend deployment: image → Docker Hub
- [ ] Add resource requests/limits to all deployments
- [ ] Verify ingress annotations for region
- [ ] Test manifest validation

---

## 🎯 Deployment Sequence

### Phase 1: Infrastructure Setup (Week 2)

1. **Terraform State Backend** (15 minutes)
   - Create S3 bucket
   - Create DynamoDB table
   - Configure backend.tf

2. **Jenkins Server** (30 minutes)
   - Update Terraform files
   - Run `terraform init`
   - Run `terraform plan` (verify changes)
   - Run `terraform apply`
   - Wait for EC2 instance and tools installation

3. **Jenkins Configuration** (45 minutes)
   - Access Jenkins (http://PUBLIC_IP:8080)
   - Complete initial setup
   - Install required plugins
   - Add Docker Hub credentials
   - Add GitHub credentials
   - Configure SonarQube

### Phase 2: EKS Cluster (Week 2-3)

4. **EKS Cluster Creation** (20 minutes)
   - Create eksctl config file
   - Run `eksctl create cluster -f config.yaml`
   - Wait for cluster creation (~15-20 minutes)

5. **EKS Add-ons** (30 minutes)
   - Install AWS Load Balancer Controller
   - Configure IAM OIDC provider
   - Install metrics-server (optional)
   - Verify node readiness

### Phase 3: Application Deployment (Week 3)

6. **Container Images** (30 minutes)
   - Build frontend Docker image
   - Build backend Docker image
   - Push to Docker Hub
   - Verify images

7. **Kubernetes Deployment** (45 minutes)
   - Create namespace: `three-tier`
   - Deploy MongoDB (StatefulSet + PV + PVC)
   - Deploy Backend (Deployment + Service)
   - Deploy Frontend (Deployment + Service)
   - Deploy Ingress (ALB)
   - Verify pods running

8. **Testing & Validation** (30 minutes)
   - Test frontend access
   - Test backend API
   - Test database connectivity
   - Test CI/CD pipeline end-to-end

**Total Estimated Time**: 4-5 hours (excluding waiting time)

---

## ⚠️ Risks and Mitigation Strategies

### Risk 1: Jenkins Performance Degradation

**Risk**: t3.large (2 vCPU, 8 GB) vs original t2.2xlarge (8 vCPU, 32 GB)

**Impact**: High - Build times will be 2-3x longer

**Mitigation**:
- ✅ Optimize Jenkins JVM heap (max 4 GB)
- ✅ Use Docker layer caching aggressively
- ✅ Limit concurrent builds to 1-2
- ✅ Run SonarQube with memory limit (2 GB)
- ✅ Consider adding Jenkins agent if needed (uses 1 more instance)
- ✅ Schedule heavy builds during off-hours if possible

### Risk 2: EKS Node Capacity

**Risk**: 3x t3.large nodes (24 GB total) may be insufficient under heavy load

**Impact**: Medium - Pods may be evicted or pending

**Mitigation**:
- ✅ Set appropriate resource requests/limits
- ✅ Use HPA (Horizontal Pod Autoscaler) carefully
- ✅ Monitor node resources with metrics-server
- ✅ Scale to 4-5 nodes if needed (within limits)
- ✅ Optimize application resource usage

### Risk 3: Docker Hub Rate Limits

**Risk**: 200 pulls/6hrs with authentication may be exceeded

**Impact**: Low-Medium - Pipeline may fail if rate limit hit

**Mitigation**:
- ✅ Use authenticated pulls (200 vs 100 limit)
- ✅ Cache images locally on Jenkins
- ✅ Use image pull secrets in Kubernetes
- ✅ Consider Docker Hub Pro ($5/month) for unlimited pulls if needed
- ✅ Use `imagePullPolicy: IfNotPresent` in Kubernetes

### Risk 4: Learner Lab Session Expiry

**Risk**: All resources deleted when session ends (typically 4 hours)

**Impact**: High - Must recreate everything

**Mitigation**:
- ✅ Use Terraform for infrastructure (reproducible)
- ✅ Store images in Docker Hub (persistent)
- ✅ Keep Terraform state in S3 (if bucket survives)
- ✅ Document all manual steps
- ✅ Export important data before session end
- ⚠️ **Note**: S3 and DynamoDB may also be deleted - verify with instructor

### Risk 5: Resource Quota Exhaustion

**Risk**: Accidentally exceed 9 instances or 32 vCPU limit

**Impact**: High - New instances will fail or be terminated

**Mitigation**:
- ✅ Always check current resource usage before launching
- ✅ Use AWS CLI to monitor: `aws ec2 describe-instances`
- ✅ Maintain resource tracking spreadsheet
- ✅ Set up CloudWatch alarms (if possible)
- ✅ Clean up unused resources immediately

---

## 📊 Cost Optimization (Learner Lab Budget)

### Resource Efficiency

**Current Plan**:
- 4 instances running concurrently
- 8 vCPUs total
- **44% instance utilization, 25% vCPU utilization**

**Optimization Opportunities**:

1. **Stop Jenkins when not in use**
   - Save 2 vCPUs (25% of quota)
   - Save $XX per hour (Learner Lab budget)
   - Can be restarted when needed

2. **Scale down EKS nodes during idle**
   - Reduce from 3 to 2 nodes during testing
   - Save 2 vCPUs
   - Scale up for demos/production testing

3. **Use smaller instances for testing**
   - Test with t3.medium instead of t3.large
   - Validate before scaling up
   - Saves resources during development

---

## 📚 Documentation Updates Required

### README.md

Add section:
```markdown
## AWS Learner Lab Deployment

This project is optimized for AWS Learner Lab with the following resource allocation:

- **Jenkins Server**: 1x t3.large (2 vCPU, 8 GB RAM)
- **EKS Worker Nodes**: 3x t3.large (6 vCPUs, 24 GB RAM total)
- **Total Resources**: 4 instances, 8 vCPUs (within 9 instances, 32 vCPU limits)
- **Container Registry**: Docker Hub (private repositories)
- **Terraform Backend**: S3 + DynamoDB

See [Resource Allocation Plan](document/phase1/issue-15-resource-allocation-plan.md) for details.
```

---

## ✅ Acceptance Criteria Completion

All acceptance criteria from Issue #15 have been met:

- ✅ **Decide Jenkins EC2 instance type**: `t3.large` (2 vCPU, 8 GB RAM)
- ✅ **Decide EKS node count and instance type**: 3x `t3.large` (2 vCPU, 8 GB each)
- ✅ **Calculate total instances and vCPUs used**: 4 instances, 8 vCPUs
- ✅ **Verify within limits**: 44% instance utilization, 25% vCPU utilization ✅
- ✅ **Decide Terraform backend strategy**: S3 + DynamoDB (with manual pre-creation)
- ✅ **Decide Container Registry strategy**: Docker Hub private repositories
- ✅ **Document final decision**: This document + README updates

---

## 🎉 Summary

### Final Resource Allocation

| Component | Instance Type | Count | vCPUs | RAM | Purpose |
|-----------|--------------|-------|-------|-----|---------|
| Jenkins Server | t3.large | 1 | 2 | 8 GB | CI/CD + SonarQube |
| EKS Workers | t3.large | 3 | 6 | 24 GB | Application hosting |
| **TOTAL** | - | **4** | **8** | **32 GB** | **Within limits ✅** |

### Key Decisions

1. **Instance Types**: t3.large (maximum allowed, modern, efficient)
2. **Container Registry**: Docker Hub private repositories (persistent, free tier)
3. **Terraform Backend**: S3 + DynamoDB (team collaboration, state locking)
4. **Resource Buffer**: 5 instances, 24 vCPUs available for scaling

### Next Steps

1. Implement infrastructure changes (Phase 1, Week 2)
2. Deploy and test Jenkins server
3. Create EKS cluster with node groups
4. Deploy application and test end-to-end
5. Monitor performance and optimize as needed

---

**Document Status**: ✅ Complete and Ready for Implementation  
**Reviewed By**: Technical Team  
**Approved For**: Phase 1, Week 2 Deployment

---

*This resource allocation plan ensures successful deployment within AWS Learner Lab constraints while maintaining performance, reliability, and scalability.*
