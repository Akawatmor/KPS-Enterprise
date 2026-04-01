#!/bin/bash
# =============================================================================
# KPS-Enterprise: Application Deployment Script
# =============================================================================
# This script deploys the three-tier application to EKS:
#   - MongoDB (Database)
#   - Backend API (Node.js)
#   - Frontend (React)
#   - Ingress (ALB)
#
# Prerequisites:
#   - EKS cluster created and kubectl configured
#   - AWS Load Balancer Controller installed
#   - Docker images pushed to Docker Hub
#
# Usage: ./deploy-app.sh DOCKERHUB_USER [IMAGE_TAG]
#   - DOCKERHUB_USER: Docker Hub username/organization
#   - IMAGE_TAG: Optional image tag to deploy (default: latest)
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../../../../src/Kubernetes-Manifests-file"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  KPS-Enterprise: Application Deployment"
echo "=============================================="
echo ""

# ----------------------------------------
# Configuration
# ----------------------------------------
NAMESPACE="three-tier"
DOCKERHUB_USER="${1:-}"
IMAGE_TAG="${2:-latest}"

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    log_info "Run: aws eks update-kubeconfig --name kps-three-tier-cluster --region us-east-1"
    exit 1
fi
log_success "Cluster connection verified"

# Check manifests directory
if [ ! -d "$MANIFESTS_DIR" ]; then
    log_error "Manifests directory not found: $MANIFESTS_DIR"
    exit 1
fi
log_success "Manifests directory found"

# Check for AWS Load Balancer Controller
if ! kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    log_warn "AWS Load Balancer Controller not found."
    log_info "Run: ../eks/install-controllers.sh"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi

# ----------------------------------------
# Get Docker Hub Username
# ----------------------------------------
if [ -z "$DOCKERHUB_USER" ]; then
    # Check for saved image info
    if [ -f "${SCRIPT_DIR}/image-info.txt" ]; then
        DOCKERHUB_USER=$(grep "DOCKERHUB_USER=" "${SCRIPT_DIR}/image-info.txt" | cut -d'=' -f2)
    fi
    
    if [ -z "$DOCKERHUB_USER" ]; then
        read -p "Enter Docker Hub username: " DOCKERHUB_USER
    fi
fi

if [ -z "$DOCKERHUB_USER" ]; then
    log_error "Docker Hub username is required."
    exit 1
fi

log_info "Using Docker Hub images from: ${DOCKERHUB_USER}"

# ----------------------------------------
# Update Manifests with Docker Hub User
# ----------------------------------------
log_info "Updating manifests with Docker Hub username..."

# Update Backend deployment
sed -i "s|image: .*kps-backend:.*|image: ${DOCKERHUB_USER}/kps-backend:${IMAGE_TAG}|g" "${MANIFESTS_DIR}/Backend/deployment.yaml"
sed -i "s|image: DOCKERHUB_USER/kps-backend:.*|image: ${DOCKERHUB_USER}/kps-backend:${IMAGE_TAG}|g" "${MANIFESTS_DIR}/Backend/deployment.yaml"

# Fix MongoDB connection string to include authSource for root user authentication
sed -i 's|mongodb://mongodb-svc:27017/todo?directConnection=true|mongodb://mongodb-svc:27017/todo?directConnection=true\&authSource=admin|g' "${MANIFESTS_DIR}/Backend/deployment.yaml"

# Update Frontend deployment
sed -i "s|image: .*kps-frontend:.*|image: ${DOCKERHUB_USER}/kps-frontend:${IMAGE_TAG}|g" "${MANIFESTS_DIR}/Frontend/deployment.yaml"
sed -i "s|image: DOCKERHUB_USER/kps-frontend:.*|image: ${DOCKERHUB_USER}/kps-frontend:${IMAGE_TAG}|g" "${MANIFESTS_DIR}/Frontend/deployment.yaml"

log_success "Manifests updated"

# ----------------------------------------
# Create Namespace
# ----------------------------------------
echo ""
log_info "Step 1: Creating namespace..."
kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"
log_success "Namespace '${NAMESPACE}' created"

# ----------------------------------------
# Deploy MongoDB
# ----------------------------------------
echo ""
log_info "Step 2: Deploying MongoDB..."

kubectl apply -f "${MANIFESTS_DIR}/Database/secrets.yaml"
log_info "  - MongoDB secrets created"

# Check if EBS CSI Driver is available for dynamic provisioning
if kubectl get pods -n kube-system -l app=ebs-csi-controller 2>/dev/null | grep -q Running; then
    log_info "  - EBS CSI Driver found, using PVC..."
    sed 's/storageClassName: ""/storageClassName: gp2/' "${MANIFESTS_DIR}/Database/pvc.yaml" | kubectl apply -f -
    log_info "  - MongoDB PVC created"
    # Remove custom command to allow docker-entrypoint.sh to initialize users
    cat "${MANIFESTS_DIR}/Database/deployment.yaml" | \
        sed '/command:/,/0\.0\.0\.0"/d' | \
        kubectl apply -f -
else
    log_warn "  - EBS CSI Driver not found (common in Learner Lab)"
    log_info "  - Using emptyDir volume for MongoDB (data non-persistent)"
    # Skip PVC and patch deployment to use emptyDir instead
    # Also remove custom command to allow docker-entrypoint.sh to initialize users
    cat "${MANIFESTS_DIR}/Database/deployment.yaml" | \
        sed 's/persistentVolumeClaim:/emptyDir: {}\'$'\n''          # claimName removed - using emptyDir/' | \
        sed '/claimName: mongo-volume-claim/d' | \
        sed '/command:/,/0\.0\.0\.0"/d' | \
        kubectl apply -f -
fi
log_info "  - MongoDB deployment created"

kubectl apply -f "${MANIFESTS_DIR}/Database/service.yaml"
log_info "  - MongoDB service created"

# Wait for MongoDB to be ready
log_info "  Waiting for MongoDB to be ready..."
kubectl rollout status deployment/mongodb -n "$NAMESPACE" --timeout=300s
log_success "MongoDB deployed and ready"

# ----------------------------------------
# Deploy Backend
# ----------------------------------------
echo ""
log_info "Step 3: Deploying Backend API..."

kubectl apply -f "${MANIFESTS_DIR}/Backend/deployment.yaml"
log_info "  - Backend deployment created"

kubectl apply -f "${MANIFESTS_DIR}/Backend/service.yaml"
log_info "  - Backend service created"

# Wait for Backend to be ready
log_info "  Waiting for Backend to be ready..."
kubectl rollout status deployment/api -n "$NAMESPACE" --timeout=300s
log_success "Backend deployed and ready"

# ----------------------------------------
# Deploy Frontend
# ----------------------------------------
echo ""
log_info "Step 4: Deploying Frontend..."

kubectl apply -f "${MANIFESTS_DIR}/Frontend/deployment.yaml"
log_info "  - Frontend deployment created"

kubectl apply -f "${MANIFESTS_DIR}/Frontend/service.yaml"
log_info "  - Frontend service created"

# Wait for Frontend to be ready
log_info "  Waiting for Frontend to be ready..."
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=300s
log_success "Frontend deployed and ready"

# ----------------------------------------
# Deploy Ingress / LoadBalancer
# ----------------------------------------
echo ""
log_info "Step 5: Exposing Frontend via LoadBalancer..."

# Use LoadBalancer instead of ALB Ingress (Learner Lab doesn't support ALB Controller)
kubectl patch svc frontend -n "$NAMESPACE" -p '{"spec": {"type": "LoadBalancer"}}' 2>/dev/null || true

log_info "  Waiting for LoadBalancer address..."
FRONTEND_URL=""
for i in {1..20}; do
    FRONTEND_URL=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$FRONTEND_URL" ]; then
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

if [ -z "$FRONTEND_URL" ]; then
    log_warn "LoadBalancer address not available yet."
    log_info "Check later: kubectl get svc frontend -n ${NAMESPACE}"
else
    log_success "Frontend URL: http://${FRONTEND_URL}:3000"
fi

# ----------------------------------------
# Install ArgoCD for GitOps (Optional)
# ----------------------------------------
echo ""
log_info "Step 6: ArgoCD GitOps Setup..."

if kubectl get namespace argocd &> /dev/null; then
    log_info "  ArgoCD already installed"
    ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$ARGOCD_URL" ]; then
        log_success "  ArgoCD URL: http://${ARGOCD_URL}"
    fi
else
    read -p "Install ArgoCD for GitOps auto-deployment? (y/n): " INSTALL_ARGOCD
    if [ "$INSTALL_ARGOCD" == "y" ]; then
        if [ -f "${SCRIPT_DIR}/install-argocd.sh" ]; then
            "${SCRIPT_DIR}/install-argocd.sh"
        else
            log_warn "ArgoCD install script not found. Run manually:"
            log_info "  ${SCRIPT_DIR}/install-argocd.sh"
        fi
    else
        log_info "  Skipping ArgoCD installation"
        log_info "  To install later: ./install-argocd.sh"
    fi
fi

# ----------------------------------------
# Verify Deployment
# ----------------------------------------
echo ""
log_info "Verifying deployment..."
echo ""

echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide
echo ""

echo "Services:"
kubectl get svc -n "$NAMESPACE"
echo ""

echo "Ingress:"
kubectl get ingress -n "$NAMESPACE"
echo ""

echo "PVC:"
kubectl get pvc -n "$NAMESPACE"

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Application Deployment Complete!"
echo "=============================================="
echo ""
log_success "Three-tier application deployed to EKS!"
echo ""
echo "Resources Deployed:"
echo "  ✅ MongoDB (1 pod, emptyDir volume)"
echo "  ✅ Backend API (2 pods)"
echo "  ✅ Frontend (1 pod)"
echo "  ✅ LoadBalancer (Classic ELB)"
echo ""

if [ -n "$FRONTEND_URL" ]; then
    echo "Application URL:"
    echo "  Frontend:  http://${FRONTEND_URL}:3000"
    echo ""
    log_warn "Note: ELB may take 1-2 minutes to become fully operational."
else
    log_warn "Frontend URL not available yet. Run:"
    echo "  kubectl get svc frontend -n ${NAMESPACE}"
fi

echo ""
log_info "Useful Commands:"
echo "  kubectl get pods -n ${NAMESPACE}     # Check pod status"
echo "  kubectl logs -f -l role=api -n ${NAMESPACE}     # Backend logs"
echo "  kubectl logs -f -l role=frontend -n ${NAMESPACE} # Frontend logs"
echo ""
echo "=============================================="

# Save deployment info
cat > "${SCRIPT_DIR}/deployment-info.txt" << EOF
# KPS-Enterprise Deployment Info
# Generated: $(date)

NAMESPACE=${NAMESPACE}
DOCKERHUB_USER=${DOCKERHUB_USER}
IMAGE_TAG=${IMAGE_TAG}
FRONTEND_URL=http://${FRONTEND_URL}:3000

# Kubectl commands
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get application -n argocd  # ArgoCD status
EOF

log_success "Deployment info saved to: ${SCRIPT_DIR}/deployment-info.txt"
log_success "Application deployed!"
