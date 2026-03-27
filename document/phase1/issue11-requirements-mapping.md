# Issue #11: AWS Learner Lab Limitations and Required Modifications - Requirements Mapping

**Issue**: [#11 - Document AWS Learner Lab limitations and required modifications](https://github.com/Akawatmor/KPS-Enterprise/issues/11)  
**Milestone**: Phase 1 - Week 1  
**Date**: March 26, 2026  
**Status**: ✅ COMPLETED

---

## Executive Summary

This document provides a comprehensive mapping of AWS Learner Lab limitations to required code changes for the KPS-Enterprise three-tier DevSecOps project. All acceptance criteria from issue #11 have been verified and documented.

---

## 📋 Acceptance Criteria Status

- ✅ Document IAM restriction → must use LabRole / LabInstanceProfile
- ✅ Document EC2 limits → max 9 instances, only up to large type, max 32 vCPU
- ✅ Document ECR permission issue → LabRole is read-only
- ✅ Document EKS support → must use LabEksClusterRole
- ✅ Document region restriction → us-east-1 or us-west-2 only
- ✅ Create mapping table: Original Config → Required Change → File to Modify

---

## 🔴 Critical Limitations and Required Changes

### 1. IAM Role Restrictions

#### **Limitation Details:**
- **Cannot create custom IAM roles, policies, or instance profiles**
- Learner Lab provides pre-created roles:
  - `LabRole` - For general EC2 instances
  - `LabInstanceProfile` - Instance profile attached to LabRole
  - `LabEksClusterRole` - For EKS cluster operations

#### **Impact:**
- Original project uses `AdministratorAccess` policy (NOT ALLOWED)
- Custom IAM role creation will fail

#### **Required Changes:**

| Original File | Original Config | Required Change | Action |
|--------------|----------------|-----------------|--------|
| `Jenkins-Server-TF/iam-role.tf` | `resource "aws_iam_role" "iam-role"` | ❌ REMOVE - Use LabRole instead | DELETE FILE |
| `Jenkins-Server-TF/iam-policy.tf` | `resource "aws_iam_role_policy_attachment"` | ❌ REMOVE - LabRole has predefined permissions | DELETE FILE |
| `Jenkins-Server-TF/iam-instance-profile.tf` | `resource "aws_iam_instance_profile"` | ❌ REMOVE - Use LabInstanceProfile | DELETE FILE |
| `Jenkins-Server-TF/ec2.tf` | `iam_instance_profile = aws_iam_instance_profile.instance-profile.name` | ✅ Change to: `iam_instance_profile = "LabInstanceProfile"` | MODIFY |

#### **Code Changes:**

**Before (ec2.tf):**
```terraform
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t2.2xlarge"
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance-profile.name  # ❌ Not allowed
  root_block_device {
    volume_size = 30
  }
  user_data = templatefile("./tools-install.sh", {})
  
  tags = {
    Name = var.instance-name
  }
}
```

**After (ec2.tf):**
```terraform
resource "aws_instance" "ec2" {
  ami                    = data.aws_ami.ami.image_id
  instance_type          = "t2.large"                              # ✅ Changed from 2xlarge
  key_name               = var.key-name
  subnet_id              = aws_subnet.public-subnet.id
  vpc_security_group_ids = [aws_security_group.security-group.id]
  iam_instance_profile   = "LabInstanceProfile"                   # ✅ Use Learner Lab profile
  root_block_device {
    volume_size = 30
  }
  user_data = templatefile("./tools-install.sh", {})
  
  tags = {
    Name = var.instance-name
  }
}
```

---

### 2. EC2 Instance Limitations

#### **Limitation Details:**
- **Maximum 9 EC2 instances** per Learner Lab session
- **Instance type restrictions:**
  - Maximum: `*.large` (2 vCPU, 8 GB RAM)
  - Cannot use: `*.xlarge`, `*.2xlarge`, `*.4xlarge`, etc.
- **Total vCPU limit: 32 vCPUs** across all instances

#### **Impact:**
- Original project uses `t2.2xlarge` (8 vCPU, 32 GB RAM) - **NOT ALLOWED**
- EKS worker nodes are limited to `t2.large` or smaller

#### **Required Changes:**

| Original File | Original Config | Required Change | Impact |
|--------------|----------------|-----------------|--------|
| `Jenkins-Server-TF/ec2.tf` | `instance_type = "t2.2xlarge"` | `instance_type = "t2.large"` | Jenkins may run slower |
| `Jenkins-Server-TF/variables.tfvars` | Default: `t2.2xlarge` | Default: `t2.large` | Update default value |
| EKS Node Groups (future) | Any `*.xlarge` or larger | Max `t2.large` or `t3.large` | Limited node capacity |

#### **Resource Planning:**

```
Available Resources:
- Max Instances: 9
- Max vCPU per instance: 2 (for *.large)
- Total vCPU budget: 32

Recommended Allocation:
1. Jenkins Server: 1x t2.large (2 vCPU) - 2 vCPU used
2. EKS Control Plane: Managed by AWS - 0 vCPU used
3. EKS Worker Nodes: 3x t2.large (2 vCPU each) - 6 vCPU used
4. Reserved for testing: 2-3 instances - 4-6 vCPU

Total: 12-14 vCPU (within 32 vCPU limit ✅)
```

---

### 3. ECR (Elastic Container Registry) Permissions

#### **Limitation Details:**
- **LabRole has READ-ONLY access to ECR**
- Can pull images but **CANNOT push images**
- Cannot create new ECR repositories

#### **Impact:**
- Jenkins pipeline `ECR Image Pushing` stage will FAIL
- Cannot store custom Docker images in private ECR

#### **Required Changes:**

| Component | Original Approach | Required Change | Alternative Solution |
|-----------|------------------|-----------------|---------------------|
| Jenkins Pipeline | Push to private ECR | ❌ NOT ALLOWED | Use Docker Hub (public/private) |
| `Jenkinsfile-Backend` | AWS ECR push commands | Remove ECR push stage | Use `docker push` to Docker Hub |
| `Jenkinsfile-Frontend` | AWS ECR push commands | Remove ECR push stage | Use `docker push` to Docker Hub |
| Kubernetes Manifests | ECR image URLs | Docker Hub image URLs | Update `image:` fields |

#### **Docker Hub Implementation:**

**Required Jenkins Credentials:**
- `dockerhub-username` (String)
- `dockerhub-token` (Secret text)

**Pipeline Changes (Example):**
```groovy
// Before (ECR)
stage('Push to ECR') {
  steps {
    sh "aws ecr get-login-password --region us-east-1 | docker login ..."
    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/backend:${BUILD_NUMBER}"
  }
}

// After (Docker Hub)
stage('Push to Docker Hub') {
  steps {
    withCredentials([string(credentialsId: 'dockerhub-username', variable: 'DOCKER_USER'),
                     string(credentialsId: 'dockerhub-token', variable: 'DOCKER_TOKEN')]) {
      sh "echo \$DOCKER_TOKEN | docker login -u \$DOCKER_USER --password-stdin"
      sh "docker push \${DOCKER_USER}/kps-backend:\${BUILD_NUMBER}"
    }
  }
}
```

---

### 4. EKS (Elastic Kubernetes Service) Support

#### **Limitation Details:**
- **EKS IS SUPPORTED** ✅ (confirmed via AWS documentation)
- Must use `LabEksClusterRole` for EKS cluster IAM role
- Must use `LabRole` for EKS node group IAM role
- Cannot create custom service roles for EKS

#### **Impact:**
- Positive: EKS can be used in Learner Lab
- Constraint: Must use pre-existing IAM roles

#### **Required Changes:**

| Component | Original Config | Required Change | Tool |
|-----------|----------------|-----------------|------|
| EKS Cluster Creation | Custom IAM role | Use `LabEksClusterRole` | eksctl or Terraform |
| EKS Node Group | Custom IAM role | Use `LabRole` | eksctl or Terraform |

#### **eksctl Configuration Example:**

**Before:**
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: three-tier-cluster
  region: us-east-1
iam:
  serviceRoleARN: arn:aws:iam::ACCOUNT_ID:role/CustomEKSRole  # ❌ Not allowed
nodeGroups:
  - name: three-tier-nodes
    instanceType: t2.2xlarge  # ❌ Not allowed
    desiredCapacity: 3
```

**After:**
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: three-tier-cluster
  region: us-east-1                              # ✅ Allowed region
iam:
  serviceRoleARN: arn:aws:iam::ACCOUNT_ID:role/LabEksClusterRole  # ✅ Use Learner Lab role
nodeGroups:
  - name: three-tier-nodes
    instanceType: t2.large                        # ✅ Allowed instance type
    desiredCapacity: 3                            # ✅ Within instance limit (9)
    iam:
      instanceRoleARN: arn:aws:iam::ACCOUNT_ID:role/LabRole  # ✅ Use Learner Lab role
```

---

### 5. AWS Region Restrictions

#### **Limitation Details:**
- **Only 2 regions available:**
  - `us-east-1` (N. Virginia) - **PRIMARY**
  - `us-west-2` (Oregon) - **SECONDARY**
- All other regions are blocked

#### **Impact:**
- Original project uses `us-east-1` - **ALLOWED** ✅
- Multi-region deployment **NOT POSSIBLE**

#### **Required Changes:**

| File | Original Config | Required Change | Notes |
|------|----------------|-----------------|-------|
| `Jenkins-Server-TF/provider.tf` | `region = "us-east-1"` | ✅ No change needed | Already correct |
| `Jenkins-Server-TF/variables.tfvars` | `region = "us-east-1"` | ✅ No change needed | Already correct |
| All Terraform files | Any other region | Must be `us-east-1` or `us-west-2` | Verify before deployment |
| Kubernetes Manifests | Region-specific resources (e.g., ALB) | Ensure `us-east-1` | Check ALB annotations |

#### **Verification Checklist:**
```bash
# Verify all region references
grep -r "region" Jenkins-Server-TF/
grep -r "us-" Kubernetes-Manifests-file/

# Expected output: Only us-east-1 or us-west-2
```

---

## 🟠 Major Issues (Workarounds Available)

### 6. Terraform S3 Backend

#### **Limitation:**
- S3 bucket for Terraform state must be **created manually**
- DynamoDB table for state locking must be **created manually**
- Cannot use Terraform to create its own backend resources

#### **Required Changes:**

| Component | Required Action | Commands |
|-----------|----------------|----------|
| S3 Bucket | Create manually before running Terraform | `aws s3 mb s3://terraform-state-kps-enterprise --region us-east-1` |
| DynamoDB Table | Create manually for state locking | `aws dynamodb create-table --table-name terraform-state-lock --region us-east-1 ...` |
| `backend.tf` | Update with created bucket name | Change bucket name to actual created bucket |

---

### 7. Hardcoded Values in Manifests

#### **Required Changes:**

| File | Original Value | Required Change | Reason |
|------|---------------|-----------------|--------|
| `Kubernetes-Manifests-file/Backend/deployment.yaml` | `image: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/backend` | `image: dockerhub-user/kps-backend:TAG` | ECR not writable |
| `Kubernetes-Manifests-file/Frontend/deployment.yaml` | `image: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/frontend` | `image: dockerhub-user/kps-frontend:TAG` | ECR not writable |
| `Kubernetes-Manifests-file/ingress.yaml` | `alb.ingress.kubernetes.io/subnets` | Add actual subnet IDs | Auto-discovery may fail |
| `Kubernetes-Manifests-file/ingress.yaml` | Region-specific annotations | Verify `us-east-1` | Ensure correct region |

---

## 📊 Complete Mapping Table: Original Config → Required Changes

| # | Component | Original Configuration | Learner Lab Limitation | Required Change | Files to Modify | Priority |
|---|-----------|----------------------|----------------------|----------------|----------------|----------|
| 1 | IAM Role | Custom IAM role creation | Cannot create IAM roles | Use `LabRole` | `iam-role.tf` (DELETE) | 🔴 CRITICAL |
| 2 | IAM Policy | AdministratorAccess policy | Cannot attach policies | Use LabRole's predefined permissions | `iam-policy.tf` (DELETE) | 🔴 CRITICAL |
| 3 | IAM Instance Profile | Custom instance profile | Cannot create profiles | Use `LabInstanceProfile` | `iam-instance-profile.tf` (DELETE), `ec2.tf` (MODIFY) | 🔴 CRITICAL |
| 4 | EC2 Instance Type | `t2.2xlarge` (8 vCPU, 32 GB) | Max `*.large` (2 vCPU, 8 GB) | Change to `t2.large` | `ec2.tf`, `variables.tfvars` | 🔴 CRITICAL |
| 5 | ECR Push Access | Push images to ECR | LabRole is read-only for ECR | Use Docker Hub instead | `Jenkinsfile-Backend`, `Jenkinsfile-Frontend` | 🔴 CRITICAL |
| 6 | Container Images | ECR image URLs | Cannot push to ECR | Docker Hub image URLs | All K8s deployment manifests | 🔴 CRITICAL |
| 7 | EKS Cluster Role | Custom EKS service role | Cannot create service roles | Use `LabEksClusterRole` | eksctl config or Terraform | 🔴 CRITICAL |
| 8 | EKS Node Role | Custom node IAM role | Cannot create IAM roles | Use `LabRole` for node groups | eksctl config or Terraform | 🔴 CRITICAL |
| 9 | AWS Region | `us-east-1` | Only `us-east-1` or `us-west-2` | ✅ No change (already correct) | `provider.tf` | ✅ OK |
| 10 | S3 Backend | Terraform creates S3 bucket | Cannot use Terraform to create backend | Create S3/DynamoDB manually first | Manual AWS CLI commands | 🟠 MAJOR |
| 11 | Max Instances | Unlimited (in normal AWS) | Max 9 instances | Plan resource allocation carefully | Architecture design | 🟡 MINOR |
| 12 | Total vCPU | Unlimited (in normal AWS) | Max 32 vCPUs total | Limit node count and instance types | EKS node group config | 🟡 MINOR |

---

## ✅ Files to Delete (No Longer Needed)

These files attempt to create IAM resources, which is not allowed in Learner Lab:

1. ❌ `Jenkins-Server-TF/iam-role.tf` - Custom IAM role creation
2. ❌ `Jenkins-Server-TF/iam-policy.tf` - IAM policy attachment
3. ❌ `Jenkins-Server-TF/iam-instance-profile.tf` - Instance profile creation

---

## 📝 Files to Modify

### High Priority (Must Change)

1. **`Jenkins-Server-TF/ec2.tf`**
   - Change: `iam_instance_profile = "LabInstanceProfile"`
   - Change: `instance_type = "t2.large"`

2. **`Jenkins-Pipeline-Code/Jenkinsfile-Backend`**
   - Remove: ECR push stage
   - Add: Docker Hub push stage
   - Update: Image naming convention

3. **`Jenkins-Pipeline-Code/Jenkinsfile-Frontend`**
   - Remove: ECR push stage
   - Add: Docker Hub push stage
   - Update: Image naming convention

4. **`Kubernetes-Manifests-file/Backend/deployment.yaml`**
   - Change: `image:` from ECR to Docker Hub

5. **`Kubernetes-Manifests-file/Frontend/deployment.yaml`**
   - Change: `image:` from ECR to Docker Hub

### Medium Priority (Recommended)

6. **`Jenkins-Server-TF/variables.tfvars`**
   - Update: Default instance type to `t2.large`

7. **EKS Creation Scripts** (when created)
   - Add: `LabEksClusterRole` for cluster
   - Add: `LabRole` for node groups
   - Set: `instance_type = "t2.large"` for nodes

---

## 🎯 Implementation Checklist

### Pre-Deployment Steps

- [ ] Verify AWS Learner Lab session is active
- [ ] Confirm region is set to `us-east-1` or `us-west-2`
- [ ] Create S3 bucket for Terraform state manually
- [ ] Create DynamoDB table for state locking manually
- [ ] Set up Docker Hub account and access token
- [ ] Add Docker Hub credentials to Jenkins

### Terraform Changes

- [ ] Delete `iam-role.tf`
- [ ] Delete `iam-policy.tf`
- [ ] Delete `iam-instance-profile.tf`
- [ ] Modify `ec2.tf` to use `LabInstanceProfile`
- [ ] Change instance type to `t2.large` in `ec2.tf`
- [ ] Update `variables.tfvars` defaults
- [ ] Update `backend.tf` with manually created S3 bucket name

### Jenkins Pipeline Changes

- [ ] Update Backend Jenkinsfile for Docker Hub
- [ ] Update Frontend Jenkinsfile for Docker Hub
- [ ] Add Docker Hub credentials to Jenkins
- [ ] Remove ECR-related credential requirements
- [ ] Test pipeline with Docker Hub integration

### Kubernetes Manifest Changes

- [ ] Update Backend deployment image to Docker Hub
- [ ] Update Frontend deployment image to Docker Hub
- [ ] Verify ingress annotations for `us-east-1`
- [ ] Add subnet IDs if auto-discovery fails
- [ ] Test manifest validation

### EKS Deployment

- [ ] Use `LabEksClusterRole` for EKS cluster
- [ ] Use `LabRole` for EKS node groups
- [ ] Limit node instance types to `t2.large` or smaller
- [ ] Set node count to stay within 9 instance limit
- [ ] Verify total vCPU usage < 32

---

## 📚 Reference Documentation

- [AWS Learner Lab Limitations (Full Document)](../learnerlab-problem-predocs.md)
- [Original Project Structure](../original-project-structure.md)
- [GitHub Issue #11](https://github.com/Akawatmor/KPS-Enterprise/issues/11)

---

## 📧 Questions for Instructor

Based on the analysis, the following questions should be addressed:

1. **ECR Alternative**: Confirmed Docker Hub as the alternative. Is this acceptable for the project?
2. **Instance Performance**: Jenkins on `t2.large` (2 vCPU, 8 GB) instead of `t2.2xlarge`. Will this affect CI/CD performance?
3. **Cost Considerations**: Docker Hub paid plan needed for private repositories?
4. **EKS Worker Nodes**: With `t2.large` nodes, should we increase node count to 4-5 nodes for adequate capacity?

---

## 🎉 Summary

All requirements from Issue #11 have been documented and mapped to specific code changes:

✅ **IAM Restrictions** - Must use LabRole/LabInstanceProfile  
✅ **EC2 Limits** - Max 9 instances, t2.large max, 32 vCPU total  
✅ **ECR Permissions** - Read-only access, use Docker Hub instead  
✅ **EKS Support** - Supported with LabEksClusterRole  
✅ **Region Restrictions** - us-east-1 or us-west-2 only  
✅ **Complete Mapping Table** - All changes documented with files to modify

**Next Steps**: Implement changes in Phase 1 and test with Learner Lab environment.

---

*Document created for Issue #11 - Phase 1 Week 1*  
*Date: March 26, 2026*  
*Status: Ready for Review and Implementation*
