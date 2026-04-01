#!/bin/bash
# =============================================================================
# KPS-Enterprise: ArgoCD Installation Script
# =============================================================================
# This script installs ArgoCD for GitOps-based continuous deployment.
# ArgoCD watches the Git repository and auto-deploys changes to EKS.
#
# GitOps Flow:
#   Jenkins (CI) → Build Image → Push to Docker Hub → Update deployment.yaml
#                                                            ↓
#   ArgoCD (CD) ← Detects Git change ← Git Push ←───────────┘
#        ↓
#   Auto sync to EKS cluster
#
# Usage: ./install-argocd.sh
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
echo "  KPS-Enterprise: ArgoCD Installation"
echo "=============================================="
echo ""

# ----------------------------------------
# Configuration
# ----------------------------------------
ARGOCD_NAMESPACE="argocd"
APP_NAMESPACE="three-tier"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/Akawatmor/KPS-Enterprise.git}"
GIT_BRANCH="${GIT_BRANCH:-phase1-implementation}"
MANIFESTS_PATH="${MANIFESTS_PATH:-src/Kubernetes-Manifests-file}"

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    exit 1
fi
log_success "Cluster connection verified"

# ----------------------------------------
# Check if ArgoCD is already installed
# ----------------------------------------
if kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
    log_warn "ArgoCD namespace already exists."
    if kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE &> /dev/null; then
        log_info "ArgoCD is already installed. Checking status..."
        kubectl get pods -n $ARGOCD_NAMESPACE
        
        # Get existing password and URL
        ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
        ARGOCD_URL=$(kubectl get svc argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ -n "$ARGOCD_PASSWORD" ]; then
            echo ""
            echo "=============================================="
            echo "  ArgoCD Access Info"
            echo "=============================================="
            echo "  URL:      http://${ARGOCD_URL}"
            echo "  Username: admin"
            echo "  Password: ${ARGOCD_PASSWORD}"
            echo "=============================================="
        fi
        
        read -p "Reinstall ArgoCD? (y/n): " REINSTALL
        if [ "$REINSTALL" != "y" ]; then
            log_info "Skipping ArgoCD installation."
            exit 0
        fi
        log_info "Reinstalling ArgoCD..."
        kubectl delete namespace $ARGOCD_NAMESPACE --wait=true 2>/dev/null || true
    fi
fi

# ----------------------------------------
# Install ArgoCD
# ----------------------------------------
echo ""
log_info "Step 1: Creating ArgoCD namespace..."
kubectl create namespace $ARGOCD_NAMESPACE
log_success "Namespace created"

log_info "Step 2: Installing ArgoCD..."
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
log_success "ArgoCD manifests applied"

log_info "Step 3: Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n $ARGOCD_NAMESPACE
log_success "ArgoCD server is ready"

# ----------------------------------------
# Expose ArgoCD via LoadBalancer
# ----------------------------------------
echo ""
log_info "Step 4: Exposing ArgoCD via LoadBalancer..."
kubectl patch svc argocd-server -n $ARGOCD_NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}'

log_info "  Waiting for LoadBalancer address..."
ARGOCD_URL=""
for i in {1..30}; do
    ARGOCD_URL=$(kubectl get svc argocd-server -n $ARGOCD_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$ARGOCD_URL" ]; then
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

if [ -z "$ARGOCD_URL" ]; then
    log_warn "LoadBalancer address not available yet."
    log_info "Check later: kubectl get svc argocd-server -n $ARGOCD_NAMESPACE"
else
    log_success "ArgoCD URL: http://${ARGOCD_URL}"
fi

# ----------------------------------------
# Get Admin Password
# ----------------------------------------
echo ""
log_info "Step 5: Getting admin password..."
ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
log_success "Password retrieved"

# ----------------------------------------
# Create Application for KPS-Enterprise
# ----------------------------------------
echo ""
log_info "Step 6: Creating ArgoCD Application for KPS-Enterprise..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kps-three-tier
  namespace: $ARGOCD_NAMESPACE
spec:
  project: default
  source:
    repoURL: $GIT_REPO_URL
    targetRevision: $GIT_BRANCH
    path: $MANIFESTS_PATH
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

log_success "ArgoCD Application created"

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  ArgoCD Installation Complete!"
echo "=============================================="
echo ""
echo "  ArgoCD URL:  http://${ARGOCD_URL}"
echo "  Username:    admin"
echo "  Password:    ${ARGOCD_PASSWORD}"
echo ""
echo "=============================================="
echo "  GitOps Flow Configured:"
echo "=============================================="
echo ""
echo "  Repository:  ${GIT_REPO_URL}"
echo "  Branch:      ${GIT_BRANCH}"
echo "  Path:        ${MANIFESTS_PATH}"
echo "  Target NS:   ${APP_NAMESPACE}"
echo ""
echo "  Auto-sync:   ENABLED"
echo "  Self-heal:   ENABLED"
echo "  Prune:       ENABLED"
echo ""
echo "=============================================="
echo "  How it works:"
echo "=============================================="
echo ""
echo "  1. Jenkins builds & pushes image to Docker Hub"
echo "  2. Jenkins updates deployment.yaml with new tag"
echo "  3. Jenkins pushes changes to Git"
echo "  4. ArgoCD detects Git change (auto-sync)"
echo "  5. ArgoCD deploys new version to EKS"
echo ""
echo "=============================================="

# Save ArgoCD info
cat > "${SCRIPT_DIR}/argocd-info.txt" << EOF
# ArgoCD Access Info
# Generated: $(date)

ARGOCD_URL=http://${ARGOCD_URL}
ARGOCD_USERNAME=admin
ARGOCD_PASSWORD=${ARGOCD_PASSWORD}

# GitOps Configuration
GIT_REPO_URL=${GIT_REPO_URL}
GIT_BRANCH=${GIT_BRANCH}
MANIFESTS_PATH=${MANIFESTS_PATH}
APP_NAMESPACE=${APP_NAMESPACE}

# Useful Commands
kubectl get application -n argocd
kubectl get pods -n argocd
argocd app sync kps-three-tier
EOF

log_success "ArgoCD info saved to: ${SCRIPT_DIR}/argocd-info.txt"
