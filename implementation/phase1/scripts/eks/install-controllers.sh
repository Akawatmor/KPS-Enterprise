#!/bin/bash
# KPS-Enterprise: Install EKS Controllers
# NOTE: AWS Load Balancer Controller requires OIDC which is not available in Learner Lab
# This script has been simplified to skip OIDC-dependent components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-kps-three-tier-cluster}"
REGION="${REGION:-us-east-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "  KPS-Enterprise: EKS Controllers Info"
echo "=============================================="
echo ""
echo -e "${YELLOW}[WARN] AWS Learner Lab Limitation:${NC}"
echo "  - OIDC Provider cannot be created in Learner Lab"
echo "  - AWS Load Balancer Controller and EBS CSI Driver require OIDC"
echo "  - Use Classic ELB (LoadBalancer service) instead of ALB Ingress"
echo "  - Use emptyDir for MongoDB storage instead of EBS PVC"
echo ""
echo -e "${GREEN}[INFO] Recommended approach for Learner Lab:${NC}"
echo "  1. Use 'type: LoadBalancer' services (creates Classic ELB)"
echo "  2. Use 'emptyDir' volumes for MongoDB (data not persistent)"
echo "  3. Skip AWS Load Balancer Controller installation"
echo ""
echo "=============================================="
echo ""

# Verify cluster access
echo -e "${GREEN}[INFO]${NC} Verifying cluster access..."
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Cannot access cluster. Check kubeconfig."
    exit 1
fi
echo -e "${GREEN}[SUCCESS]${NC} Cluster access verified"

# Install Helm if needed
if ! command -v helm &>/dev/null; then
    echo -e "${GREEN}[INFO]${NC} Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo ""
echo "=============================================="
echo "  Controllers Installation Skipped"
echo "=============================================="
echo ""
echo -e "${YELLOW}Due to Learner Lab OIDC limitations, the following are NOT installed:${NC}"
echo "  - AWS Load Balancer Controller (use Classic ELB instead)"
echo "  - AWS EBS CSI Driver (use emptyDir instead)"
echo ""
echo -e "${GREEN}Your application will still work using:${NC}"
echo "  - Classic ELB via 'type: LoadBalancer' services"
echo "  - emptyDir volumes for MongoDB (non-persistent)"
echo ""
echo "=============================================="
