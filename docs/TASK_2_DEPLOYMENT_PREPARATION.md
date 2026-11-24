# Task 2 — Production Deployment Preparation (Hostinger)

**Status**: PREPARED — nothing deployed, nothing merged, no production migrations run.
**Target**: https://jobs.sunrisepaint.in — Hostinger Business, PHP 8.3, MySQL.

## 1. Repository inspection (verified)

- Laravel 13.43 backend in `backend/` — `composer.lock` committed (116 packages).
- React/Vite/TS frontend; production build committed at `backend/public/app/` (`index.html` + hashed assets).
- SPA fallback `routes/web.php` serves `public/app/index.html` for all non-`/api` paths; `/sanctum/csrf-cookie` is a Sanctum web route.
- Auth: cookie-based Sanctum (`auth:sanctum` + stateful middleware), `throttle:5,1` login, `AdminMiddleware`, `php artisan admin:create`, registration disabled in production.
- Migrations: users, candidates, resumes, queue_jobs, cache/cache_locks, job_listings.
- Docs: `DEPLOYMENT.md`, `DEPLOYMENT_ARCHITECTURE.md`, `TASK_1G_COMPLETION_REPORT.md`.

## 2. Production build (reproducible)

Already verified in CI (run 45233210376) and locally:

```bash
cd frontend && npm ci && npx tsc --noEmit && npm run lint && npm run build
# copy frontend/dist -> backend/public/app   (committed; server never builds)
cd ../backend && composer install --no-dev --prefer-dist --optimize-autoloader
```

No `composer update` on server or CI. `composer.lock` is the source of truth.

## 3. Hostinger layout — REQUIRED

```
/home/<user>/
├── public_html/                     # Sunrise Paint main site — NEVER touched
└── jobs-platform/                   # git clone of repo (main branch)
    └── backend/                     # Laravel root — OUTSIDE docroot
        ├── .env                     # secrets — outside docroot
        ├── vendor/  storage/  app/  bootstrap/  config/  database/  routes/  artisan
        └── public/                  # ← subdomain docroot points HERE
            ├── index.php  .htaccess
            └── app/                 # React build (index.html + assets)
```

**hPanel requirement**: subdomain `jobs.sunrisepaint.in` document root =
`/home/<user>/jobs-platform/backend/public` (NOT `public_html`).
Git deploy dir = `/home/<user>/jobs-platform`, branch `main`.

**Evaluation**: Hostinger hPanel → Domains → subdomain settings allows a custom
document root on Business plans. MUST be confirmed in hPanel before deploy.
If it cannot be changed, the ONLY fallback is docroot=`public_html` with the whole
repo inside it protected by root `.htaccess` — this is NOT approved for production
(secrets one misconfiguration away from exposure). Do not deploy on the fallback.

## 4. Production environment

`backend/.env.production.example` created — safe placeholders only. Server `.env`
must set: `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://jobs.sunrisepaint.in`,
MySQL creds, `SESSION_SECURE_COOKIE=true`, `SESSION_DOMAIN=.sunrisepaint.in`,
`SANCTUM_STATEFUL_DOMAINS=jobs.sunrisepaint.in`, `LOG_LEVEL=error`, `LOG_STACK=daily`,
`QUEUE_CONNECTION=database`, `CACHE_STORE=database`, `FILESYSTEM_DISK=local`
(resumes → `storage/app/private`, never public).

## 5. SSH commands

### A. Preparation (read-only / safe to run anytime)
```bash
ssh <user>@<host>
# verify layout target exists and is empty
test ! -e ~/jobs-platform && echo "OK: jobs-platform does not exist yet"
df -h ~ | tail -1
php -v            # expect 8.3.x
composer --version || echo "composer missing — see DEPLOYMENT.md Path B"
```

### B. Deployment (MODIFIES production — run only after approval)
```bash
cd ~
git clone https://github.com/26rakesh/resume-job-platform.git jobs-platform
cd jobs-platform && git checkout main && git pull origin main

cd backend
cp .env.production.example .env        # then edit: fill ALL <placeholders>
php artisan key:generate --force

composer install --no-dev --prefer-dist --optimize-autoloader
chmod -R 775 storage bootstrap/cache
php artisan storage:link 2>/dev/null || true   # private disk needs no link
```

### C. Post-deploy (MODIFIES production DB — ONLY after explicit approval)
```bash
# 0. BACKUP FIRST (see §6)
cd ~/jobs-platform/backend
php artisan migrate --force              # creates tables only; no drops
php artisan admin:create                 # interactive: name/email/password/role=admin
php artisan config:cache && php artisan route:cache && php artisan view:cache
php artisan queue:restart
```

### D. Cron (hPanel → Cron Jobs)
```cron
*/15 * * * * cd /home/<user>/jobs-platform/backend && php artisan schedule:run >> /dev/null 2>&1
```

## 6. Database safety & backup

- No `migrate:fresh`, no drops, no truncates anywhere in runbook.
- Backup BEFORE first migrate (empty DB — still take one for procedure):
```bash
mysqldump -u <db_user> -p <db_name> > ~/backups/jobs_$(date +%F).sql
# restore: mysql -u <db_user> -p <db_name> < ~/backups/jobs_<date>.sql
```
- hPanel → Databases → phpMyAdmin export is the GUI fallback.

## 7. Rollback procedure

```bash
cd ~/jobs-platform
git checkout <previous-good-sha>        # or: git revert <bad-commit> && push
cd backend && composer install --no-dev --optimize-autoloader
php artisan config:cache route:cache view:cache
# DB rollback: restore ~/backups/jobs_<date>.sql via mysql import
# DNS/hPanel: repoint subdomain docroot back if layout was wrong
```
Main Sunrise Paint site is untouched by all of the above (separate `public_html`).

## 8. Outstanding hosting requirements

1. Confirm hPanel allows custom docroot for `jobs.sunrisepaint.in` → `backend/public`.
2. Confirm Hostinger Git deploy can target `~/jobs-platform` on `main`.
3. Provide DB name/user/password + `GEMINI_API_KEY` via secure channel (not chat).
4. SSH access confirmed previously; verify `composer` on server (or use Path B in DEPLOYMENT.md).
5. Approval gates: merge PR #1 → deploy → migrate → admin:create.

## 9. Pre-deploy verification checklist (run after deploy, before announce)

- [ ] `https://jobs.sunrisepaint.in/` loads SPA; refresh `/candidates`,`/jobs`,`/settings` → no 404
- [ ] `/api/user` unauthenticated → 401; login works; logout works
- [ ] Registration endpoint → 403 in production
- [ ] DevTools: session cookie HttpOnly+Secure+SameSite=Lax; XSRF cookie present
- [ ] `https://jobs.sunrisepaint.in/.env`, `/../backend/.env`, `/vendor/` → 403/404
- [ ] `storage/app/private` not web-reachable
- [ ] `APP_DEBUG=false` (no stack traces on forced error)
- [ ] Main Sunrise Paint site still works
