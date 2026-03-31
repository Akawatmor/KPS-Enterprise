# KPS-Enterprise Phase 1 Implementation

Deploy the complete three-tier DevSecOps application to AWS Learner Lab.

## Quick Start

```bash
# Make scripts executable
chmod +x start.sh destroy.sh
chmod +x scripts/**/*.sh

# Deploy everything (interactive)
./start.sh

# Or deploy specific components
./start.sh --component terraform    # Jenkins EC2 only
./start.sh --component eks          # EKS cluster only
./start.sh --component app          # Application only
```

## Directory Structure

```
implementation/phase1/
├── start.sh                    # Master deployment orchestrator
├── destroy.sh                  # Master cleanup script
├── Implementation-Info.md      # Comprehensive documentation
├── README.md                   # This file
└── scripts/
    ├── terraform/
    │   ├── start-terraform.sh  # Deploy Jenkins EC2
    │   └── destroy-terraform.sh
    ├── jenkins/
    │   └── verify-jenkins.sh   # Jenkins setup guide
    ├── eks/
    │   ├── start-eks.sh        # Create EKS cluster
    │   ├── install-controllers.sh
    │   └── destroy-eks.sh
    └── app/
        ├── build-images.sh     # Build Docker images
        ├── deploy-app.sh       # Deploy to EKS
        └── destroy-app.sh
```

## Prerequisites

- AWS CLI configured with Learner Lab credentials
- Terraform v1.0+
- kubectl v1.28+
- eksctl
- Helm v3.x
- Docker Hub account

## Deployment Order

1. **Terraform** → Jenkins EC2 (3-5 min)
2. **Jenkins Config** → Manual UI setup (15-20 min)
3. **EKS** → Cluster creation (15-20 min)
4. **Controllers** → ALB + EBS CSI (5 min)
5. **Images** → Build & push (5-10 min)
6. **Application** → Deploy to EKS (3-5 min)

## Cleanup

```bash
# Destroy everything
./destroy.sh

# Destroy specific component
./destroy.sh --component app        # App only
./destroy.sh --component eks        # EKS + App
./destroy.sh --component terraform  # Jenkins only
```

## Documentation

See [Implementation-Info.md](./Implementation-Info.md) for:
- Detailed step-by-step instructions
- Verification procedures
- Troubleshooting guide
- Cost considerations

## Issues

Issues #16-32 from [Phase 1 Week 2 Milestone](https://github.com/Akawatmor/KPS-Enterprise/milestone/2)
