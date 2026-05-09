# TodoApp — Big Calendar · K3s · Woodpecker CI/CD

A full-stack **Todo App** with a large full-screen calendar as the primary UI.  
Each calendar day shows todos as colored pills; click a day to open the side panel for that day.

## ✨ New Features

- 🔐 **Password Authentication** — Register & login with email/password
- 👥 **User Management** — Admin dashboard for user administration
- 🤝 **Friends System** — Add friends and collaborate
- 📊 **Shared Kanban Boards** — Create and share boards with friends
- 📱 **PWA Support** — Install as standalone app, works offline
- 🔔 **Push Notifications** — Get reminders for upcoming tasks
- ✅ **Subtasks** — Break down tasks into smaller checkboxes
- 🔒 **Role-Based Access** — Admin and user roles with proper authorization

## Tech Stack

| Layer      | Technology |
|-----------|-----------|
| Backend   | Go 1.22, SQLite/PostgreSQL |
| Frontend  | Next.js 14, React 18, TypeScript |
| Auth      | Bcrypt password hashing, JWT-like tokens |
| PWA       | Service Worker, Web Push API |
| Container | Docker Hub (`akawatmor/todoapp-core`, `akawatmor/todoapp-web`) |
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

### Authentication
```
GET  /api/v1/auth/providers
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/github/exchange
POST /api/v1/auth/session/refresh
POST /api/v1/auth/session/logout
```

### Tasks
```
GET    /api/v1/tasks
POST   /api/v1/tasks
PATCH  /api/v1/tasks/:id
DELETE /api/v1/tasks/:id
```

### Subtasks
```
POST   /api/v1/tasks/:id/subtasks
PATCH  /api/v1/tasks/:id/subtasks/:sid
```

### Reminders
```
GET    /api/v1/reminders/rules
POST   /api/v1/reminders/rules
PATCH  /api/v1/reminders/rules/:id
POST   /api/v1/reminders/dispatch
```

### Admin (Admin role required)
```
GET    /api/v1/admin/users
PATCH  /api/v1/admin/users/:id/role
DELETE /api/v1/admin/users/:id
```

### Friends
```
POST /api/v1/friends/request
POST /api/v1/friends/:id/accept
GET  /api/v1/friends
```

### Shared Boards
```
POST /api/v1/boards
GET  /api/v1/boards
POST /api/v1/boards/:id/members
```

### Push Notifications
```
POST /api/v1/push/subscribe
GET  /api/v1/push/subscriptions
```

### Health & Meta
```
GET  /healthz
GET  /readyz
GET  /api/v1/meta
```

## Calendar Features

- **Big calendar** — full-screen 6×7 grid, each cell shows date + todo pills  
- **Todo pills** — blue = open, green = done, red = high priority  
- **Click any day** — right panel slides in with todos for that day  
- **Add/Edit/Delete** todos with title, description, due date+time, priority  
- **Subtasks** — Break down tasks into smaller actionable items with checkboxes
- **Stats bar** — live count of open, done, today, overdue todos

## 🔐 Security Features

- **Bcrypt password hashing** (cost factor 12)
- **Strong password requirements** (8+ chars, uppercase, lowercase, number, special char)
- **Session management** with access & refresh tokens
- **Role-based access control** (user, admin)
- **Authorization checks** on all protected endpoints
- **Input validation** & SQL injection prevention
- See [SECURITY.md](SECURITY.md) for details

## 📱 PWA Features

- **Installable** — Add to home screen on mobile/desktop
- **Offline support** — Service worker caches static assets
- **Push notifications** — Get task reminders even when app is closed
- **Responsive design** — Works on phones, tablets, desktops

## 🧪 Testing

Comprehensive testing suite including:
- **Unit tests** — Backend (Go) and Frontend (Jest)
- **Integration tests** — API endpoint testing
- **Security tests** — Password validation, authorization, SQL injection
- **Performance benchmarks** — Response time goals

See [TESTING.md](TESTING.md) for full testing guide.

## 📚 Documentation

- **[SECURITY.md](SECURITY.md)** — Security implementation & best practices
- **[TESTING.md](TESTING.md)** — Testing guide & checklists
- **[frontend/public/ICONS-README.md](frontend/public/ICONS-README.md)** — PWA icon generation

## 🚀 Getting Started

### First Time Setup

1. **Create first admin user:**
   ```bash
   # Register via API
   curl -X POST http://localhost:8080/api/v1/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"Admin123!@#","display_name":"Admin"}'
   
   # Manually update role in database
   # SQLite: UPDATE users SET role='admin' WHERE email='admin@example.com';
   # Or use SQL client to connect to PostgreSQL
   ```

2. **Generate VAPID keys for push notifications:**
   ```bash
   npx web-push generate-vapid-keys
   # Add to .env:
   # NEXT_PUBLIC_VAPID_KEY=...
   ```

3. **Update PWAInstaller component** with your VAPID public key

## 🎯 User Guide

### For Regular Users

1. **Register/Login** — Create account or login
2. **Create tasks** — Click on calendar day, add task details
3. **Add subtasks** — Break down tasks into smaller steps
4. **Set reminders** — Configure task reminders
5. **Add friends** — Invite friends to collaborate
6. **Create boards** — Set up shared Kanban boards
7. **Enable notifications** — Get push notifications for reminders

### For Admins

1. **Access admin panel** — Navigate to admin dashboard
2. **Manage users** — View all users, promote/demote roles
3. **Monitor system** — Check user activity and system health
4. **Configure settings** — Adjust system-wide settings

## 🔧 Configuration

### Environment Variables

```bash
# Backend (.env)
SERVER_PORT=8080
DATA_BACKEND=sqlite  # or postgres
SQLITE_PATH=/var/lib/todoapp/todoapp.db
POSTGRES_DSN=postgres://user:pass@host:5432/db?sslmode=disable

# Frontend (.env.local)
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
NEXT_PUBLIC_VAPID_KEY=your_vapid_public_key
```

## 🛡️ Security Recommendations

### For Production

1. **Enable HTTPS** — Use Traefik/nginx with Let's Encrypt
2. **Use strong passwords** — For database, secrets
3. **Enable rate limiting** — Prevent brute force attacks
4. **Regular backups** — Backup database regularly
5. **Monitor logs** — Watch for suspicious activity
6. **Update dependencies** — Keep all packages up to date

See [SECURITY.md](SECURITY.md) for comprehensive security guide.

## 📊 Performance

### Expected Response Times

- Health check: < 5ms
- Login/Register: < 350ms (bcrypt hashing)
- Task operations: < 50ms
- List queries: < 100ms

### Optimization Tips

- Use PostgreSQL for better multi-user performance
- Enable caching in Traefik/nginx
- Use connection pooling for database
- Monitor and tune database queries

## 🐛 Troubleshooting

### Common Issues

**"Unauthorized" errors:**
- Check if access token is valid
- Try refreshing session
- Re-login if token expired

**Push notifications not working:**
- Check browser supports Web Push
- Verify VAPID keys configured
- Ensure HTTPS enabled (required for push)

**Database connection errors:**
- Verify DATABASE_URL/POSTGRES_DSN correct
- Check database is running
- Ensure permissions correct for SQLite file

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Run security checks
5. Submit pull request

## 📄 License

See LICENSE file

## 👥 Authors

KPS-Enterprise Team — Phase 2 DevOps Project
