#!/bin/bash
# =============================================================================
# KPS-Enterprise: Application Destroy Script
# =============================================================================
# This script removes the three-tier application from EKS.
#
# Usage: ./destroy-app.sh [--auto-approve]
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="three-tier"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  KPS-Enterprise: Application Destroy"
echo "=============================================="
echo ""

# Check kubectl
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    exit 1
fi

# Check namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_warn "Namespace '${NAMESPACE}' not found. Nothing to delete."
    exit 0
fi

# Show current resources
log_info "Current resources in namespace '${NAMESPACE}':"
kubectl get all -n "$NAMESPACE"
echo ""

# Confirmation
if [ "$1" != "--auto-approve" ]; then
    log_warn "This will delete all application resources."
    read -p "Are you sure? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
fi

# Delete Ingress first (releases ALB)
log_info "Deleting Ingress..."
kubectl delete ingress --all -n "$NAMESPACE" 2>/dev/null || true
log_info "Waiting for ALB to be released (30s)..."
sleep 30

# Delete Frontend
log_info "Deleting Frontend..."
kubectl delete deployment,service -l role=frontend -n "$NAMESPACE" 2>/dev/null || true

# Delete Backend
log_info "Deleting Backend..."
kubectl delete deployment,service -l role=api -n "$NAMESPACE" 2>/dev/null || true

# Delete MongoDB
log_info "Deleting MongoDB..."
kubectl delete deployment,service -l app=mongodb -n "$NAMESPACE" 2>/dev/null || true
kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null || true
kubectl delete secret mongo-sec -n "$NAMESPACE" 2>/dev/null || true

# Delete namespace
log_info "Deleting namespace..."
kubectl delete namespace "$NAMESPACE" --timeout=60s 2>/dev/null || true

log_success "Application destroyed successfully!"
echo ""
echo "All resources in namespace '${NAMESPACE}' have been deleted."
