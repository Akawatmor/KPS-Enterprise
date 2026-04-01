#!/bin/bash
# =============================================================================
# KPS-Enterprise: Master Deployment Orchestrator
# =============================================================================
# This script orchestrates the complete deployment of the KPS-Enterprise
# three-tier DevSecOps application to AWS Learner Lab.
#
# Components deployed:
#   1. Jenkins EC2 Server (Terraform)
#   2. EKS Cluster (eksctl)
#   3. EKS Controllers (Helm)
#   4. Docker Images (Docker Hub)
#   5. Application (Kubernetes)
#
# Usage: ./start.sh [--component COMPONENT] [--skip-to COMPONENT]
#
# Components: terraform, jenkins, eks, controllers, images, app, all
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# State tracking
STATE_FILE="${SCRIPT_DIR}/.deployment-state"

save_state() {
    echo "$1" > "$STATE_FILE"
}

get_state() {
    cat "$STATE_FILE" 2>/dev/null || echo "none"
}

# ----------------------------------------
# Banner
# ----------------------------------------
show_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}║     ${GREEN}KPS-Enterprise: Three-Tier DevSecOps Deployment${CYAN}              ║${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}║     Phase 1 - Week 2 Implementation                              ║${NC}"
    echo -e "${CYAN}║     AWS Learner Lab Environment                                  ║${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ----------------------------------------
# Menu
# ----------------------------------------
show_menu() {
    echo "What would you like to deploy?"
    echo ""
    echo "  1) Full Deployment (All Components)"
    echo "  2) Infrastructure Only (Terraform + EKS)"
    echo "  3) Terraform Only (Jenkins EC2)"
    echo "  4) EKS Only (Cluster + Controllers)"
    echo "  5) Application Only (Images + Deploy)"
    echo "  6) Skip to Step (Continue from checkpoint)"
    echo ""
    echo "  0) Exit"
    echo ""
}

# ----------------------------------------
# Prerequisites Check
# ----------------------------------------
check_prerequisites() {
    log_step "Checking Prerequisites..."
    echo ""
    
    local MISSING=0
    
    # AWS CLI
    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed"
    else
        log_error "AWS CLI not installed"
        MISSING=1
    fi
    
    # AWS Credentials
    if aws sts get-caller-identity &> /dev/null; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        log_success "AWS credentials configured (Account: ${AWS_ACCOUNT_ID})"
    else
        log_error "AWS credentials not configured"
        log_info "For Learner Lab: Copy credentials from AWS Details → AWS CLI"
        MISSING=1
    fi
    
    # Terraform
    if command -v terraform &> /dev/null; then
        log_success "Terraform installed"
    else
        log_error "Terraform not installed"
        MISSING=1
    fi
    
    # kubectl
    if command -v kubectl &> /dev/null; then
        log_success "kubectl installed"
    else
        log_error "kubectl not installed"
        MISSING=1
    fi
    
    # eksctl
    if command -v eksctl &> /dev/null; then
        log_success "eksctl installed"
    else
        log_error "eksctl not installed"
        MISSING=1
    fi
    
    # Helm
    if command -v helm &> /dev/null; then
        log_success "Helm installed"
    else
        log_warn "Helm not installed (needed for EKS controllers)"
    fi
    
    # Docker
    if command -v docker &> /dev/null; then
        log_success "Docker installed"
    else
        log_warn "Docker not installed locally (OK if building on Jenkins)"
    fi
    
    echo ""
    
    if [ $MISSING -eq 1 ]; then
        log_error "Missing required tools. Please install them first."
        return 1
    fi
    
    return 0
}

# ----------------------------------------
# Deploy Terraform (Jenkins EC2)
# ----------------------------------------
deploy_terraform() {
    log_step "Step 1: Deploying Jenkins EC2 with Terraform"
    echo ""
    
    "${SCRIPT_DIR}/scripts/terraform/start-terraform.sh"
    
    if [ $? -eq 0 ]; then
        save_state "terraform"
        log_success "Terraform deployment complete!"
    else
        log_error "Terraform deployment failed!"
        return 1
    fi
}

# ----------------------------------------
# Configure Jenkins (Manual Step)
# ----------------------------------------
configure_jenkins() {
    log_step "Step 2: Configure Jenkins and SonarQube"
    echo ""
    
    "${SCRIPT_DIR}/scripts/jenkins/verify-jenkins.sh"
    
    echo ""
    log_warn "Jenkins and SonarQube require MANUAL configuration."
    log_info "Please follow the setup guide above."
    echo ""
    read -p "Press Enter when Jenkins configuration is complete..."
    
    save_state "jenkins"
}

# ----------------------------------------
# Deploy EKS
# ----------------------------------------
deploy_eks() {
    log_step "Step 3: Creating EKS Cluster"
    echo ""
    
    "${SCRIPT_DIR}/scripts/eks/start-eks.sh"
    
    if [ $? -eq 0 ]; then
        save_state "eks"
        log_success "EKS cluster created!"
    else
        log_error "EKS cluster creation failed!"
        return 1
    fi
}

# ----------------------------------------
# Install Controllers
# ----------------------------------------
deploy_controllers() {
    log_step "Step 4: Installing EKS Controllers"
    echo ""
    
    "${SCRIPT_DIR}/scripts/eks/install-controllers.sh"
    
    if [ $? -eq 0 ]; then
        save_state "controllers"
        log_success "Controllers installed!"
    else
        log_error "Controller installation failed!"
        return 1
    fi
}

# ----------------------------------------
# Build Images
# ----------------------------------------
build_images() {
    log_step "Step 5: Building Docker Images"
    echo ""
    
    log_info "You can build images locally or on the Jenkins server."
    read -p "Build images locally now? (y/n): " BUILD_LOCAL
    
    if [ "$BUILD_LOCAL" = "y" ]; then
        "${SCRIPT_DIR}/scripts/app/build-images.sh"
        
        if [ $? -eq 0 ]; then
            save_state "images"
            log_success "Images built and pushed!"
        else
            log_error "Image build failed!"
            return 1
        fi
    else
        log_info "Skipping local build. Build images on Jenkins server later."
        save_state "images"
    fi
}

# ----------------------------------------
# Deploy Application
# ----------------------------------------
deploy_application() {
    log_step "Step 6: Deploying Application to EKS"
    echo ""
    
    "${SCRIPT_DIR}/scripts/app/deploy-app.sh"
    
    if [ $? -eq 0 ]; then
        save_state "app"
        log_success "Application deployed!"
    else
        log_error "Application deployment failed!"
        return 1
    fi
}

# ----------------------------------------
# Full Deployment
# ----------------------------------------
full_deployment() {
    log_info "Starting full deployment..."
    echo ""
    
    # Step 1: Terraform
    deploy_terraform || return 1
    echo ""
    
    # Step 2: Jenkins Config (Manual)
    configure_jenkins
    echo ""
    
    # Step 3: EKS
    deploy_eks || return 1
    echo ""
    
    # Step 4: Controllers
    deploy_controllers || return 1
    echo ""
    
    # Step 5: Images
    build_images || return 1
    echo ""
    
    # Step 6: Application
    deploy_application || return 1
    echo ""
    
    show_summary
}

# ----------------------------------------
# Summary
# ----------------------------------------
show_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    DEPLOYMENT COMPLETE!                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Load saved info
    if [ -f "${SCRIPT_DIR}/scripts/terraform/connection-info.txt" ]; then
        JENKINS_IP=$(grep "EC2_PUBLIC_IP=" "${SCRIPT_DIR}/scripts/terraform/connection-info.txt" | cut -d'=' -f2)
        echo "Jenkins:   http://${JENKINS_IP}:8080"
        echo "SonarQube: http://${JENKINS_IP}:9000"
    fi
    
    if [ -f "${SCRIPT_DIR}/scripts/app/deployment-info.txt" ]; then
        ALB_DNS=$(grep "ALB_DNS=" "${SCRIPT_DIR}/scripts/app/deployment-info.txt" | cut -d'=' -f2)
        if [ -n "$ALB_DNS" ]; then
            echo ""
            echo "Application: http://${ALB_DNS}/"
            echo "Backend API: http://${ALB_DNS}/api/tasks"
        fi
    fi
    
    echo ""
    log_info "Next Steps:"
    echo "  1. Access Jenkins and run the Backend pipeline"
    echo "  2. Run the Frontend pipeline"
    echo "  3. Test the application end-to-end"
    echo ""
}

# ----------------------------------------
# Main
# ----------------------------------------
show_banner

# Check prerequisites
check_prerequisites || exit 1

# Parse arguments
COMPONENT=""
SKIP_TO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --component)
            COMPONENT="$2"
            shift 2
            ;;
        --skip-to)
            SKIP_TO="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Handle direct component
if [ -n "$COMPONENT" ]; then
    case "$COMPONENT" in
        terraform) deploy_terraform ;;
        jenkins) configure_jenkins ;;
        eks) deploy_eks ;;
        controllers) deploy_controllers ;;
        images) build_images ;;
        app) deploy_application ;;
        all) full_deployment ;;
        *) log_error "Unknown component: $COMPONENT" ;;
    esac
    exit 0
fi

# Show menu
show_menu
read -p "Select option (0-6): " CHOICE

case $CHOICE in
    1)
        full_deployment
        ;;
    2)
        deploy_terraform && deploy_eks && deploy_controllers
        ;;
    3)
        deploy_terraform
        ;;
    4)
        deploy_eks && deploy_controllers
        ;;
    5)
        build_images && deploy_application
        ;;
    6)
        echo ""
        echo "Current state: $(get_state)"
        echo ""
        echo "Skip to which step?"
        echo "  1) jenkins - Configure Jenkins"
        echo "  2) eks - Create EKS Cluster"
        echo "  3) controllers - Install Controllers"
        echo "  4) images - Build Images"
        echo "  5) app - Deploy Application"
        read -p "Select step: " STEP
        
        case $STEP in
            1) configure_jenkins && deploy_eks && deploy_controllers && build_images && deploy_application ;;
            2) deploy_eks && deploy_controllers && build_images && deploy_application ;;
            3) deploy_controllers && build_images && deploy_application ;;
            4) build_images && deploy_application ;;
            5) deploy_application ;;
        esac
        ;;
    0)
        log_info "Exiting..."
        exit 0
        ;;
    *)
        log_error "Invalid option"
        exit 1
        ;;
esac
