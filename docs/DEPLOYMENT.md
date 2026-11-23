# Deployment Plan — jobs.sunrisepaint.in (Hostinger Business)

Status: **PLANNED — nothing deployed, nothing triggered.**
Source of truth: GitHub `main` branch of `26rakesh/resume-job-platform`.

## Confirmed constraints

- Hostinger Git auto-deploy: **enabled**, currently targeting `public_html` of jobs.sunrisepaint.in.
- **Do NOT assume** Hostinger Git runs `composer install`.
- **Do NOT assume** Hostinger Git runs `npm`/`vite build`.
- PHP 8.3 on server; extensions per compatibility assessment.
- Main Sunrise Paint website is at a separate `public_html` — jobs site is isolated.

## Deployment approach (client-approved)

Hostinger Git deploys directly to `public_html` of jobs.sunrisepaint.in. This is
**not standard Laravel deployment** and has security implications, mitigated
by `.htaccess` rules that deny web access to sensitive directories.

### Target layout on server

```
/home/<user>/domains/jobs.sunrisepaint.in/
└── public_html/                  # Hostinger Git deployment directory & web root
    ├── .htaccess                 # 🔒 denies access to app/, vendor/, .env, storage/
    ├── app/ bootstrap/ config/ database/ routes/   # protected by .htaccess
    ├── vendor/                   # protected by .htaccess
    ├── storage/                  # protected by .htaccess
    ├── .env                      # protected by .htaccess
    ├── index.php                 # Laravel entrypoint
    └── app/                      # React build output (vite build)
```

**Security mitigation**: Top-level `.htaccess` denies web access to:
- `.env` and `.env.*`
- `app/`, `bootstrap/`, `config/`, `database/`, `routes/`, `vendor/`
- `storage/` (except framework cache/view via Laravel's symlink)
- `artisan`, `composer.json`, `composer.lock`, `package.json`, etc.

This is a partial mitigation — for production deployments to client domains,
recommend moving deployment outside `public_html` with proper document root
pointing to Laravel's `public/` folder.

## Reproducible build process

All builds happen **locally (or CI) before push** — the server never builds.

### Step 1 — Frontend (React + Vite → static)

```
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
  ```
  ssh user@jobs.sunrisepaint.in
  cd ~/domains/jobs.sunrisepaint.in/public_html
  git pull origin main            # Hostinger Git may already do this
  composer install --no-dev --optimize-autoloader
  php artisan migrate --force
  php artisan config:cache && php artisan route:cache && php artisan view:cache
  php artisan storage:link        # if public disk used; resumes use private disk
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

- `.env` created **manually on the server once** (copy from `.env.example`).
- Contains: `APP_KEY` (`php artisan key:generate` on server), DB creds,
  `GEMINI_API_KEY`, `QUEUE_CONNECTION=database`, `CACHE_STORE=file`/`database`.
- `.env` is gitignored; it lives at `jobs-app/.env`, outside docroot.

### Step 5 — Cron (scheduled processing)

One hPanel cron entry (every 15 min, or the minimum allowed):

```
*/15 * * * * cd ~/domains/jobs.sunrisepaint.in/public_html && php artisan schedule:run >> /dev/null 2>&1
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
Hostinger Git auto-deploy → pulls into ~/domains/jobs.sunrisepaint.in/public_html
  ▼
post-deploy (SSH):
  composer install --no-dev (if composer.lock changed)
  php artisan migrate --force
  php artisan config:cache route:cache view:cache
  chmod -R 775 storage bootstrap/cache
```

## Security checklist for deploy

- [ ] `.htaccess` in place denying access to app/, vendor/, .env, storage/, etc.
- [ ] `.env` present on server, not in git, permissions 640/644 owner-only
- [ ] `storage/` writable by PHP user (775), `bootstrap/cache` writable
- [ ] Resumes stored in `storage/app/private` — never under `public/`
- [ ] `APP_DEBUG=false` in production `.env`
- [ ] Main site `public_html` untouched — verify after first deploy

**Note**: This deployment pattern (Git to `public_html`) is mitigated but not
production-standard. For client domain deployments, recommend the standard
pattern: deploy outside `public_html`, point document root to Laravel's `public/`.

## Open items (waiting on user)

1. SSH credentials (hPanel → Advanced → SSH Access) for post-deploy composer.
2. MySQL DB name/user created in hPanel for `.env`.
