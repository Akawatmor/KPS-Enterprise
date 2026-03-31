#!/bin/bash
# =============================================================================
# KPS-Enterprise: Jenkins Verification Script
# =============================================================================
# This script verifies the Jenkins installation and provides setup guidance.
#
# Usage: ./verify-jenkins.sh [JENKINS_IP]
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
echo "  KPS-Enterprise: Jenkins Verification"
echo "=============================================="
echo ""

# ----------------------------------------
# Get Jenkins IP
# ----------------------------------------
JENKINS_IP="${1:-}"

# Try to get from connection-info.txt
if [ -z "$JENKINS_IP" ] && [ -f "${SCRIPT_DIR}/../terraform/connection-info.txt" ]; then
    JENKINS_IP=$(grep "EC2_PUBLIC_IP=" "${SCRIPT_DIR}/../terraform/connection-info.txt" | cut -d'=' -f2)
fi

if [ -z "$JENKINS_IP" ]; then
    # Try to get from AWS
    JENKINS_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=KPS-Jenkins-server" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
fi

if [ -z "$JENKINS_IP" ] || [ "$JENKINS_IP" = "None" ]; then
    log_error "Could not determine Jenkins IP address."
    log_info "Usage: ./verify-jenkins.sh <JENKINS_IP>"
    exit 1
fi

log_info "Jenkins IP: ${JENKINS_IP}"

# ----------------------------------------
# Check Jenkins URL
# ----------------------------------------
echo ""
log_info "Checking Jenkins accessibility..."

JENKINS_URL="http://${JENKINS_IP}:8080"

# Check if Jenkins is responding
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}" --max-time 10 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "403" ]; then
    log_success "Jenkins is accessible (HTTP ${HTTP_STATUS})"
elif [ "$HTTP_STATUS" = "503" ]; then
    log_warn "Jenkins is starting up. Wait a few minutes."
else
    log_error "Jenkins is not accessible (HTTP ${HTTP_STATUS})"
    log_info "Wait for tools-install.sh to complete (5-10 minutes after EC2 start)"
fi

# ----------------------------------------
# Check SonarQube URL
# ----------------------------------------
echo ""
log_info "Checking SonarQube accessibility..."

SONAR_URL="http://${JENKINS_IP}:9000"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SONAR_URL}" --max-time 10 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    log_success "SonarQube is accessible"
else
    log_warn "SonarQube may still be starting (HTTP ${HTTP_STATUS})"
fi

# ----------------------------------------
# Configuration Guide
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Jenkins Configuration Guide"
echo "=============================================="
echo ""
log_info "Step 1: Get Initial Admin Password"
echo "  SSH into the Jenkins server and run:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
log_info "Step 2: Access Jenkins"
echo "  URL: ${JENKINS_URL}"
echo "  - Enter the initial admin password"
echo "  - Select 'Install suggested plugins'"
echo "  - Create your admin user"
echo ""
log_info "Step 3: Install Additional Plugins"
echo "  Go to: Manage Jenkins → Plugins → Available plugins"
echo "  Install these plugins:"
echo "  - Docker, Docker Pipeline"
echo "  - Kubernetes CLI, Kubernetes"
echo "  - SonarQube Scanner"
echo "  - OWASP Dependency-Check"
echo "  - NodeJS"
echo ""
log_info "Step 4: Configure Global Tools"
echo "  Go to: Manage Jenkins → Tools"
echo ""
echo "  JDK:"
echo "    Name: jdk"
echo "    Install automatically: ✓"
echo "    Version: OpenJDK 17"
echo ""
echo "  NodeJS:"
echo "    Name: nodejs"
echo "    Install automatically: ✓"
echo "    Version: NodeJS 18.x or later"
echo ""
echo "  SonarQube Scanner:"
echo "    Name: sonar-scanner"
echo "    Install automatically: ✓"
echo ""
echo "  OWASP Dependency-Check:"
echo "    Name: DP-Check"
echo "    Install automatically: ✓"
echo ""
log_info "Step 5: Add Credentials"
echo "  Go to: Manage Jenkins → Credentials → (global) → Add Credentials"
echo ""
echo "  1. GitHub Token (for Git operations):"
echo "     Kind: Secret text"
echo "     ID: github-token"
echo "     Secret: [Your GitHub Personal Access Token]"
echo ""
echo "  2. GitHub Credentials (for checkout):"
echo "     Kind: Username with password"
echo "     ID: GITHUB"
echo "     Username: [Your GitHub username]"
echo "     Password: [Your GitHub PAT]"
echo ""
echo "  3. Docker Hub Credentials:"
echo "     Kind: Username with password"
echo "     ID: dockerhub-credentials"
echo "     Username: [Your Docker Hub username]"
echo "     Password: [Your Docker Hub access token]"
echo ""
echo "  4. SonarQube Token:"
echo "     Kind: Secret text"
echo "     ID: sonar-token"
echo "     Secret: [Token from SonarQube]"
echo ""
log_info "Step 6: Configure SonarQube Server"
echo "  Go to: Manage Jenkins → System → SonarQube servers"
echo "  Name: sonar-server"
echo "  Server URL: http://localhost:9000"
echo "  Server authentication token: sonar-token (credential)"
echo ""
log_info "Step 7: Create Pipeline Jobs"
echo "  New Item → Pipeline:"
echo ""
echo "  Backend Pipeline:"
echo "    Name: kps-backend-pipeline"
echo "    Pipeline from SCM: Git"
echo "    Repository: https://github.com/Akawatmor/KPS-Enterprise.git"
echo "    Branch: phase1-implementation"
echo "    Script Path: src/Jenkins-Pipeline-Code/Jenkinsfile-Backend"
echo ""
echo "  Frontend Pipeline:"
echo "    Name: kps-frontend-pipeline"
echo "    Pipeline from SCM: Git"
echo "    Repository: https://github.com/Akawatmor/KPS-Enterprise.git"
echo "    Branch: phase1-implementation"
echo "    Script Path: src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend"
echo ""
echo "=============================================="
echo ""
log_warn "SonarQube Configuration:"
echo "  URL: ${SONAR_URL}"
echo "  Default credentials: admin / admin"
echo "  1. Change admin password immediately"
echo "  2. Create projects: kps-backend, kps-frontend"
echo "  3. Generate authentication token for Jenkins"
echo ""
echo "=============================================="

# Save the guide
cat > "${SCRIPT_DIR}/jenkins-setup-guide.txt" << EOF
# KPS-Enterprise Jenkins Setup Guide
# Generated: $(date)

JENKINS_URL=${JENKINS_URL}
SONAR_URL=${SONAR_URL}

# Initial Admin Password
ssh -i ~/.ssh/<key>.pem ubuntu@${JENKINS_IP}
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Required Plugins
- Docker, Docker Pipeline
- Kubernetes CLI, Kubernetes
- SonarQube Scanner
- OWASP Dependency-Check
- NodeJS

# Required Credentials
- github-token (Secret text)
- GITHUB (Username with password)
- dockerhub-credentials (Username with password)
- sonar-token (Secret text)

# Tool Configurations
- jdk (OpenJDK 17)
- nodejs (NodeJS 18.x)
- sonar-scanner (SonarQube Scanner)
- DP-Check (OWASP Dependency-Check)

# SonarQube Server Config
Name: sonar-server
URL: http://localhost:9000
Token: sonar-token
EOF

log_success "Setup guide saved to: ${SCRIPT_DIR}/jenkins-setup-guide.txt"
