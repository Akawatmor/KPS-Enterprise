# Jenkins Provisioning and Configuration Guide

**Created**: 2026-04-01  
**Status**: Complete  
**Target**: AWS Learner Lab Environment

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Provisioning](#step-by-step-provisioning)
4. [Detailed Configuration Guide](#detailed-configuration-guide)
5. [Troubleshooting](#troubleshooting)
6. [Verification Checklist](#verification-checklist)

---

## Overview

This guide provides **detailed, step-by-step instructions** for provisioning and configuring Jenkins after the EC2 instance is created. The process includes:

- Accessing Jenkins for the first time
- Installing required plugins
- Configuring global tools (JDK, NodeJS, SonarQube Scanner)
- Setting up credentials (GitHub, Docker Hub, SonarQube)
- Creating Jenkins pipeline jobs
- Configuring SonarQube integration

**Estimated Total Time**: 20-30 minutes

---

## Prerequisites

✅ Jenkins EC2 instance is running (created via Terraform)  
✅ Security group allows access to ports 8080 (Jenkins) and 9000 (SonarQube)  
✅ `tools-install.sh` has completed successfully  
✅ You have:
- GitHub Personal Access Token (PAT)
- Docker Hub username and access token
- SSH key to access EC2 instance

---

## Step-by-Step Provisioning

### Step 1: Wait for Installation to Complete

After Terraform creates the EC2 instance, the `tools-install.sh` script runs via `user_data`. This takes **5-10 minutes**.

**Check installation progress**:

```bash
# SSH into EC2
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Monitor installation log
tail -f /var/log/cloud-init-output.log

# Check if Jenkins is running
sudo systemctl status jenkins

# Check if SonarQube container is running
docker ps | grep sonar
```

**Expected output**:
```
jenkins.service - Jenkins Continuous Integration Server
   Loaded: loaded
   Active: active (running)
```

---

### Step 2: Get Initial Admin Password

Jenkins generates a one-time admin password during first startup.

**Option A: Via SSH**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Option B: From EC2 Console**
```bash
# Using AWS Session Manager (if configured)
aws ssm start-session --target <INSTANCE_ID>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

**Expected output**:
```
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
```

⚠️ **Save this password** - you'll need it for the next step.

---

### Step 3: Access Jenkins UI and Complete Initial Setup

#### 3.1 Open Jenkins in Browser

```
http://<EC2_PUBLIC_IP>:8080
```

You should see the "Unlock Jenkins" page.

#### 3.2 Enter Initial Admin Password

- Paste the password from Step 2
- Click "Continue"

#### 3.3 Install Suggested Plugins

- Select **"Install suggested plugins"**
- Wait for plugins to install (~3-5 minutes)

**Plugins installed include**:
- Git, GitHub
- Pipeline
- Credentials Binding
- Workspace Cleanup
- Email Extension
- Build Timeout
- Timestamper

#### 3.4 Create First Admin User

Fill in the form:

| Field | Example |
|-------|---------|
| Username | `admin` |
| Password | `YourSecurePassword123!` |
| Full name | `KPS Admin` |
| Email | `admin@kps-enterprise.local` |

Click **"Save and Continue"**

#### 3.5 Configure Jenkins URL

The URL should auto-populate:
```
http://<EC2_PUBLIC_IP>:8080/
```

Click **"Save and Finish"** → **"Start using Jenkins"**

---

### Step 4: Install Additional Required Plugins

Some plugins are not included in the suggested set. We need them for our pipelines.

#### 4.1 Navigate to Plugin Manager

1. Click **"Manage Jenkins"** (left sidebar)
2. Click **"Plugins"**
3. Click **"Available plugins"** tab

#### 4.2 Search and Install Plugins

Use the search box to find and **check** these plugins:

| Plugin Name | Purpose |
|-------------|---------|
| **Docker** | Docker commands in pipeline |
| **Docker Pipeline** | Docker build steps |
| **Kubernetes CLI** | kubectl commands |
| **Kubernetes** | K8s deployment support |
| **SonarQube Scanner** | Code quality scanning |
| **OWASP Dependency-Check** | Security vulnerability scan |
| **NodeJS** | Frontend build support |

#### 4.3 Install Plugins

1. After checking all plugins, click **"Install"** button (bottom right)
2. ✅ Check **"Restart Jenkins when installation is complete and no jobs are running"**
3. Wait for Jenkins to restart (~2-3 minutes)
4. Log back in with your admin credentials

#### 4.4 Verify Plugin Installation

Go to **Manage Jenkins** → **Plugins** → **Installed plugins**

Search for each plugin to confirm:
- ✅ Docker
- ✅ Docker Pipeline
- ✅ Kubernetes CLI
- ✅ Kubernetes
- ✅ SonarQube Scanner
- ✅ OWASP Dependency-Check
- ✅ NodeJS

---

### Step 5: Configure Global Tools

Jenkins needs to know where to find tools like JDK, NodeJS, etc.

#### 5.1 Navigate to Tools Configuration

1. **Manage Jenkins** → **Tools**

#### 5.2 Configure JDK

Scroll to **"JDK installations"** section:

1. Click **"Add JDK"**
2. **Name**: `jdk` (must match Jenkinsfile)
3. ❌ Uncheck **"Install automatically"**
4. **JAVA_HOME**: `/usr/lib/jvm/java-18-openjdk-amd64`

> ℹ️ We use the JDK already installed by `tools-install.sh`

#### 5.3 Configure NodeJS

Scroll to **"NodeJS installations"** section:

1. Click **"Add NodeJS"**
2. **Name**: `nodejs` (must match Jenkinsfile)
3. ✅ Check **"Install automatically"**
4. **Version**: Select **"NodeJS 18.x"** or **"NodeJS 20.x"**

#### 5.4 Configure SonarQube Scanner

Scroll to **"SonarQube Scanner installations"** section:

1. Click **"Add SonarQube Scanner"**
2. **Name**: `sonar-scanner` (must match Jenkinsfile)
3. ✅ Check **"Install automatically"**
4. **Version**: Select **"SonarQube Scanner 5.x.x"** (latest)

#### 5.5 Configure OWASP Dependency-Check

Scroll to **"Dependency-Check installations"** section:

1. Click **"Add Dependency-Check"**
2. **Name**: `DP-Check` (must match Jenkinsfile)
3. ✅ Check **"Install automatically"**
4. **Install from github.com**: Select latest version

#### 5.6 Save Configuration

- Scroll to bottom
- Click **"Save"**

---

### Step 6: Add Credentials

Our pipelines need credentials to access GitHub, Docker Hub, and SonarQube.

#### 6.1 Navigate to Credentials

1. **Manage Jenkins** → **Credentials**
2. Click **"System"** → **"Global credentials (unrestricted)"**
3. Click **"Add Credentials"** (left sidebar)

#### 6.2 Add GitHub Token (for Git operations)

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Scope** | Global |
| **Secret** | `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| **ID** | `github-token` |
| **Description** | `GitHub Personal Access Token` |

Click **"Create"**

**How to create GitHub PAT**:
1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Select scopes: `repo`, `admin:repo_hook`
4. Copy the token (you won't see it again!)

#### 6.3 Add GitHub Credentials (for checkout)

Click **"Add Credentials"** again:

| Field | Value |
|-------|-------|
| **Kind** | Username with password |
| **Scope** | Global |
| **Username** | Your GitHub username |
| **Password** | Same GitHub PAT as above |
| **ID** | `GITHUB` |
| **Description** | `GitHub Credentials` |

Click **"Create"**

#### 6.4 Add Docker Hub Credentials

Click **"Add Credentials"** again:

| Field | Value |
|-------|-------|
| **Kind** | Username with password |
| **Scope** | Global |
| **Username** | Your Docker Hub username |
| **Password** | Docker Hub access token |
| **ID** | `dockerhub-credentials` |
| **Description** | `Docker Hub Credentials` |

Click **"Create"**

**How to create Docker Hub access token**:
1. Docker Hub → Account Settings → Security → Access Tokens
2. New Access Token
3. Description: "Jenkins Pipeline"
4. Access permissions: Read, Write, Delete
5. Generate and copy the token

#### 6.5 Add SonarQube Token (placeholder for now)

We'll generate the actual token in Step 8. For now, create a placeholder:

| Field | Value |
|-------|-------|
| **Kind** | Secret text |
| **Scope** | Global |
| **Secret** | `placeholder` (we'll update this later) |
| **ID** | `sonar-token` |
| **Description** | `SonarQube Authentication Token` |

Click **"Create"**

#### 6.6 Verify Credentials

You should now have **4 credentials**:

- ✅ `github-token` (Secret text)
- ✅ `GITHUB` (Username with password)
- ✅ `dockerhub-credentials` (Username with password)
- ✅ `sonar-token` (Secret text - placeholder)

---

### Step 7: Configure SonarQube

SonarQube runs as a Docker container on the same EC2 instance.

#### 7.1 Access SonarQube UI

Open in browser:
```
http://<EC2_PUBLIC_IP>:9000
```

**Default credentials**:
- Username: `admin`
- Password: `admin`

#### 7.2 Change Admin Password

SonarQube will force you to change the password on first login.

1. Enter current password: `admin`
2. Enter new password: `YourSecureSonarPassword123!`
3. Confirm new password
4. Click **"Update"**

#### 7.3 Create Projects

##### Backend Project

1. Click **"Create Project"** → **"Manually"**
2. **Project display name**: `kps-backend`
3. **Project key**: `kps-backend`
4. **Main branch name**: `main`
5. Click **"Set Up"**
6. **How do you want to analyze?**: Select **"With Jenkins"**
7. **DevOps Platform**: Select **"GitHub"**
8. Click **"Configure Analysis"** → **"Other CI"**
9. Click **"Continue"**

##### Frontend Project

Repeat the process:

1. **Project display name**: `kps-frontend`
2. **Project key**: `kps-frontend`
3. Same settings as backend

#### 7.4 Generate Authentication Token

1. Click on profile icon (top right) → **"My Account"**
2. Click **"Security"** tab
3. In **"Generate Tokens"** section:
   - **Name**: `jenkins-integration`
   - **Type**: Select **"User Token"**
   - **Expires in**: 30 days (or longer)
4. Click **"Generate"**
5. **Copy the token** (e.g., `squ_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

⚠️ **Save this token** - you won't see it again!

#### 7.5 Update SonarQube Token in Jenkins

Go back to Jenkins:

1. **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click on **"sonar-token"** credential
3. Click **"Update"**
4. Replace `placeholder` with the actual SonarQube token
5. Click **"Save"**

---

### Step 8: Configure SonarQube Server in Jenkins

Tell Jenkins where to find SonarQube.

#### 8.1 Navigate to System Configuration

1. **Manage Jenkins** → **System**

#### 8.2 Configure SonarQube Servers

Scroll to **"SonarQube servers"** section:

1. ✅ Check **"Environment variables"** → **"Enable injection of SonarQube server configuration as build environment variables"**
2. Click **"Add SonarQube"**

| Field | Value |
|-------|-------|
| **Name** | `sonar-server` |
| **Server URL** | `http://localhost:9000` |
| **Server authentication token** | Select `sonar-token` |

3. Click **"Save"** (bottom of page)

---

### Step 9: Create Pipeline Jobs

Now we'll create two Jenkins pipelines for backend and frontend.

#### 9.1 Create Backend Pipeline

1. From Jenkins dashboard, click **"New Item"**
2. **Enter an item name**: `kps-backend-pipeline`
3. Select **"Pipeline"**
4. Click **"OK"**

##### Configure Backend Pipeline

**General Section**:
- ✅ Check **"GitHub project"**
- **Project url**: `https://github.com/Akawatmor/KPS-Enterprise/`

**Build Triggers** (optional):
- ✅ Check **"GitHub hook trigger for GITScm polling"** (if you set up webhooks)

**Pipeline Section**:

| Field | Value |
|-------|-------|
| **Definition** | Pipeline script from SCM |
| **SCM** | Git |
| **Repository URL** | `https://github.com/Akawatmor/KPS-Enterprise.git` |
| **Credentials** | Select `GITHUB` |
| **Branch Specifier** | `*/phase1-implementation` |
| **Script Path** | `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend` |

Click **"Save"**

#### 9.2 Create Frontend Pipeline

Repeat the process:

1. **New Item** → **Enter an item name**: `kps-frontend-pipeline`
2. Select **"Pipeline"** → **OK**

**Configure exactly like Backend, except**:
- **Script Path**: `src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend`

Click **"Save"**

---

### Step 10: Configure Docker Permissions (Important!)

Jenkins needs permission to run Docker commands.

#### 10.1 SSH into EC2

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

#### 10.2 Verify Docker Group Membership

```bash
# Check if jenkins user is in docker group
groups jenkins
```

**Expected output**: `jenkins : jenkins docker`

If `docker` is missing:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

#### 10.3 Test Docker Access

```bash
# Switch to jenkins user
sudo su - jenkins

# Try docker command
docker ps

# Exit jenkins user
exit
```

If you see `permission denied`, check `/var/run/docker.sock` permissions:

```bash
ls -l /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock
```

---

### Step 11: Configure AWS Credentials for EKS Access

Jenkins needs to deploy to EKS cluster.

#### 11.1 Update kubeconfig on Jenkins Server

After your EKS cluster is created:

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Update kubeconfig
aws eks update-kubeconfig --name three-tier-cluster --region us-east-1

# Test kubectl access
kubectl get nodes

# Copy config for jenkins user
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
```

#### 11.2 Verify Jenkins Can Access EKS

```bash
sudo su - jenkins
kubectl get nodes
exit
```

**Expected output**: List of EKS worker nodes

---

## Detailed Configuration Guide

### Required Environment Variables

Some Jenkinsfiles may require environment variables. Set them in:

**Manage Jenkins** → **System** → **Global properties** → ✅ **Environment variables**

| Name | Value | Purpose |
|------|-------|---------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | Docker image tagging |
| `AWS_REGION` | `us-east-1` | AWS region for ECR/EKS |
| `EKS_CLUSTER_NAME` | `three-tier-cluster` | EKS cluster name |

### Jenkinsfile Parameter Mapping

Ensure your Jenkins configuration matches these Jenkinsfile expectations:

| Jenkinsfile Reference | Jenkins Configuration |
|-----------------------|----------------------|
| `tools { jdk 'jdk' }` | JDK installation name: `jdk` |
| `tools { nodejs 'nodejs' }` | NodeJS installation name: `nodejs` |
| `SONAR_SCANNER_HOME` | SonarQube Scanner name: `sonar-scanner` |
| `environment { SCANNER_HOME=tool 'sonar-scanner' }` | Must match tool name |
| `withCredentials([string(credentialsId: 'github-token'...` | Credential ID: `github-token` |
| `withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials'...` | Credential ID: `dockerhub-credentials` |
| `withSonarQubeEnv('sonar-server')` | SonarQube server name: `sonar-server` |

---

## Troubleshooting

### Issue 1: Jenkins UI Not Accessible

**Symptoms**: Cannot access `http://<EC2_PUBLIC_IP>:8080`

**Solutions**:

1. **Check Security Group**:
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <SECURITY_GROUP_ID> \
     --query 'SecurityGroups[0].IpPermissions'
   ```
   Ensure port 8080 is open to your IP

2. **Check Jenkins Service**:
   ```bash
   ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
   sudo systemctl status jenkins
   sudo journalctl -u jenkins -f
   ```

3. **Check if installation is complete**:
   ```bash
   tail -f /var/log/cloud-init-output.log
   ```

### Issue 2: Jenkins Cannot Run Docker Commands

**Symptoms**: `permission denied while trying to connect to the Docker daemon socket`

**Solutions**:

```bash
# SSH into EC2
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Add jenkins to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Verify
sudo su - jenkins
docker ps
exit
```

### Issue 3: SonarQube Container Not Running

**Symptoms**: `http://<EC2_PUBLIC_IP>:9000` not accessible

**Solutions**:

```bash
# Check if container is running
docker ps -a | grep sonar

# Check container logs
docker logs sonarqube

# If exited, check vm.max_map_count
sysctl vm.max_map_count
# Should be >= 262144

# Restart container
docker start sonarqube

# If still failing, recreate
docker rm sonarqube
docker run -d --name sonarqube --restart unless-stopped \
  -p 9000:9000 sonarqube:lts-community
```

### Issue 4: Pipeline Cannot Clone Repository

**Symptoms**: `Couldn't find any revision to build. Verify the repository and branch configuration`

**Solutions**:

1. **Check GitHub credentials**:
   - Manage Jenkins → Credentials
   - Verify `GITHUB` credential has correct username and PAT
   - Test PAT has `repo` scope

2. **Check branch name**:
   - Ensure branch `phase1-implementation` exists
   - Try `*/main` or `*/*` to see all branches

3. **Check Jenkinsfile path**:
   - Verify `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend` exists in repo

### Issue 5: Pipeline Cannot Push to Docker Hub

**Symptoms**: `denied: requested access to the resource is denied`

**Solutions**:

1. **Check Docker Hub credentials**:
   - Manage Jenkins → Credentials
   - Verify `dockerhub-credentials` is correct

2. **Test Docker login**:
   ```bash
   sudo su - jenkins
   docker login -u <username>
   # Enter token as password
   ```

3. **Check image naming**:
   - Format: `dockerhub-username/image-name:tag`
   - Ensure username matches exactly

### Issue 6: kubectl Commands Fail

**Symptoms**: `The connection to the server localhost:8080 was refused`

**Solutions**:

```bash
# SSH into EC2
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Update kubeconfig
aws eks update-kubeconfig --name three-tier-cluster --region us-east-1

# Copy to jenkins home
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube

# Verify
sudo su - jenkins
kubectl get nodes
exit
```

### Issue 7: SonarQube Analysis Fails

**Symptoms**: `ERROR: SonarQube server [...] can not be reached`

**Solutions**:

1. **Check SonarQube is running**:
   ```bash
   curl http://localhost:9000
   docker ps | grep sonar
   ```

2. **Check Jenkins SonarQube configuration**:
   - Manage Jenkins → System → SonarQube servers
   - Server URL must be `http://localhost:9000` (not public IP)
   - Token must be valid

3. **Regenerate SonarQube token**:
   - SonarQube → My Account → Security → Generate Token
   - Update `sonar-token` credential in Jenkins

---

## Verification Checklist

Use this checklist to ensure everything is configured correctly:

### ✅ Jenkins Setup
- [ ] Jenkins UI accessible at `http://<EC2_PUBLIC_IP>:8080`
- [ ] Admin user created and can log in
- [ ] All required plugins installed (Docker, Kubernetes, SonarQube, NodeJS)
- [ ] No plugin installation errors

### ✅ Tools Configuration
- [ ] JDK configured (name: `jdk`)
- [ ] NodeJS configured (name: `nodejs`)
- [ ] SonarQube Scanner configured (name: `sonar-scanner`)
- [ ] OWASP Dependency-Check configured (name: `DP-Check`)

### ✅ Credentials
- [ ] `github-token` credential exists (Secret text)
- [ ] `GITHUB` credential exists (Username/Password)
- [ ] `dockerhub-credentials` credential exists (Username/Password)
- [ ] `sonar-token` credential exists with valid token (Secret text)

### ✅ SonarQube
- [ ] SonarQube accessible at `http://<EC2_PUBLIC_IP>:9000`
- [ ] Admin password changed from default
- [ ] Projects created: `kps-backend`, `kps-frontend`
- [ ] Authentication token generated
- [ ] SonarQube server configured in Jenkins (name: `sonar-server`)

### ✅ Pipeline Jobs
- [ ] `kps-backend-pipeline` created
- [ ] `kps-frontend-pipeline` created
- [ ] Both pipelines point to correct repository and branch
- [ ] Jenkinsfile paths are correct

### ✅ System Access
- [ ] Jenkins can run Docker commands
- [ ] Jenkins can access kubectl
- [ ] Jenkins can push to Docker Hub
- [ ] Jenkins can deploy to EKS

### ✅ Test Runs
- [ ] Backend pipeline runs successfully (or fails at expected stage)
- [ ] Frontend pipeline runs successfully (or fails at expected stage)
- [ ] SonarQube analysis appears in dashboard
- [ ] Docker images appear in Docker Hub

---

## Quick Command Reference

### SSH Access
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

### Get Jenkins Initial Password
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Check Service Status
```bash
sudo systemctl status jenkins
docker ps
docker logs sonarqube
```

### Restart Services
```bash
sudo systemctl restart jenkins
docker restart sonarqube
```

### Test Docker Access
```bash
sudo su - jenkins
docker ps
kubectl get nodes
exit
```

### Update kubeconfig
```bash
aws eks update-kubeconfig --name three-tier-cluster --region us-east-1
sudo cp ~/.kube/config /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
```

### View Logs
```bash
# Jenkins logs
sudo journalctl -u jenkins -f

# Cloud-init logs (installation)
tail -f /var/log/cloud-init-output.log

# SonarQube logs
docker logs -f sonarqube
```

---

## Summary

After completing this guide, you should have:

1. ✅ Jenkins running and accessible
2. ✅ All required plugins installed
3. ✅ Global tools configured (JDK, NodeJS, SonarQube Scanner, OWASP)
4. ✅ Credentials configured (GitHub, Docker Hub, SonarQube)
5. ✅ SonarQube running and integrated with Jenkins
6. ✅ Pipeline jobs created for backend and frontend
7. ✅ System permissions configured (Docker, kubectl)

**Next Steps**:
1. Create EKS cluster (`./start.sh --component eks`)
2. Configure kubectl access on Jenkins server
3. Run pipeline builds to verify configuration
4. Deploy application to EKS

---

## Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

**Last Updated**: 2026-04-01  
**Maintained by**: KPS-Enterprise Team
