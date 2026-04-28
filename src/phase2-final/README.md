# TodoApp — Big Calendar · K3s · Woodpecker CI/CD

A full-stack **Todo App** with a large full-screen calendar as the primary UI.  
Each calendar day shows todos as colored pills; click a day to open the side panel for that day.

## Tech Stack

| Layer      | Technology |
|-----------|-----------|
| Backend   | Go 1.22, SQLite (K3s PVC) |
| Frontend  | Next.js 14, React 18, date-fns |
| Container | Docker Hub (`YOURDOCKERHUB/todoapp-core`, `YOURDOCKERHUB/todoapp-web`) |
| K8s       | K3s 3-node (1 master + 2 workers), Traefik ingress |
| CI/CD     | Woodpecker CI (test → build → push → deploy) |

---

## Quick Start (Docker Compose)

```bash
cp .env.example .env
docker compose up --build
```

- Frontend: http://localhost:3000  
- Backend:  http://localhost:8080/healthz

---

## K3s Deployment

### Prerequisites

- K3s cluster running (1 master + 2 workers)
- `kubectl` configured to point at your master node
- Docker Hub account — replace `YOURDOCKERHUB` in `k8s/*.yaml` files

### 1. Replace the Docker Hub username

```bash
DOCKER_USER=yourusername
sed -i "s/YOURDOCKERHUB/$DOCKER_USER/g" k8s/core-deployment.yaml k8s/web-deployment.yaml
```

### 2. Create secrets

```bash
kubectl create secret generic todoapp-secret -n todoapp \
  --from-literal=GITHUB_OAUTH_CLIENT_ID=your-id \
  --from-literal=GITHUB_OAUTH_CLIENT_SECRET=your-secret
```

### 3. Apply manifests

```bash
kubectl apply -k k8s/
```

### 4. Add hosts entry

```bash
# Get K3s master node IP
echo "<MASTER_IP>  todoapp.local" | sudo tee -a /etc/hosts
```

Open http://todoapp.local in your browser.

---

## Woodpecker CI/CD Setup

1. Install Woodpecker CI on your K3s cluster or a dedicated VM.  
2. Connect your repo to Woodpecker.  
3. Add these secrets in **Project → Settings → Secrets**:

| Secret | Value |
|--------|-------|
| `DOCKER_USERNAME` | Your Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token |
| `KUBECONFIG_B64`  | `base64 -w0 ~/.kube/config` |

4. Push to `main` — Woodpecker will test, build, push images, and `kubectl set image` the deployments.

---

## API Endpoints

```
GET  /healthz
GET  /readyz
GET  /api/v1/meta

POST /api/v1/auth/github/login
POST /api/v1/auth/github/callback
POST /api/v1/auth/refresh
POST /api/v1/auth/logout

GET    /api/v1/tasks
POST   /api/v1/tasks
GET    /api/v1/tasks/:id
PATCH  /api/v1/tasks/:id
DELETE /api/v1/tasks/:id

GET    /api/v1/tasks/:id/subtasks
POST   /api/v1/tasks/:id/subtasks
DELETE /api/v1/tasks/:id/subtasks/:sid

GET    /api/v1/reminders
POST   /api/v1/reminders
DELETE /api/v1/reminders/:id
```

## Calendar Features

- **Big calendar** — full-screen 6×7 grid, each cell shows date + todo pills  
- **Todo pills** — blue = open, green = done, red = high priority  
- **Click any day** — right panel slides in with todos for that day  
- **Add/Edit/Delete** todos with title, description, due date+time, priority  
- **Stats bar** — live count of open, done, today, overdue todos
