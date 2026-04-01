#!/bin/bash
# =============================================================================
# KPS-Enterprise: Master Destroy Script
# =============================================================================
# This script tears down the complete KPS-Enterprise infrastructure.
#
# WARNING: This will permanently delete:
#   - Application resources on EKS
#   - EKS Cluster and all nodes
#   - Jenkins EC2 instance
#   - VPC and networking resources
#
# Usage: ./destroy.sh [--auto-approve] [--component COMPONENT]
#
# Components: app, eks, terraform, all
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_APPROVE=""

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# ----------------------------------------
# Banner
# ----------------------------------------
echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                                   ║${NC}"
echo -e "${RED}║     KPS-Enterprise: Infrastructure Destruction                    ║${NC}"
echo -e "${RED}║                                                                   ║${NC}"
echo -e "${RED}║     ⚠️  WARNING: This will DELETE all resources!                  ║${NC}"
echo -e "${RED}║                                                                   ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Parse arguments
COMPONENT=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE="--auto-approve"
            shift
            ;;
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ----------------------------------------
# Confirmation
# ----------------------------------------
if [ -z "$AUTO_APPROVE" ]; then
    log_warn "This will PERMANENTLY DELETE the following resources:"
    echo ""
    echo "  - Application deployments on EKS"
    echo "  - MongoDB with all data"
    echo "  - EKS Cluster and worker nodes"
    echo "  - AWS Load Balancer Controller"
    echo "  - Jenkins EC2 instance"
    echo "  - VPC, Subnets, Security Groups"
    echo "  - All associated EBS volumes"
    echo ""
    log_warn "This action CANNOT be undone!"
    echo ""
    read -p "Type 'DESTROY' to confirm: " CONFIRM
    if [ "$CONFIRM" != "DESTROY" ]; then
        log_info "Destruction cancelled"
        exit 0
    fi
fi

# ----------------------------------------
# Destroy Application
# ----------------------------------------
destroy_app() {
    log_step "Step 1: Destroying Application..."
    echo ""
    
    if "${SCRIPT_DIR}/scripts/app/destroy-app.sh" $AUTO_APPROVE; then
        log_success "Application destroyed"
    else
        log_warn "Application destruction had issues (may not be deployed)"
    fi
}

# ----------------------------------------
# Destroy EKS
# ----------------------------------------
destroy_eks() {
    log_step "Step 2: Destroying EKS Cluster..."
    echo ""
    
    if "${SCRIPT_DIR}/scripts/eks/destroy-eks.sh" $AUTO_APPROVE; then
        log_success "EKS cluster destroyed"
    else
        log_warn "EKS destruction had issues"
    fi
}

# ----------------------------------------
# Destroy Terraform (Jenkins)
# ----------------------------------------
destroy_terraform() {
    log_step "Step 3: Destroying Jenkins Infrastructure..."
    echo ""
    
    if "${SCRIPT_DIR}/scripts/terraform/destroy-terraform.sh" $AUTO_APPROVE; then
        log_success "Jenkins infrastructure destroyed"
    else
        log_warn "Terraform destruction had issues"
    fi
}

# ----------------------------------------
# Cleanup
# ----------------------------------------
cleanup() {
    log_step "Cleaning up local files..."
    
    rm -f "${SCRIPT_DIR}/scripts/terraform/connection-info.txt"
    rm -f "${SCRIPT_DIR}/scripts/jenkins/jenkins-setup-guide.txt"
    rm -f "${SCRIPT_DIR}/scripts/eks/cluster-info.txt"
    rm -f "${SCRIPT_DIR}/scripts/eks/eks-cluster-config.yaml"
    rm -f "${SCRIPT_DIR}/scripts/app/deployment-info.txt"
    rm -f "${SCRIPT_DIR}/scripts/app/image-info.txt"
    rm -f "${SCRIPT_DIR}/scripts/app/argocd-info.txt"
    rm -f "${SCRIPT_DIR}/scripts/prerequisites-info.txt"
    rm -f "${SCRIPT_DIR}/.deployment-state"
    
    log_success "Local files cleaned up"
}

# ----------------------------------------
# Execute
# ----------------------------------------
if [ -n "$COMPONENT" ]; then
    case "$COMPONENT" in
        app) destroy_app ;;
        eks) destroy_app && destroy_eks ;;
        terraform) destroy_terraform ;;
        all) destroy_app && destroy_eks && destroy_terraform && cleanup ;;
        *) log_error "Unknown component: $COMPONENT" ;;
    esac
else
    # Full destruction
    destroy_app
    echo ""
    destroy_eks
    echo ""
    destroy_terraform
    echo ""
    cleanup
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    DESTRUCTION COMPLETE                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_success "All infrastructure has been destroyed."
log_info "Remember to stop your AWS Learner Lab session to avoid any charges."
echo ""
