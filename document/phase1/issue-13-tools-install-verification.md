# Issue #13: Analyze tools-install.sh and verify tool compatibility

**Status:** Open  
**Labels:** infrastructure, devops  
**Assignee:** Akawatmor  
**Milestone:** Phase 1 - Week 1

## Description
Review the tools-install.sh user data script and verify all tools are compatible with Learner Lab.

## Tools to Verify
- Java OpenJDK 17
- Jenkins (latest)
- Docker (latest)
- SonarQube LTS (Docker container)
- AWS CLI v2
- kubectl v1.28.4
- eksctl (latest)
- Terraform (latest)
- Trivy (latest)
- Helm (snap)

## Acceptance Criteria
- [ ] Verify each tool installs correctly on Amazon Linux 2 / Ubuntu
- [ ] Document any version conflicts or deprecations
- [ ] Document estimated disk space usage (must fit in 30GB EBS)
- [ ] Document estimated memory usage (must fit in instance type)

## Tool Installation Analysis

### 1. Java OpenJDK 17

**Installation Commands:**
```bash
# Amazon Linux 2
sudo amazon-linux-extras enable java-openjdk17
sudo yum install java-17-openjdk java-17-openjdk-devel -y

# Ubuntu
sudo apt update
sudo apt install openjdk-17-jdk openjdk-17-jre -y
```

**Verification:**
```bash
java -version
# Expected: openjdk version "17.x.x"
```

**Disk Space:** ~300-400 MB  
**Memory Impact:** Minimal at rest, ~512MB-1GB when running Jenkins  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** Required for Jenkins and SonarQube Scanner

### 2. Jenkins (Latest)

**Installation Commands:**
```bash
# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
sudo yum install jenkins -y

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Verification:**
```bash
sudo systemctl status jenkins
curl http://localhost:8080
```

**Disk Space:** ~500MB initial, grows with jobs/artifacts  
**Memory Usage:** 2-4GB recommended  
**Port:** 8080  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** 
- Jenkins home directory: `/var/lib/jenkins`
- Configure max heap size if limited memory: `-Xmx2048m`

### 3. Docker (Latest)

**Installation Commands:**
```bash
# Amazon Linux 2
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG docker ec2-user

# Verify
docker --version
```

**Ubuntu Alternative:**
```bash
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
```

**Verification:**
```bash
docker ps
docker run hello-world
```

**Disk Space:** ~200-300MB for Docker engine  
**Additional:** Docker images can consume significant space  
**Memory Impact:** Minimal for daemon, containers consume per config  
**Compatibility:** ✅ Compatible with Learner Lab  
**Important:** Restart Jenkins after adding jenkins user to docker group

### 4. SonarQube LTS (Docker Container)

**Installation Commands:**
```bash
# Pull SonarQube LTS image
docker pull sonarqube:lts-community

# Run SonarQube container
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  -p 9092:9092 \
  sonarqube:lts-community
```

**Verification:**
```bash
docker ps | grep sonarqube
curl http://localhost:9000
```

**Access:**
- URL: http://<jenkins-ip>:9000
- Default credentials: admin/admin (change on first login)

**Disk Space:** ~600-800MB for image  
**Memory Usage:** 2-3GB recommended  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** 
- May need to increase vm.max_map_count:
  ```bash
  sudo sysctl -w vm.max_map_count=262144
  echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
  ```

### 5. AWS CLI v2

**Installation Commands:**
```bash
# Download and install
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

**Configuration:**
```bash
# Configure (not needed if using IAM role)
aws configure
```

**Disk Space:** ~200-300MB  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** 
- Use IAM instance profile instead of access keys
- Verify ECR access: `aws ecr describe-repositories`

### 6. kubectl v1.28.4

**Installation Commands:**
```bash
# Download specific version
curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"

# Make executable and move to PATH
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

**Version Note:**
- Use kubectl version matching or close to EKS version
- v1.28.4 compatible with EKS 1.28, 1.27, 1.29

**Disk Space:** ~50MB  
**Compatibility:** ✅ Compatible with Learner Lab  
**Configuration:**
```bash
# After EKS cluster creation
aws eks update-kubeconfig --name <cluster-name> --region <region>
kubectl get nodes
```

### 7. eksctl (Latest)

**Installation Commands:**
```bash
# Download latest
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

# Move to PATH
sudo mv /tmp/eksctl /usr/local/bin

# Verify
eksctl version
```

**Disk Space:** ~100MB  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** 
- Verify vCPU and instance limits before creating cluster
- Sample command:
  ```bash
  eksctl create cluster \
    --name three-tier-cluster \
    --region us-east-1 \
    --nodegroup-name worker-nodes \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 4
  ```

### 8. Terraform (Latest)

**Installation Commands:**
```bash
# Add HashiCorp repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# Install Terraform
sudo yum install terraform -y

# Verify
terraform version
```

**Ubuntu Alternative:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Disk Space:** ~100-150MB  
**Compatibility:** ✅ Compatible with Learner Lab  
**Notes:** 
- Used for provisioning Jenkins infrastructure
- Can also provision EKS (alternative to eksctl)

### 9. Trivy (Latest)

**Installation Commands:**
```bash
# Add Trivy repository
RELEASE_VERSION=$(curl --silent "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

# Download and install
wget https://github.com/aquasecurity/trivy/releases/download/v${RELEASE_VERSION}/trivy_${RELEASE_VERSION}_Linux-64bit.tar.gz
tar zxvf trivy_${RELEASE_VERSION}_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/

# Verify
trivy version
```

**Disk Space:** ~100MB binary + vulnerability DB (~200MB)  
**Compatibility:** ✅ Compatible with Learner Lab  
**Usage:**
```bash
# Scan filesystem
trivy fs --severity HIGH,CRITICAL .

# Scan image
trivy image nginx:latest
```

### 10. Helm (snap)

**Installation Commands:**

**For Ubuntu (snap available):**
```bash
sudo snap install helm --classic
```

**For Amazon Linux 2 (snap not available, use binary):**
```bash
# Download Helm binary
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

**Disk Space:** ~50-100MB  
**Compatibility:** ⚠️ Snap not available on Amazon Linux 2  
**Solution:** Use binary installation method  
**Notes:** 
- Used for installing AWS Load Balancer Controller
- Used for installing monitoring tools (Prometheus, Grafana)

## Complete Installation Script

### tools-install.sh (Amazon Linux 2 optimized)

```bash
#!/bin/bash
set -e

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install Java 17
echo "Installing Java OpenJDK 17..."
sudo amazon-linux-extras enable java-openjdk17
sudo yum install java-17-openjdk java-17-openjdk-devel -y

# Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Install Docker
echo "Installing Docker..."
sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker jenkins
sudo usermod -aG docker ec2-user

# Pull and run SonarQube
echo "Setting up SonarQube..."
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
docker pull sonarqube:lts-community
docker run -d --name sonarqube --restart unless-stopped \
  -p 9000:9000 -p 9092:9092 sonarqube:lts-community

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo yum install unzip -y
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# Install eksctl
echo "Installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# Install Terraform
echo "Installing Terraform..."
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install terraform -y
terraform version

# Install Trivy
echo "Installing Trivy..."
RELEASE_VERSION=$(curl --silent "https://api.github.com/repos/aquasecurity/trivy/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
wget https://github.com/aquasecurity/trivy/releases/download/v${RELEASE_VERSION}/trivy_${RELEASE_VERSION}_Linux-64bit.tar.gz
tar zxvf trivy_${RELEASE_VERSION}_Linux-64bit.tar.gz
sudo mv trivy /usr/local/bin/
rm -f trivy_${RELEASE_VERSION}_Linux-64bit.tar.gz
trivy version

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Restart Jenkins to pick up docker group membership
echo "Restarting Jenkins..."
sudo systemctl restart jenkins

echo "====================================="
echo "All tools installed successfully!"
echo "====================================="
echo "Jenkins: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "SonarQube: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
echo "Jenkins initial password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## Resource Usage Summary

### Disk Space Breakdown

| Tool | Disk Space |
|------|-----------|
| System (Amazon Linux 2) | ~2GB |
| Java OpenJDK 17 | ~400MB |
| Jenkins | ~500MB initial |
| Docker Engine | ~300MB |
| SonarQube (container) | ~800MB |
| AWS CLI v2 | ~300MB |
| kubectl | ~50MB |
| eksctl | ~100MB |
| Terraform | ~150MB |
| Trivy + DB | ~300MB |
| Helm | ~100MB |
| **Base Total** | ~5GB |
| **Jenkins workspace** | ~3-5GB (grows) |
| **Docker images** | ~5-10GB |
| **Total Estimated** | ~15-20GB |

**30GB EBS Volume:** ✅ Sufficient with monitoring

### Memory Usage Breakdown

| Component | Memory Usage |
|-----------|-------------|
| OS + System | ~500MB |
| Jenkins | ~2-4GB |
| SonarQube | ~2-3GB |
| Docker Daemon | ~200MB |
| Running Containers | Variable |
| **Total Active** | ~5-8GB |

**Recommended Instance:** t3.xlarge (16GB RAM) ✅  
**Minimum Instance:** t3.large (8GB RAM) ⚠️ Tight

### CPU Usage

- Normal operation: 1-2 cores
- During builds: 3-4 cores
- **Recommended:** t3.xlarge (4 vCPU) ✅

## Version Compatibility Matrix

| Tool | Version | EKS 1.28 | EKS 1.29 | Notes |
|------|---------|----------|----------|-------|
| kubectl | 1.28.4 | ✅ | ✅ | ±1 version skew supported |
| eksctl | Latest | ✅ | ✅ | Always use latest |
| Helm | 3.x | ✅ | ✅ | v3 required |
| AWS CLI | v2 | ✅ | ✅ | v2 recommended |
| Terraform | Latest | ✅ | ✅ | Use AWS provider ~> 5.0 |

## Common Installation Issues

### Issue 1: Jenkins Cannot Access Docker
**Symptom:** `permission denied while trying to connect to the Docker daemon`  
**Solution:**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Issue 2: SonarQube Container Exits
**Symptom:** `max virtual memory areas vm.max_map_count [65530] is too low`  
**Solution:**
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### Issue 3: Out of Disk Space
**Symptom:** `no space left on device`  
**Solution:**
```bash
# Clean Docker
docker system prune -a -f

# Clean Jenkins old builds
# Jenkins → Manage Jenkins → Configure System → Discard Old Builds

# Resize EBS volume (if allowed)
```

### Issue 4: kubectl Cannot Connect to Cluster
**Symptom:** `The connection to the server localhost:8080 was refused`  
**Solution:**
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

## Verification Checklist

```bash
# After installation, verify all tools:
java -version
jenkins --version
docker --version
docker ps
aws --version
kubectl version --client
eksctl version
terraform version
trivy version
helm version

# Check Jenkins
curl http://localhost:8080

# Check SonarQube
curl http://localhost:9000

# Check disk space
df -h

# Check memory
free -h
```

## Recommendations

### For Learner Lab Deployment:

1. ✅ **Use t3.xlarge for Jenkins** (4 vCPU, 16GB RAM)
2. ✅ **30GB EBS is sufficient** with regular cleanup
3. ⚠️ **Monitor disk space** - set up alerts
4. ✅ **All tools are compatible** - no blockers
5. ⚠️ **Helm via binary** - snap not available on Amazon Linux 2

### Optimization Tips:

- Configure Jenkins to discard old builds automatically
- Use Docker image lifecycle policies
- Run SonarQube in Docker (don't install separately)
- Use IAM roles instead of access keys
- Implement log rotation for Jenkins

### Alternative Approach:

If resources are tight, consider:
- Running SonarQube on separate instance (or SonarCloud)
- Using managed Jenkins (AWS CodeBuild) - not recommended for learning
- Reducing Jenkins heap size if memory constrained

## Next Steps

1. Test tools-install.sh on a test EC2 instance
2. Verify all tools work correctly
3. Document any adjustments needed
4. Integrate script into Terraform user_data
5. Create verification tests in Jenkins
