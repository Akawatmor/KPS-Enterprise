# Security Implementation Guide

## 🔒 Security Features Implemented

### 1. Authentication & Authorization

#### Password Security
- **Bcrypt hashing** with cost factor 12 (~300ms on modern hardware)
- **Password requirements enforced:**
  - Minimum 8 characters
  - At least 1 uppercase letter
  - At least 1 lowercase letter
  - At least 1 number
  - At least 1 special character
- **Email validation** using regex pattern

#### Session Management
- **JWT-like access tokens** with expiration (default 15 minutes)
- **Refresh tokens** for session renewal (default 7 days)
- **Session revocation** on logout
- Tokens stored securely in `localStorage` (client-side)

#### Role-Based Access Control (RBAC)
- **User roles:** `user`, `admin`
- Admin-only endpoints protected by role checks
- Users cannot elevate their own privileges

### 2. API Security

#### Input Validation
- All user input validated on backend
- Email format validation
- Password strength validation
- Type checking on all API inputs

#### CORS Configuration
- Configurable via `ALLOWED_ORIGIN` environment variable
- Supports specific domain restriction

#### Authorization Checks
- Bearer token authentication required for all protected endpoints
- User ID verification for data access
- Ownership validation before updates/deletes

### 3. Data Protection

#### Password Storage
- **Never store plaintext passwords**
- Passwords hashed with bcrypt before storage
- Password hashes never exposed in JSON responses (marked with `json:"-"`)

#### User Data Privacy
- Users can only access their own tasks/data
- Admin required to view all users
- Friends feature requires mutual consent

### 4. Database Security (PostgreSQL/SQLite)

#### SQL Injection Prevention
- Using parameterized queries (prepared statements)
- No string concatenation for SQL queries
- Database driver handles escaping automatically

#### File Permissions (SQLite)
- Database file permissions: 0600 (owner read-write only)
- Database directory permissions: 0750 (owner full, group read-execute)

### 5. PWA Security

#### Service Worker
- Served over HTTPS in production
- Cache strategy: Network-first, fallback to cache
- No sensitive data cached

#### Push Notifications
- Requires explicit user permission
- VAPID keys for authentication (need to be generated)
- Subscription data stored securely

## 🚨 Security Best Practices

### For Development

1. **Never commit secrets**
   ```bash
   # Use .env files (already in .gitignore)
   cp .env.example .env
   # Fill in real values
   ```

2. **Use strong secrets in production**
   ```bash
   # Generate random secrets
   openssl rand -hex 32
   ```

3. **Enable HTTPS**
   - Use Traefik/nginx with Let's Encrypt
   - Force HTTPS redirects

### For Deployment

1. **Environment Variables**
   ```yaml
   # k8s/secret.yaml
   POSTGRES_DSN: "postgres://user:STRONG_PASSWORD@host:5432/db?sslmode=require"
   GITHUB_OAUTH_CLIENT_SECRET: "real_secret_here"
   ```

2. **Database**
   - Use SSL/TLS for PostgreSQL connections
   - Strong password for database user
   - Restrict network access to database

3. **API Rate Limiting** (TODO)
   - Implement rate limiting to prevent brute force
   - Use nginx/Traefik rate limiting features

4. **Logging**
   - Log authentication failures
   - Monitor suspicious activity
   - Don't log passwords or tokens

## ⚠️ Known Limitations

### Current Implementation

1. **No rate limiting** on login/register endpoints
   - Risk: Brute force attacks
   - Mitigation: Add nginx/Traefik rate limiting

2. **No email verification**
   - Users can register with any email
   - Mitigation: Add email verification flow

3. **No password reset**
   - Users cannot reset forgotten passwords
   - Mitigation: Implement password reset via email

4. **No CSRF protection**
   - Risk: Cross-site request forgery
   - Mitigation: Minimal risk with token-based auth, but consider adding CSRF tokens

5. **No API request logging**
   - Cannot track suspicious activity easily
   - Mitigation: Add request logging middleware

6. **localStorage for tokens**
   - Risk: XSS attacks can steal tokens
   - Mitigation: Consider httpOnly cookies for production

## 🧪 Security Testing Checklist

### Authentication Tests

- [ ] Cannot register with weak password
- [ ] Cannot register with invalid email
- [ ] Cannot login with wrong password
- [ ] Session expires after TTL
- [ ] Refresh token works
- [ ] Logout invalidates session

### Authorization Tests

- [ ] User A cannot access User B's tasks
- [ ] Non-admin cannot access admin endpoints
- [ ] Admin can manage all users
- [ ] Cannot delete own admin account

### Input Validation Tests

- [ ] SQL injection attempts fail
- [ ] XSS attempts sanitized
- [ ] Path traversal blocked
- [ ] Invalid JSON rejected

### API Security Tests

- [ ] Unauthorized requests return 401
- [ ] Forbidden requests return 403
- [ ] CORS headers correct
- [ ] Options requests handled

## 📝 Recommended Security Enhancements

### Priority 1 (Critical)

1. **Add rate limiting**
   ```nginx
   limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;
   location /api/v1/auth/ {
     limit_req zone=auth burst=10;
   }
   ```

2. **Enable HTTPS everywhere**
3. **Add request logging**

### Priority 2 (Important)

1. **Email verification**
2. **Password reset flow**
3. **2FA (Two-Factor Authentication)**
4. **Security headers:**
   ```go
   w.Header().Set("X-Frame-Options", "DENY")
   w.Header().Set("X-Content-Type-Options", "nosniff")
   w.Header().Set("X-XSS-Protection", "1; mode=block")
   w.Header().Set("Strict-Transport-Security", "max-age=31536000")
   ```

### Priority 3 (Nice to have)

1. **Content Security Policy (CSP)**
2. **Subresource Integrity (SRI)**
3. **API versioning strategy**
4. **Audit logging**

## 🔐 VAPID Keys for Web Push

Generate VAPID keys for push notifications:

```bash
# Using web-push library
npx web-push generate-vapid-keys

# Output:
# Public Key: BN...
# Private Key: xyz...
```

Store in environment variables:
```bash
VAPID_PUBLIC_KEY=BN...
VAPID_PRIVATE_KEY=xyz...
VAPID_SUBJECT=mailto:admin@yourdomain.com
```

Update `PWAInstaller.tsx`:
```typescript
const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_KEY || "";
```

## 📞 Security Contact

For security issues, please contact: security@yourdomain.com

**Do not** create public GitHub issues for security vulnerabilities.
