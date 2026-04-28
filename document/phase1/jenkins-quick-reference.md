# Jenkins Provisioning Quick Reference Card

**⏱️ Total Time**: 20-30 minutes  
**📖 Full Guide**: [jenkins-provisioning-guide.md](./jenkins-provisioning-guide.md)

---

## Prerequisites Checklist

- [ ] Jenkins EC2 is running (`terraform apply` complete)
- [ ] Security group allows port 8080 and 9000
- [ ] GitHub Personal Access Token ready
- [ ] Docker Hub username + access token ready
- [ ] SSH key to access EC2

---

## Step-by-Step Checklist

### 1️⃣ Initial Setup (5 min)

- [ ] Get initial password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- [ ] Access: `http://<EC2_IP>:8080`
- [ ] Install suggested plugins
- [ ] Create admin user

### 2️⃣ Install Plugins (5 min)

**Manage Jenkins → Plugins → Available plugins**

- [ ] Docker
- [ ] Docker Pipeline
- [ ] Kubernetes CLI
- [ ] Kubernetes
- [ ] SonarQube Scanner
- [ ] OWASP Dependency-Check
- [ ] NodeJS
- [ ] ✅ Restart Jenkins after installation

### 3️⃣ Configure Tools (3 min)

**Manage Jenkins → Tools**

| Tool | Name | Type | Value |
|------|------|------|-------|
| JDK | `jdk` | Manual | `/usr/lib/jvm/java-18-openjdk-amd64` |
| NodeJS | `nodejs` | Auto | NodeJS 18.x |
| SonarQube Scanner | `sonar-scanner` | Auto | Latest |
| OWASP Dependency-Check | `DP-Check` | Auto | Latest |

### 4️⃣ Add Credentials (5 min)

**Manage Jenkins → Credentials → System → Global**

- [ ] **github-token**
  - Kind: Secret text
  - ID: `github-token`
  - Secret: `ghp_xxxx...`

- [ ] **GITHUB**
  - Kind: Username with password
  - ID: `GITHUB`
  - Username: your-github-username
  - Password: same GitHub PAT

- [ ] **dockerhub-credentials**
  - Kind: Username with password
  - ID: `dockerhub-credentials`
  - Username: your-dockerhub-username
  - Password: Docker Hub access token

- [ ] **sonar-token** (placeholder)
  - Kind: Secret text
  - ID: `sonar-token`
  - Secret: `placeholder` (update later)

### 5️⃣ Configure SonarQube (5 min)

**SonarQube UI**: `http://<EC2_IP>:9000`

- [ ] Login: `admin` / `admin`
- [ ] Change password
- [ ] Create project: `kps-backend`
- [ ] Create project: `kps-frontend`
- [ ] Generate token: My Account → Security → Generate Tokens
- [ ] Copy token: `squ_xxxx...`

**Back to Jenkins**:
- [ ] Update `sonar-token` credential with real token
- [ ] Manage Jenkins → System → SonarQube servers
  - Name: `sonar-server`
  - URL: `http://localhost:9000`
  - Token: `sonar-token`

### 6️⃣ Create Pipelines (5 min)

**Backend Pipeline**:
- [ ] New Item → `kps-backend-pipeline` → Pipeline
- [ ] Definition: Pipeline script from SCM
- [ ] SCM: Git
- [ ] Repository: `https://github.com/Akawatmor/KPS-Enterprise.git`
- [ ] Credentials: `GITHUB`
- [ ] Branch: `*/phase1-implementation`
- [ ] Script Path: `src/Jenkins-Pipeline-Code/Jenkinsfile-Backend`

**Frontend Pipeline**:
- [ ] New Item → `kps-frontend-pipeline` → Pipeline
- [ ] Same as backend but Script Path: `src/Jenkins-Pipeline-Code/Jenkinsfile-Frontend`

### 7️⃣ Fix Docker Permissions (2 min)

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_IP>
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Verify
sudo su - jenkins
docker ps
exit
```

---

## Critical Configuration Mappings

### ⚠️ These MUST match between Jenkins and Jenkinsfile

| Jenkinsfile Reference | Jenkins Configuration |
|-----------------------|----------------------|
| `tools { jdk 'jdk' }` | JDK name: **`jdk`** |
| `tools { nodejs 'nodejs' }` | NodeJS name: **`nodejs`** |
| `tool 'sonar-scanner'` | SonarQube Scanner name: **`sonar-scanner`** |
| `tool 'DP-Check'` | OWASP name: **`DP-Check`** |
| `credentialsId: 'github-token'` | Credential ID: **`github-token`** |
| `credentialsId: 'GITHUB'` | Credential ID: **`GITHUB`** |
| `credentialsId: 'dockerhub-credentials'` | Credential ID: **`dockerhub-credentials`** |
| `credentialsId: 'sonar-token'` | Credential ID: **`sonar-token`** |
| `withSonarQubeEnv('sonar-server')` | SonarQube server name: **`sonar-server`** |

---

## Final Verification

### Jenkins
- [ ] UI accessible at `http://<EC2_IP>:8080`
- [ ] 8 plugins installed (Docker, Kubernetes, SonarQube, NodeJS, OWASP)
- [ ] 4 tools configured (jdk, nodejs, sonar-scanner, DP-Check)
- [ ] 4 credentials added (github-token, GITHUB, dockerhub-credentials, sonar-token)
- [ ] 2 pipelines created (backend, frontend)
- [ ] `sudo su - jenkins` → `docker ps` works

### SonarQube
- [ ] UI accessible at `http://<EC2_IP>:9000`
- [ ] Admin password changed
- [ ] 2 projects created (kps-backend, kps-frontend)
- [ ] Token generated and updated in Jenkins

### Test
- [ ] Run backend pipeline (may fail at deploy stage before EKS exists - OK)
- [ ] Check console output for errors
- [ ] SonarQube analysis appears in SonarQube dashboard

---

## Quick Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| Jenkins UI not loading | `sudo systemctl status jenkins` |
| Docker permission denied | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| SonarQube not accessible | `docker ps -a \| grep sonar` → `docker start sonarqube` |
| Pipeline can't clone repo | Check `GITHUB` credential has correct PAT |
| Pipeline can't push to Docker Hub | Check `dockerhub-credentials` is correct |
| kubectl not found | Configure after EKS cluster creation |

---

## Commands Cheat Sheet

```bash
# SSH to Jenkins server
ssh -i ~/.ssh/your-key.pem ubuntu@<EC2_IP>

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Check services
sudo systemctl status jenkins
docker ps

# Restart services
sudo systemctl restart jenkins
docker restart sonarqube

# Fix Docker permissions
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Test as jenkins user
sudo su - jenkins
docker ps
exit

# View logs
sudo journalctl -u jenkins -f
docker logs -f sonarqube
tail -f /var/log/cloud-init-output.log
```

---

## Next Steps After Jenkins Provisioning

1. ✅ Jenkins provisioning complete
2. ⏭️ Create EKS cluster: `./start.sh --component eks`
3. ⏭️ Configure kubectl access on Jenkins server
4. ⏭️ Run pipelines to build and deploy

---

**Last Updated**: 2026-04-01  
**Full Documentation**: [jenkins-provisioning-guide.md](./jenkins-provisioning-guide.md)
