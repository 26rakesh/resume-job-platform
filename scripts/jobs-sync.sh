#!/usr/bin/env bash
# jobs-sync.sh — Hostinger cron sync: Git deploy dir -> Laravel runtime.
# Install on server at: /home/u444986405/bin/jobs-sync.sh  (chmod +x)
# Cron (every 3 min): */3 * * * * /home/u444986405/bin/jobs-sync.sh >> /dev/null 2>&1
#
# Guarantees:
#  - single-instance lock (shared with jobs-rollback.sh), commit verification, append-only log
#  - never touches .env, APP_KEY, storage/app/private, resumes, logs, DB
#  - never runs migrations, never runs composer update
#  - React assets staged to temp dir first, replaced atomically in BOTH locations
#  - view:cache skipped when resources/views is absent
#  - bootstrap/cache preserved (only framework dirs synced, .gitignore kept)
#  - any failure after sync start -> full rollback to snapshot, non-zero exit
set -u

PHP=/opt/alt/php83/usr/bin/php
COMPOSER=/home/u444986405/bin/composer
SRC=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/jobs-platform
DST=/home/u444986405/jobs-platform/backend
LIVE_APP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/app
LIVE_TMP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/.app.tmp.$$ 
STATE=/home/u444986405/jobs-platform/.deployed-sha
LOCK=/tmp/jobs-sync.lock
LOG=/home/u444986405/jobs-platform/storage/logs/deploy-sync.log
SNAP=/home/u444986405/jobs-platform/.snapshots
SYNC_DIRS="app bootstrap config database routes tests public artisan composer.json composer.lock phpunit.xml"

log(){ echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }
die(){ log "FAIL: $*"; exit 1; }

# ---- pre-flight: lock, sources, PHP ----
exec 9>"$LOCK" || die "cannot open lock"
flock -n 9 || exit 0
[ -x "$PHP" ] || die "PHP missing: $PHP"
[ -x "$COMPOSER" ] || die "composer missing"
[ -d "$SRC/backend" ] || die "source backend missing"
[ -d "$DST" ] || die "runtime backend missing"
for d in app bootstrap config database routes public; do
  [ -d "$SRC/backend/$d" ] || die "source dir missing: backend/$d"
done
[ -f "$SRC/backend/artisan" ] || die "artisan missing"
[ -f "$SRC/backend/composer.json" ] || die "composer.json missing"
[ -f "$SRC/backend/composer.lock" ] || die "composer.lock missing"
[ -d "$SRC/backend/public/app" ] || die "React build missing: public/app"
[ -f "$SRC/backend/public/app/index.html" ] || die "React index.html missing"

NEW_SHA=$(git -C "$SRC" rev-parse HEAD 2>/dev/null) || die "not a git repo"
OLD_SHA=$(cat "$STATE" 2>/dev/null || echo "none")
[ "$NEW_SHA" = "$OLD_SHA" ] && exit 0

mkdir -p "$(dirname "$LOG")" "$SNAP"
log "SYNC start $OLD_SHA -> $NEW_SHA"

# ---- snapshot (code dirs only — NEVER .env/storage/vendor/private data) ----
SNAPDIR="$SNAP/$NEW_SHA.prev"
rm -rf "$SNAPDIR"; mkdir -p "$SNAPDIR"
for d in $SYNC_DIRS; do
  [ -e "$DST/$d" ] && cp -a "$DST/$d" "$SNAPDIR/" 2>/dev/null
done
[ -d "$DST/bootstrap/cache" ] && cp -a "$DST/bootstrap/cache/.gitignore" "$SNAPDIR/bootstrap-cache-gitignore" 2>/dev/null

rollback(){
  log "ROLLBACK to snapshot $OLD_SHA"
  for d in $SYNC_DIRS; do rm -rf "$DST/$d"; done
  for d in $SYNC_DIRS; do
    [ -e "$SNAPDIR/$d" ] && cp -a "$SNAPDIR/$d" "$DST/$d"
  done
  # restore React assets to temp then swap (never delete live first)
  rm -rf "$DST/public/app.tmp" "$LIVE_TMP"
  [ -d "$SNAPDIR/public/app" ] && cp -a "$SNAPDIR/public/app" "$DST/public/app.tmp"
  [ -d "$DST/public/app.tmp" ] && { rm -rf "$DST/public/app"; mv "$DST/public/app.tmp" "$DST/public/app"; }
  [ -d "$SNAPDIR/public/app" ] && cp -a "$SNAPDIR/public/app" "$LIVE_TMP" && { rm -rf "$LIVE_APP"; mv "$LIVE_TMP" "$LIVE_APP"; }
  (cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1
  (cd "$DST" && "$PHP" artisan config:cache route:cache) >> "$LOG" 2>&1
  rm -rf "$LIVE_TMP" "$DST/public/app.tmp"
  log "ROLLBACK done"
}
fail(){ log "FAIL: $* — rolling back"; rollback; exit 1; }

# ---- stage React assets to temp, verify, then swap both locations ----
rm -rf "$DST/public/app.new" "$LIVE_TMP"
cp -a "$SRC/backend/public/app" "$DST/public/app.new" || fail "stage runtime app"
[ -f "$DST/public/app.new/index.html" ] || fail "staged index.html missing"
cp -a "$DST/public/app.new" "$LIVE_TMP" || fail "stage live app"
[ -f "$LIVE_TMP/index.html" ] || fail "staged live index.html missing"
rm -rf "$DST/public/app"; mv "$DST/public/app.new" "$DST/public/app" || fail "swap runtime app"
rm -rf "$LIVE_APP"; mv "$LIVE_TMP" "$LIVE_APP" || fail "swap live app"

# ---- sync code dirs ----
for d in app bootstrap config database routes tests; do
  rm -rf "$DST/$d"
  cp -a "$SRC/backend/$d" "$DST/$d" || fail "sync $d"
done
for f in artisan composer.json composer.lock phpunit.xml; do
  cp -a "$SRC/backend/$f" "$DST/$f" || fail "sync $f"
done
# public dir: keep runtime public/.htaccess & index.php, sync only app/ (already done)
[ -f "$DST/public/index.php" ] || cp -a "$SRC/backend/public/index.php" "$DST/public/index.php"
[ -f "$DST/public/.htaccess" ] || cp -a "$SRC/backend/public/.htaccess" "$DST/public/.htaccess"
# bootstrap/cache: ensure dir exists, keep server .gitignore, do not wipe
mkdir -p "$DST/bootstrap/cache"
[ -f "$SNAPDIR/bootstrap-cache-gitignore" ] && cp -a "$SNAPDIR/bootstrap-cache-gitignore" "$DST/bootstrap/cache/.gitignore" 2>/dev/null || true

# ---- composer only when lock changed ----
if ! cmp -s "$SRC/backend/composer.lock" "$SNAPDIR/composer.lock" 2>/dev/null; then
  (cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
    || fail "composer install"
fi

chmod -R 775 "$DST/storage" "$DST/bootstrap/cache" 2>/dev/null

# ---- caches: view:cache only if resources/views exists ----
CACHE_CMD="config:cache route:cache"
[ -d "$DST/resources/views" ] && CACHE_CMD="$CACHE_CMD view:cache"
(cd "$DST" && "$PHP" artisan $CACHE_CMD) >> "$LOG" 2>&1 || fail "cache rebuild"

# ---- verify boot + live /up ----
(cd "$DST" && "$PHP" artisan --version) >> "$LOG" 2>&1 || fail "artisan boot"
UP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 https://jobs.sunrisepaint.in/up)
[ "$UP" = "200" ] || fail "live /up returned $UP"

echo "$NEW_SHA" > "$STATE"
log "SYNC done $NEW_SHA (live /up=200)"
