#!/bin/bash
# =============================================================================
# KPS-Enterprise: Install AWS Load Balancer Controller and EBS CSI Driver
# =============================================================================
# This script installs the required controllers for EKS:
#   - AWS Load Balancer Controller (for ALB Ingress)
#   - AWS EBS CSI Driver (for PersistentVolumes)
#
# Prerequisites:
#   - EKS cluster created and kubectl configured
#   - Helm installed
#
# Usage: ./install-controllers.sh
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  KPS-Enterprise: Install EKS Controllers"
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

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    exit 1
fi
log_success "kubectl installed"

# Check helm
if ! command -v helm &> /dev/null; then
    log_error "Helm is not installed."
    log_info "Install: sudo snap install helm --classic"
    exit 1
fi
log_success "Helm installed: $(helm version --short)"

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    log_info "Run: aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}"
    exit 1
fi
log_success "Cluster access verified"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS Account: ${AWS_ACCOUNT_ID}"

# ----------------------------------------
# Add Helm Repositories
# ----------------------------------------
log_info "Adding Helm repositories..."

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver 2>/dev/null || true
helm repo update

log_success "Helm repositories updated"

# ----------------------------------------
# Install AWS Load Balancer Controller
# ----------------------------------------
echo ""
log_info "Installing AWS Load Balancer Controller..."

# Check if already installed
if kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
    log_warn "AWS Load Balancer Controller is already installed."
    kubectl get deployment -n kube-system aws-load-balancer-controller
else
    # For Learner Lab: Use LabRole (already has required permissions)
    # Get the OIDC provider URL
    OIDC_PROVIDER=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
        --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")
    
    log_info "OIDC Provider: ${OIDC_PROVIDER}"
    
    # Check for LabRole
    LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null || echo "")
    
    if [ -n "$LAB_ROLE_ARN" ] && [ "$LAB_ROLE_ARN" != "None" ]; then
        log_info "Using LabRole for controller..."
        
        # Create service account that uses LabRole
        kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LAB_ROLE_ARN}
EOF
        
        # Install with service account
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            --namespace kube-system \
            --set clusterName="${CLUSTER_NAME}" \
            --set serviceAccount.create=false \
            --set serviceAccount.name=aws-load-balancer-controller \
            --set region="${REGION}" \
            --set vpcId=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
                --query "cluster.resourcesVpcConfig.vpcId" --output text)
    else
        log_info "LabRole not found, installing with default service account..."
        
        helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
            --namespace kube-system \
            --set clusterName="${CLUSTER_NAME}" \
            --set region="${REGION}" \
            --set vpcId=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
                --query "cluster.resourcesVpcConfig.vpcId" --output text)
    fi
    
    log_info "Waiting for Load Balancer Controller to be ready..."
    kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=300s
    
    log_success "AWS Load Balancer Controller installed!"
fi

echo ""
kubectl get deployment -n kube-system aws-load-balancer-controller

# ----------------------------------------
# Install AWS EBS CSI Driver
# ----------------------------------------
echo ""
log_info "Installing AWS EBS CSI Driver..."

# Check if already installed
if kubectl get deployment -n kube-system ebs-csi-controller &> /dev/null; then
    log_warn "AWS EBS CSI Driver is already installed."
    kubectl get deployment -n kube-system ebs-csi-controller
else
    # Check for LabRole
    LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null || echo "")
    
    if [ -n "$LAB_ROLE_ARN" ] && [ "$LAB_ROLE_ARN" != "None" ]; then
        log_info "Installing EBS CSI Driver with LabRole..."
        
        # Create service account
        kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ebs-csi-controller-sa
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LAB_ROLE_ARN}
EOF
        
        helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
            --namespace kube-system \
            --set controller.serviceAccount.create=false \
            --set controller.serviceAccount.name=ebs-csi-controller-sa
    else
        log_info "Installing EBS CSI Driver with default configuration..."
        
        helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
            --namespace kube-system
    fi
    
    log_info "Waiting for EBS CSI Driver to be ready..."
    kubectl rollout status deployment/ebs-csi-controller -n kube-system --timeout=300s
    
    log_success "AWS EBS CSI Driver installed!"
fi

echo ""
kubectl get deployment -n kube-system ebs-csi-controller

# ----------------------------------------
# Create Default Storage Class
# ----------------------------------------
echo ""
log_info "Creating GP3 StorageClass..."

kubectl apply -f - << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  fsType: ext4
EOF

log_success "StorageClass 'gp3' created"

# ----------------------------------------
# Verify Installation
# ----------------------------------------
echo ""
log_info "Verifying installation..."
echo ""

echo "Load Balancer Controller:"
kubectl get deployment -n kube-system aws-load-balancer-controller
echo ""

echo "EBS CSI Driver:"
kubectl get deployment -n kube-system ebs-csi-controller
kubectl get daemonset -n kube-system ebs-csi-node
echo ""

echo "CSI Drivers:"
kubectl get csidriver
echo ""

echo "Storage Classes:"
kubectl get storageclass

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Controllers Installation Complete!"
echo "=============================================="
echo ""
log_success "AWS Load Balancer Controller: Installed"
log_success "AWS EBS CSI Driver: Installed"
log_success "GP3 StorageClass: Created (default)"
echo ""
log_info "Next Steps:"
echo "  1. Build and push Docker images: ../app/build-images.sh"
echo "  2. Deploy the application: ../app/deploy-app.sh"
echo ""
echo "=============================================="
