# Testing Guide

## 🧪 Testing Strategy

### Test Pyramid

```
    /\
   /UI\
  /────\
 / API  \
/────────\
/ Unit    \
```

## 1. Backend Testing

### Unit Tests

Run existing tests:
```bash
cd backend
go test ./internal/...
```

### API Integration Tests

Test authentication:
```bash
# Register new user
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#","display_name":"Test User"}'

# Response should include access_token
# {"user":{"id":"usr_..."},"session":{"access_token":"atk_..."}}

# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#"}'

# Save the access_token for next requests
TOKEN="atk_..."

# Create a task
curl -X POST http://localhost:8080/api/v1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"title":"Test task","column":"todo","priority":"high"}'

# List tasks
curl -X GET http://localhost:8080/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN"
```

### Admin API Tests

```bash
# First user is admin by default (update manually in DB)
# Or promote via API after creating admin user

# List all users (admin only)
curl -X GET http://localhost:8080/api/v1/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Update user role
curl -X PATCH http://localhost:8080/api/v1/admin/users/usr_123/role \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"role":"admin"}'
```

### Friends & Boards Tests

```bash
# Send friend request
curl -X POST http://localhost:8080/api/v1/friends/request \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"friend_id":"usr_456"}'

# Accept friend request (as friend)
curl -X POST http://localhost:8080/api/v1/friends/frd_123/accept \
  -H "Authorization: Bearer $FRIEND_TOKEN" \
  -d '{}'

# List friends
curl -X GET http://localhost:8080/api/v1/friends \
  -H "Authorization: Bearer $TOKEN"

# Create shared board
curl -X POST http://localhost:8080/api/v1/boards \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Team Board","description":"Shared tasks"}'

# List boards
curl -X GET http://localhost:8080/api/v1/boards \
  -H "Authorization: Bearer $TOKEN"
```

## 2. Frontend Testing

### Jest Unit Tests

Run existing tests:
```bash
cd frontend
npm test
```

### Component Tests

Test specific component:
```bash
npm test -- AuthForm
npm test -- AdminDashboard
```

### E2E Testing (Manual)

1. **Registration Flow**
   - Open http://localhost:3000
   - Should see login/register form if not authenticated
   - Try registering with weak password → Should show error
   - Register with strong password → Should succeed and login

2. **Authentication Flow**
   - Logout
   - Login with correct credentials → Should succeed
   - Login with wrong credentials → Should show error

3. **Task Management**
   - Create new task
   - Edit task
   - Mark task as done
   - Delete task

4. **Subtasks**
   - Click on a task
   - Add subtask
   - Toggle subtask completion
   - Delete subtask

5. **Admin Panel** (if admin)
   - Navigate to /admin (if admin route added)
   - View all users
   - Promote user to admin
   - Delete test user

6. **Friends**
   - Add friend by user ID
   - Check friend request status
   - Accept friend request (as other user)

7. **Shared Boards**
   - Create new board
   - Add board member (friend)
   - View shared boards

8. **PWA Features**
   - Click "Enable Notifications"
   - Grant permission
   - Check if subscription saved
   - Test offline mode (disconnect network, reload)

## 3. Load Testing

### Using Apache Bench

```bash
# Test login endpoint
ab -n 1000 -c 10 \
  -p login.json \
  -T application/json \
  http://localhost:8080/api/v1/auth/login

# login.json content:
# {"email":"test@example.com","password":"Test123!@#"}
```

### Using wrk

```bash
wrk -t4 -c100 -d30s \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/v1/tasks
```

## 4. Security Testing

### Password Validation

```bash
# Should fail - too short
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test1!","display_name":"Test"}'

# Should fail - no uppercase
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123!@#","display_name":"Test"}'

# Should fail - no special char
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test12345","display_name":"Test"}'

# Should succeed
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!@#","display_name":"Test"}'
```

### Authorization Tests

```bash
# Try to access tasks without token
curl -X GET http://localhost:8080/api/v1/tasks
# Should return 401 Unauthorized

# Try to access admin endpoint as normal user
curl -X GET http://localhost:8080/api/v1/admin/users \
  -H "Authorization: Bearer $USER_TOKEN"
# Should return 403 Forbidden
```

### SQL Injection Tests

```bash
# Try SQL injection in email
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com OR 1=1--","password":"anything"}'
# Should fail safely

# Try in task title
curl -X POST http://localhost:8080/api/v1/tasks \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"'; DROP TABLE tasks;--","column":"todo"}'
# Should be safely escaped
```

## 5. Performance Benchmarks

### Expected Response Times

| Endpoint | Expected | Acceptable |
|----------|----------|------------|
| GET /healthz | < 5ms | < 20ms |
| POST /auth/login | < 350ms | < 500ms |
| POST /auth/register | < 350ms | < 500ms |
| GET /tasks | < 50ms | < 100ms |
| POST /tasks | < 30ms | < 100ms |
| GET /admin/users | < 100ms | < 200ms |

### Database Query Performance

```bash
# Enable query logging in PostgreSQL
# postgresql.conf:
# log_statement = 'all'
# log_duration = on

# Check slow queries
tail -f /var/log/postgresql/postgresql-*.log | grep "duration:"
```

## 6. Browser Compatibility Testing

### Supported Browsers

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

### PWA Features

Test on:
- Chrome/Edge (full support)
- Firefox (limited push notification support)
- Safari iOS (limited PWA support)

### Testing Checklist

- [ ] Service worker registers successfully
- [ ] Offline mode works (static assets cached)
- [ ] Add to home screen works
- [ ] Push notifications work (Chrome/Edge)
- [ ] Responsive design works on mobile
- [ ] Calendar touch interactions work
- [ ] Task drag-drop works (if implemented)

## 7. Accessibility Testing

### Tools

- Chrome DevTools Lighthouse
- WAVE Browser Extension
- axe DevTools

### Checklist

- [ ] All interactive elements keyboard accessible
- [ ] Proper ARIA labels
- [ ] Color contrast meets WCAG AA
- [ ] Screen reader friendly
- [ ] Focus indicators visible

## 8. CI/CD Testing

### Woodpecker Pipeline Tests

The `.woodpecker.yml` should include:

```yaml
- name: test-frontend
  image: node:22-bookworm-slim
  commands:
    - cd src/phase2-final/frontend
    - npm ci
    - npm run type-check
    - npm run test:ci

- name: test-backend
  image: golang:1.22-bookworm
  commands:
    - cd src/phase2-final/backend
    - go test -v -race -coverprofile=coverage.out ./...
```

## 9. Monitoring & Alerts

### Health Checks

```bash
# Backend health
curl http://localhost:8080/healthz

# Backend ready (with DB check)
curl http://localhost:8080/readyz
```

### Metrics to Monitor

- Response times
- Error rates
- Authentication failures
- Database connection pool
- Memory usage
- Disk space (for SQLite)

## 10. Test Data Setup

### Create Test Users

```bash
# Admin user
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!@#","display_name":"Admin User"}'

# Regular users
for i in {1..5}; do
  curl -X POST http://localhost:8080/api/v1/auth/register \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"user$i@test.com\",\"password\":\"Test123!@#\",\"display_name\":\"Test User $i\"}"
done
```

### Create Test Tasks

```bash
TOKEN="..." # From login response

for i in {1..10}; do
  curl -X POST http://localhost:8080/api/v1/tasks \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Task $i\",\"description\":\"Test task $i\",\"column\":\"todo\",\"priority\":\"normal\"}"
done
```

## 📊 Test Coverage Goals

- **Backend:** > 70% code coverage
- **Frontend:** > 60% code coverage
- **E2E:** Critical user paths covered
- **Security:** All OWASP Top 10 tested

## 🐛 Bug Reporting

When reporting bugs, include:
1. Steps to reproduce
2. Expected behavior
3. Actual behavior
4. Screenshots/logs
5. Environment (browser, OS, version)

## ✅ Release Checklist

Before releasing to production:

- [ ] All tests pass
- [ ] No security vulnerabilities
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Database migrations tested
- [ ] Rollback plan ready
- [ ] Monitoring configured
- [ ] Backups configured
