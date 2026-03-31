#!/bin/bash
# =============================================================================
# KPS-Enterprise: Terraform Deployment Script
# =============================================================================
# This script provisions the Jenkins EC2 server infrastructure using Terraform.
# It creates: VPC, Subnet, Internet Gateway, Security Group, and EC2 instance.
#
# Prerequisites:
#   - AWS credentials configured (aws configure or Learner Lab credentials)
#   - Terraform installed (v1.0+)
#   - SSH key pair created in AWS console
#   - key-name updated in variables.tfvars
#
# Usage: ./start-terraform.sh [--auto-approve]
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../../../../src/Jenkins-Server-TF"

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
echo "=============================================="
echo "  KPS-Enterprise: Terraform Deployment"
echo "=============================================="
echo ""

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed. Please install Terraform v1.0+"
    exit 1
fi
TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4 2>/dev/null || terraform version | head -1 | awk '{print $2}' | tr -d 'v')
log_success "Terraform installed: v${TERRAFORM_VERSION}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured. Please run 'aws configure' or update ~/.aws/credentials"
    log_info "For Learner Lab: Copy credentials from AWS Details → AWS CLI"
    exit 1
fi
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS credentials configured (Account: ${AWS_ACCOUNT_ID})"

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    log_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi
log_success "Terraform directory found"

# Change to Terraform directory
cd "$TERRAFORM_DIR"
log_info "Working directory: $(pwd)"

# ----------------------------------------
# Check Configuration
# ----------------------------------------
log_info "Checking configuration files..."

# Check if key-name is set
KEY_NAME=$(grep 'key-name' variables.tfvars | cut -d'"' -f2)
if [ "$KEY_NAME" = "YOUR_KEY_PAIR_NAME" ]; then
    log_error "SSH key pair not configured!"
    log_info "Please edit src/Jenkins-Server-TF/variables.tfvars and set key-name to your AWS key pair"
    log_info "Create key pair in AWS Console: EC2 → Key Pairs → Create key pair"
    exit 1
fi
log_success "SSH key pair configured: ${KEY_NAME}"

# Check if key pair exists in AWS
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
    log_error "Key pair '${KEY_NAME}' does not exist in AWS!"
    log_info "Available key pairs:"
    aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text
    exit 1
fi
log_success "Key pair verified in AWS"

# Check backend configuration
if grep -q "kps-terraform-state-CHANGE_TO_YOUR_ACCOUNT_ID" backend.tf; then
    log_warn "S3 backend bucket name not updated. Options:"
    log_info "  1. Use local backend: Uncomment 'backend \"local\" {}' in backend.tf"
    log_info "  2. Update S3 bucket name with your account ID"
    log_info ""
    read -p "Do you want to use local backend? (y/n): " USE_LOCAL
    if [ "$USE_LOCAL" = "y" ] || [ "$USE_LOCAL" = "Y" ]; then
        log_info "Using local backend (state stored locally)"
        # Create a temporary backend override file
        cat > backend_override.tf << 'EOF'
terraform {
  backend "local" {}
}
EOF
        log_success "Local backend override created"
    else
        log_info "Please update backend.tf with correct S3 bucket name"
        exit 1
    fi
fi

# ----------------------------------------
# Terraform Init
# ----------------------------------------
log_info "Initializing Terraform..."
if [ -f "backend_override.tf" ]; then
    terraform init -reconfigure
else
    terraform init
fi

if [ $? -ne 0 ]; then
    log_error "Terraform init failed!"
    exit 1
fi
log_success "Terraform initialized"

# ----------------------------------------
# Terraform Validate
# ----------------------------------------
log_info "Validating Terraform configuration..."
terraform validate

if [ $? -ne 0 ]; then
    log_error "Terraform validation failed!"
    exit 1
fi
log_success "Terraform configuration is valid"

# ----------------------------------------
# Terraform Plan
# ----------------------------------------
log_info "Creating Terraform plan..."
terraform plan -var-file=variables.tfvars -out=tfplan

if [ $? -ne 0 ]; then
    log_error "Terraform plan failed!"
    exit 1
fi
log_success "Terraform plan created"

# ----------------------------------------
# Confirmation
# ----------------------------------------
if [ "$1" != "--auto-approve" ]; then
    echo ""
    log_warn "This will create AWS resources (VPC, EC2, Security Groups)."
    log_info "Estimated time: 3-5 minutes"
    log_info "Resources will incur costs if not in Learner Lab free tier."
    echo ""
    read -p "Do you want to proceed? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        log_info "Deployment cancelled"
        rm -f tfplan
        exit 0
    fi
fi

# ----------------------------------------
# Terraform Apply
# ----------------------------------------
log_info "Applying Terraform plan..."
terraform apply tfplan

if [ $? -ne 0 ]; then
    log_error "Terraform apply failed!"
    rm -f tfplan
    exit 1
fi

rm -f tfplan
log_success "Terraform apply completed!"

# ----------------------------------------
# Get Outputs
# ----------------------------------------
echo ""
log_info "Retrieving deployment information..."

# Get EC2 public IP
EC2_PUBLIC_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=KPS-Jenkins-server" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# Get EC2 instance ID
EC2_INSTANCE_ID=$(terraform output -raw ec2_instance_id 2>/dev/null || aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=KPS-Jenkins-server" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo ""
log_success "Jenkins EC2 Instance Deployed"
echo ""
echo "Instance Details:"
echo "  Instance ID:  ${EC2_INSTANCE_ID}"
echo "  Public IP:    ${EC2_PUBLIC_IP}"
echo "  Region:       us-east-1"
echo ""
echo "Access URLs (wait 5-10 minutes for tools to install):"
echo "  SSH:        ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_PUBLIC_IP}"
echo "  Jenkins:    http://${EC2_PUBLIC_IP}:8080"
echo "  SonarQube:  http://${EC2_PUBLIC_IP}:9000"
echo ""
log_warn "Initial Jenkins password: SSH into server and run:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
log_warn "SonarQube default credentials: admin / admin"
echo ""
echo "=============================================="

# Save connection info
cat > "${SCRIPT_DIR}/connection-info.txt" << EOF
# KPS-Enterprise Jenkins Server Connection Info
# Generated: $(date)

EC2_INSTANCE_ID=${EC2_INSTANCE_ID}
EC2_PUBLIC_IP=${EC2_PUBLIC_IP}
SSH_KEY=${KEY_NAME}

# SSH Connection
ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@${EC2_PUBLIC_IP}

# Jenkins URL (port 8080)
http://${EC2_PUBLIC_IP}:8080

# SonarQube URL (port 9000)
http://${EC2_PUBLIC_IP}:9000
EOF

log_success "Connection info saved to: ${SCRIPT_DIR}/connection-info.txt"
