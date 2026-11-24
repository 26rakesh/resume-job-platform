# Task 3 — Pre-Deployment Audit (post-merge `main`)

**Audited commit**: `origin/main` @ `1514ae2` (merge of PR #1)
**Date**: 2026-11-23 | **Auditor**: Devin | **Production touched**: NO

## 1. Verified on `main`

| Item | Result |
|---|---|
| `backend/composer.lock` | ✅ committed (116 pkgs; laravel/framework v13.43.0, tinker v3.2.0, phpunit 12.5.45, sanctum v4.5.0) |
| `backend/public/index.php` | ✅ standard Laravel front controller |
| `backend/public/.htaccess` | ✅ mod_rewrite → `index.php`, auth-header passthrough |
| SPA fallback `routes/web.php` | ✅ serves `public/app/index.html` for non-`/api` paths; 404s cleanly if build missing |
| React build `backend/public/app/` | ✅ `index.html` + hashed assets committed; Vite `base: '/app/'` |
| `.env` exclusion | ✅ `backend/.env` gitignored, NOT in tree; `.env.production` also ignored |
| Sanctum config | ✅ `config/sanctum.php` stateful domains env-driven; `statefulApi()` + `auth:sanctum` in `bootstrap/app.php` |
| Login throttle | ✅ `throttle:5,1` on `/api/login` |
| Registration | ✅ route omitted when `APP_ENV=production`; controller 403 defense-in-depth; role forced `user` |
| Admin creation | ✅ `php artisan admin:create` (auto-discovered); `AdminMiddleware` on admin routes |
| CSRF | ✅ `/sanctum/csrf-cookie` + `VerifyCsrfToken` + `EncryptCookies`; frontend `initCsrf()` + `withCredentials` |
| Migrations (6) | ✅ create-only: users, candidates, resumes, queue_jobs, cache/cache_locks, job_listings. Only `dropIfExists` inside `down()` — normal rollback, no destructive `up()` ops |
| Storage dirs | ✅ `bootstrap/cache`, `storage/{app,framework/{cache,sessions,views},logs}` committed via `.gitignore` placeholders |
| Private resumes | ✅ `storage/app/private` path; outside any docroot in target layout |
| Error handling | ✅ `APP_DEBUG=false` required in prod `.env`; `LOG_LEVEL=error`, `LOG_STACK=daily` in `.env.production.example` |
| Tests | ✅ 7/7 AuthTest pass locally & in CI; CI green on `d8e73c5` (node24 actions) |

## 2. Issues / blockers found

1. **BLOCKER — docroot cannot change**: Hostinger won't let the subdomain docroot point to `backend/public`. Mitigation = symlink approach (see runbook §3). MUST be verified on server before committing to it — Apache `FollowSymLinks`/`SymLinksIfOwnerMatch` behavior on Hostinger is unverified.
2. **`public_html` currently hosts the Git deployment** — replacing its contents is destructive to whatever is there now. Runbook preserves it first (rename, not delete).
3. **No scheduler entries**: `routes/console.php` only has `inspire`. `schedule:run` cron is harmless but does nothing until queue/schedule commands are added. Not a blocker.
4. **`QUEUE_CONNECTION=database` + `CACHE_STORE=database`** in prod template → requires `queue_jobs`, `cache`, `cache_locks` migrations to run (covered by `migrate --force`).
5. **`SESSION_DOMAIN=.sunrisepaint.in`** in prod template — verify parent-domain cookie is desired; if the main site sets conflicting cookies, use `jobs.sunrisepaint.in` instead.
6. **Composer on server**: provided at `/home/u444986405/bin/composer` — confirm it runs under the site's PHP 8.3 CLI (`composer --version` may use a different PHP; check `php -v` on SSH).
7. **No health/uptime route beyond `/up`** — Laravel 13 includes `up`; verify it responds post-deploy.
8. Resume download/upload authorization endpoints are not yet implemented — resumes are stored privately but there is no app route serving them yet. Out of scope for MVP deploy, noted for backlog.

## 3. Go / no-go summary

Code is deployable. The ONLY hard blocker is confirming the symlink serving strategy works on Hostinger Apache (runbook §3 verification, read-only). Everything else is procedure.
