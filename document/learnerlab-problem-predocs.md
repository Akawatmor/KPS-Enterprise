# 🚨 ปัญหาและข้อจำกัดของ AWS Learner Lab สำหรับ CI/CD Pipeline

> ⚠️ **อัปเดต**: เอกสารนี้ถูกแก้ไขตามข้อมูลจาก `learnerlab-limit.txt` แล้ว

## 📋 สารบัญ
- [ภาพรวมข้อจำกัดของ Learner Lab](#ภาพรวมข้อจำกัดของ-learner-lab)
- [ข่าวดี - Services ที่ใช้ได้](#ข่าวดี---services-ที่ใช้ได้)
- [ปัญหาที่พบจากโปรเจคเดิม](#ปัญหาที่พบจากโปรเจคเดิม)
- [รายละเอียดปัญหาแต่ละส่วน](#รายละเอียดปัญหาแต่ละส่วน)
- [คำถามสำหรับปรึกษาอาจารย์](#คำถามสำหรับปรึกษาอาจารย์)
- [แผนการ Deploy ที่แนะนำ](#แผนการ-deploy-ที่แนะนำ)

---

## ภาพรวมข้อจำกัดของ Learner Lab (ยืนยันแล้ว)

AWS Academy Learner Lab มีข้อจำกัดดังนี้:

| ข้อจำกัด | รายละเอียด |
|---------|-----------|
| **Region** | ✅ `us-east-1` และ `us-west-2` เท่านั้น |
| **IAM** | ⚠️ ไม่สามารถสร้าง IAM Users/Roles ได้ แต่มี `LabRole` และ `LabInstanceProfile` ให้ใช้ |
| **EC2 Instances** | ⚠️ สูงสุด **9 instances** พร้อมกันใน us-east-1 |
| **vCPU Quota** | ⚠️ สูงสุด **32 vCPU** พร้อมกัน (us-west-2 = 32, us-east-1 = ตามจำนวน instance) |
| **Instance Types** | ⚠️ เฉพาะ nano, micro, small, medium, large |
| **EBS Volume** | ⚠️ สูงสุด **100GB** ต่อ volume, ไม่รองรับ PIOPS |
| **Services** | ✅ รองรับหลาย services รวมถึง **EKS** (ข่าวดี!) |

---

## ข่าวดี - Services ที่ใช้ได้

### ✅ Services สำคัญที่พร้อมใช้งาน:

| Service | สถานะ | หมายเหตุ |
|---------|-------|----------|
| **EKS** | ✅ ใช้ได้! | ใช้ `LabEksClusterRole` สำหรับ Cluster และ Node |
| **ECR** | ⚠️ Read-only ผ่าน LabRole | Console user มี write access |
| **EC2** | ✅ ใช้ได้ | จำกัด instance types และจำนวน |
| **VPC** | ✅ ใช้ได้ | สร้าง VPC ใหม่ได้ |
| **S3** | ✅ ใช้ได้ | LabRole มี permissions |
| **CloudFormation** | ✅ ใช้ได้ | ใช้ LabRole |
| **ALB/NLB** | ✅ ใช้ได้ | ใช้ LabRole |
| **Lambda** | ✅ ใช้ได้ | ใช้ LabRole, max 10 concurrent executions |
| **RDS** | ✅ ใช้ได้ | nano, micro, small, medium เท่านั้น |
| **DynamoDB** | ✅ ใช้ได้ | ใช้ LabRole |
| **Route 53** | ⚠️ ใช้ได้บางส่วน | ไม่สามารถลงทะเบียนโดเมนใหม่ |
| **Secrets Manager** | ✅ ใช้ได้ | ใช้ LabRole |

### 🎉 สรุป: **EKS ใช้ได้แน่นอน!**

---

## ปัญหาที่พบจากโปรเจคเดิม

### 🔴 Critical Issues (ต้องแก้ไขก่อน deploy)

| # | Component | ไฟล์ที่เกี่ยวข้อง | ปัญหา | ระดับความรุนแรง |
|---|-----------|------------------|-------|----------------|
| 1 | **IAM Role Creation** | `Jenkins-Server-TF/iam-role.tf` | ❌ ไม่สามารถสร้าง IAM Role ใหม่ได้ (ใช้ `LabRole` แทน) | 🔴 Critical |
| 2 | **IAM Policy Attachment** | `Jenkins-Server-TF/iam-policy.tf` | ❌ ไม่สามารถ attach policy ได้ (ใช้ `LabRole` แทน) | 🔴 Critical |
| 3 | **IAM Instance Profile** | `Jenkins-Server-TF/iam-instance-profile.tf` | ❌ ไม่สามารถสร้างใหม่ได้ (ใช้ `LabInstanceProfile` แทน) | 🔴 Critical |
| 4 | **Hardcoded ECR URL** | K8s deployments | ❌ ต้องเปลี่ยนเป็น account ของตัวเอง | 🔴 Critical |
| 5 | **Hardcoded Domain** | `ingress.yaml` | ❌ `amanpathakdevops.study` ต้องเปลี่ยน | 🔴 Critical |

### 🟠 Major Issues (มีข้อจำกัดแต่ใช้งานได้)

| # | Component | ไฟล์ที่เกี่ยวข้อง | ปัญหา | ระดับความรุนแรง |
|---|-----------|------------------|-------|----------------|
| 6 | **EC2 Instance Type** | `Jenkins-Server-TF/ec2.tf` | ⚠️ `t2.2xlarge` (8 vCPU) เกิน quota - ใช้ได้แค่ `large` ขนาดใหญ่สุด | 🟠 Major |
| 7 | **S3 Backend for Terraform** | `Jenkins-Server-TF/backend.tf` | ⚠️ ต้องสร้าง S3 bucket ก่อน หรือใช้ local backend | 🟠 Major |
| 8 | **EBS Volume Size** | `Jenkins-Server-TF/ec2.tf` | ⚠️ 30GB ใช้ได้ (max 100GB) | 🟢 OK |
| 9 | **Key Pair** | `Jenkins-Server-TF/variables.tfvars` | ⚠️ ต้องใช้ชื่อ `vockey` ใน us-east-1 | 🟠 Major |
| 10 | **ECR Permissions** | `Jenkinsfile-*` | ⚠️ LabRole มี read-only, แต่ console user มี write access | 🟠 Major |
| 11 | **EKS IAM Role** | EKS Cluster creation | ⚠️ ต้องใช้ `LabEksClusterRole` แทน custom role | 🟠 Major |

### 🟡 Minor Issues (ควรระวัง)

| # | Component | ไฟล์ที่เกี่ยวข้อง | ปัญหา | ระดับความรุนแรง |
|---|-----------|------------------|-------|----------------|
| 12 | **Region Lock** | ทั้งหมด | ⚠️ ต้องใช้ us-east-1 หรือ us-west-2 เท่านั้น | 🟡 Minor |
| 13 | **Instance Count** | ทั้งหมด | ⚠️ สูงสุด 9 instances พร้อมกัน (Jenkins + EKS nodes) | 🟡 Minor |
| 14 | **Route 53 Domain** | `ingress.yaml` | ⚠️ ไม่สามารถลงทะเบียนโดเมนใหม่ได้ | 🟡 Minor |

---

## รายละเอียดปัญหาแต่ละส่วน

### 1. ✅ AWS EKS (ข่าวดีครับ!)

**สถานะ**: ✅ **ใช้ได้แน่นอน!**

**ข้อมูลจาก learnerlab-limit.txt**:
```
Amazon Elastic Kubernetes Service (EKS)
This service can assume the IAM Roles having identifier LabEksClusterRole 
created for Cluster and Node.

Supported Instance types: nano, micro, small, medium, and large.
```

**ข้อจำกัด**:
- ต้องใช้ IAM Role ชื่อ `LabEksClusterRole` สำหรับ Cluster และ Node
- Instance types: เฉพาะ nano, micro, small, medium, large
- ต้องนับรวมกับ EC2 instances อื่นๆ (max 9 instances ทั้งหมด)

**ผลกระทบต่อโปรเจค**:
- ✅ สามารถใช้ Kubernetes manifests ทั้งหมดได้
- ✅ ALB Ingress Controller ใช้ได้
- ✅ Persistent Volume (EBS CSI Driver) ใช้ได้
- ✅ ArgoCD GitOps workflow ใช้ได้

**คำถามสำหรับอาจารย์**:
> ❓ **Q1**: `LabEksClusterRole` มีอยู่แล้วหรือต้องสร้าง? ถ้าต้องสร้าง มี procedure อย่างไร?
> 
> ❓ **Q2**: EKS Node Group ควรใช้ instance type อะไร? (แนะนำ t3.medium หรือ t3.large)
> 
> ❓ **Q3**: Node Group ควรมีกี่ nodes? (แนะนำ 2-3 nodes เพื่อให้เหลือ EC2 สำหรับ Jenkins)

---

### 2. 🔴 IAM Restrictions (ต้องใช้ LabRole)

**สถานะ**: ⚠️ **ไม่สามารถสร้าง IAM Resources ได้ แต่มี LabRole ให้ใช้**

**ข้อมูลจาก learnerlab-limit.txt**:
```
AWS Identity and Access Management (IAM)
Extremely limited access. You cannot create users or groups. 
You cannot create roles, except that you can create service-linked roles.

A role named LabRole has been pre-created for you. 
A role named LabInstanceProfile has been pre-created for you.

The LabRole grants many AWS services access to other AWS services 
and has permissions very similar to the permissions you have as a user.
```

**ไฟล์ที่ได้รับผลกระทบ**:
```
Jenkins-Server-TF/
├── iam-role.tf              # สร้าง IAM Role
├── iam-policy.tf            # Attach AdministratorAccess policy
└── iam-instance-profile.tf  # สร้าง Instance Profile
```

**Code ที่มีปัญหา**:

```hcl
# iam-role.tf - ใช้ไม่ได้
resource "aws_iam_role" "iam-role" {
  name               = var.iam-role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# iam-policy.tf - ใช้ไม่ได้
resource "aws_iam_role_policy_attachment" "iam-policy" {
  role       = aws_iam_role.iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# iam-instance-profile.tf - ใช้ไม่ได้
resource "aws_iam_instance_profile" "instance-profile" {
  name = "Jenkins-instance-profile"
  role = aws_iam_role.iam-role.name
}
```

**ผลกระทบ**:
- ❌ ไม่สามารถสร้าง IAM Role ใหม่ได้
- ✅ ใช้ `LabRole` แทนได้
- ✅ ใช้ `LabInstanceProfile` สำหรับ EC2 ได้

**แก้ไข**:

```hcl
# ec2.tf - แก้ไขจาก
resource "aws_instance" "ec2" {
  # ...
  iam_instance_profile = aws_iam_instance_profile.instance-profile.name  # ❌ ลบบรรทัดนี้
}

# แก้เป็น
resource "aws_instance" "ec2" {
  # ...
  iam_instance_profile = "LabInstanceProfile"  # ✅ ใช้ existing profile
}
```

**Files ที่ต้องลบ**:
- ❌ `iam-role.tf`
- ❌ `iam-policy.tf`  
- ❌ `iam-instance-profile.tf`

**คำถามสำหรับอาจารย์**:
> ❓ **Q4**: LabRole มี permissions ครบสำหรับ ECR push/pull, EKS access, S3 ไหมครับ?
> 
> ❓ **Q5**: ต้องทำอะไรเพิ่มเติมเพื่อให้ Jenkins ใช้ AWS services ได้ไหมครับ?

---

### 3. ⚠️ AWS ECR (Elastic Container Registry)

**สถานะ**: ⚠️ **LabRole มี read-only แต่ console user มี write access**

**ข้อมูลจาก learnerlab-limit.txt**:
```
Amazon Elastic Container Registry (ECR)
The LabRole IAM role has read-only access to this service 
and as a console user you have write access to this service.
```

**ปัญหา**:
- LabRole มี read-only เท่านั้น → Jenkins บน EC2 (ใช้ LabRole) จะ **push ไม่ได้**
- Console user มี write access → ต้อง config AWS credentials ใน Jenkins

**แก้ไข**:

**Option A: ใช้ AWS Credentials ใน Jenkins**
```groovy
// Jenkinsfile - เพิ่ม AWS credentials
environment {
    AWS_CREDENTIALS = credentials('aws-credentials-id')  // เพิ่มบรรทัดนี้
}

stage("ECR Image Pushing") {
    steps {
        script {
            // ใช้ credentials จาก Jenkins
            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                            credentialsId: 'aws-credentials-id']]) {
                sh 'aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URI}'
                sh 'docker push ${REPOSITORY_URI}${AWS_ECR_REPO_NAME}:${BUILD_NUMBER}'
            }
        }
    }
}
```

**Option B: ใช้ Docker Hub แทน ECR**
- ไม่มีปัญหา permissions
- ต้องแก้ Jenkinsfile และ K8s deployment YAML

**คำถามสำหรับอาจารย์**:
> ❓ **Q6**: วิธีไหนดีกว่าครับ: (A) Config AWS credentials ใน Jenkins หรือ (B) ใช้ Docker Hub?
> 
> ❓ **Q7**: ถ้าใช้ Option A จะได้ AWS Access Key/Secret Key จากไหนครับ? (Learner Lab console?)

---

### 4. 🟠 Terraform S3 Backend

**ไฟล์ที่ได้รับผลกระทบ**:
```
Jenkins-Server-TF/backend.tf
```

**Code ที่มีปัญหา**:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-ews-baket1"
    region         = "us-east-1"
    key            = "End-to-End-Kubernetes-Three-Tier-DevSecOps-Project/Jenkins-Server-TF/terraform.tfstate"
    dynamodb_table = "Lock-Files"
    encrypt        = true
  }
}
```

**สถานะ**: ⚠️ **S3 ใช้ได้แต่ต้องสร้าง bucket ก่อน**

**ไฟล์ที่ได้รับผลกระทบ**:
```
Jenkins-Server-TF/backend.tf
```

**Code ที่มีปัญหา**:
```hcl
terraform {
  backend "s3" {
    bucket         = "my-ews-baket1"           # ❌ ต้องสร้าง bucket ก่อน
    region         = "us-east-1"
    key            = "End-to-End-Kubernetes-Three-Tier-DevSecOps-Project/Jenkins-Server-TF/terraform.tfstate"
    dynamodb_table = "Lock-Files"              # ❌ ต้องสร้าง table ก่อน
    encrypt        = true
  }
}
```

**แก้ไข - Option A: Local Backend (แนะนำสำหรับ Lab)**
```hcl
terraform {
  # ลบ backend "s3" { ... } ทั้งหมด
  # หรือ comment ออก
  
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
}
```

**แก้ไข - Option B: สร้าง S3 Backend**
```bash
# สร้าง S3 bucket และ DynamoDB table ก่อน
aws s3 mb s3://my-terraform-state-bucket-<YOUR_NAME> --region us-east-1
aws dynamodb create-table \
    --table-name terraform-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
```

**คำถามสำหรับอาจารย์**:
> ❓ **Q8**: ควรใช้ local backend หรือ S3 backend ครับ? (local ง่ายกว่าสำหรับ lab)

---

### 5. 🟠 EC2 Instance Type Limitations

**สถานะ**: ⚠️ **t2.2xlarge ใช้ไม่ได้ (เกิน quota)**

**ข้อมูลจาก learnerlab-limit.txt**:
```
Amazon Elastic Compute Cloud (EC2)
Supported Instance types: nano, micro, small, medium, and large.
Maximum of 9 concurrently running EC2 instances
Maximum of 32 vCPU used by concurrently running instances
```

**ไฟล์ที่ได้รับผลกระทบ**:
```
Jenkins-Server-TF/ec2.tf
```

**Code ที่มีปัญหา**:
```hcl
resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ami.image_id
  instance_type = "t2.2xlarge"   # ❌ 8 vCPUs - ใช้ไม่ได้!
  # ...
  root_block_device {
    volume_size = 30    # ✅ OK (max 100GB)
  }
}
```

**Instance Type Comparison**:

| Instance Type | vCPUs | Memory | ใช้ได้ไหม? | เหมาะสำหรับ |
|--------------|-------|--------|-----------|------------|
| t2.2xlarge | 8 | 32 GB | ❌ ไม่ได้ | - |
| t2.xlarge | 4 | 16 GB | ✅ ได้ | Jenkins + SonarQube + Docker |
| t2.large | 2 | 8 GB | ✅ ได้ | Jenkins + Docker (ไม่มี SonarQube) |
| t3.xlarge | 4 | 16 GB | ✅ ได้ | แนะนำ (ดีกว่า t2) |
| t3.large | 2 | 8 GB | ✅ ได้ | ทางเลือก |

**แก้ไข**:
```hcl
resource "aws_instance" "ec2" {
  ami           = data.aws_ami.ami.image_id
  instance_type = "t3.xlarge"   # ✅ แนะนำ (4 vCPUs, 16 GB)
  # หรือ
  # instance_type = "t2.xlarge"  # ✅ ทางเลือก
  
  key_name               = "vockey"  # ✅ ต้องใช้ชื่อนี้ใน us-east-1
  iam_instance_profile   = "LabInstanceProfile"  # ✅ ใช้ existing
  # ...
}
```

**คำถามสำหรับอาจารย์**:
> ❓ **Q9**: ควรใช้ t3.xlarge หรือ t2.xlarge ครับ? (t3 ใหม่กว่าและดีกว่า)
> 
> ❓ **Q10**: ถ้าใช้ Jenkins + SonarQube + Docker บน t3.xlarge พอไหมครับ?
> 
> ❓ **Q11**: EKS Node Group ควรใช้ instance type และจำนวน nodes เท่าไหร่? (ต้องรวมไม่เกิน 9 instances)

---

### 6. 🟡 Resource Planning (สำคัญ!)

**ข้อจำกัด**:
- **Maximum 9 EC2 instances** พร้อมกัน
- **Maximum 32 vCPUs** พร้อมกัน

**การวางแผน**:

**Scenario 1: Minimal Setup**
```
Jenkins EC2:       1 instance (t3.xlarge = 4 vCPUs)
EKS Control Plane: 0 instances (managed by AWS)
EKS Worker Nodes:  2 instances (t3.medium = 2 vCPUs each = 4 vCPUs total)
---
Total: 3 instances, 8 vCPUs ✅ OK
```

**Scenario 2: Production-like**
```
Jenkins EC2:       1 instance (t3.xlarge = 4 vCPUs)
EKS Control Plane: 0 instances (managed by AWS)
EKS Worker Nodes:  3 instances (t3.large = 2 vCPUs each = 6 vCPUs total)
---
Total: 4 instances, 10 vCPUs ✅ OK
```

**Scenario 3: High Availability**
```
Jenkins EC2:       1 instance (t3.xlarge = 4 vCPUs)
EKS Control Plane: 0 instances (managed by AWS)
EKS Worker Nodes:  4 instances (t3.medium = 2 vCPUs each = 8 vCPUs total)
---
Total: 5 instances, 12 vCPUs ✅ OK
```

**คำถามสำหรับอาจารย์**:
> ❓ **Q12**: ควรเลือก Scenario ไหนครับ? (แนะนำ Scenario 2)
> 
> ❓ **Q13**: ถ้าต้องการรัน ArgoCD ด้วย ต้อง provision resources เพิ่มไหมครับ?

---

### 7. ⚠️ Hardcoded Values ที่ต้องเปลี่ยน

**1. ECR Repository URL**

```yaml
# Kubernetes-Manifests-file/Backend/deployment.yaml
spec:
  containers:
  - name: api
    image: 407622020962.dkr.ecr.us-east-1.amazonaws.com/backend:1  # ❌ Hardcoded
```

**แก้เป็น**:
```yaml
    image: <YOUR_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/backend:${BUILD_NUMBER}
```

**2. Domain Name**

```yaml
# Kubernetes-Manifests-file/ingress.yaml
spec:
  rules:
    - host: amanpathakdevops.study  # ❌ Hardcoded
```

**แก้เป็น**:
```yaml
    - host: <YOUR_DOMAIN_OR_ALB_DNS>  # หรือลบบรรทัดนี้ออก (ใช้ ALB DNS)
```

**3. Git Repository**

```groovy
// Jenkinsfile-Backend (line 22-23)
stage('Checkout from Git') {
    steps {
        git credentialsId: 'GITHUB', 
            url: 'https://github.com/AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project.git'  # ❌
    }
}
```

**แก้เป็น**:
```groovy
        git credentialsId: 'GITHUB', 
            url: 'https://github.com/<YOUR_USERNAME>/<YOUR_REPO>.git'  # ✅
```

---

### 8. 🟢 Tools Installation (ตรวจสอบแล้ว)

**ไฟล์**: `Jenkins-Server-TF/tools-install.sh`

**Tools ที่ติดตั้ง**:

| Tool | ใช้งานได้ไหม? | เหตุผล |
|------|-------------|--------|
| Java 17 | ✅ ใช้ได้ | Jenkins runtime |
| Jenkins | ✅ ใช้ได้ | CI/CD server |
| Docker | ✅ ใช้ได้ | Container build |
| SonarQube | ✅ ใช้ได้ | Code analysis (Docker container) |
| Trivy | ✅ ใช้ได้ | Security scanning |
| AWS CLI | ✅ ใช้ได้ | AWS interaction |
| **kubectl** | ✅ ใช้ได้ | **สำหรับ EKS** |
| **eksctl** | ✅ ใช้ได้ | **สำหรับสร้าง EKS cluster** |
| **helm** | ✅ ใช้ได้ | **สำหรับ K8s packages** |
| Terraform | ✅ ใช้ได้ | IaC |

**สรุป**: ✅ **ทุก tools ใช้ได้ครับ!**

---

## คำถามสำหรับปรึกษาอาจารย์

### 🔴 คำถามด่วน (Critical Questions)

| # | คำถาม | หมายเหตุ |
|---|-------|----------|
| **Q1** | `LabEksClusterRole` มีอยู่แล้วหรือต้องสร้าง? | สำคัญมากสำหรับ EKS |
| **Q2** | EKS Node Group ควรใช้ instance type อะไร? | แนะนำ t3.medium หรือ t3.large |
| **Q3** | Node Group ควรมีกี่ nodes? | แนะนำ 2-3 nodes |
| **Q4** | LabRole มี permissions ครบสำหรับ ECR, EKS, S3 ไหม? | สำคัญมาก |
| **Q6** | ECR: ควรใช้ AWS credentials ใน Jenkins หรือ Docker Hub? | การ push images |
| **Q9** | ควรใช้ t3.xlarge หรือ t2.xlarge สำหรับ Jenkins? | t3 ใหม่กว่า |

### 🟠 คำถามสำคัญ (Important Questions)

| # | คำถาม | หมายเหตุ |
|---|-------|----------|
| **Q5** | ต้องทำอะไรเพิ่มเพื่อให้ Jenkins ใช้ AWS services ได้? | Configuration |
| **Q7** | AWS Access Key/Secret Key ได้จากไหน? | Learner Lab console? |
| **Q8** | ควรใช้ local หรือ S3 Terraform backend? | แนะนำ local สำหรับ lab |
| **Q10** | t3.xlarge พอสำหรับ Jenkins + SonarQube + Docker ไหม? | Resource planning |
| **Q11** | EKS nodes จำนวนเท่าไหร่? (รวมไม่เกิน 9 instances) | Quota planning |
| **Q12** | ควรเลือก Scenario ไหน? | Minimal/Production-like/HA |
| **Q13** | ถ้ารัน ArgoCD ด้วย ต้อง provision เพิ่มไหม? | Additional resources |

---

## แผนการ Deploy ที่แนะนำ

### 🎯 แผนที่แนะนำ: Production-like Setup

```
┌───────────────────────────────────────────────────────────────────┐
│                      AWS Learner Lab (us-east-1)                  │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────┐                     │
│  │   EC2 Instance (t3.xlarge) - 4 vCPUs    │                     │
│  │  ┌──────────┐  ┌──────────┐            │                     │
│  │  │ Jenkins  │  │SonarQube │            │                     │
│  │  │  :8080   │  │  :9000   │            │                     │
│  │  └──────────┘  └──────────┘            │                     │
│  │         IAM: LabInstanceProfile         │                     │
│  └─────────────────────────────────────────┘                     │
│                      │                                            │
│                      │ Push Images                                │
│                      ▼                                            │
│  ┌─────────────────────────────────────────┐                     │
│  │   Amazon ECR                            │                     │
│  │   - backend:${BUILD_NUMBER}             │                     │
│  │   - frontend:${BUILD_NUMBER}            │                     │
│  └─────────────────────────────────────────┘                     │
│                      │                                            │
│                      │ Deploy via K8s                             │
│                      ▼                                            │
│  ┌─────────────────────────────────────────┐                     │
│  │   Amazon EKS Cluster                    │                     │
│  │   - IAM Role: LabEksClusterRole         │                     │
│  │                                         │                     │
│  │   Worker Nodes (3x t3.large) - 6 vCPUs │                     │
│  │   ┌─────────┐ ┌─────────┐ ┌─────────┐  │                     │
│  │   │ Node 1  │ │ Node 2  │ │ Node 3  │  │                     │
│  │   └─────────┘ └─────────┘ └─────────┘  │                     │
│  │                                         │                     │
│  │   Pods:                                 │                     │
│  │   - Frontend (ReactJS)                  │                     │
│  │   - Backend (NodeJS API)                │                     │
│  │   - MongoDB                             │                     │
│  │   - ArgoCD (optional)                   │                     │
│  └─────────────────────────────────────────┘                     │
│                      │                                            │
│                      │ Ingress                                    │
│                      ▼                                            │
│  ┌─────────────────────────────────────────┐                     │
│  │   Application Load Balancer (ALB)       │                     │
│  │   - /      → Frontend                   │                     │
│  │   - /api   → Backend                    │                     │
│  └─────────────────────────────────────────┘                     │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

Total Resources:
- 1 EC2 (Jenkins) = 4 vCPUs
- 3 EKS Nodes = 6 vCPUs
- Total: 4 instances, 10 vCPUs ✅ Within limits!
```

### 📝 Deployment Steps

**Phase 1: Jenkins Server (Terraform)**
1. ✅ แก้ไข IAM: ใช้ `LabInstanceProfile`
2. ✅ แก้ไข EC2: เปลี่ยนเป็น `t3.xlarge`, key = `vockey`
3. ✅ แก้ไข Backend: ใช้ local backend (comment S3)
4. ✅ Run Terraform: `terraform init && terraform apply`

**Phase 2: ECR Setup**
1. ✅ สร้าง ECR repositories (console หรือ AWS CLI)
   ```bash
   aws ecr create-repository --repository-name backend --region us-east-1
   aws ecr create-repository --repository-name frontend --region us-east-1
   ```
2. ✅ Config AWS credentials ใน Jenkins (ถ้าจำเป็น)

**Phase 3: EKS Cluster**
1. ✅ สร้าง EKS cluster ด้วย eksctl
   ```bash
   eksctl create cluster \
     --name three-tier-cluster \
     --region us-east-1 \
     --node-type t3.large \
     --nodes 3 \
     --nodes-min 2 \
     --nodes-max 4 \
     --managed
   ```
2. ✅ ติดตั้ง AWS Load Balancer Controller
3. ✅ ติดตั้ง EBS CSI Driver (สำหรับ MongoDB PV)

**Phase 4: Jenkins Configuration**
1. ✅ ติดตั้ง Jenkins plugins
2. ✅ Config credentials (GitHub, AWS, SonarQube)
3. ✅ สร้าง Jenkins pipelines (Backend, Frontend)
4. ✅ แก้ไข Jenkinsfiles (ECR URLs, Git repos)

**Phase 5: Kubernetes Deployment**
1. ✅ สร้าง namespace: `kubectl create namespace three-tier`
2. ✅ แก้ไข K8s manifests (ECR URLs)
3. ✅ Deploy Database
4. ✅ Deploy Backend
5. ✅ Deploy Frontend
6. ✅ Deploy Ingress

**Phase 6: ArgoCD (Optional)**
1. ✅ ติดตั้ง ArgoCD บน EKS
2. ✅ Config GitOps sync

---

## Summary Checklist

### ✅ ก่อนเริ่ม Deploy:

- [x] ✅ EKS ใช้ได้ใน Learner Lab
- [x] ✅ ECR ใช้ได้ (ต้อง config credentials)
- [ ] ❓ ยืนยัน `LabEksClusterRole` มีหรือต้องสร้าง
- [ ] ❓ ยืนยัน LabRole permissions
- [x] ✅ Region: us-east-1
- [x] ✅ EC2 limit: 9 instances, 32 vCPUs
- [x] ✅ Instance types: up to `large` only
- [x] ✅ EBS: max 100GB

### 📝 Files ที่ต้องแก้ไข:

**Terraform (Jenkins-Server-TF/)**:
- [x] `ec2.tf`: เปลี่ยน instance_type, key_name, iam_instance_profile
- [x] `backend.tf`: comment S3 backend
- [x] ลบ `iam-role.tf`, `iam-policy.tf`, `iam-instance-profile.tf`

**Jenkins (Jenkins-Pipeline-Code/)**:
- [ ] `Jenkinsfile-Backend`: แก้ Git URL, ECR URL
- [ ] `Jenkinsfile-Frontend`: แก้ Git URL, ECR URL

**Kubernetes (Kubernetes-Manifests-file/)**:
- [ ] `Backend/deployment.yaml`: แก้ ECR image URL
- [ ] `Frontend/deployment.yaml`: แก้ ECR image URL, BACKEND_URL
- [ ] `ingress.yaml`: แก้หรือลบ domain name

---

## 🎓 คำแนะนำสุดท้าย

1. **เริ่มจาก Minimal Setup ก่อน**: 1 Jenkins EC2 + 2 EKS nodes
2. **ทดสอบ Jenkins pipeline ครั้งละ stage**: ไม่ต้อง run ทั้งหมดครั้งเดียว
3. **Monitor costs**: ใช้ AWS Cost Explorer ดู spending
4. **Stop resources เมื่อไม่ใช้**: หยุด EC2, scale EKS nodes เป็น 0
5. **Backup important data**: S3 สำหรับเก็บ configs, images

**Good luck with your deployment! 🚀**

### 🔴 คำถามด่วน (Critical Questions)

| # | คำถาม | หมายเหตุ |
|---|-------|----------|
| **Q1** | สามารถใช้ **Minikube/Kind** บน EC2 แทน EKS ได้ไหมครับ? | ทางเลือกหลักสำหรับ K8s |
| **Q2** | หรือควรใช้ **Docker Compose** แทน K8s ทั้งหมดครับ? | ง่ายกว่า แต่ไม่ใช่ K8s |
| **Q3** | ArgoCD ยังจำเป็นไหมถ้าไม่มี EKS? | GitOps workflow |
| **Q4** | Learner Lab มี default IAM Role (`LabRole`) ให้ใช้ไหมครับ? ARN คืออะไร? | สำคัญมากสำหรับ AWS access |
| **Q5** | `LabRole` มี permissions อะไรบ้างครับ? | ECR, S3, EC2 access |
| **Q9** | ECR ใช้ได้ใน Learner Lab ไหมครับ? | Container registry |
| **Q10** | ถ้า ECR ใช้ไม่ได้ ใช้ Docker Hub/GHCR แทนได้ไหม? | Alternative registry |

### 🟠 คำถามสำคัญ (Important Questions)

| # | คำถาม | หมายเหตุ |
|---|-------|----------|
| **Q6** | EC2 ใช้ existing Instance Profile ได้ไหมครับ? | IAM for EC2 |
| **Q7** | ควรใช้ local Terraform backend แทน S3 ไหมครับ? | State management |
| **Q12** | vCPU quota ใน Learner Lab เท่าไหร่ครับ? | Instance sizing |
| **Q13** | แนะนำ instance type อะไรครับ? | Resource planning |
| **Q15** | ควรใช้ default VPC ไหมครับ? | Networking |
| **Q17** | Resources หายเมื่อ session หมดไหมครับ? | Data persistence |

### 🟡 คำถามทั่วไป (General Questions)

| # | คำถาม | หมายเหตุ |
|---|-------|----------|
| **Q8** | สร้าง S3 bucket ใน Learner Lab ได้ไหมครับ? | Storage |
| **Q14** | EBS volume size มี limit ไหมครับ? | Storage |
| **Q16** | VPC/Subnet/SG มี limit ไหมครับ? | Networking |
| **Q18** | มีวิธี persist data ระหว่าง sessions ไหมครับ? | Development workflow |
| **Q19** | Extend session ได้กี่ครั้งครับ? | Time management |
| **Q20** | ดู remaining credits ได้อย่างไรครับ? | Budget tracking |
| **Q21** | Credits หมดแล้วขอเพิ่มได้ไหมครับ? | Budget |

---

## ทางเลือกที่เป็นไปได้

### Option A: Minikube/Kind บน EC2 (แนะนำ)

```
┌─────────────────────────────────────────────────────────────┐
│                    EC2 Instance (t2.xlarge)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Jenkins   │  │  SonarQube  │  │   Minikube  │         │
│  │   :8080     │  │   :9000     │  │  (K8s)      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                          │                                  │
│                    Docker Runtime                           │
└─────────────────────────────────────────────────────────────┘
```

**Pros**:
- ยังคง Kubernetes experience
- Jenkins pipelines ส่วนใหญ่ใช้ได้
- Ingress ใช้ NGINX แทน ALB

**Cons**:
- ต้องการ EC2 ขนาดใหญ่
- ไม่ได้เรียนรู้ managed K8s (EKS)

### Option B: Docker Compose (ง่ายที่สุด)

```
┌─────────────────────────────────────────────────────────────┐
│                    EC2 Instance (t2.large)                  │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │   Jenkins   │  │  SonarQube  │                          │
│  │   :8080     │  │   :9000     │                          │
│  └─────────────┘  └─────────────┘                          │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │         Docker Compose (Application)             │      │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │      │
│  │  │ Frontend │  │ Backend  │  │ MongoDB  │       │      │
│  │  │  :3000   │  │  :3500   │  │  :27017  │       │      │
│  │  └──────────┘  └──────────┘  └──────────┘       │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

**Pros**:
- ใช้ EC2 เล็กลงได้
- Setup ง่ายกว่า
- ไม่ต้อง K8s knowledge

**Cons**:
- ไม่ได้เรียนรู้ Kubernetes
- ไม่มี GitOps (ArgoCD)
- Pipeline ต้องเขียนใหม่

### Option C: Hybrid (Jenkins + Minikube แยก EC2)

```
┌─────────────────────┐     ┌─────────────────────┐
│   EC2 #1 (t2.large) │     │   EC2 #2 (t2.large) │
│  ┌───────────────┐  │     │  ┌───────────────┐  │
│  │    Jenkins    │  │────▶│  │   Minikube    │  │
│  │   SonarQube   │  │     │  │  (K8s Apps)   │  │
│  └───────────────┘  │     │  └───────────────┘  │
└─────────────────────┘     └─────────────────────┘
```

**Pros**:
- แยก workloads
- EC2 เล็กลงแต่ละตัว

**Cons**:
- ใช้ budget มากขึ้น
- Network configuration ซับซ้อนขึ้น

---

## Summary Checklist

### ก่อนเริ่ม Deploy ต้องตรวจสอบ:

- [ ] ยืนยัน IAM Role/Instance Profile ที่ใช้ได้
- [ ] ยืนยัน EC2 instance type quota
- [ ] ยืนยัน EBS volume size limit
- [ ] ยืนยันว่า ECR ใช้ได้หรือไม่
- [ ] ตัดสินใจเลือก Option (A/B/C)
- [ ] ยืนยัน VPC strategy (default vs new)
- [ ] เข้าใจ session timeout และ data persistence

### Files ที่ต้องแก้ไข (หลังจากได้คำตอบ):

| ไฟล์ | การแก้ไข |
|------|----------|
| `ec2.tf` | เปลี่ยน instance type, ลบ IAM instance profile |
| `iam-*.tf` | ลบหรือแก้ไขใช้ existing role |
| `backend.tf` | เปลี่ยนเป็น local backend |
| `vpc.tf` | ใช้ default VPC หรือคงไว้ |
| `tools-install.sh` | ลบ eksctl ถ้าไม่ต้องการ, เพิ่ม Minikube ถ้าต้องการ |
| `Jenkinsfile-*` | แก้ ECR เป็น Docker Hub/GHCR |
| `deployment.yaml` | แก้ image URL |
| (ใหม่) `docker-compose.yaml` | สร้างถ้าเลือก Option B |

---

*เอกสารนี้สร้างเพื่อใช้ประกอบการปรึกษากับอาจารย์ก่อนเริ่ม deploy CI/CD Pipeline บน AWS Learner Lab*
