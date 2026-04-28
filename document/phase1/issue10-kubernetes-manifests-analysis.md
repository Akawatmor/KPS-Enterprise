# Issue #10: Analyze Kubernetes manifests for all components

**Status:** Open  
**Labels:** kubernetes, documentation  
**Assignee:** Akawatmor  
**Milestone:** Phase 1 - Week 1

## Backend Manifests

### Backend Deployment (deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/backend:latest
        ports:
        - containerPort: 3500
        env:
        - name: MONGO_CONN_STR
          value: "mongodb-svc:27017/taskdb"
        - name: MONGO_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: mongo-username
        - name: MONGO_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: mongo-password
        - name: USE_DB_AUTH
          value: "true"
        livenessProbe:
          httpGet:
            path: /health
            port: 3500
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 3500
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        startupProbe:
          httpGet:
            path: /health
            port: 3500
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 30
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

**Key Configurations:**

| Setting | Value | Purpose |
|---------|-------|---------|
| Replicas | 2 | High availability, load distribution |
| Port | 3500 | Backend API port |
| RollingUpdate maxSurge | 1 | Allow 1 extra pod during update |
| RollingUpdate maxUnavailable | 0 | Keep service available during update |

**Health Probes:**

- **Liveness Probe:** 
  - Checks if container is alive
  - Restarts container if fails 3 times
  - Initial delay: 30s, period: 10s

- **Readiness Probe:**
  - Checks if container can serve traffic
  - Removes from service endpoints if fails
  - Initial delay: 10s, period: 5s

- **Startup Probe:**
  - Gives container time to start
  - Disables liveness/readiness until passes
  - Max wait: 150s (30 failures × 5s)

**Resource Limits:**
- Requests: 256Mi RAM, 0.25 CPU cores
- Limits: 512Mi RAM, 0.5 CPU cores

### Backend Service (service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 3500
    protocol: TCP
```

**Configuration:**
- **Type:** ClusterIP (internal only, not exposed externally)
- **Port:** 80 (service port)
- **TargetPort:** 3500 (container port)
- **Selector:** Routes to pods with label `app: backend`

## Frontend Manifests

### Frontend Deployment (deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/frontend:latest
        ports:
        - containerPort: 3000
        env:
        - name: REACT_APP_BACKEND_URL
          value: "http://backend-svc/api"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

**Key Configurations:**
- **Replicas:** 1 (can scale horizontally if needed)
- **Port:** 3000 (React dev server or nginx)
- **Environment:** Backend API URL points to internal service

### Frontend Service (service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  labels:
    app: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
```

## Database Manifests

### Database Secrets (secrets.yaml)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
type: Opaque
data:
  mongo-username: YWRtaW4=           # admin (base64)
  mongo-password: cGFzc3dvcmQxMjM=   # password123 (base64)
```

**⚠️ Security Warning:**
- Secrets in Git should be encrypted (use SealedSecrets or External Secrets Operator)
- For production, use AWS Secrets Manager
- Never commit plain text secrets

**Encoding/Decoding:**
```bash
# Encode
echo -n "admin" | base64
# Decode
echo "YWRtaW4=" | base64 -d
```

### Database PersistentVolume (pv.yaml)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-pv
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: "/mnt/data/mongodb"
```

**Configuration:**
- **Capacity:** 1Gi
- **Access Mode:** ReadWriteOnce (single node read-write)
- **Reclaim Policy:** Retain (data kept after PVC deletion)
- **Storage Class:** manual (for local testing)

**Production Alternative:**
- Use AWS EBS CSI Driver
- Storage Class: `gp3` or `gp2`
- Remove hostPath, use dynamic provisioning

### Database PersistentVolumeClaim (pvc.yaml)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual
```

**Purpose:** Requests storage from PersistentVolume  
**Binding:** Automatically binds to PV with matching criteria

### Database Deployment (deployment.yaml)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  labels:
    app: mongodb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:4.4.6
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: mongo-username
        - name: MONGO_INITDB_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mongodb-secret
              key: mongo-password
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mongodb-storage
        persistentVolumeClaim:
          claimName: mongodb-pvc
```

**Key Points:**
- **Replicas:** 1 (single instance, not a replica set)
- **Image:** mongo:4.4.6 (specific version for stability)
- **Volume Mount:** /data/db (MongoDB data directory)
- **Secrets:** Injected as environment variables

**Production Considerations:**
- Use MongoDB Replica Set for HA
- Consider MongoDB Atlas for managed service
- Implement backup strategy

### Database Service (service.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-svc
  labels:
    app: mongodb
spec:
  type: ClusterIP
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
    protocol: TCP
```

**DNS Name:** `mongodb-svc.default.svc.cluster.local`  
**Connection String:** `mongodb://mongodb-svc:27017/taskdb`

## Ingress Configuration

### ALB Ingress (ingress.yaml)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/success-codes: '200'
spec:
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
```

### ALB Annotations Explained

| Annotation | Value | Purpose |
|------------|-------|---------|
| ingress.class | alb | Use AWS ALB Ingress Controller |
| scheme | internet-facing | Public ALB (not internal) |
| target-type | ip | Route to pod IPs directly |
| listen-ports | HTTP 80 | Listen on port 80 |
| healthcheck-path | /health | Health check endpoint |
| success-codes | 200 | Expected HTTP status |

### Routing Rules

**Path: /api → Backend**
- Prefix match: `/api/*` routes to backend-svc
- Example: `/api/tasks` → `backend-svc:80`

**Path: / → Frontend**
- Prefix match: `/*` routes to frontend-svc
- Example: `/` → `frontend-svc:80`

**Order Matters:** More specific paths (/api) should be listed first

### Additional ALB Annotations (Optional)

```yaml
# HTTPS with ACM Certificate
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'

# Health Check Settings
alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
alb.ingress.kubernetes.io/healthy-threshold-count: '2'
alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'

# Security
alb.ingress.kubernetes.io/security-groups: sg-xxxxx
alb.ingress.kubernetes.io/waf-acl-id: arn:aws:wafv2:...
```

## Deployment Order

```bash
# 1. Create namespace (optional)
kubectl create namespace three-tier

# 2. Deploy Database
kubectl apply -f Database/secrets.yaml
kubectl apply -f Database/pv.yaml
kubectl apply -f Database/pvc.yaml
kubectl apply -f Database/deployment.yaml
kubectl apply -f Database/service.yaml

# 3. Wait for MongoDB to be ready
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=60s

# 4. Deploy Backend
kubectl apply -f Backend/deployment.yaml
kubectl apply -f Backend/service.yaml

# 5. Deploy Frontend
kubectl apply -f Frontend/deployment.yaml
kubectl apply -f Frontend/service.yaml

# 6. Deploy Ingress
kubectl apply -f ingress.yaml

# 7. Verify
kubectl get all
kubectl get ingress
```

## Verification Commands

```bash
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check ingress and ALB DNS
kubectl get ingress

# Check pod logs
kubectl logs -l app=backend
kubectl logs -l app=frontend
kubectl logs -l app=mongodb

# Exec into pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward for testing
kubectl port-forward svc/backend-svc 3500:80
kubectl port-forward svc/frontend-svc 3000:80

# Test backend API
curl http://localhost:3500/api/tasks
```

## Rolling Update Process

When new image is pushed:

```bash
# Update deployment with new image
kubectl set image deployment/backend backend=<new-image>:tag

# Monitor rollout
kubectl rollout status deployment/backend

# Rollout history
kubectl rollout history deployment/backend

# Rollback if needed
kubectl rollout undo deployment/backend
```

## Resource Optimization for Learner Lab

**Current Resources:**
- Backend: 2 pods × (256Mi-512Mi RAM, 0.25-0.5 CPU)
- Frontend: 1 pod × (128Mi-256Mi RAM, 0.1-0.2 CPU)
- MongoDB: 1 pod × (256Mi-512Mi RAM, 0.25-0.5 CPU)

**Total Estimate:**
- ~1.5 CPU cores
- ~2-3 GB RAM

**Fits comfortably in:** 2 × t3.medium nodes (2 vCPU, 4GB RAM each)

## Best Practices Observed

✅ **Good Practices:**
- Health probes configured
- RollingUpdate with zero downtime
- Resource limits set
- ClusterIP for internal services
- Persistent storage for database

⚠️ **Needs Improvement:**
- Secrets should be encrypted (SealedSecrets/External Secrets)
- Consider HPA (Horizontal Pod Autoscaler)
- Add PodDisruptionBudget for HA
- Implement NetworkPolicies for security
- Add labels for better organization

## Next Steps

1. Create EKS cluster with appropriate node groups
2. Install AWS Load Balancer Controller
3. Apply manifests in correct order
4. Verify application accessibility via ALB DNS
5. Test CRUD operations end-to-end
