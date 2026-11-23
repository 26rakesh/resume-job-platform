# Deployment Plan — jobs.sunrisepaint.in (Hostinger Business)

Status: **PLANNED — nothing deployed, nothing triggered.**
Source of truth: GitHub `main` branch of `26rakesh/resume-job-platform`.

## Confirmed constraints

- Hostinger Git auto-deploy: **enabled**, currently targeting `public_html` of jobs.sunrisepaint.in.
- **Do NOT assume** Hostinger Git runs `composer install`.
- **Do NOT assume** Hostinger Git runs `npm`/`vite build`.
- PHP 8.3 on server; extensions per compatibility assessment.
- Main Sunrise Paint website is at a separate `public_html` — jobs site is isolated.

## Repository Structure

The repository structure is:
```
jobs-platform/
├── backend/           # Laravel application (artisan, composer.json, etc.)
│   ├── app/
│   ├── bootstrap/
│   ├── config/
│   ├── database/
│   ├── public/        # Laravel public directory (index.php, .htaccess)
│   ├── routes/
│   ├── storage/
│   └── .env.example
├── frontend/          # React application
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── scripts/           # Build scripts
└── docs/
```

**IMPORTANT**: The Laravel application root is `backend/`, not the repository root. All Composer commands must be run from the `backend/` directory.

## Recommended Deployment Structure (Preferred)

This is the standard Laravel deployment pattern. Requires changing the subdomain document root in hPanel.

### Target layout on server

```
/home/<user>/
├── public_html/                  # Main Sunrise Paint site — NEVER touched
└── jobs-platform/                # Hostinger Git deployment directory (repository root)
    ├── backend/                  # Laravel application root
    │   ├── app/ bootstrap/ config/ database/ routes/   # NOT web-accessible
    │   ├── vendor/               # NOT web-accessible
    │   ├── storage/              # NOT web-accessible
    │   ├── .env                  # NOT web-accessible
    │   ├── artisan               # NOT web-accessible
    │   └── public/               # ← Subdomain document root points here
    │       ├── index.php         # Laravel entrypoint
    │       ├── .htaccess         # Laravel routing
    │       └── app/              # React build output (vite build)
    ├── frontend/                 # React source (not deployed, built locally)
    ├── scripts/                  # Build scripts
    └── docs/                     # Documentation
```

### hPanel Configuration Required

1. **Git Deployment Directory**: Set to `jobs-platform` (or full path `/home/<user>/jobs-platform`)
2. **Subdomain Document Root**: Set to `jobs-platform/backend/public` (or full path `/home/<user>/jobs-platform/backend/public`)

### Exact Paths

|| Item | Path |
||------|------|
|| Git deployment directory | `/home/<user>/jobs-platform` |
|| Repository root | `/home/<user>/jobs-platform` |
|| Laravel application root | `/home/<user>/jobs-platform/backend` |
|| Laravel public directory | `/home/<user>/jobs-platform/backend/public` |
|| React build output | `/home/<user>/jobs-platform/backend/public/app` |
|| Private resume storage | `/home/<user>/jobs-platform/backend/storage/app/private` |
|| .env file | `/home/<user>/jobs-platform/backend/.env` |

### Composer Commands

All Composer commands run from Laravel application root (`backend/`):

```bash
cd /home/<user>/jobs-platform/backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache route:cache view:cache
chmod -R 775 storage bootstrap/cache
```

### Cron Job

```cron
*/15 * * * * cd /home/<user>/jobs-platform/backend && php artisan schedule:run >> /dev/null 2>&1
```

---

## Alternative Deployment Structure (Fallback)

If hPanel does not allow changing the subdomain document root, use this fallback with `.htaccess` protection. This structure preserves the repository layout but places everything under the public document root.

### Target layout on server

```
/home/<user>/domains/jobs.sunrisepaint.in/
└── public_html/                  # Hostinger Git deployment directory & web root (repository root)
    ├── .htaccess                 # 🔒 denies access to backend/, frontend/, vendor/, .env, storage/
    ├── backend/                  # Laravel application root
    │   ├── app/ bootstrap/ config/ database/ routes/   # protected by .htaccess
    │   ├── vendor/               # protected by .htaccess
    │   ├── storage/              # protected by .htaccess
    │   ├── .env                  # protected by .htaccess
    │   ├── artisan               # protected by .htaccess
    │   └── public/               # Web root for Laravel
    │       ├── index.php         # Laravel entrypoint
    │       ├── .htaccess         # Laravel routing
    │       └── app/              # React build output (vite build)
    ├── frontend/                 # React source (protected by .htaccess)
    ├── scripts/                  # Build scripts (protected by .htaccess)
    └── docs/                     # Documentation (protected by .htaccess)
```

### Exact Paths

|| Item | Path |
||------|------|
|| Git deployment directory | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` |
|| Repository root | `/home/<user>/domains/jobs.sunrisepaint.in/public_html` |
|| Laravel application root | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend` |
|| Laravel public directory | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/public` |
|| React build output | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/public/app` |
|| Private resume storage | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/storage/app/private` |
|| .env file | `/home/<user>/domains/jobs.sunrisepaint.in/public_html/backend/.env` |

### Composer Commands

All Composer commands run from Laravel application root (`backend/`):

```bash
cd /home/<user>/domains/jobs.sunrisepaint.in/public_html/backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache route:cache view:cache
chmod -R 775 storage bootstrap/cache
```

### Cron Job

```cron
*/15 * * * * cd /home/<user>/domains/jobs.sunrisepaint.in/public_html/backend && php artisan schedule:run >> /dev/null 2>&1
```

**Security mitigation**: Root `.htaccess` denies web access to sensitive directories (`backend/`, `frontend/`, `vendor/`, etc.). This is a partial mitigation — for client deployments, recommend the preferred structure.

## Reproducible build process

All builds happen **locally (or CI) before push** — the server never builds.

### Step 1 — Frontend (React + Vite → static)

```bash
cd frontend
npm ci
npm run build            # outputs frontend/dist
```

`dist/` is copied into `backend/public/app/` and **committed to the repo**
(build artifacts are deterministic; committing them is the standard
shared-hosting pattern when the host can't run Node). `.gitignore` must NOT
ignore `backend/public/app/` — add an exception.

Alternative if artifact commits are unwanted: GitHub Actions builds `dist`
on push and commits it back / or deploys via SSH rsync. Decide at M0.

### Step 2 — Backend dependencies (vendor/)

Vendor is **not committed**. Two paths depending on SSH availability:

- **Path A — SSH available (preferred):**
  ```bash
  ssh user@jobs.sunrisepaint.in
  cd /home/<user>/jobs-platform/backend  # or appropriate path based on deployment structure
  git pull origin main                    # Hostinger Git may already do this
  composer install --no-dev --optimize-autoloader
  php artisan migrate --force
  php artisan config:cache && php artisan route:cache && php artisan view:cache
  php artisan storage:link                # if public disk used; resumes use private disk
  chmod -R 775 storage bootstrap/cache
  ```
- **Path B — no SSH:** check hPanel → Git settings for a "run composer"
  option or deployment hooks. If none exists, fallback options:
  1. Commit `vendor/` built with `composer install --no-dev` locally
     (works, but ~large repo; last resort).
  2. Ask Hostinger support whether Git deploy supports composer.
  3. Upgrade path: deploy via GitHub Actions + FTP/SSH credentials stored
     as GitHub secrets (needs SSH or FTP credentials from hPanel).

### Step 3 — Database

- MySQL DB + user created once in hPanel; credentials go into server `.env`
  (`DB_HOST=localhost`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`).
- Migrations run via `php artisan migrate --force` (Path A) or a one-time
  manual run. Never run migrations from the browser.
- Seeders: only non-sensitive reference data (roles, permissions). **No real
  candidate resumes or personal data in seeders.**

### Step 4 — Environment & secrets

- `.env` created **manually on the server once** (copy from `backend/.env.example`).
- Contains: `APP_KEY` (`php artisan key:generate` on server), DB creds,
  `GEMINI_API_KEY`, `QUEUE_CONNECTION=database`, `CACHE_STORE=file`/`database`.
- `.env` is gitignored; it lives at `backend/.env`, outside docroot (preferred structure) or protected by .htaccess (fallback).

### Step 5 — Cron (scheduled processing)

One hPanel cron entry (every 15 min, or the minimum allowed):

```cron
*/15 * * * * cd /home/<user>/jobs-platform/backend && php artisan schedule:run >> /dev/null 2>&1
```

Laravel scheduler fans out: queue drain (`queue:work --stop-when-empty
--max-time=50`), match refresh, cleanup. No daemon required.

## Deployment workflow (steady state)

```
developer machine / CI
  ├─ edit code
  ├─ cd frontend && npm ci && npm run build
  ├─ copy frontend/dist → backend/public/app
  ├─ git commit & push main
  ▼
GitHub main
  ▼
Hostinger Git auto-deploy → pulls into deployment directory
  ▼
post-deploy (SSH):
  cd backend
  composer install --no-dev (if composer.lock changed)
  php artisan migrate --force
  php artisan config:cache route:cache view:cache
  chmod -R 775 storage bootstrap/cache
```

## Security checklist for deploy

- [ ] `.htaccess` in place denying access to backend/, frontend/, vendor/, .env, storage/, etc.
- [ ] `.env` present on server, not in git, permissions 640/644 owner-only
- [ ] `storage/` writable by PHP user (775), `bootstrap/cache` writable
- [ ] Resumes stored in `storage/app/private` — never under `public/`
- [ ] `APP_DEBUG=false` in production `.env`
- [ ] Main site `public_html` untouched — verify after first deploy

**Note**: The fallback deployment pattern (Git to `public_html`) is mitigated but not
production-standard. For client domain deployments, recommend the standard
pattern: deploy outside `public_html`, point document root to Laravel's `public/`.

## Open items (waiting on user)

1. SSH credentials (hPanel → Advanced → SSH Access) for post-deploy composer.
2. MySQL DB name/user created in hPanel for `.env`.
3. Confirm whether hPanel allows changing subdomain document root to implement preferred structure.
