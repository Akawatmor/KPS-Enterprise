#!/bin/bash
# =============================================================================
# KPS-Enterprise: EKS Cluster Destroy Script
# =============================================================================
# This script deletes the EKS cluster and all associated resources.
# WARNING: This will permanently delete your cluster and all workloads!
#
# Usage: ./destroy-eks.sh [--auto-approve]
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  KPS-Enterprise: EKS Cluster Destroy"
echo "=============================================="
echo ""

# ----------------------------------------
# Configuration
# ----------------------------------------
CLUSTER_NAME="kps-three-tier-cluster"
REGION="us-east-1"

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

if ! command -v eksctl &> /dev/null; then
    log_error "eksctl is not installed."
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured."
    exit 1
fi

# ----------------------------------------
# Check Cluster Exists
# ----------------------------------------
log_info "Checking for cluster '${CLUSTER_NAME}'..."
CLUSTER_EXISTS=$(eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || echo "")

if [ -z "$CLUSTER_EXISTS" ]; then
    log_warn "Cluster '${CLUSTER_NAME}' not found."
    log_info "Nothing to delete."
    exit 0
fi

log_info "Found cluster:"
echo "$CLUSTER_EXISTS"

# ----------------------------------------
# Delete Kubernetes Resources First
# ----------------------------------------
if kubectl cluster-info &> /dev/null; then
    log_info "Cleaning up Kubernetes resources..."
    
    # Delete ingress (releases ALB)
    kubectl delete ingress --all -n three-tier 2>/dev/null || true
    log_info "Ingress deleted"
    
    # Wait for ALB to be deleted
    log_info "Waiting for ALB to be released (30s)..."
    sleep 30
    
    # Delete application resources
    kubectl delete deployment,service,pvc --all -n three-tier 2>/dev/null || true
    log_info "Application resources deleted"
    
    # Delete namespace
    kubectl delete namespace three-tier 2>/dev/null || true
    log_info "Namespace deleted"
fi

# ----------------------------------------
# Uninstall Helm Charts
# ----------------------------------------
if command -v helm &> /dev/null; then
    log_info "Uninstalling Helm charts..."
    helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true
    helm uninstall aws-ebs-csi-driver -n kube-system 2>/dev/null || true
    log_info "Helm charts uninstalled"
fi

# ----------------------------------------
# Confirmation
# ----------------------------------------
echo ""
log_warn "⚠️  WARNING: This will PERMANENTLY DELETE:"
echo "  - EKS Cluster: ${CLUSTER_NAME}"
echo "  - All worker nodes"
echo "  - All CloudFormation stacks created by eksctl"
echo ""
log_warn "This action CANNOT be undone!"
echo ""

if [ "$1" != "--auto-approve" ]; then
    read -p "Are you absolutely sure? Type 'destroy' to confirm: " CONFIRM
    if [ "$CONFIRM" != "destroy" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
fi

# ----------------------------------------
# Delete EKS Cluster
# ----------------------------------------
echo ""
log_info "Deleting EKS cluster '${CLUSTER_NAME}'..."
log_info "This will take 5-10 minutes..."

START_TIME=$(date +%s)

eksctl delete cluster --name "$CLUSTER_NAME" --region "$REGION"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))

if [ $? -ne 0 ]; then
    log_error "EKS cluster deletion failed!"
    log_info "Try manually deleting CloudFormation stacks in AWS Console"
    exit 1
fi

# ----------------------------------------
# Cleanup Local Files
# ----------------------------------------
log_info "Cleaning up local files..."
rm -f "${SCRIPT_DIR}/cluster-info.txt"
rm -f "${SCRIPT_DIR}/eks-cluster-config.yaml"

# Remove cluster from kubeconfig
kubectl config delete-cluster "arn:aws:eks:${REGION}:*:cluster/${CLUSTER_NAME}" 2>/dev/null || true
kubectl config delete-context "arn:aws:eks:${REGION}:*:cluster/${CLUSTER_NAME}" 2>/dev/null || true

log_success "EKS cluster deleted in ${MINUTES} minutes!"
echo ""
echo "All EKS resources have been deleted."
