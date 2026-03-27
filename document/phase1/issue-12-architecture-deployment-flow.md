# Issue #12: Analyze deployment flow and create architecture diagram

**Status:** Open  
**Labels:** documentation  
**Assignee:** Akawatmor  
**Milestone:** Phase 1 - Week 1

## Description
Create a comprehensive architecture diagram and deployment flow document.

## Acceptance Criteria
- [ ] Create overall architecture diagram (Developer → Git → Jenkins → ECR → EKS → ALB)
- [ ] Create AWS infrastructure diagram (VPC, EC2, EKS, ECR, ALB)
- [ ] Create Kubernetes cluster diagram (namespace, pods, services, ingress)
- [x] Document DevSecOps pipeline flow with security scan positions
- [ ] Identify potential improvements for Phase 2

## Overall Architecture Overview

### High-Level Flow

```
Developer Workstation
       ↓
   Git Push (GitHub)
       ↓
   Webhook Trigger
       ↓
Jenkins CI/CD Pipeline
  ├─ Build
  ├─ Security Scans (SonarQube, OWASP, Trivy)
  ├─ Docker Build
  └─ Push to ECR
       ↓
Update K8s Manifest (GitOps)
       ↓
ArgoCD Detects Change
       ↓
Deploy to EKS Cluster
       ↓
AWS ALB (Public Access)
       ↓
End Users
```

## AWS Infrastructure Architecture

### Components

1. **VPC (Virtual Private Cloud)**
   - CIDR: 10.0.0.0/16
   - Public Subnets (2+ for ALB)
   - Private Subnets (2+ for EKS nodes)
   - Internet Gateway
   - NAT Gateway (for private subnet internet access)

2. **Jenkins Server (EC2)**
   - Instance Type: t3.xlarge (modified for Learner Lab)
   - Security Group: Ports 22, 8080, 9000
   - IAM Role: ECR, EKS, S3 permissions
   - Tools: Jenkins, Docker, kubectl, eksctl, Terraform, Trivy

3. **Amazon ECR (Elastic Container Registry)**
   - Repository 1: three-tier-backend
   - Repository 2: three-tier-frontend
   - Lifecycle Policies: Keep last N images

4. **Amazon EKS (Elastic Kubernetes Service)**
   - Control Plane: Managed by AWS
   - Worker Nodes: 2-3 × t3.medium/large
   - Node Group: Auto Scaling enabled
   - Add-ons: VPC CNI, CoreDNS, kube-proxy

5. **Application Load Balancer (ALB)**
   - Scheme: Internet-facing
   - Target Type: IP (pod IPs)
   - Listeners: HTTP:80 (HTTPS:443 optional)
   - Path-based routing: / → frontend, /api → backend

6. **Supporting Services**
   - Amazon S3: Terraform state, artifacts
   - CloudWatch: Logs and monitoring
   - AWS Secrets Manager: Production secrets (optional)

### Network Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                     │
│                                                               │
│  ┌────────────────────┐         ┌────────────────────┐      │
│  │  Public Subnet 1   │         │  Public Subnet 2   │      │
│  │  (10.0.1.0/24)     │         │  (10.0.2.0/24)     │      │
│  │                    │         │                    │      │
│  │  ┌──────────┐      │         │  ┌──────────┐     │      │
│  │  │ Jenkins  │      │         │  │   ALB    │     │      │
│  │  │   EC2    │      │         │  └──────────┘     │      │
│  │  └──────────┘      │         │                    │      │
│  └────────────────────┘         └────────────────────┘      │
│          │                               │                   │
│  ┌────────────────────┐         ┌────────────────────┐      │
│  │  Private Subnet 1  │         │  Private Subnet 2  │      │
│  │  (10.0.11.0/24)    │         │  (10.0.12.0/24)    │      │
│  │                    │         │                    │      │
│  │  ┌──────────┐      │         │  ┌──────────┐     │      │
│  │  │ EKS Node │      │         │  │ EKS Node │     │      │
│  │  │    1     │      │         │  │    2     │     │      │
│  │  └──────────┘      │         │  └──────────┘     │      │
│  └────────────────────┘         └────────────────────┘      │
│          │                               │                   │
│  ┌───────────────────────────────────────────┐              │
│  │          Internet Gateway (IGW)           │              │
│  └───────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────┘
                        │
                    Internet
```

## Kubernetes Cluster Architecture

### Namespace Structure

```
default (or three-tier namespace)
├── Deployments
│   ├── frontend (1 replica)
│   ├── backend (2 replicas)
│   └── mongodb (1 replica)
├── Services
│   ├── frontend-svc (ClusterIP)
│   ├── backend-svc (ClusterIP)
│   └── mongodb-svc (ClusterIP)
├── Ingress
│   └── app-ingress (ALB)
├── Secrets
│   └── mongodb-secret
└── Storage
    ├── mongodb-pv (PersistentVolume)
    └── mongodb-pvc (PersistentVolumeClaim)
```

### Pod Communication Flow

```
External User
      ↓
  AWS ALB (internet-facing)
      ↓
  Ingress Controller
      ↓
  ┌─────────────────────────────┐
  │   Path: /                   │ → frontend-svc → Frontend Pod(s)
  │   Path: /api                │ → backend-svc → Backend Pod(s)
  └─────────────────────────────┘
                                         ↓
                                   mongodb-svc
                                         ↓
                                   MongoDB Pod
                                         ↓
                                 Persistent Volume
```

### Pod Details

**Frontend Pods:**
- Image: ECR frontend:${BUILD_NUMBER}
- Port: 3000
- Environment: REACT_APP_BACKEND_URL
- Replicas: 1 (scalable)

**Backend Pods:**
- Image: ECR backend:${BUILD_NUMBER}
- Port: 3500
- Environment: MongoDB connection details
- Replicas: 2
- Health Probes: liveness, readiness, startup

**MongoDB Pod:**
- Image: mongo:4.4.6
- Port: 27017
- Volume: Persistent storage
- Secrets: username, password
- Replicas: 1

## DevSecOps Pipeline Flow

### Detailed Pipeline Stages with Security Integration

```
┌───────────────────────────────────────────────────────────────┐
│                    JENKINS CI/CD PIPELINE                      │
└───────────────────────────────────────────────────────────────┘

1. Git Checkout
   └─> Clone source code from GitHub
   
2. Install Dependencies
   └─> npm install (Node.js packages)

3. 🔒 SonarQube Analysis (SAST)
   ├─> Static Application Security Testing
   ├─> Code quality checks
   ├─> Security vulnerability detection
   └─> Generates: Code quality report

4. 🔒 Quality Gate
   ├─> Evaluates SonarQube results
   └─> ❌ FAILS pipeline if quality gate fails

5. 🔒 OWASP Dependency Check (SCA)
   ├─> Software Composition Analysis
   ├─> Scans npm dependencies
   ├─> Identifies vulnerable libraries
   └─> Generates: dependency-check-report.xml

6. 🔒 Trivy Filesystem Scan
   ├─> Scans source code and configs
   ├─> Detects secrets, misconfigurations
   └─> Generates: trivy-fs-report.html

7. Docker Build
   ├─> Build container image
   └─> Tag: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo>:<build>

8. 🔒 Trivy Image Scan
   ├─> Scans Docker image
   ├─> Identifies OS vulnerabilities
   ├─> Identifies package vulnerabilities
   └─> Generates: trivy-image-report.html

9. Push to ECR
   ├─> AWS ECR authentication
   └─> Push Docker image to registry

10. Update K8s Manifest (GitOps Trigger)
    ├─> Clone K8s manifest repository
    ├─> Update deployment.yaml with new image tag
    ├─> Commit and push changes
    └─> ArgoCD monitors this repository

┌───────────────────────────────────────────────────────────────┐
│                    ARGOCD GITOPS DEPLOYMENT                    │
└───────────────────────────────────────────────────────────────┘

11. ArgoCD Sync
    ├─> Detects manifest change
    ├─> Compares desired state vs current state
    └─> Applies changes to EKS cluster

12. Kubernetes Rolling Update
    ├─> Creates new pods with new image
    ├─> Waits for health checks to pass
    ├─> Removes old pods
    └─> Zero downtime deployment
```

### Security Scan Positioning

| Stage | Tool | Type | Detects | Fails Pipeline? |
|-------|------|------|---------|-----------------|
| 3 | SonarQube | SAST | Code smells, bugs, vulnerabilities | Yes (if Quality Gate fails) |
| 4 | Quality Gate | Gate | Quality threshold | Yes |
| 5 | OWASP DP-Check | SCA | Vulnerable dependencies | Optional |
| 6 | Trivy FS | Secrets/Config | Hardcoded secrets, misconfig | Optional |
| 8 | Trivy Image | Container | OS/package vulnerabilities | Optional |

### Security Best Practices Implemented

✅ **Multiple layers of security scanning**
✅ **Fail-fast approach** (Quality Gate)
✅ **Secrets management** (K8s Secrets, not hardcoded)
✅ **Least privilege** (IAM roles)
✅ **Container image scanning** (before deployment)
✅ **GitOps pattern** (audit trail, rollback capability)

## Deployment Flow Timeline

### From Code Commit to Production

1. **Developer pushes code** → GitHub (0 min)
2. **Webhook triggers Jenkins** → Pipeline starts (instant)
3. **Build + Security Scans** → ~5-10 minutes
4. **Docker build + scan** → ~3-5 minutes
5. **Push to ECR** → ~1-2 minutes
6. **Update manifest + push** → ~30 seconds
7. **ArgoCD sync** → ~1-2 minutes (configurable interval)
8. **K8s rolling update** → ~2-3 minutes

**Total Time:** ~15-25 minutes from commit to production

## Infrastructure as Code Flow

```
1. Developer runs Terraform
   └─> terraform apply

2. Terraform provisions:
   ├─> VPC, Subnets, IGW, Route Tables
   ├─> Security Groups
   ├─> Jenkins EC2 instance
   ├─> IAM Roles and Policies
   └─> Executes tools-install.sh (user data)

3. Jenkins EC2 boots up
   ├─> Installs: Java, Jenkins, Docker, kubectl, etc.
   └─> Jenkins available at http://<public-ip>:8080

4. Manual EKS cluster creation
   └─> eksctl create cluster --config-file eks-config.yaml

5. Install AWS Load Balancer Controller
   └─> helm install aws-load-balancer-controller ...

6. Deploy application manifests
   └─> kubectl apply -f Kubernetes-Manifests-file/
```

## Monitoring and Observability (Future)

### Planned Components

1. **Prometheus** (metrics collection)
   - Scrapes K8s metrics
   - Scrapes application metrics
   - Port: 9090

2. **Grafana** (visualization)
   - Dashboards for K8s cluster health
   - Dashboards for application metrics
   - Port: 3001

3. **CloudWatch**
   - EKS cluster logs
   - Application logs
   - ALB access logs

## Potential Improvements for Phase 2

### Infrastructure
- [ ] Multi-AZ deployment for high availability
- [ ] Auto-scaling for EKS nodes (Cluster Autoscaler)
- [ ] Horizontal Pod Autoscaler (HPA) based on CPU/memory
- [ ] MongoDB replica set for database HA
- [ ] CloudFront CDN for frontend static assets
- [ ] HTTPS with ACM certificate
- [ ] Route53 for custom domain

### Security
- [ ] WAF (Web Application Firewall) on ALB
- [ ] Network Policies for pod-to-pod communication
- [ ] Pod Security Policies/Standards
- [ ] Secrets encryption at rest (KMS)
- [ ] AWS Secrets Manager integration
- [ ] Image signing and verification
- [ ] Runtime security (Falco)

### CI/CD
- [ ] Parallel pipeline stages for faster builds
- [ ] Automated rollback on deployment failure
- [ ] Canary deployments (progressive delivery)
- [ ] Blue/Green deployments
- [ ] Integration tests in pipeline
- [ ] Performance testing stage

### Monitoring
- [ ] Prometheus + Grafana stack
- [ ] Application Performance Monitoring (APM)
- [ ] Distributed tracing (Jaeger/X-Ray)
- [ ] Log aggregation (ELK stack or CloudWatch Insights)
- [ ] Alerting (PagerDuty, Slack)

### Database
- [ ] Automated backups
- [ ] Point-in-time recovery
- [ ] Read replicas for scalability
- [ ] Migration to Amazon DocumentDB
- [ ] Database connection pooling

### Cost Optimization
- [ ] Spot instances for non-production EKS nodes
- [ ] Fargate for serverless pods
- [ ] ECR lifecycle policies (delete old images)
- [ ] Resource request/limit optimization
- [ ] Reserved Instances for predictable workloads

### Developer Experience
- [ ] Local development with Skaffold
- [ ] Preview environments for PRs
- [ ] Self-service deployments
- [ ] Better logging and debugging tools

## Architecture Decision Records (ADRs)

### ADR-001: Use GitOps for Deployment
**Decision:** Use ArgoCD for GitOps-based deployment  
**Rationale:** 
- Declarative configuration
- Git as source of truth
- Easy rollback
- Audit trail

### ADR-002: Use ALB Ingress instead of NodePort
**Decision:** Use AWS Load Balancer Controller with Ingress  
**Rationale:**
- Native AWS integration
- Path-based routing
- SSL termination
- Auto-scaling support

### ADR-003: ClusterIP for Internal Services
**Decision:** Use ClusterIP for frontend, backend, mongodb services  
**Rationale:**
- Services not exposed externally
- Ingress provides external access
- Better security posture

### ADR-004: Separate ECR Repositories
**Decision:** Separate ECR repos for backend and frontend  
**Rationale:**
- Independent versioning
- Different lifecycle policies possible
- Clear separation of concerns

## Diagrams Location

**Note:** Actual diagrams should be created using:
- **Draw.io** (diagrams.net)
- **Lucidchart**
- **AWS Architecture Icons**
- **Kubernetes Icons**

Suggested diagram files:
- `architecture-overview.png` - High-level flow
- `aws-infrastructure.png` - VPC, EC2, EKS, ECR, ALB
- `kubernetes-cluster.png` - Pods, Services, Ingress
- `devsecops-pipeline.png` - CI/CD stages with security gates
- `network-flow.png` - Data flow and communication

## References

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Production Best Practices](https://learnk8s.io/production-best-practices)
- [OWASP DevSecOps Guidelines](https://owasp.org/www-project-devsecops-guideline/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
