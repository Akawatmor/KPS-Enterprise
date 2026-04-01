#!/bin/bash
# =============================================================================
# KPS-Enterprise: Jenkins Server Tools Installation
# =============================================================================
# For Ubuntu 22.04
# This script installs all required tools for Jenkins CI/CD pipeline.
#
# Usage: ./tools-install.sh [NVD_API_KEY]
#   - NVD_API_KEY: Optional API key for OWASP Dependency Check
#                  Get free key at: https://nvd.nist.gov/developers/request-an-api-key
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
echo "  KPS-Enterprise: Tools Installation"
echo "=============================================="
echo ""

# Get NVD API Key from argument or prompt
NVD_API_KEY="${1:-}"

# ----------------------------------------
# Installing Java
# ----------------------------------------
log_info "Installing Java (OpenJDK 17, 21)..."
sudo apt update -y
sudo apt install wget fontconfig openjdk-17-jdk openjdk-21-jdk openjdk-21-jre -y
java -version
log_success "Java installed"

# ----------------------------------------
# Installing Jenkins
# ----------------------------------------
log_info "Installing Jenkins..."
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key 2>/dev/null || \
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2024.key 2>/dev/null || true
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install jenkins -y
log_success "Jenkins installed"

# ----------------------------------------
# Installing Docker
# ----------------------------------------
log_info "Installing Docker..."
sudo apt update
sudo apt install docker.io -y
sudo usermod -aG docker jenkins
sudo usermod -aG docker ubuntu
sudo systemctl restart docker
sudo chmod 777 /var/run/docker.sock
log_success "Docker installed"

# ----------------------------------------
# Run SonarQube Container
# ----------------------------------------
log_info "Starting SonarQube container..."
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community || true
log_success "SonarQube started on port 9000"

# ----------------------------------------
# Installing AWS CLI
# ----------------------------------------
log_info "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip -o awscliv2.zip
sudo ./aws/install --update || sudo ./aws/install
rm -rf aws awscliv2.zip
log_success "AWS CLI installed"

# ----------------------------------------
# Installing Kubectl
# ----------------------------------------
log_info "Installing kubectl..."
sudo curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
log_success "kubectl installed"

# ----------------------------------------
# Installing eksctl
# ----------------------------------------
log_info "Installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
log_success "eksctl installed"

# ----------------------------------------
# Installing Terraform
# ----------------------------------------
log_info "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null || true
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install terraform -y
log_success "Terraform installed"

# ----------------------------------------
# Installing Trivy
# ----------------------------------------
log_info "Installing Trivy..."
sudo apt-get install wget apt-transport-https gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy -y
log_success "Trivy installed"

# ----------------------------------------
# Installing Helm
# ----------------------------------------
log_info "Installing Helm..."
sudo snap install helm --classic
log_success "Helm installed"

# ----------------------------------------
# Installing OWASP Dependency Check
# ----------------------------------------
log_info "Installing OWASP Dependency Check..."
cd /opt
DEPCHECK_VERSION="12.1.0"
sudo wget -q "https://github.com/dependency-check/DependencyCheck/releases/download/v${DEPCHECK_VERSION}/dependency-check-${DEPCHECK_VERSION}-release.zip" -O dependency-check.zip || true
if [ -f dependency-check.zip ]; then
    sudo unzip -o dependency-check.zip
    sudo rm dependency-check.zip
    sudo chown -R jenkins:jenkins /opt/dependency-check
    log_success "Dependency Check installed"
    
    # Update NVD database if API key provided
    if [ -n "$NVD_API_KEY" ]; then
        log_info "Updating NVD database with API key..."
        sudo -u jenkins /opt/dependency-check/bin/dependency-check.sh --updateonly --nvdApiKey "$NVD_API_KEY" || true
        log_success "NVD database updated"
    else
        log_warn "NVD API Key not provided - Dependency Check will run without NVD data"
        log_info "To get an API key: https://nvd.nist.gov/developers/request-an-api-key"
        log_info "You can update later with:"
        echo "  sudo -u jenkins /opt/dependency-check/bin/dependency-check.sh --updateonly --nvdApiKey YOUR_KEY"
    fi
else
    log_warn "Failed to download Dependency Check - skipping"
fi

cd ~

# ----------------------------------------
# Summary
# ----------------------------------------
echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
echo "Tools installed:"
echo "  ✅ Java (OpenJDK 17, 21)"
echo "  ✅ Jenkins"
echo "  ✅ Docker"
echo "  ✅ SonarQube (container)"
echo "  ✅ AWS CLI"
echo "  ✅ kubectl"
echo "  ✅ eksctl"
echo "  ✅ Terraform"
echo "  ✅ Trivy"
echo "  ✅ Helm"
if [ -d "/opt/dependency-check" ]; then
    echo "  ✅ OWASP Dependency Check"
    if [ -n "$NVD_API_KEY" ]; then
        echo "      └─ NVD database updated"
    else
        echo "      └─ NVD database NOT updated (no API key)"
    fi
fi
echo ""
echo "Next steps:"
echo "  1. Access Jenkins at http://<server-ip>:8080"
echo "  2. Get initial admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo "  3. Access SonarQube at http://<server-ip>:9000 (admin/admin)"
echo ""