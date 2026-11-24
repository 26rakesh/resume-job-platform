#!/usr/bin/env bash
# jobs-rollback.sh <sha> — restore runtime snapshot taken by jobs-sync.sh
# Install: /home/u444986405/bin/jobs-rollback.sh ; usage: jobs-rollback.sh <deployed-sha>
set -u
PHP=/opt/alt/php83/usr/bin/php
COMPOSER=/home/u444986405/bin/composer
DST=/home/u444986405/jobs-platform/backend
LIVE_APP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/app
LIVE_TMP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/.app.tmp.rb$$
SNAP=/home/u444986405/jobs-platform/.snapshots
LOCK=/tmp/jobs-sync.lock
LOG=/home/u444986405/jobs-platform/storage/logs/deploy-sync.log
SHA="${1:?usage: jobs-rollback.sh <deployed-sha>}"
SNAPDIR="$SNAP/$SHA.prev"

exec 9>"$LOCK" || { echo "cannot open lock"; exit 1; }
flock -n 9 || { echo "another deploy/rollback running"; exit 1; }
[ -d "$SNAPDIR" ] || { echo "no snapshot for $SHA"; ls "$SNAP" 2>/dev/null; exit 1; }
log(){ echo "$(date -u +%FT%TZ) ROLLBACK $SHA: $*" >> "$LOG"; }

# validate snapshot completeness before touching runtime
for d in app bootstrap config database routes public; do
  [ -d "$SNAPDIR/$d" ] || { log "FAIL: snapshot incomplete (missing $d)"; exit 1; }
done
[ -d "$SNAPDIR/public/app" ] && [ -f "$SNAPDIR/public/app/index.html" ] || { log "FAIL: snapshot app build missing"; exit 1; }

# remove partially-synced dirs, restore snapshot
for d in app bootstrap config database routes tests public; do
  rm -rf "$DST/$d"
done
for d in app bootstrap config database routes tests public; do
  [ -e "$SNAPDIR/$d" ] && cp -a "$SNAPDIR/$d" "$DST/$d"
done
for f in artisan composer.json composer.lock phpunit.xml; do
  [ -f "$SNAPDIR/$f" ] && cp -a "$SNAPDIR/$f" "$DST/$f"
done
# restore public entry files if snapshot lacks them, keep runtime ones otherwise
[ -f "$DST/public/index.php" ] || cp -a "$SNAPDIR/public/index.php" "$DST/public/index.php" 2>/dev/null || true
[ -f "$DST/public/.htaccess" ] || cp -a "$SNAPDIR/public/.htaccess" "$DST/public/.htaccess" 2>/dev/null || true

# React assets: stage to temp, verify, swap — never delete live first
rm -rf "$DST/public/app.rbtmp" "$LIVE_TMP"
cp -a "$DST/public/app" "$DST/public/app.rbtmp" || { log "FAIL: stage runtime app"; exit 1; }
[ -f "$DST/public/app.rbtmp/index.html" ] || { log "FAIL: staged index missing"; exit 1; }
rm -rf "$DST/public/app"; mv "$DST/public/app.rbtmp" "$DST/public/app"
cp -a "$DST/public/app" "$LIVE_TMP" && [ -f "$LIVE_TMP/index.html" ] || { log "FAIL: stage live app"; exit 1; }
rm -rf "$LIVE_APP"; mv "$LIVE_TMP" "$LIVE_APP"

chmod -R 775 "$DST/storage" "$DST/bootstrap/cache" 2>/dev/null

(cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
  || { log "FAIL: composer install"; exit 1; }

CACHE_CMD="config:cache route:cache"
[ -d "$DST/resources/views" ] && CACHE_CMD="$CACHE_CMD view:cache"
(cd "$DST" && "$PHP" artisan $CACHE_CMD) >> "$LOG" 2>&1 || { log "FAIL: cache rebuild"; exit 1; }

(cd "$DST" && "$PHP" artisan --version) >> "$LOG" 2>&1 || { log "FAIL: artisan boot"; exit 1; }
UP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 https://jobs.sunrisepaint.in/up)
[ "$UP" = "200" ] || { log "FAIL: live /up=$UP"; exit 1; }

echo "$SHA" > /home/u444986405/jobs-platform/.deployed-sha
log "ROLLBACK success to $SHA (live /up=200)"
echo "rolled back to $SHA"
