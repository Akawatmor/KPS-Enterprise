#!/bin/bash
# =============================================================================
# KPS-Enterprise: Prerequisites Setup Script
# =============================================================================
# This script automatically sets up required AWS resources:
#   - SSH Key Pair for EC2 access
#   - S3 Bucket for Terraform state
#   - DynamoDB Table for Terraform state locking
#
# Usage: ./setup-prerequisites.sh
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
echo "  KPS-Enterprise: Prerequisites Setup"
echo "=============================================="
echo ""

# ----------------------------------------
# Check AWS CLI
# ----------------------------------------
log_info "Checking AWS CLI..."

if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed"
    log_info "Install: curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip && unzip awscliv2.zip && sudo ./aws/install"
    exit 1
fi
log_success "AWS CLI installed"

# Check credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured"
    log_info "For Learner Lab: Copy credentials from AWS Details → AWS CLI"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-east-1")
log_success "AWS Account: ${AWS_ACCOUNT_ID}"
log_success "AWS Region: ${AWS_REGION}"

# ----------------------------------------
# Configuration
# ----------------------------------------
KEY_PAIR_NAME="kps-jenkins-key"
KEY_PAIR_FILE="${HOME}/.ssh/${KEY_PAIR_NAME}.pem"
S3_BUCKET_NAME="kps-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE_NAME="kps-terraform-lock"

echo ""
log_info "Resources to be created (if not exist):"
echo "  1. SSH Key Pair: ${KEY_PAIR_NAME}"
echo "     Location: ${KEY_PAIR_FILE}"
echo "  2. S3 Bucket: ${S3_BUCKET_NAME}"
echo "  3. DynamoDB Table: ${DYNAMODB_TABLE_NAME}"
echo ""

read -p "Do you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log_info "Setup cancelled"
    exit 0
fi

# ----------------------------------------
# 1. Create SSH Key Pair
# ----------------------------------------
echo ""
log_info "Step 1: Setting up SSH Key Pair..."

# Check if key pair exists in AWS
if aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_warn "Key pair '${KEY_PAIR_NAME}' already exists in AWS"
    
    # Check if local file exists
    if [ -f "$KEY_PAIR_FILE" ]; then
        log_success "Local key file found: ${KEY_PAIR_FILE}"
    else
        log_error "Key pair exists in AWS but local file not found: ${KEY_PAIR_FILE}"
        log_info "Options:"
        echo "  1. Delete the key pair in AWS Console and run this script again"
        echo "  2. Download the key pair manually if you have it"
        echo "  3. Use a different key pair name by editing this script"
        exit 1
    fi
else
    log_info "Creating new key pair: ${KEY_PAIR_NAME}"
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "${HOME}/.ssh"
    
    # Create key pair and save to file
    aws ec2 create-key-pair \
        --key-name "$KEY_PAIR_NAME" \
        --region "$AWS_REGION" \
        --query 'KeyMaterial' \
        --output text > "$KEY_PAIR_FILE"
    
    # Set proper permissions
    chmod 400 "$KEY_PAIR_FILE"
    
    log_success "Key pair created and saved to: ${KEY_PAIR_FILE}"
    log_info "Key pair permissions set to 400 (read-only)"
fi

# ----------------------------------------
# 2. Create S3 Bucket for Terraform State
# ----------------------------------------
echo ""
log_info "Step 2: Setting up S3 Bucket for Terraform state..."

# Check if bucket exists
if aws s3 ls "s3://${S3_BUCKET_NAME}" --region "$AWS_REGION" &> /dev/null; then
    log_warn "S3 bucket already exists: ${S3_BUCKET_NAME}"
else
    log_info "Creating S3 bucket: ${S3_BUCKET_NAME}"
    
    # Create bucket
    if [ "$AWS_REGION" = "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3api create-bucket \
            --bucket "$S3_BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        # Other regions need LocationConstraint
        aws s3api create-bucket \
            --bucket "$S3_BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    # Enable versioning
    log_info "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "$S3_BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$AWS_REGION"
    
    # Enable encryption
    log_info "Enabling encryption on S3 bucket..."
    aws s3api put-bucket-encryption \
        --bucket "$S3_BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }' \
        --region "$AWS_REGION"
    
    # Block public access
    log_info "Blocking public access on S3 bucket..."
    aws s3api put-public-access-block \
        --bucket "$S3_BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$AWS_REGION"
    
    log_success "S3 bucket created with versioning and encryption enabled"
fi

# ----------------------------------------
# 3. Create DynamoDB Table for State Locking
# ----------------------------------------
echo ""
log_info "Step 3: Setting up DynamoDB Table for Terraform state locking..."

# Check if table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_warn "DynamoDB table already exists: ${DYNAMODB_TABLE_NAME}"
else
    log_info "Creating DynamoDB table: ${DYNAMODB_TABLE_NAME}"
    
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=KPS-Enterprise Key=Purpose,Value=TerraformStateLock
    
    log_info "Waiting for table to become active..."
    aws dynamodb wait table-exists \
        --table-name "$DYNAMODB_TABLE_NAME" \
        --region "$AWS_REGION"
    
    log_success "DynamoDB table created"
fi

# ----------------------------------------
# 4. Update Terraform Configuration
# ----------------------------------------
echo ""
log_info "Step 4: Updating Terraform configuration files..."

TERRAFORM_DIR="${SCRIPT_DIR}/../../src/Jenkins-Server-TF"

# Update backend.tf
if [ -f "${TERRAFORM_DIR}/backend.tf" ]; then
    log_info "Updating backend.tf..."
    
    # Backup original
    cp "${TERRAFORM_DIR}/backend.tf" "${TERRAFORM_DIR}/backend.tf.backup"
    
    # Update bucket name
    sed -i "s/bucket[[:space:]]*=[[:space:]]*\".*\"/bucket         = \"${S3_BUCKET_NAME}\"/" "${TERRAFORM_DIR}/backend.tf"
    sed -i "s/dynamodb_table[[:space:]]*=[[:space:]]*\".*\"/dynamodb_table = \"${DYNAMODB_TABLE_NAME}\"/" "${TERRAFORM_DIR}/backend.tf"
    
    log_success "backend.tf updated"
fi

# Update variables.tfvars
if [ -f "${TERRAFORM_DIR}/variables.tfvars" ]; then
    log_info "Updating variables.tfvars..."
    
    # Backup original
    cp "${TERRAFORM_DIR}/variables.tfvars" "${TERRAFORM_DIR}/variables.tfvars.backup"
    
    # Update key-name
    sed -i "s/key-name[[:space:]]*=[[:space:]]*\".*\"/key-name = \"${KEY_PAIR_NAME}\"/" "${TERRAFORM_DIR}/variables.tfvars"
    
    log_success "variables.tfvars updated with key-name: ${KEY_PAIR_NAME}"
fi

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Prerequisites Setup Complete!"
echo "=============================================="
echo ""
log_success "All required resources are ready!"
echo ""
echo "Resources Created/Verified:"
echo "  ✓ SSH Key Pair: ${KEY_PAIR_NAME}"
echo "    File: ${KEY_PAIR_FILE}"
echo "  ✓ S3 Bucket: ${S3_BUCKET_NAME}"
echo "    - Versioning: Enabled"
echo "    - Encryption: AES256"
echo "    - Public Access: Blocked"
echo "  ✓ DynamoDB Table: ${DYNAMODB_TABLE_NAME}"
echo "    - Billing: Pay-per-request"
echo ""
echo "Terraform Configuration Updated:"
echo "  ✓ backend.tf - S3 backend configured"
echo "  ✓ variables.tfvars - SSH key pair configured"
echo ""
log_info "SSH Connection Command (after EC2 is created):"
echo "  ssh -i ${KEY_PAIR_FILE} ubuntu@<EC2_PUBLIC_IP>"
echo ""
log_info "Next Steps:"
echo "  1. Run: cd implementation/phase1"
echo "  2. Run: ./start.sh"
echo "  3. Or run Terraform directly: cd src/Jenkins-Server-TF && terraform init && terraform apply"
echo ""
echo "=============================================="

# Save configuration info
cat > "${SCRIPT_DIR}/prerequisites-info.txt" << EOF
# KPS-Enterprise Prerequisites Information
# Generated: $(date)

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
AWS_REGION=${AWS_REGION}

# SSH Key Pair
KEY_PAIR_NAME=${KEY_PAIR_NAME}
KEY_PAIR_FILE=${KEY_PAIR_FILE}

# S3 Bucket (Terraform State)
S3_BUCKET_NAME=${S3_BUCKET_NAME}

# DynamoDB Table (Terraform State Lock)
DYNAMODB_TABLE_NAME=${DYNAMODB_TABLE_NAME}

# SSH Command (after EC2 created)
ssh -i ${KEY_PAIR_FILE} ubuntu@<EC2_PUBLIC_IP>

# Clean up commands (if needed)
# aws ec2 delete-key-pair --key-name ${KEY_PAIR_NAME} --region ${AWS_REGION}
# aws s3 rb s3://${S3_BUCKET_NAME} --force --region ${AWS_REGION}
# aws dynamodb delete-table --table-name ${DYNAMODB_TABLE_NAME} --region ${AWS_REGION}
EOF

log_success "Configuration saved to: ${SCRIPT_DIR}/prerequisites-info.txt"
