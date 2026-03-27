# Issue #9: Analyze Jenkins Pipeline code (Backend & Frontend)

**Status:** Open  
**Labels:** ci/cd, documentation  
**Assignee:** Akawatmor  
**Milestone:** Phase 1 - Week 1

## Description
Study both Jenkinsfiles to understand every pipeline stage.

## Files to Analyze
- `Jenkins-Pipeline-Code/Jenkinsfile-Backend`
- `Jenkins-Pipeline-Code/Jenkinsfile-Frontend`

## Acceptance Criteria
- [ ] Document all 10 pipeline stages with purpose
- [ ] Document all required Jenkins credentials (GITHUB, sonar-token, ACCOUNT_ID, ECR_REPO1, ECR_REPO2)
- [ ] Document all required Jenkins tools (jdk, nodejs, sonar-scanner, DP-Check)
- [ ] Document security scan stages (SonarQube, OWASP, Trivy FS, Trivy Image)
- [ ] Document GitOps trigger mechanism (K8s YAML update)

## Pipeline Stages Overview

Both Backend and Frontend pipelines follow similar DevSecOps patterns with approximately 10 stages:

### Common Pipeline Stages

| Stage | Purpose | Tools Used |
|-------|---------|------------|
| 1. Git Checkout | Clone repository code | Git |
| 2. Install Dependencies | Install packages | npm (Node.js) |
| 3. SonarQube Analysis | Static code analysis | SonarQube Scanner |
| 4. Quality Gate | Check SonarQube results | SonarQube |
| 5. OWASP Dependency Check | Scan dependencies for vulnerabilities | OWASP DP-Check |
| 6. Trivy FS Scan | Scan filesystem for vulnerabilities | Trivy |
| 7. Docker Build | Build container image | Docker |
| 8. Trivy Image Scan | Scan Docker image | Trivy |
| 9. Push to ECR | Upload image to AWS ECR | AWS CLI |
| 10. Update K8s Manifest | Trigger GitOps deployment | Git |

## Detailed Stage Analysis

### Stage 1: Git Checkout
```groovy
stage('Git Checkout') {
    steps {
        git branch: 'main', 
            credentialsId: 'GITHUB',
            url: 'https://github.com/user/repo.git'
    }
}
```
**Purpose:** Clone source code from GitHub  
**Credentials Required:** GITHUB (username/password or token)

### Stage 2: Install Dependencies
```groovy
stage('Install Dependencies') {
    steps {
        sh 'npm install'
    }
}
```
**Purpose:** Install Node.js packages  
**Tool Required:** Node.js, npm

### Stage 3: SonarQube Analysis
```groovy
stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('sonar-server') {
            sh '''
                $SCANNER_HOME/bin/sonar-scanner \
                -Dsonar.projectKey=backend \
                -Dsonar.projectName=backend \
                -Dsonar.sources=.
            '''
        }
    }
}
```
**Purpose:** Perform static application security testing (SAST)  
**Tools Required:**
- SonarQube Scanner tool configured in Jenkins
- SonarQube server running (typically port 9000)

**Configuration:**
- Token: `sonar-token` credential
- Project Key: backend/frontend
- Server: SonarQube instance URL

### Stage 4: Quality Gate
```groovy
stage('Quality Gate') {
    steps {
        timeout(time: 2, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```
**Purpose:** Ensure code meets quality standards  
**Behavior:** Pipeline fails if quality gate fails

### Stage 5: OWASP Dependency Check
```groovy
stage('OWASP Dependency Check') {
    steps {
        dependencyCheck additionalArguments: '''
            --scan ./
            --format HTML
            --format XML
            --out ./dependency-check-report
        ''',
        odcInstallation: 'DP-Check'
    }
    
    post {
        always {
            dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
        }
    }
}
```
**Purpose:** Software Composition Analysis (SCA) - identify vulnerable dependencies  
**Tool Required:** OWASP Dependency-Check plugin  
**Output:** HTML and XML reports

### Stage 6: Trivy FS Scan
```groovy
stage('Trivy FS Scan') {
    steps {
        sh 'trivy fs --format table -o trivy-fs-report.html .'
    }
}
```
**Purpose:** Scan filesystem for vulnerabilities  
**Tool Required:** Trivy CLI  
**Scans:** Source code, configuration files, dependencies

### Stage 7: Docker Build
```groovy
stage('Docker Build') {
    steps {
        script {
            sh '''
                docker build -t backend:${BUILD_NUMBER} .
                docker tag backend:${BUILD_NUMBER} \
                    ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO1}:${BUILD_NUMBER}
            '''
        }
    }
}
```
**Purpose:** Build Docker container image  
**Tags:** 
- Local: `backend:${BUILD_NUMBER}`
- ECR: Full ECR repository path with build number

### Stage 8: Trivy Image Scan
```groovy
stage('Trivy Image Scan') {
    steps {
        sh '''
            trivy image \
            --format table \
            -o trivy-image-report.html \
            backend:${BUILD_NUMBER}
        '''
    }
}
```
**Purpose:** Scan Docker image for vulnerabilities  
**Checks:** OS packages, application dependencies in container

### Stage 9: Push to ECR
```groovy
stage('Push to ECR') {
    steps {
        script {
            sh '''
                aws ecr get-login-password --region us-east-1 | \
                docker login --username AWS --password-stdin \
                ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
                
                docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO1}:${BUILD_NUMBER}
            '''
        }
    }
}
```
**Purpose:** Upload Docker image to AWS Elastic Container Registry  
**Credentials Required:** AWS IAM role with ECR permissions  
**Prerequisites:** ECR repository must exist

### Stage 10: Update K8s Manifest (GitOps Trigger)
```groovy
stage('Update Kubernetes Manifest') {
    steps {
        script {
            withCredentials([string(credentialsId: 'GITHUB', variable: 'GITHUB_TOKEN')]) {
                sh '''
                    git clone https://github.com/user/k8s-manifests.git
                    cd k8s-manifests/Backend
                    
                    sed -i "s|image:.*|image: ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${ECR_REPO1}:${BUILD_NUMBER}|g" deployment.yaml
                    
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins"
                    git add deployment.yaml
                    git commit -m "Update backend image to ${BUILD_NUMBER}"
                    git push https://${GITHUB_TOKEN}@github.com/user/k8s-manifests.git
                '''
            }
        }
    }
}
```
**Purpose:** Implement GitOps deployment pattern  
**Workflow:**
1. Clone K8s manifest repository
2. Update image tag in deployment.yaml
3. Commit and push changes
4. ArgoCD detects change and deploys to EKS

## Required Jenkins Credentials

### 1. GITHUB
- **Type:** Username with password or Secret text (token)
- **Purpose:** Git clone and push operations
- **Scope:** Repository access

### 2. sonar-token
- **Type:** Secret text
- **Purpose:** SonarQube authentication
- **Generation:** SonarQube → My Account → Security → Generate Token

### 3. ACCOUNT_ID
- **Type:** Secret text or Global variable
- **Value:** AWS Account ID (12 digits)
- **Purpose:** ECR repository path construction

### 4. ECR_REPO1
- **Type:** Secret text or Global variable
- **Value:** Backend ECR repository name
- **Example:** `three-tier-backend`

### 5. ECR_REPO2
- **Type:** Secret text or Global variable
- **Value:** Frontend ECR repository name
- **Example:** `three-tier-frontend`

## Required Jenkins Tools Configuration

### 1. JDK (Java Development Kit)
- **Name:** `jdk17` or `jdk`
- **Version:** Java 17
- **Purpose:** Jenkins and SonarQube Scanner

### 2. Node.js
- **Name:** `nodejs` or `node16`
- **Version:** 16.x or 18.x
- **Purpose:** npm install and build

### 3. SonarQube Scanner
- **Name:** `sonar-scanner`
- **Version:** Latest
- **Installation:** Automatic installer from Maven Central

### 4. OWASP Dependency-Check
- **Name:** `DP-Check`
- **Installation:** Jenkins Plugin → Tools → Dependency-Check
- **Version:** Latest

## Backend vs Frontend Differences

### Backend Pipeline (Jenkinsfile-Backend)
- **Build Context:** `./Application-Code/backend`
- **Port:** 3500
- **ECR Repository:** ECR_REPO1
- **K8s Manifest:** `Kubernetes-Manifests-file/Backend/deployment.yaml`

### Frontend Pipeline (Jenkinsfile-Frontend)
- **Build Context:** `./Application-Code/frontend`
- **Port:** 3000
- **ECR Repository:** ECR_REPO2
- **K8s Manifest:** `Kubernetes-Manifests-file/Frontend/deployment.yaml`
- **Build Args:** May include `REACT_APP_BACKEND_URL`

## GitOps Workflow

```
Developer Push → GitHub Webhook → Jenkins Pipeline
                                         ↓
                              Build → Test → Scan → Push ECR
                                         ↓
                              Update K8s Manifest (Git Push)
                                         ↓
                              ArgoCD Detects Change
                                         ↓
                              Deploy to EKS Cluster
```

## Pipeline Execution

### Trigger Pipeline Manually
1. Jenkins Dashboard → Select Pipeline
2. Click "Build Now"
3. Monitor console output

### Trigger via GitHub Webhook
1. Configure webhook in GitHub repository
2. Payload URL: `http://jenkins-server:8080/github-webhook/`
3. Events: Push events
4. Pipeline triggers automatically on git push

## Common Issues & Solutions

### Issue 1: SonarQube Quality Gate Fails
- **Solution:** Review SonarQube report, fix code issues
- **Bypass (not recommended):** Set `abortPipeline: false`

### Issue 2: Trivy Scan Finds Critical Vulnerabilities
- **Solution:** Update base image or dependencies
- **Temporary:** Continue despite warnings (update threshold)

### Issue 3: ECR Push Fails - Authentication
- **Solution:** Verify IAM role has ECR permissions
- **Check:** `aws ecr get-login-password` works

### Issue 4: K8s Manifest Update Fails
- **Solution:** Verify GITHUB token has push permissions
- **Alternative:** Use SSH key instead of token

## Best Practices

1. **Fail Fast:** Stop pipeline early on critical issues
2. **Parallel Stages:** Run independent scans in parallel
3. **Caching:** Cache Docker layers and npm dependencies
4. **Notifications:** Add Slack/email notifications on failure
5. **Artifact Archival:** Save scan reports for compliance

## Security Considerations

- Never hardcode credentials in Jenkinsfile
- Use Jenkins Credentials Store
- Rotate tokens regularly
- Implement least-privilege IAM policies
- Review security scan results before deployment

## Next Steps

1. Set up Jenkins server with all required tools
2. Configure credentials in Jenkins
3. Create ECR repositories
4. Run pipelines and verify all stages pass
5. Set up ArgoCD for GitOps deployment
