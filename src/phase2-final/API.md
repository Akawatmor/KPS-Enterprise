# API Documentation

**Base URL:** `http://localhost:8080/api/v1`  
**Production:** `https://yourdomain.com/api/v1`

## Authentication

All authenticated endpoints require:
```
Authorization: Bearer {access_token}
```

---

## Authentication Endpoints

### POST /auth/register

Register a new user with email/password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "StrongPass123!",
  "display_name": "John Doe"
}
```

**Response:** 201 Created
```json
{
  "user": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "display_name": "John Doe",
    "role": "user",
    "created_at": "2024-01-15T10:30:00Z"
  },
  "session": {
    "access_token": "atk_...",
    "refresh_token": "rtk_...",
    "expires_at": "2024-01-15T10:45:00Z"
  }
}
```

**Errors:**
- `400` — Invalid input (weak password, invalid email)
- `409` — Email already exists

---

### POST /auth/login

Login with email/password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "StrongPass123!"
}
```

**Response:** 200 OK
```json
{
  "user": {
    "id": "usr_abc123",
    "email": "user@example.com",
    "display_name": "John Doe",
    "role": "user"
  },
  "session": {
    "access_token": "atk_...",
    "refresh_token": "rtk_...",
    "expires_at": "2024-01-15T10:45:00Z"
  }
}
```

**Errors:**
- `401` — Invalid credentials
- `400` — Missing required fields

---

### POST /auth/github/exchange

Exchange GitHub OAuth code for access token.

**Request:**
```json
{
  "code": "github_oauth_code"
}
```

**Response:** 200 OK
```json
{
  "user": {...},
  "session": {...}
}
```

---

### POST /auth/session/refresh

Refresh expired access token.

**Request:**
```json
{
  "refresh_token": "rtk_..."
}
```

**Response:** 200 OK
```json
{
  "access_token": "atk_new...",
  "expires_at": "2024-01-15T11:00:00Z"
}
```

---

### POST /auth/session/logout

Logout and invalidate session.

**Headers:** `Authorization: Bearer {token}`

**Response:** 204 No Content

---

## Task Endpoints

### GET /tasks

Get all tasks for authenticated user.

**Headers:** `Authorization: Bearer {token}`

**Query Parameters:**
- `status` (optional): `open` | `done`
- `from` (optional): Start date (ISO 8601)
- `to` (optional): End date (ISO 8601)

**Response:** 200 OK
```json
{
  "tasks": [
    {
      "id": "tsk_123",
      "user_id": "usr_abc123",
      "title": "Complete project",
      "description": "Finish the todo app",
      "column": "todo",
      "priority": "high",
      "due_at": "2024-01-20T15:00:00Z",
      "created_at": "2024-01-15T10:00:00Z",
      "updated_at": "2024-01-15T10:00:00Z",
      "subtasks": [
        {
          "id": "sub_456",
          "title": "Design UI",
          "done": true
        },
        {
          "id": "sub_789",
          "title": "Write tests",
          "done": false
        }
      ]
    }
  ]
}
```

---

### POST /tasks

Create a new task.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "title": "New task",
  "description": "Task description",
  "column": "todo",
  "priority": "normal",
  "due_at": "2024-01-20T15:00:00Z"
}
```

**Response:** 201 Created
```json
{
  "task": {
    "id": "tsk_new123",
    "user_id": "usr_abc123",
    "title": "New task",
    ...
  }
}
```

**Errors:**
- `400` — Invalid input
- `401` — Unauthorized

---

### PATCH /tasks/:id

Update an existing task.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "title": "Updated title",
  "column": "done",
  "priority": "high"
}
```

**Response:** 200 OK
```json
{
  "task": {...}
}
```

**Errors:**
- `404` — Task not found
- `403` — Not task owner

---

### DELETE /tasks/:id

Delete a task.

**Headers:** `Authorization: Bearer {token}`

**Response:** 204 No Content

---

## Subtask Endpoints

### POST /tasks/:id/subtasks

Add subtask to a task.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "title": "Subtask title",
  "done": false
}
```

**Response:** 201 Created
```json
{
  "subtask": {
    "id": "sub_new123",
    "task_id": "tsk_123",
    "title": "Subtask title",
    "done": false
  }
}
```

---

### PATCH /tasks/:id/subtasks/:sid

Update subtask (toggle done).

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "done": true
}
```

**Response:** 200 OK

---

## Admin Endpoints

**Requires:** `role: admin`

### GET /admin/users

List all users (admin only).

**Headers:** `Authorization: Bearer {admin_token}`

**Response:** 200 OK
```json
{
  "users": [
    {
      "id": "usr_123",
      "email": "user@example.com",
      "display_name": "John Doe",
      "role": "user",
      "created_at": "2024-01-15T10:00:00Z"
    },
    {
      "id": "usr_456",
      "email": "admin@example.com",
      "display_name": "Admin",
      "role": "admin",
      "created_at": "2024-01-10T08:00:00Z"
    }
  ]
}
```

**Errors:**
- `403` — Forbidden (not admin)

---

### PATCH /admin/users/:id/role

Update user role (admin only).

**Headers:** `Authorization: Bearer {admin_token}`

**Request:**
```json
{
  "role": "admin"
}
```

**Response:** 200 OK
```json
{
  "user": {
    "id": "usr_123",
    "role": "admin"
  }
}
```

**Errors:**
- `403` — Forbidden (not admin)
- `400` — Invalid role

---

### DELETE /admin/users/:id

Delete a user (admin only).

**Headers:** `Authorization: Bearer {admin_token}`

**Response:** 204 No Content

**Errors:**
- `403` — Forbidden
- `400` — Cannot delete self

---

## Friends Endpoints

### POST /friends/request

Send friend request.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "friend_id": "usr_456"
}
```

**Response:** 201 Created
```json
{
  "friend": {
    "id": "frd_123",
    "user_id": "usr_abc",
    "friend_id": "usr_456",
    "status": "pending",
    "created_at": "2024-01-15T12:00:00Z"
  }
}
```

---

### POST /friends/:id/accept

Accept friend request.

**Headers:** `Authorization: Bearer {token}`

**Response:** 200 OK
```json
{
  "friend": {
    "id": "frd_123",
    "status": "accepted"
  }
}
```

---

### GET /friends

List all friends.

**Headers:** `Authorization: Bearer {token}`

**Response:** 200 OK
```json
{
  "friends": [
    {
      "id": "frd_123",
      "user_id": "usr_abc",
      "friend_id": "usr_456",
      "friend_display_name": "Jane Doe",
      "friend_email": "jane@example.com",
      "status": "accepted",
      "created_at": "2024-01-15T12:00:00Z"
    }
  ]
}
```

---

## Shared Board Endpoints

### POST /boards

Create a shared Kanban board.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "name": "Team Project",
  "description": "Shared team board"
}
```

**Response:** 201 Created
```json
{
  "board": {
    "id": "brd_123",
    "owner_id": "usr_abc",
    "name": "Team Project",
    "description": "Shared team board",
    "created_at": "2024-01-15T13:00:00Z"
  }
}
```

---

### GET /boards

List user's boards (owned + member of).

**Headers:** `Authorization: Bearer {token}`

**Response:** 200 OK
```json
{
  "boards": [
    {
      "id": "brd_123",
      "owner_id": "usr_abc",
      "name": "Team Project",
      "description": "Shared team board",
      "is_owner": true,
      "created_at": "2024-01-15T13:00:00Z"
    }
  ]
}
```

---

### POST /boards/:id/members

Add member to board.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "user_id": "usr_456"
}
```

**Response:** 201 Created

**Errors:**
- `403` — Not board owner

---

## Push Notification Endpoints

### POST /push/subscribe

Save push notification subscription.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "endpoint": "https://fcm.googleapis.com/...",
  "keys": {
    "p256dh": "...",
    "auth": "..."
  }
}
```

**Response:** 201 Created

---

### GET /push/subscriptions

Get user's push subscriptions.

**Headers:** `Authorization: Bearer {token}`

**Response:** 200 OK
```json
{
  "subscriptions": [
    {
      "id": "sub_123",
      "user_id": "usr_abc",
      "endpoint": "https://fcm.googleapis.com/...",
      "p256dh": "...",
      "auth": "...",
      "created_at": "2024-01-15T14:00:00Z"
    }
  ]
}
```

---

## Reminder Endpoints

### GET /reminders/rules

Get reminder rules for user.

**Headers:** `Authorization: Bearer {token}`

**Response:** 200 OK
```json
{
  "rules": [
    {
      "id": "rem_123",
      "user_id": "usr_abc",
      "task_id": "tsk_456",
      "remind_at": "2024-01-20T09:00:00Z",
      "interval_hours": 24,
      "active": true
    }
  ]
}
```

---

### POST /reminders/rules

Create reminder rule.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "task_id": "tsk_456",
  "remind_at": "2024-01-20T09:00:00Z",
  "interval_hours": 24
}
```

**Response:** 201 Created

---

### PATCH /reminders/rules/:id

Update reminder rule.

**Headers:** `Authorization: Bearer {token}`

**Request:**
```json
{
  "active": false
}
```

**Response:** 200 OK

---

## Health & Meta Endpoints

### GET /healthz

Health check endpoint.

**Response:** 200 OK
```json
{
  "status": "ok"
}
```

---

### GET /readyz

Readiness check (includes DB).

**Response:** 200 OK
```json
{
  "status": "ready",
  "database": "ok"
}
```

---

### GET /api/v1/meta

Get API metadata.

**Response:** 200 OK
```json
{
  "version": "1.0.0",
  "build": "2024-01-15",
  "database": "sqlite"
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "error": {
    "code": "invalid_input",
    "message": "Password must be at least 8 characters",
    "details": {
      "field": "password"
    }
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `unauthorized` | 401 | Missing or invalid token |
| `forbidden` | 403 | Insufficient permissions |
| `not_found` | 404 | Resource not found |
| `invalid_input` | 400 | Validation failed |
| `conflict` | 409 | Resource already exists |
| `internal_error` | 500 | Server error |

---

## Rate Limiting

**Current:** No rate limiting implemented  
**Recommended:** 100 requests per minute per IP

---

## CORS

**Allowed Origins:** Configured via `ALLOWED_ORIGIN` env variable  
**Allowed Methods:** GET, POST, PATCH, DELETE, OPTIONS  
**Allowed Headers:** Authorization, Content-Type

---

## Versioning

API version is included in URL: `/api/v1/...`

Breaking changes will increment the version number.
