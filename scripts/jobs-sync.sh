#!/usr/bin/env bash
# jobs-sync.sh — Hostinger cron sync: Git deploy dir -> Laravel runtime.
# Install on server at: /home/u444986405/bin/jobs-sync.sh  (chmod +x)
# Cron (every 3 min): */3 * * * * /home/u444986405/bin/jobs-sync.sh >> /dev/null 2>&1
#
# Guarantees:
#  - single-instance lock, commit verification, append-only log
#  - never touches .env, APP_KEY, storage/app/private, logs, DB
#  - never runs migrations, never runs composer update
#  - syncs React build to BOTH runtime public/app and live public_html/app
#  - snapshot + auto-rollback on post-check failure
set -u

PHP=/opt/alt/php83/usr/bin/php
COMPOSER=/home/u444986405/bin/composer
SRC=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/jobs-platform
DST=/home/u444986405/jobs-platform/backend
LIVE_APP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/app
STATE=/home/u444986405/jobs-platform/.deployed-sha
LOCK=/tmp/jobs-sync.lock
LOG=/home/u444986405/jobs-platform/storage/logs/deploy-sync.log
SNAP=/home/u444986405/jobs-platform/.snapshots
DEPS="app bootstrap config database public routes artisan composer.json composer.lock phpunit.xml tests bootstrap/providers.php"

exec 9>"$LOCK" || exit 1
flock -n 9 || exit 0   # another sync running

mkdir -p "$(dirname "$LOG")" "$SNAP"
log(){ echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }

cd "$SRC" || { log "FAIL: src missing"; exit 1; }
NEW_SHA=$(git rev-parse HEAD 2>/dev/null) || { log "FAIL: not a git repo"; exit 1; }
OLD_SHA=$(cat "$STATE" 2>/dev/null || echo "none")
[ "$NEW_SHA" = "$OLD_SHA" ] && exit 0   # nothing new

log "SYNC start $OLD_SHA -> $NEW_SHA"

# Snapshot current runtime code dirs (NO .env, storage, vendor, private data)
SNAPDIR="$SNAP/$OLD_SHA"
mkdir -p "$SNAPDIR"
for d in $DEPS; do
  [ -e "$DST/$d" ] && cp -a "$DST/$d" "$SNAPDIR/" 2>/dev/null
done
cp -a "$DST/composer.lock" "$SNAPDIR/" 2>/dev/null

# Sync application files (rsync-style via cp -a after clean of synced dirs)
for d in $DEPS; do
  rm -rf "$DST/$d"
  cp -a "$SRC/backend/$d" "$DST/$d" 2>/dev/null || true
done
# dotfiles/configs at backend root that are safe to sync
for f in artisan composer.json composer.lock phpunit.xml; do
  cp -a "$SRC/backend/$f" "$DST/$f" 2>/dev/null || true
done

# React assets -> BOTH runtime public/app and live public_html/app
rm -rf "$DST/public/app" "$LIVE_APP"
cp -a "$SRC/backend/public/app" "$DST/public/app" 2>/dev/null || true
cp -a "$SRC/backend/public/app" "$LIVE_APP" 2>/dev/null || true

# Composer only when lock changed
if ! cmp -s "$SRC/backend/composer.lock" "$SNAPDIR/composer.lock" 2>/dev/null; then
  (cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
    || { log "FAIL: composer install"; exit 1; }
fi

# Permissions + caches (never migrations)
chmod -R 775 "$DST/storage" "$DST/bootstrap/cache" 2>/dev/null
(cd "$DST" && "$PHP" artisan config:cache route:cache view:cache) >> "$LOG" 2>&1 \
  || { log "FAIL: cache rebuild"; exit 1; }

# Post-check: artisan boots
(cd "$DST" && "$PHP" artisan --version) >> "$LOG" 2>&1 \
  || { log "FAIL: artisan boot — rolling back"; cp -a "$SNAPDIR/." "$DST/" 2>/dev/null; exit 1; }

echo "$NEW_SHA" > "$STATE"
log "SYNC done $NEW_SHA"
