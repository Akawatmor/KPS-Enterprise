#!/bin/bash
# =============================================================================
# KPS-Enterprise: Application Destroy Script
# =============================================================================
# This script removes the three-tier application and ArgoCD from EKS.
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
ARGOCD_NAMESPACE="argocd"

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

# Show current resources
log_info "Checking current resources..."

APP_EXISTS=false
ARGOCD_EXISTS=false

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    APP_EXISTS=true
    log_info "Application namespace '${NAMESPACE}' found"
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || true
fi

if kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
    ARGOCD_EXISTS=true
    log_info "ArgoCD namespace '${ARGOCD_NAMESPACE}' found"
fi

if [ "$APP_EXISTS" = false ] && [ "$ARGOCD_EXISTS" = false ]; then
    log_warn "No resources found. Nothing to delete."
    exit 0
fi

echo ""

# Confirmation
if [ "$1" != "--auto-approve" ]; then
    log_warn "This will delete:"
    [ "$APP_EXISTS" = true ] && echo "  - Application in namespace '${NAMESPACE}'"
    [ "$ARGOCD_EXISTS" = true ] && echo "  - ArgoCD in namespace '${ARGOCD_NAMESPACE}'"
    echo ""
    read -p "Are you sure? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Destroy cancelled"
        exit 0
    fi
fi

# ----------------------------------------
# Delete ArgoCD Application first
# ----------------------------------------
if [ "$ARGOCD_EXISTS" = true ]; then
    log_info "Deleting ArgoCD Application..."
    kubectl delete application kps-three-tier -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
    sleep 5
fi

# ----------------------------------------
# Delete Application Resources
# ----------------------------------------
if [ "$APP_EXISTS" = true ]; then
    # Delete Services with LoadBalancer first (releases ELB)
    log_info "Deleting LoadBalancer services..."
    kubectl delete svc frontend -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete svc api -n "$NAMESPACE" 2>/dev/null || true
    log_info "Waiting for ELB to be released (30s)..."
    sleep 30
    
    # Delete Ingress (if any)
    log_info "Deleting Ingress..."
    kubectl delete ingress --all -n "$NAMESPACE" 2>/dev/null || true
    
    # Delete Frontend
    log_info "Deleting Frontend..."
    kubectl delete deployment -l role=frontend -n "$NAMESPACE" 2>/dev/null || true
    
    # Delete Backend
    log_info "Deleting Backend..."
    kubectl delete deployment -l role=api -n "$NAMESPACE" 2>/dev/null || true
    
    # Delete MongoDB
    log_info "Deleting MongoDB..."
    kubectl delete deployment -l app=mongodb -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete svc mongodb-svc -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete pvc --all -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete secret mongo-sec -n "$NAMESPACE" 2>/dev/null || true
    
    # Delete namespace
    log_info "Deleting application namespace..."
    kubectl delete namespace "$NAMESPACE" --timeout=60s 2>/dev/null || true
    log_success "Application destroyed"
fi

# ----------------------------------------
# Delete ArgoCD
# ----------------------------------------
if [ "$ARGOCD_EXISTS" = true ]; then
    log_info "Deleting ArgoCD..."
    
    # Delete ArgoCD LoadBalancer service first
    kubectl delete svc argocd-server -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
    sleep 10
    
    # Delete ArgoCD namespace
    kubectl delete namespace "$ARGOCD_NAMESPACE" --timeout=120s 2>/dev/null || true
    log_success "ArgoCD destroyed"
fi

echo ""
log_success "All application resources destroyed successfully!"
echo ""
echo "Deleted:"
[ "$APP_EXISTS" = true ] && echo "  ✅ Application namespace '${NAMESPACE}'"
[ "$ARGOCD_EXISTS" = true ] && echo "  ✅ ArgoCD namespace '${ARGOCD_NAMESPACE}'"
echo ""
