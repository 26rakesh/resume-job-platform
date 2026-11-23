# Hostinger Deployment Architecture

## Current Repository Structure

```
jobs-platform/                          # Local workspace root
├── backend/                            # Laravel application root
│   ├── app/                            # Application code
│   ├── bootstrap/                      # Bootstrap files
│   ├── config/                         # Configuration
│   ├── database/                       # Migrations and seeders
│   ├── public/                         # Web root (ONLY this exposed)
│   │   ├── index.php                   # Laravel entry point
│   │   ├── .htaccess                   # Laravel routing
│   │   └── app/                        # React build output (after build)
│   ├── routes/                         # Routes
│   ├── storage/                        # Private storage
│   ├── .env                            # Environment (NOT in git)
│   ├── artisan                         # CLI
│   └── composer.json                   # PHP dependencies
├── frontend/                           # React source
│   └── src/                            # React components
└── scripts/                            # Build scripts
```

## Preferred Deployment Structure (Standard Laravel)

This is the recommended production deployment pattern. Requires changing the subdomain document root in hPanel.

### Hostinger Server Paths

```
/home/<user>/
├── public_html/                        # Main Sunrise Paint site (untouched)
└── jobs-app/                           # Laravel application root (Git deployment directory)
    ├── app/                            # NOT web-accessible
    ├── bootstrap/                      # NOT web-accessible
    ├── config/                         # NOT web-accessible
    ├── database/                       # NOT web-accessible
    ├── routes/                         # NOT web-accessible
    ├── storage/                        # NOT web-accessible
    ├── vendor/                         # NOT web-accessible
    ├── .env                            # NOT web-accessible
    ├── artisan                         # NOT web-accessible
    ├── composer.json                   # NOT web-accessible
    └── public/                         # ← Subdomain document root points here
        ├── index.php                   # Laravel entry point
        ├── .htaccess                   # Laravel routing
        └── app/                        # React build output
```

### Exact Paths

| Item | Path | Access |
|------|------|--------|
| Git deployment directory | `/home/<user>/jobs-app` | Outside web root |
| Laravel application root | `/home/<user>/jobs-app` | Outside web root |
| Laravel public directory | `/home/<user>/jobs-app/public` | Subdomain docroot |
| React build output | `/home/<user>/jobs-app/public/app` | Via subdomain |
| Private resume storage | `/home/<user>/jobs-app/storage/app/private` | Not web-accessible |
| .env file | `/home/<user>/jobs-app/.env` | Not web-accessible |
| Composer execution directory | `/home/<user>/jobs-app` | SSH only |

### hPanel Configuration Required

1. **Git Deployment Directory**: Set to `jobs-app` (or full path `/home/<user>/jobs-app`)
2. **Subdomain Document Root**: Set to `jobs-app/public` (or full path `/home/<user>/jobs-app/public`)

### Composer Commands

All Composer commands must run from the Laravel application root:

```bash
cd /home/<user>/jobs-app
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache route:cache view:cache
chmod -R 775 storage bootstrap/cache
```

### Cron Job

```cron
*/15 * * * * cd /home/<user>/jobs-app && php artisan schedule:run >> /dev/null 2>&1
```

---

## Alternative: Deploy to public_html with .htaccess Protection

If hPanel does not allow changing the subdomain document root, use this fallback. This is what was previously approved but is less secure.

### Hostinger Server Paths

```
/home/<user>/domains/jobs.sunrisepaint.in/
└── public_html/                       # Git deployment directory AND web root
    ├── .htaccess                      # Root security .htaccess (denies access to sensitive dirs)
    ├── app/                           # Laravel app (protected by .htaccess)
    ├── bootstrap/                     # Laravel bootstrap (protected by .htaccess)
    ├── config/                        # Laravel config (protected by .htaccess)
    ├── database/                      # Laravel database (protected by .htaccess)
    ├── routes/                        # Laravel routes (protected by .htaccess)
    ├── storage/                       # Laravel storage (protected by .htaccess)
    ├── vendor/                        # Composer dependencies (protected by .htaccess)
    ├── .env                           # Environment (protected by .htaccess)
    ├── artisan                        # CLI (protected by .htaccess)
    ├── composer.json                  # PHP dependencies (protected by .htaccess)
    ├── index.php                      # Laravel entry point
    └── app/                           # React build output
```

### Exact Paths

| Item | Path | Access |
|------|------|--------|
| Git deployment directory | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` | Web root (with .htaccess protection) |
| Laravel application root | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` | Web root (with .htaccess protection) |
| Laravel public directory | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` | Web root (with .htaccess protection) |
| React build output | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/app` | Via subdomain |
| Private resume storage | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/storage/app/private` | Protected by .htaccess |
| .env file | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/.env` | Protected by .htaccess |
| Composer execution directory | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` | SSH only |

### Security Mitigation

Root `.htaccess` denies web access to:
- `app/`, `bootstrap/`, `config/`, `database/`, `routes/`, `vendor/`, `storage/`
- `.env`, `.env.*`
- `artisan`, `composer.json`, `composer.lock`, `package.json`

### Composer Commands

```bash
cd /home/<user>/domains/jobs.sunrisepaint.in/public_html
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache route:cache view:cache
chmod -R 775 storage bootstrap/cache
```

### Cron Job

```cron
*/15 * * * * cd /home/<user>/domains/jobs.sunrisepaint.in/public_html && php artisan schedule:run >> /dev/null 2>&1
```

---

## Repository to Server Mapping

### Local to Server (Preferred Structure)

| Local Path | Server Path |
|------------|-------------|
| `backend/` | `/home/<user>/jobs-app/` |
| `backend/app/` | `/home/<user>/jobs-app/app/` |
| `backend/public/` | `/home/<user>/jobs-app/public/` |
| `backend/storage/` | `/home/<user>/jobs-app/storage/` |
| `backend/.env` | `/home/<user>/jobs-app/.env` (created manually) |
| `frontend/dist/` (after build) | `/home/<user>/jobs-app/public/app/` |

### Local to Server (Alternative Structure)

| Local Path | Server Path |
|------------|-------------|
| `backend/` | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/` |
| `backend/app/` | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/app/` |
| `backend/public/` | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/` |
| `backend/storage/` | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/storage/` |
| `backend/.env` | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/.env` (created manually) |
| `frontend/dist/` (after build) | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/app/` |

---

## Deployment Recommendation

**Use the Preferred Structure** (Laravel outside public_html) if possible. This is:
- Standard Laravel deployment pattern
- More secure by default
- Cleaner separation of concerns
- No reliance on .htaccess for security

**Use the Alternative Structure** only if hPanel does not allow changing the subdomain document root. This requires:
- Root `.htaccess` for security mitigation
- Additional security audit
- Documentation of the limitation for client deployments

---

## Migration from Alternative to Preferred

If currently using the alternative structure and hPanel later allows document root changes:

1. Move Laravel files from `public_html` to `jobs-app/` (outside public_html)
2. Update hPanel Git deployment directory to `jobs-app`
3. Update hPanel subdomain document root to `jobs-app/public`
4. Remove root `.htaccess` (no longer needed)
5. Verify all paths and permissions
