# KPS-Enterprise: Three-Tier DevSecOps Application

A complete end-to-end DevSecOps project implementing a three-tier web application (Frontend + Backend + Database) with CI/CD pipeline, deployed on AWS EKS, optimized for AWS Learner Lab environment.

## 📋 Project Overview

- **Frontend**: ReactJS
- **Backend**: Node.js (Express.js)
- **Database**: MongoDB
- **Container Orchestration**: AWS EKS (Elastic Kubernetes Service)
- **CI/CD**: Jenkins with DevSecOps pipeline
- **Infrastructure**: Terraform (Infrastructure as Code)
- **Container Registry**: Docker Hub
- **Security**: SonarQube, OWASP Dependency-Check, Trivy

## 👥 Team Members

1. Ratthatummanoon Kosasang - 6609612178
2. Akawat Moradsatian - 6609681231
3. Virtual Assistants - 0000011111

## 🚀 AWS Learner Lab Deployment

This project is optimized for **AWS Learner Lab** with resource allocation designed to work within strict limits:

### Resource Allocation

| Component | Instance Type | Count | vCPU | RAM | Purpose |
|-----------|--------------|-------|------|-----|---------|
| **Jenkins Server** | t3.large | 1 | 2 | 8 GB | CI/CD + SonarQube + Docker |
| **EKS Control Plane** | AWS Managed | 1 | - | - | Kubernetes control plane |
| **EKS Worker Nodes** | t3.large | 3 | 6 | 24 GB | Application hosting |
| **TOTAL** | - | **4** | **8** | **32 GB** | **Within Learner Lab limits** ✅ |

### Learner Lab Constraints

- ✅ **Max 9 EC2 instances** - Using 4 (44% utilization)
- ✅ **Max 32 vCPUs** - Using 8 (25% utilization)
- ✅ **Instance types limited to *.large** - Using t3.large
- ✅ **Regions: us-east-1 or us-west-2** - Deployed in us-east-1

### Key Adaptations for Learner Lab

1. **IAM Roles**: Use pre-existing `LabRole`, `LabInstanceProfile`, and `LabEksClusterRole`
2. **Instance Types**: Maximum `t3.large` (2 vCPU, 8 GB) instead of original `t2.2xlarge`
3. **Container Registry**: Docker Hub (private) instead of AWS ECR (read-only access)
4. **Terraform Backend**: S3 + DynamoDB (manually created before Terraform)

### Deployment Guide

See detailed documentation:
- [Resource Allocation Plan](document/phase1/issue-15-resource-allocation-plan.md) - Complete resource planning
- [Learner Lab Limitations](document/learnerlab-problem-predocs.md) - All AWS constraints
- [Requirements Mapping](document/phase1/issue-11-requirements-mapping.md) - Code changes needed

## 📚 Documentation

- [Phase 1 Reports](document/phase1/) - Week 1 analysis and planning
- [Original Project Structure](document/original-project-structure.md) - Baseline documentation
- [Learner Lab Issues](document/learnerlab-problem-predocs.md) - Technical challenges and solutions

## 🛠️ Technology Stack

### Infrastructure & Deployment
- **Cloud Provider**: AWS (Learner Lab)
- **IaC**: Terraform
- **Container Orchestration**: Kubernetes (EKS)
- **Container Runtime**: Docker
- **Container Registry**: Docker Hub

### CI/CD Pipeline
- **Automation**: Jenkins
- **Code Quality**: SonarQube
- **Security Scanning**: 
  - SAST: SonarQube
  - SCA: OWASP Dependency-Check
  - Container Scanning: Trivy
- **GitOps**: ArgoCD (planned)

### Application Stack
- **Frontend**: ReactJS, Material-UI
- **Backend**: Node.js, Express.js
- **Database**: MongoDB
- **Load Balancer**: AWS Application Load Balancer (ALB)

## 🔐 Security Features (DevSecOps)

The CI/CD pipeline includes multiple security stages:

1. **SAST** - Static Application Security Testing with SonarQube
2. **SCA** - Software Composition Analysis with OWASP Dependency-Check
3. **Container Scanning** - Filesystem and image scanning with Trivy
4. **Quality Gates** - Automated quality checks before deployment
5. **Secrets Management** - Kubernetes Secrets and Jenkins Credentials

## 📦 Repository Structure

```
KPS-Enterprise/
├── document/                      # Project documentation
│   ├── phase1/                   # Phase 1 deliverables
│   ├── learnerlab-problem-predocs.md
│   └── original-project-structure.md
├── original-project/              # Original source code
│   ├── Application-Code/         # Frontend & Backend code
│   ├── Jenkins-Pipeline-Code/    # Jenkinsfiles
│   ├── Jenkins-Server-TF/        # Jenkins infrastructure
│   └── Kubernetes-Manifests-file/ # K8s deployments
└── README.md                      # This file
```

## 🚀 Quick Start (AWS Learner Lab)

### Prerequisites

1. Active AWS Learner Lab session
2. Docker Hub account with access token
3. GitHub account

### Deployment Steps

1. **Prepare Terraform Backend**
   ```bash
   aws s3 mb s3://kps-enterprise-terraform-state --region us-east-1
   aws dynamodb create-table --table-name kps-terraform-state-lock ...
   ```

2. **Deploy Jenkins Server**
   ```bash
   cd Jenkins-Server-TF/
   terraform init
   terraform plan
   terraform apply
   ```

3. **Create EKS Cluster**
   ```bash
   eksctl create cluster -f eks-config.yaml
   ```

4. **Deploy Application**
   ```bash
   kubectl apply -f Kubernetes-Manifests-file/
   ```

See [Resource Allocation Plan](document/phase1/issue-15-resource-allocation-plan.md) for detailed instructions.

## 📊 Project Status

- ✅ Phase 1, Week 1: Requirements Analysis & Resource Planning
- ⏳ Phase 1, Week 2: Infrastructure Deployment (In Progress)
- ⏳ Phase 1, Week 3: Application Deployment
- ⏳ Phase 2: CI/CD Pipeline Implementation
- ⏳ Phase 3: Security & Monitoring

## 📝 Reference Links

- [Original Medium Blog Post](https://blog.stackademic.com/advanced-end-to-end-devsecops-kubernetes-three-tier-project-using-aws-eks-argocd-prometheus-fbbfdb956d1a)
- [Original GitHub Repository](https://github.com/AmanPathak-DevOps/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project)
- [AWS Learner Lab Documentation](https://aws.amazon.com/training/digital/aws-learner-lab/)

## 📄 License

This project is for educational purposes as part of the Thammasat University curriculum.

---

**Note**: This is an adapted version of the original project, modified to work within AWS Learner Lab constraints. See documentation for all changes and adaptations made.
