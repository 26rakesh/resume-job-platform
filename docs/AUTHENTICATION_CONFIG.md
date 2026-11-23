# Authentication Configuration and Security

## Overview

This application uses **Laravel Sanctum with cookie-based authentication** for the React SPA. This provides secure, same-origin authentication with CSRF protection without storing tokens in localStorage.

## Architecture

### Backend (Laravel 13 + Sanctum)

**Authentication Method**: Session-based cookies with CSRF protection

**Configuration**:
- `bootstrap/app.php`: Uses `statefulApi()` middleware for SPA authentication
- `config/sanctum.php`: Stateful domains configured via `SANCTUM_STATEFUL_DOMAINS`
- `routes/api.php`: Protected routes use `auth` middleware (session-based)
- Rate limiting: Login endpoint throttled to 5 requests per minute

**Security Features**:
1. **Production registration disabled**: `/api/register` returns 403 in production
2. **Admin creation via Artisan command only**: `php artisan admin:create`
3. **Role assignment**: Default registration assigns 'user' role, never 'admin'
4. **CSRF protection**: All stateful requests require valid CSRF token
5. **HttpOnly cookies**: Session cookies are HttpOnly to prevent XSS token theft
6. **Secure cookies**: `SESSION_SECURE_COOKIE=true` for HTTPS
7. **SameSite cookies**: `SESSION_SAME_SITE=lax` to prevent CSRF
8. **Rate limiting**: Login endpoint limited to 5 attempts per minute

### Frontend (React + Axios)

**API Configuration** (`src/lib/api.ts`):
- `withCredentials: true` enables cookie transmission
- CSRF token initialized on app mount via `/sanctum/csrf-cookie`
- 401 responses auto-redirect to login
- 419 (CSRF mismatch) re-initializes CSRF token

**No localStorage tokens**: Authentication state is maintained via HTTP-only cookies only.

## Admin User Creation

### Development Registration
In development (`APP_ENV=local`), public registration is enabled:
- Creates user with `role: 'user'` (never admin)
- Can be used for testing non-admin functionality

### Production Admin Creation
In production, registration is disabled. Admin users are created via:

```bash
php artisan admin:create
```

This command:
- Prompts for name, email, password
- Validates email uniqueness
- Requires minimum 8-character password
- Creates user with `role: 'admin'`
- Only accessible via SSH/command line (not HTTP)

## Role-Based Authorization

### Admin Middleware
A custom `AdminMiddleware` protects admin-only endpoints:

```php
Route::middleware(['auth', 'admin'])->group(function () {
    // Admin-only routes
});
```

### User Role Checks
The `User` model provides an `isAdmin()` helper:

```php
if ($user->isAdmin()) {
    // Admin-specific logic
}
```

## Environment Variables

### Required for Authentication

```env
APP_ENV=production  # or local for development
APP_URL=https://jobs.sunrisepaint.in
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
SESSION_SAME_SITE=lax
SANCTUM_STATEFUL_DOMAINS=jobs.sunrisepaint.in
```

### Development Configuration

```env
APP_ENV=local
APP_URL=http://localhost:8000
FRONTEND_URL=http://localhost:3000
SANCTUM_STATEFUL_DOMAINS=localhost,localhost:3000,127.0.0.1,127.0.0.1:8000,::1
```

## API Endpoints

### Public Endpoints
- `GET /api/csrf-cookie` - Initialize CSRF token
- `POST /api/login` - Authenticate user (rate limited: 5/min)
- `POST /api/register` - Register new user (dev only, 403 in production)

### Protected Endpoints (Require Authentication)
- `GET /api/user` - Get current user
- `POST /api/logout` - Invalidate session

### Admin-Only Endpoints (Require Admin Role)
- Future endpoints for candidate/job management will use `['auth', 'admin']` middleware

## Security Checklist

- [x] Public registration disabled in production
- [x] Admin role cannot be assigned via public API
- [x] Admin creation via secure Artisan command only
- [x] Cookie-based authentication (no localStorage tokens)
- [x] CSRF protection enabled for stateful requests
- [x] HttpOnly session cookies
- [x] Secure cookies (HTTPS only in production)
- [x] SameSite cookies (lax)
- [x] Login rate limiting (5 attempts/minute)
- [x] Admin middleware for sensitive endpoints
- [x] Session invalidation on logout
- [x] 401 auto-redirect to login

## Testing Authentication

### Local Development
1. Start Laravel: `php artisan serve`
2. Start React: `npm run dev`
3. Register user (dev only): http://localhost:3000
4. Login: Test cookie-based auth
5. Check browser DevTools → Application → Cookies for session cookie

### Production Testing
1. SSH to server
2. Create admin: `php artisan admin:create`
3. Login with admin credentials
4. Verify session cookie is HttpOnly and Secure
5. Test that `/api/register` returns 403
6. Test rate limiting with multiple failed login attempts

## Migration from Token-Based Auth

If you previously used token-based authentication:

1. Remove `HasApiTokens` trait from User model (not needed for session auth)
2. Remove token storage from frontend (localStorage)
3. Update Axios config to use `withCredentials: true`
4. Initialize CSRF token on app mount
5. Update middleware from `auth:sanctum` to `auth`

## References

- [Laravel Sanctum Documentation](https://laravel.com/docs/sanctum)
- [SPA Authentication with Sanctum](https://laravel.com/docs/sanctum#spa-authentication)
- [Laravel Session Configuration](https://laravel.com/docs/session)
