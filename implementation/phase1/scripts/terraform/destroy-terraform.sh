#!/bin/bash
# =============================================================================
# KPS-Enterprise: Terraform Destroy Script
# =============================================================================
# This script destroys the Jenkins EC2 server infrastructure.
# WARNING: This will permanently delete all Terraform-managed resources!
#
# Usage: ./destroy-terraform.sh [--auto-approve]
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
echo "  KPS-Enterprise: Terraform Destroy"
echo "=============================================="
echo ""

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
log_info "Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    log_error "Terraform is not installed."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured."
    exit 1
fi

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    log_error "Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Change to Terraform directory
cd "$TERRAFORM_DIR"
log_info "Working directory: $(pwd)"

# Check if state exists
if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    log_warn "No Terraform state found. Nothing to destroy."
    exit 0
fi

# ----------------------------------------
# Show Current Resources
# ----------------------------------------
log_info "Checking current resources..."
terraform state list 2>/dev/null || true

# ----------------------------------------
# Confirmation
# ----------------------------------------
echo ""
log_warn "⚠️  WARNING: This will PERMANENTLY DELETE the following resources:"
echo "  - EC2 Instance (KPS-Jenkins-server)"
echo "  - VPC, Subnet, Internet Gateway"
echo "  - Security Groups"
echo "  - Route Tables"
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
# Terraform Destroy
# ----------------------------------------
log_info "Initializing Terraform..."
terraform init -reconfigure 2>/dev/null || terraform init

log_info "Destroying infrastructure..."
if [ "$1" = "--auto-approve" ]; then
    terraform destroy -var-file=variables.tfvars -auto-approve
else
    terraform destroy -var-file=variables.tfvars
fi

if [ $? -ne 0 ]; then
    log_error "Terraform destroy failed!"
    exit 1
fi

# ----------------------------------------
# Cleanup
# ----------------------------------------
log_info "Cleaning up local files..."
rm -f tfplan backend_override.tf
rm -f "${SCRIPT_DIR}/connection-info.txt"

log_success "Infrastructure destroyed successfully!"
echo ""
echo "All Terraform-managed resources have been deleted."
echo "Terraform state files remain for reference."
