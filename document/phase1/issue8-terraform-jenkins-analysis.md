# Issue #8: Analyze Terraform files for Jenkins Server infrastructure

**Status:** Open  
**Labels:** infrastructure, documentation  
**Assignee:** Akawatmor  
**Milestone:** Phase 1 - Week 1

## Terraform Files Analysis

### 1. provider.tf
**Purpose:** Configure AWS provider and set region

```hcl
provider "aws" {
  region = var.aws_region
}
```

**Key Points:**
- Uses variable for region flexibility
- Default region should be specified in variables.tf

### 2. vpc.tf
**Purpose:** Create VPC networking infrastructure

**Resources Created:**
- **VPC:** CIDR block 10.0.0.0/16
- **Subnet:** Public subnet for Jenkins server
- **Internet Gateway:** Enable internet access
- **Route Table:** Routes traffic to IGW
- **Route Table Association:** Links subnet to route table

**Configuration:**
```hcl
resource "aws_vpc" "jenkins_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}
```

### 3. ec2.tf
**Purpose:** Create Jenkins EC2 instance

**Specifications:**
- **Instance Type:** t2.2xlarge (8 vCPU, 32GB RAM) - **NEEDS MODIFICATION FOR LEARNER LAB**
- **AMI:** Amazon Linux 2 or Ubuntu (from gather.tf)
- **EBS Volume:** 30GB root volume
- **User Data:** tools-install.sh script
- **IAM Instance Profile:** Attached for AWS permissions

**Key Configuration:**
```hcl
resource "aws_instance" "jenkins_server" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.jenkins_subnet.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_profile.name
  
  root_block_device {
    volume_size = 30
  }
  
  user_data = file("${path.module}/tools-install.sh")
}
```

### 4. Security Group (in ec2.tf or separate file)
**Purpose:** Control inbound/outbound traffic

**Inbound Rules:**

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | 0.0.0.0/0 | SSH access |
| 80 | TCP | 0.0.0.0/0 | HTTP |
| 8080 | TCP | 0.0.0.0/0 | Jenkins UI |
| 9000 | TCP | 0.0.0.0/0 | SonarQube UI |
| 9090 | TCP | 0.0.0.0/0 | Prometheus (optional) |

**Security Consideration:** 
- Restrict SSH (port 22) to specific IP ranges in production
- Consider using AWS Session Manager instead of direct SSH

### 5. iam-role.tf
**Purpose:** Create IAM role for Jenkins EC2 instance

```hcl
resource "aws_iam_role" "jenkins_role" {
  name = "jenkins-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
```

### 6. iam-policy.tf
**Purpose:** Attach policies to Jenkins role

**Policy Attached:** AdministratorAccess

**⚠️ WARNING:** AdministratorAccess is overly permissive
- **Recommended:** Create custom policy with minimal required permissions:
  - ECR (push/pull images)
  - EKS (cluster management)
  - S3 (artifact storage)
  - CloudWatch (logs)

### 7. iam-instance-profile.tf
**Purpose:** Attach IAM role to EC2 instance

```hcl
resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile"
  role = aws_iam_role.jenkins_role.name
}
```

### 8. backend.tf
**Purpose:** Configure Terraform remote state storage

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "jenkins/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**Learner Lab Consideration:**
- S3 bucket must be created manually first
- Consider using local backend for short-lived environments

### 9. gather.tf
**Purpose:** Data sources for dynamic values

**Typical Use:**
```hcl
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

### 10. variables.tf
**Purpose:** Define input variables

**Expected Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| aws_region | us-east-1 | AWS region |
| instance_type | t2.2xlarge | EC2 instance type |
| vpc_cidr | 10.0.0.0/16 | VPC CIDR block |
| key_name | - | SSH key pair name |

### 11. variables.tfvars
**Purpose:** Variable values for specific environments

```hcl
aws_region    = "us-east-1"
instance_type = "t3.xlarge"  # Modified for Learner Lab
key_name      = "my-jenkins-key"
```

## tools-install.sh Analysis

### Installed Tools

1. **Java OpenJDK 17** - Jenkins requirement
2. **Jenkins (latest)** - CI/CD server
3. **Docker (latest)** - Container runtime
4. **SonarQube LTS** - Static code analysis (Docker container)
5. **AWS CLI v2** - AWS operations
6. **kubectl v1.28.4** - Kubernetes CLI
7. **eksctl (latest)** - EKS cluster management
8. **Terraform (latest)** - Infrastructure as Code
9. **Trivy (latest)** - Container security scanning
10. **Helm (snap)** - Kubernetes package manager

### Installation Script Structure
```bash
#!/bin/bash

# Update system
sudo yum update -y

# Install Java
sudo yum install java-17-openjdk -y

# Install Jenkins
# [Jenkins repository setup and installation]

# Install Docker
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker jenkins

# Install AWS CLI
# [AWS CLI installation commands]

# Install kubectl
# [kubectl installation commands]

# ... other tools
```

### Post-Installation Steps
- Start Jenkins: `sudo systemctl start jenkins`
- Get initial admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- Start SonarQube: `docker run -d -p 9000:9000 sonarqube:lts`

## Learner Lab Modifications Required

### Critical Changes:
1. **Instance Type:** t2.2xlarge → t3.xlarge (4 vCPU, 16GB RAM)
2. **Security Group:** Restrict source IPs where possible
3. **IAM Policy:** Replace AdministratorAccess with least-privilege policy
4. **Backend:** Consider local state instead of S3

### Resource Calculation:
- Jenkins EC2: 4 vCPUs (t3.xlarge)
- Leaves 28 vCPUs for EKS worker nodes
- Fits within 9 instance limit (1 Jenkins + up to 8 EKS nodes)

## Commands

### Initialize Terraform
```bash
cd Jenkins-Server-TF/
terraform init
```

### Plan Deployment
```bash
terraform plan -var-file=variables.tfvars
```

### Apply Configuration
```bash
terraform apply -var-file=variables.tfvars -auto-approve
```

### Destroy Resources
```bash
terraform destroy -var-file=variables.tfvars -auto-approve
```

## Notes
- Verify all tools install successfully before proceeding
- Monitor disk usage (30GB limit)
- Consider splitting SonarQube to separate instance if resources tight
