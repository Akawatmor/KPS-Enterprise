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

kubectl apply -f "${MANIFESTS_DIR}/Database/pvc.yaml"
log_info "  - MongoDB PVC created"

kubectl apply -f "${MANIFESTS_DIR}/Database/deployment.yaml"
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
# Deploy Ingress
# ----------------------------------------
echo ""
log_info "Step 5: Deploying Ingress (ALB)..."

kubectl apply -f "${MANIFESTS_DIR}/ingress.yaml"
log_info "  - Ingress created"

# Wait for ALB to be provisioned
log_info "  Waiting for ALB to be provisioned (this may take 2-5 minutes)..."
sleep 30

# Get ALB DNS
ALB_DNS=""
for i in {1..20}; do
    ALB_DNS=$(kubectl get ingress -n "$NAMESPACE" three-tier-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$ALB_DNS" ]; then
        break
    fi
    log_info "  Waiting for ALB address... ($i/20)"
    sleep 15
done

if [ -z "$ALB_DNS" ]; then
    log_warn "ALB DNS not available yet. Check later with:"
    log_info "  kubectl get ingress -n ${NAMESPACE}"
else
    log_success "ALB provisioned: ${ALB_DNS}"
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
echo "  ✅ MongoDB (1 pod, with PersistentVolume)"
echo "  ✅ Backend API (2 pods)"
echo "  ✅ Frontend (2 pods)"
echo "  ✅ Ingress (ALB)"
echo ""

if [ -n "$ALB_DNS" ]; then
    echo "Application URLs:"
    echo "  Frontend:  http://${ALB_DNS}/"
    echo "  Backend:   http://${ALB_DNS}/api/tasks"
    echo "  Health:    http://${ALB_DNS}/api/healthz"
    echo ""
    log_warn "Note: ALB may take a few more minutes to become fully operational."
    log_info "If the URL doesn't work immediately, wait 2-3 minutes and try again."
else
    log_warn "ALB DNS not available yet. Run this command to check:"
    echo "  kubectl get ingress -n ${NAMESPACE} -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'"
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
ALB_DNS=${ALB_DNS}

# URLs
FRONTEND_URL=http://${ALB_DNS}/
BACKEND_URL=http://${ALB_DNS}/api/tasks
HEALTH_URL=http://${ALB_DNS}/api/healthz

# Kubectl commands
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get ingress -n ${NAMESPACE}
EOF

log_success "Deployment info saved to: ${SCRIPT_DIR}/deployment-info.txt"
