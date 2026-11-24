# Hostinger Deployment — Final Architecture (main only)

## Layout
- Git auto-deploy (branch `main`): `/home/u444986405/domains/jobs.sunrisepaint.in/public_html/jobs-platform/` — **fully denied to browsers** by repo-root `.htaccess`.
- Laravel runtime (private): `/home/u444986405/jobs-platform/backend/`
- Live docroot: `/home/u444986405/domains/jobs.sunrisepaint.in/public_html/` — existing `index.php`/`.htaccess` preserved; React assets at `public_html/app/`.

## Sync mechanism (cron, no git hooks)
- Script: `/home/u444986405/bin/jobs-sync.sh` (source: `scripts/jobs-sync.sh`)
- Rollback: `/home/u444986405/bin/jobs-rollback.sh <sha>` (source: `scripts/jobs-rollback.sh`)
- PHP: `/opt/alt/php83/usr/bin/php` | Composer: `/home/u444986405/bin/composer`

Cron (hPanel → Cron Jobs):
```
*/3 * * * * /home/u444986405/bin/jobs-sync.sh >> /dev/null 2>&1
```

## Script guarantees
- `flock` single-instance; skips when HEAD == `.deployed-sha`
- Logs to `~/jobs-platform/storage/logs/deploy-sync.log`
- Snapshots synced dirs only (never `.env`, `storage`, `vendor`, resumes, logs)
- Syncs `backend/` app files → runtime; React `public/app` → **both** `backend/public/app` and live `public_html/app`
- `composer install` only when `composer.lock` changed; never `composer update`
- Rebuilds caches; **never runs migrations**; auto-restores snapshot on boot failure

## One-time server setup (manual, after approval)
```bash
mkdir -p ~/bin
cp ~/domains/jobs.sunrisepaint.in/public_html/jobs-platform/scripts/jobs-sync.sh ~/bin/jobs-sync.sh
cp ~/domains/jobs.sunrisepaint.in/public_html/jobs-platform/scripts/jobs-rollback.sh ~/bin/jobs-rollback.sh
chmod +x ~/bin/jobs-*.sh
# add cron entry above in hPanel
# first sync: run once manually, then verify https://jobs.sunrisepaint.in/up
```

## Branch policy
- Only `main` exists. `feature/mvp-foundation` deleted after merge verification (`59cdabc` is ancestor of `0308851`).
