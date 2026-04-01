#!/bin/bash
# =============================================================================
# KPS-Enterprise: EKS Cluster Deployment Script
# =============================================================================
# This script creates an EKS cluster with worker nodes for the three-tier app.
#
# Prerequisites:
#   - AWS credentials configured
#   - eksctl installed
#   - kubectl installed
#   - LabEksClusterRole and LabRole ARNs (for Learner Lab)
#
# Usage: ./start-eks.sh
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
echo "  KPS-Enterprise: EKS Cluster Deployment"
echo "=============================================="
echo ""

# ----------------------------------------
# Configuration
# ----------------------------------------
CLUSTER_NAME="kps-three-tier-cluster"
REGION="us-east-1"
K8S_VERSION="1.30"
NODE_TYPE="t3.large"
NODE_COUNT=3
NODE_MIN=2
NODE_MAX=4

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

# Check eksctl
if ! command -v eksctl &> /dev/null; then
    log_error "eksctl is not installed."
    log_info "Install: curl --silent --location 'https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_\$(uname -s)_amd64.tar.gz' | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin"
    exit 1
fi
log_success "eksctl installed: $(eksctl version)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed."
    exit 1
fi
log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -1)"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured."
    exit 1
fi
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS Account: ${AWS_ACCOUNT_ID}"

# ----------------------------------------
# Get IAM Role ARNs (Learner Lab)
# ----------------------------------------
log_info "Checking for Learner Lab IAM roles..."

# Check for LabEksClusterRole (may have random suffix in Learner Lab)
LAB_EKS_ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'LabEksClusterRole')].Arn | [0]" --output text 2>/dev/null || echo "")
if [ -z "$LAB_EKS_ROLE_ARN" ] || [ "$LAB_EKS_ROLE_ARN" = "None" ]; then
    log_warn "LabEksClusterRole not found. Trying to create cluster without specifying role..."
    LAB_EKS_ROLE_ARN=""
else
    log_success "Found LabEksClusterRole: ${LAB_EKS_ROLE_ARN}"
fi

# Check for LabEksNodeRole (for node groups)
LAB_NODE_ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'LabEksNodeRole')].Arn | [0]" --output text 2>/dev/null || echo "")
if [ -z "$LAB_NODE_ROLE_ARN" ] || [ "$LAB_NODE_ROLE_ARN" = "None" ]; then
    # Fallback to LabRole
    LAB_NODE_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null || echo "")
fi

if [ -z "$LAB_NODE_ROLE_ARN" ] || [ "$LAB_NODE_ROLE_ARN" = "None" ]; then
    log_warn "LabEksNodeRole/LabRole not found. Using default node role creation."
    LAB_NODE_ROLE_ARN=""
else
    log_success "Found Node Role: ${LAB_NODE_ROLE_ARN}"
fi

# ----------------------------------------
# Check for Existing Cluster
# ----------------------------------------
log_info "Checking for existing cluster..."
EXISTING_CLUSTER=$(eksctl get cluster --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || echo "")
if [ -n "$EXISTING_CLUSTER" ]; then
    log_warn "Cluster '${CLUSTER_NAME}' already exists!"
    log_info "Use destroy-eks.sh to delete it first, or use a different name."
    
    # Update kubeconfig for existing cluster
    log_info "Updating kubeconfig for existing cluster..."
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    
    echo ""
    kubectl get nodes
    exit 0
fi

# ----------------------------------------
# Create EKS Cluster Config
# ----------------------------------------
log_info "Creating EKS cluster configuration..."

CONFIG_FILE="${SCRIPT_DIR}/eks-cluster-config.yaml"

if [ -n "$LAB_EKS_ROLE_ARN" ] && [ -n "$LAB_NODE_ROLE_ARN" ]; then
    # Learner Lab configuration with pre-existing IAM roles
    cat > "$CONFIG_FILE" << EOF
# EKS Cluster Configuration for AWS Learner Lab
# Uses pre-existing LabEksClusterRole and LabEksNodeRole
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "${K8S_VERSION}"

iam:
  serviceRoleARN: ${LAB_EKS_ROLE_ARN}

managedNodeGroups:
  - name: kps-nodegroup
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: ${NODE_MIN}
    maxSize: ${NODE_MAX}
    volumeSize: 30
    iam:
      instanceRoleARN: ${LAB_NODE_ROLE_ARN}
    labels:
      role: worker
      project: kps-enterprise
    tags:
      Environment: demo
      Project: KPS-Enterprise

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
EOF
else
    # Standard configuration (creates IAM roles automatically)
    cat > "$CONFIG_FILE" << EOF
# EKS Cluster Configuration
# Note: This will create IAM roles automatically (requires IAM permissions)
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${REGION}
  version: "${K8S_VERSION}"

managedNodeGroups:
  - name: kps-nodegroup
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: ${NODE_MIN}
    maxSize: ${NODE_MAX}
    volumeSize: 30
    labels:
      role: worker
      project: kps-enterprise
    tags:
      Environment: demo
      Project: KPS-Enterprise

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator"]
EOF
fi

log_success "Configuration saved to: ${CONFIG_FILE}"

# ----------------------------------------
# Confirmation
# ----------------------------------------
echo ""
log_warn "This will create an EKS cluster with the following configuration:"
echo "  Cluster Name:    ${CLUSTER_NAME}"
echo "  Region:          ${REGION}"
echo "  K8s Version:     ${K8S_VERSION}"
echo "  Node Type:       ${NODE_TYPE}"
echo "  Node Count:      ${NODE_COUNT}"
echo "  Estimated Time:  15-20 minutes"
echo ""
log_warn "EKS incurs costs even in Learner Lab (within budget)."
echo ""
read -p "Do you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log_info "Deployment cancelled"
    exit 0
fi

# ----------------------------------------
# Create EKS Cluster
# ----------------------------------------
echo ""
log_info "Creating EKS cluster... This will take 15-20 minutes."
log_info "Go grab a coffee! ☕"
echo ""

START_TIME=$(date +%s)

eksctl create cluster -f "$CONFIG_FILE"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

if [ $? -ne 0 ]; then
    log_error "EKS cluster creation failed!"
    exit 1
fi

log_success "EKS cluster created in ${MINUTES}m ${SECONDS}s!"

# ----------------------------------------
# Configure kubectl
# ----------------------------------------
log_info "Configuring kubectl..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
log_success "kubectl configured for cluster ${CLUSTER_NAME}"

# ----------------------------------------
# Create Namespace
# ----------------------------------------
log_info "Creating three-tier namespace..."
kubectl create namespace three-tier --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace three-tier project=kps-enterprise --overwrite
log_success "Namespace 'three-tier' created"

# ----------------------------------------
# Verify Deployment
# ----------------------------------------
log_info "Verifying cluster deployment..."
echo ""
echo "Cluster Info:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "Namespaces:"
kubectl get namespaces

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  EKS Cluster Deployment Complete!"
echo "=============================================="
echo ""
log_success "Cluster '${CLUSTER_NAME}' is ready!"
echo ""
echo "Cluster Details:"
echo "  Name:      ${CLUSTER_NAME}"
echo "  Region:    ${REGION}"
echo "  Nodes:     ${NODE_COUNT}x ${NODE_TYPE}"
echo "  Namespace: three-tier"
echo ""
log_info "Next Steps:"
echo "  1. Install AWS Load Balancer Controller: ./install-controllers.sh"
echo "  2. Deploy the application: ../app/deploy-app.sh"
echo ""
echo "=============================================="

# Save cluster info
cat > "${SCRIPT_DIR}/cluster-info.txt" << EOF
# KPS-Enterprise EKS Cluster Info
# Generated: $(date)

CLUSTER_NAME=${CLUSTER_NAME}
REGION=${REGION}
K8S_VERSION=${K8S_VERSION}
NODE_TYPE=${NODE_TYPE}
NODE_COUNT=${NODE_COUNT}

# Update kubeconfig
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Get cluster info
kubectl cluster-info
kubectl get nodes
EOF

log_success "Cluster info saved to: ${SCRIPT_DIR}/cluster-info.txt"
