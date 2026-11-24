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
STATE=/home/u444986405/jobs-platform/.deployed-sha
SHA="${1:?usage: jobs-rollback.sh <deployed-sha>}"
SNAPDIR="$SNAP/$SHA.prev"

exec 9>"$LOCK" || { echo "cannot open lock"; exit 1; }
flock -n 9 || { echo "another deploy/rollback running"; exit 1; }
[ -d "$SNAPDIR" ] || { echo "no snapshot for $SHA"; ls "$SNAP" 2>/dev/null; exit 1; }
log(){ echo "$(date -u +%FT%TZ) ROLLBACK $SHA: $*" >> "$LOG"; }
ok=1
chk(){ [ "$1" = "0" ] && { log "ROLLBACK FAIL: $2"; ok=0; } || true; }

# ---- validate snapshot completeness BEFORE replacing anything ----
for d in app config database routes public; do
  [ -d "$SNAPDIR/$d" ] || { log "FAIL: snapshot incomplete (missing $d)"; exit 1; }
done
[ -f "$SNAPDIR/composer.json" ] && [ -f "$SNAPDIR/composer.lock" ] || { log "FAIL: snapshot missing composer files"; exit 1; }
[ -d "$SNAPDIR/public-app" ] && [ -f "$SNAPDIR/public-app/index.html" ] || { log "FAIL: snapshot React build missing index.html"; exit 1; }
for f in artisan composer.json composer.lock phpunit.xml; do
  [ -f "$SNAPDIR/$f" ] || { log "FAIL: snapshot missing $f"; exit 1; }
done
log "ROLLBACK start — snapshot validated"

# ---- restore code dirs; preserve bootstrap/cache (sync only app.php+providers.php) ----
for d in app config database routes tests public; do
  rm -rf "$DST/$d"
  [ -e "$SNAPDIR/$d" ] && cp -a "$SNAPDIR/$d" "$DST/$d" || { log "ROLLBACK FAIL: restore $d"; ok=0; }
done
for f in app.php providers.php; do
  if [ -f "$SNAPDIR/bootstrap/$f" ]; then
    cp -a "$SNAPDIR/bootstrap/$f" "$DST/bootstrap/$f" && [ -f "$DST/bootstrap/$f" ] || { log "ROLLBACK FAIL: restore bootstrap/$f"; ok=0; }
  else
    log "ROLLBACK FAIL: snapshot missing bootstrap/$f"; ok=0
  fi
done
for f in artisan composer.json composer.lock phpunit.xml; do
  [ -f "$SNAPDIR/$f" ] && cp -a "$SNAPDIR/$f" "$DST/$f" || { log "ROLLBACK FAIL: restore $f"; ok=0; }
done

# ---- React assets: staged swap — never delete live first ----
rm -rf "$DST/public/app.rbtmp" "$LIVE_TMP"
if [ -d "$SNAPDIR/public-app" ]; then
  cp -a "$SNAPDIR/public-app" "$DST/public/app.rbtmp" \
    && [ -f "$DST/public/app.rbtmp/index.html" ] \
    && { rm -rf "$DST/public/app"; mv "$DST/public/app.rbtmp" "$DST/public/app"; } \
    || { log "ROLLBACK FAIL: stage runtime app"; ok=0; }
  cp -a "$SNAPDIR/public-app" "$LIVE_TMP" \
    && [ -f "$LIVE_TMP/index.html" ] \
    && { rm -rf "$LIVE_APP"; mv "$LIVE_TMP" "$LIVE_APP"; } \
    || { log "ROLLBACK FAIL: stage live app"; ok=0; }
fi

# ---- writable dirs only — never storage/app/private ----
mkdir -p "$DST/storage/framework/cache" "$DST/storage/framework/sessions" "$DST/storage/framework/views" "$DST/storage/logs" "$DST/bootstrap/cache" 2>/dev/null
chmod 775 "$DST/storage/framework/cache" "$DST/storage/framework/sessions" "$DST/storage/framework/views" "$DST/storage/logs" 2>/dev/null || true

# ---- composer (exact required form) ----
(cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
  || { log "ROLLBACK FAIL: composer install"; ok=0; }

CACHE_CMD="config:cache route:cache"
[ -d "$DST/resources/views" ] && CACHE_CMD="$CACHE_CMD view:cache"
(cd "$DST" && "$PHP" artisan $CACHE_CMD) >> "$LOG" 2>&1 || { log "ROLLBACK FAIL: cache rebuild"; ok=0; }

(cd "$DST" && "$PHP" artisan --version) >> "$LOG" 2>&1 || { log "ROLLBACK FAIL: artisan boot"; ok=0; }
UP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 https://jobs.sunrisepaint.in/up)
[ "$UP" = "200" ] || { log "ROLLBACK FAIL: live /up=$UP"; ok=0; }

rm -rf "$LIVE_TMP" "$DST/public/app.rbtmp"
if [ "$ok" = "1" ]; then
  echo "$SHA" > "$STATE"
  log "ROLLBACK done $SHA (live /up=200)"
  echo "rolled back to $SHA"
else
  log "ROLLBACK FAILED $SHA"
  echo "ROLLBACK FAILED — see $LOG" >&2
  exit 1
fi
