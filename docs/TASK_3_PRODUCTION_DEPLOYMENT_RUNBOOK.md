# Task 3 — Production Deployment Runbook (Hostinger)

**Target**: https://jobs.sunrisepaint.in | Hostinger Business | PHP 8.3.37 | Laravel 13.43
**App root**: `/home/u444986405/jobs-platform/backend`
**Docroot (fixed by Hostinger)**: `/home/u444986405/domains/jobs.sunrisepaint.in/public_html`
**Status**: PREPARED — nothing executed against production.

Because Hostinger won't change the subdomain docroot, `public_html` must serve
Laravel's `public/` contents via **symlinks** (Hostinger supports them).

```
/home/u444986405/
├── jobs-platform/                        # git clone of main
│   └── backend/                          # Laravel root — NEVER web-accessible directly
│       ├── .env  vendor/  storage/  app/ bootstrap/ config/ database/ routes/ artisan
│       └── public/                       # real Laravel public dir
│           ├── index.php  .htaccess
│           └── app/                      # React build
└── domains/jobs.sunrisepaint.in/public_html/
    ├── index.php    -> ../jobs-platform/backend/public/index.php   (symlink)
    ├── .htaccess    -> ../jobs-platform/backend/public/.htaccess   (symlink)
    ├── app          -> ../jobs-platform/backend/public/app         (symlink)
    └── <old-site-backup>/               # preserved existing deployment
```

Only symlinks for `index.php`, `.htaccess`, `app/` are created inside
`public_html`; nothing else from `backend/` is reachable because Apache only
executes what the docroot exposes and Laravel's own `.htaccess` routes to
`index.php`. `.env`, `vendor`, `storage` live outside `public_html` entirely.

> ⚠️ Symlinks only work if Apache has `FollowSymLinks`/`SymLinksIfOwnerMatch`
> enabled and `mod_rewrite` active — verify BEFORE touching public_html (§3).

---

## Phase 0 — READ-ONLY CHECKS (safe anytime, no changes)

```bash
ssh u444986405@<host>

# environment
php -v                                   # expect 8.3.x
/home/u444986405/bin/composer --version  # expect 2.x
which composer; composer --version      # confirm PATH composer uses PHP 8.3

# current state
test -d ~/jobs-platform && echo "EXISTS" || echo "jobs-platform absent — good"
ls -la ~/domains/jobs.sunrisepaint.in/public_html/   # what's deployed NOW
readlink -f ~/domains/jobs.sunrisepaint.in/public_html  # confirm real path

# Apache symlink capability (CRITICAL — do not skip)
php -r 'echo "symlink test: "; $t="/tmp/sl_".uniqid(); symlink("/etc/hostname",$t); echo is_link($t)?"PHP symlink() OK":"PHP symlink() FAIL"; @unlink($t); echo PHP_EOL;'
grep -ri "FollowSymLinks\|SymLinksIfOwnerMatch" /etc/apache2/ 2>/dev/null | head -5 || echo "cannot read apache conf — ask Hostinger support"

# DB creds exist? (do NOT print passwords)
ls ~/.my.cnf 2>/dev/null; echo "check hPanel for DB name/user"
```

Expected: PHP 8.3.x, composer 2.x, `jobs-platform absent`, listing of current
public_html contents (back this up mentally — it is the live site right now).

## Phase 1 — SAFE PREPARATION (no production modification)

```bash
# clone repo OUTSIDE public_html
cd ~
git clone https://github.com/26rakesh/resume-job-platform.git jobs-platform
cd jobs-platform && git checkout main && git log -1 --oneline   # expect 1514ae2 merge or later

cd backend
cp .env.production.example .env      # fill placeholders LATER (Phase 3)
# DO NOT run key:generate/migrate yet
ls -la storage bootstrap/cache       # dirs exist (committed .gitignore placeholders)
```

## Phase 2 — PRODUCTION-MODIFYING (requires explicit approval)

```bash
cd ~/jobs-platform/backend

# 2a. dependencies (install only — NEVER composer update)
/home/u444986405/bin/composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction
chmod -R 775 storage bootstrap/cache

# 2b. preserve existing public_html BEFORE replacing
cd ~/domains/jobs.sunrisepaint.in
mv public_html public_html.pre-jobs-$(date +%F)     # PRESERVE — do not delete
mkdir public_html
cd public_html

# 2c. create symlinks into Laravel public
ln -s ~/jobs-platform/backend/public/index.php  index.php
ln -s ~/jobs-platform/backend/public/.htaccess  .htaccess
ln -s ~/jobs-platform/backend/public/app        app
ls -la   # verify all three links resolve (readlink -f each)
```

## Phase 3 — REQUIRES EXPLICIT HUMAN APPROVAL (secrets + DB + admin)

```bash
cd ~/jobs-platform/backend
# edit .env: APP_KEY via artisan, DB creds from hPanel, GEMINI_API_KEY, APP_URL
php artisan key:generate --force
php artisan config:cache route:cache view:cache

# DB backup FIRST (even though fresh)
mysqldump -u <db_user> -p <db_name> > ~/backups/jobs_pre_$(date +%F).sql

php artisan migrate --force          # creates tables only
php artisan admin:create             # interactive admin setup
php artisan queue:restart
```

hPanel cron: `*/15 * * * * cd /home/u444986405/jobs-platform/backend && php artisan schedule:run >> /dev/null 2>&1`

## Phase 4 — VERIFICATION (read-only)

```bash
# on server
curl -sk https://jobs.sunrisepaint.in/up                     # expect 200 "OK"
curl -sk -o /dev/null -w "%{http_code}\n" https://jobs.sunrisepaint.in/           # 200 SPA
curl -sk -o /dev/null -w "%{http_code}\n" https://jobs.sunrisepaint.in/candidates # 200 (SPA deep link)
curl -sk -o /dev/null -w "%{http_code}\n" https://jobs.sunrisepaint.in/api/user   # 401 unauth
curl -sk -o /dev/null -w "%{http_code}\n" https://jobs.sunrisepaint.in/.env       # 403/404
curl -sk -o /dev/null -w "%{http_code}\n" https://jobs.sunrisepaint.in/../.env    # 400/403
curl -skI https://jobs.sunrisepaint.in/ | grep -i "set-cookie"   # XSRF-TOKEN cookie

# in browser DevTools: session cookie HttpOnly+Secure; login/logout; register → 403
```

## ROLLBACK

```bash
# instant: restore previous docroot
cd ~/domains/jobs.sunrisepaint.in
rm public_html/index.php public_html/.htaccess && rm public_html/app   # remove symlinks only
mv public_html.pre-jobs-<date> public_html                            # restore old site
# app remains at ~/jobs-platform (inert); DB untouched unless migrate ran —
# if it did: mysql -u <db_user> -p <db_name> < ~/backups/jobs_pre_<date>.sql
```

## BLOCKERS / OPEN ITEMS

1. **Verify Apache follows symlinks** (Phase 0 grep / Hostinger support) — if `FollowSymLinks` is off, fallback: copy `public/*` into `public_html` instead of symlinking (still keeps `.env`/`vendor`/`storage` outside). Copy variant documented; symlinks preferred so deploys stay git-driven.
2. Confirm current `public_html` content before `mv` (Phase 0 `ls`).
3. hPanel DB credentials + `GEMINI_API_KEY` via secure channel.
4. Merge state: PR #1 already merged — deploy from `main` @ `1514ae2`+.
