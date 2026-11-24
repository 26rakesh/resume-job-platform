#!/usr/bin/env bash
# jobs-sync.sh — Hostinger cron sync: Git deploy dir -> Laravel runtime.
# Install on server at: /home/u444986405/bin/jobs-sync.sh  (chmod +x)
# Cron (every 3 min): */3 * * * * /home/u444986405/bin/jobs-sync.sh >> /dev/null 2>&1
#
# Guarantees:
#  - single-instance lock (shared with jobs-rollback.sh), commit verification, append-only log
#  - never touches .env, APP_KEY, storage/app/private, resumes, logs, DB
#  - never runs migrations, never runs composer update
#  - NEVER chmod -R on storage (private resumes keep their permissions)
#  - bootstrap/cache preserved: only bootstrap/app.php + providers.php synced
#  - snapshot fully validated BEFORE runtime is modified
#  - React assets staged to temp, verified, then rename-swapped in BOTH locations
#    (old dir moved aside first; brief window documented — not a true atomic swap)
#  - view:cache skipped when resources/views is absent
#  - any failure after sync start -> full rollback; non-zero exit
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
SYNC_DIRS="app config database routes tests public"
BOOT_FILES="app.php providers.php"
TOP_FILES="artisan composer.json composer.lock phpunit.xml"

log(){ echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }
die(){ log "FAIL: $*"; exit 1; }

# Guarded rename-swap: $1=target dir, $2=staged dir (must contain index.html).
# - aborts if a stale .old exists (manual inspection required)
# - checks every mv; keeps .old unless replacement verified; deletes .old only on success
swap_dir(){
  local tgt="$1" staged="$2"
  if [ -e "$tgt.old" ]; then log "FAIL: stale $tgt.old exists — manual inspection required at $tgt.old"; return 1; fi
  if [ -d "$tgt" ]; then
    mv "$tgt" "$tgt.old" || { log "FAIL: mv $tgt -> $tgt.old failed"; return 1; }
    [ -d "$tgt.old" ] || { log "FAIL: $tgt.old missing after mv"; return 1; }
  fi
  mv "$staged" "$tgt" || { log "FAIL: mv $staged -> $tgt failed"; return 1; }
  [ -f "$tgt/index.html" ] || { log "FAIL: $tgt/index.html missing after swap"; return 1; }
  rm -rf "$tgt.old"
  return 0
}

# ---- pre-flight: lock, sources, PHP ----
exec 9>"$LOCK" || die "cannot open lock"
flock -n 9 || exit 0
[ -x "$PHP" ] || die "PHP missing: $PHP"
[ -x "$COMPOSER" ] || die "composer missing"
[ -d "$SRC/backend" ] || die "source backend missing"
[ -d "$DST" ] || die "runtime backend missing"
for d in app config database routes tests public bootstrap; do
  [ -d "$SRC/backend/$d" ] || die "source dir missing: backend/$d"
done
for f in $TOP_FILES; do
  [ -f "$SRC/backend/$f" ] || die "source file missing: backend/$f"
done
for f in $BOOT_FILES; do
  [ -f "$SRC/backend/bootstrap/$f" ] || die "source file missing: backend/bootstrap/$f"
done
[ -f "$SRC/backend/public/index.php" ] || die "public/index.php missing"
[ -f "$SRC/backend/public/.htaccess" ] || die "public/.htaccess missing"
[ -d "$SRC/backend/public/app" ] || die "React build missing: public/app"
[ -f "$SRC/backend/public/app/index.html" ] || die "React index.html missing"

NEW_SHA=$(git -C "$SRC" rev-parse HEAD 2>/dev/null) || die "not a git repo"
OLD_SHA=$(cat "$STATE" 2>/dev/null || echo "none")
[ "$NEW_SHA" = "$OLD_SHA" ] && exit 0

mkdir -p "$(dirname "$LOG")" "$SNAP"
log "SYNC start $OLD_SHA -> $NEW_SHA"

# ---- snapshot (code only — NEVER .env/storage/vendor/private data) ----
SNAPDIR="$SNAP/$NEW_SHA.prev"
rm -rf "$SNAPDIR"; mkdir -p "$SNAPDIR" || die "cannot create snapshot dir"
snap_fail=0
for d in $SYNC_DIRS; do
  if [ -e "$DST/$d" ]; then cp -a "$DST/$d" "$SNAPDIR/" || snap_fail=1; fi
done
for f in $BOOT_FILES; do
  if [ -f "$DST/bootstrap/$f" ]; then mkdir -p "$SNAPDIR/bootstrap" && cp -a "$DST/bootstrap/$f" "$SNAPDIR/bootstrap/" || snap_fail=1; fi
done
for f in $TOP_FILES; do
  [ -f "$DST/$f" ] && { cp -a "$DST/$f" "$SNAPDIR/" || snap_fail=1; }
done
if [ -d "$DST/public/app" ]; then
  mkdir -p "$SNAPDIR" && cp -a "$DST/public/app" "$SNAPDIR/public-app" || snap_fail=1
fi
[ "$snap_fail" = "0" ] || { log "FAIL: snapshot copy failed — aborting before changes"; rm -rf "$SNAPDIR"; exit 1; }
# validate snapshot BEFORE touching runtime
for d in $SYNC_DIRS; do
  [ -d "$SNAPDIR/$d" ] || { log "FAIL: snapshot incomplete (missing $d) — aborting before changes"; rm -rf "$SNAPDIR"; exit 1; }
done
for f in $BOOT_FILES; do
  [ -f "$SNAPDIR/bootstrap/$f" ] || { log "FAIL: snapshot missing bootstrap/$f — aborting"; rm -rf "$SNAPDIR"; exit 1; }
done
for f in $TOP_FILES; do
  [ -f "$SNAPDIR/$f" ] || { log "FAIL: snapshot missing $f — aborting"; rm -rf "$SNAPDIR"; exit 1; }
done
[ -d "$SNAPDIR/public-app" ] && [ -f "$SNAPDIR/public-app/index.html" ] || { log "FAIL: snapshot React build missing index.html — aborting"; rm -rf "$SNAPDIR"; exit 1; }

rollback(){
  log "ROLLBACK start to snapshot $OLD_SHA"
  local ok=1
  for d in $SYNC_DIRS; do
    rm -rf "$DST/$d"
    if [ -e "$SNAPDIR/$d" ]; then
      cp -a "$SNAPDIR/$d" "$DST/$d" && [ -e "$DST/$d" ] || { log "ROLLBACK FAIL: restore $d"; ok=0; }
    else
      log "ROLLBACK FAIL: snapshot missing $d"; ok=0
    fi
  done
  for f in $BOOT_FILES; do
    if [ -f "$SNAPDIR/bootstrap/$f" ]; then
      cp -a "$SNAPDIR/bootstrap/$f" "$DST/bootstrap/$f" && [ -f "$DST/bootstrap/$f" ] || { log "ROLLBACK FAIL: restore bootstrap/$f"; ok=0; }
    else
      log "ROLLBACK FAIL: snapshot missing bootstrap/$f"; ok=0
    fi
  done
  for f in $TOP_FILES; do
    if [ -f "$SNAPDIR/$f" ]; then
      cp -a "$SNAPDIR/$f" "$DST/$f" && [ -f "$DST/$f" ] || { log "ROLLBACK FAIL: restore $f"; ok=0; }
    else
      log "ROLLBACK FAIL: snapshot missing $f"; ok=0
    fi
  done
  # React: stage to temp, verify, guarded rename-swap per dir; .old kept on any failure
  rm -rf "$DST/public/app.rbtmp" "$LIVE_TMP"
  if [ -d "$SNAPDIR/public-app" ]; then
    if cp -a "$SNAPDIR/public-app" "$DST/public/app.rbtmp" && [ -f "$DST/public/app.rbtmp/index.html" ]; then
      swap_dir "$DST/public/app" "$DST/public/app.rbtmp" || { log "ROLLBACK FAIL: restore runtime app"; ok=0; }
    else
      log "ROLLBACK FAIL: stage runtime app"; ok=0
    fi
    if cp -a "$SNAPDIR/public-app" "$LIVE_TMP" && [ -f "$LIVE_TMP/index.html" ]; then
      swap_dir "$LIVE_APP" "$LIVE_TMP" || { log "ROLLBACK FAIL: restore live app"; ok=0; }
    else
      log "ROLLBACK FAIL: stage live app"; ok=0
    fi
    [ -f "$DST/public/app/index.html" ] || { log "ROLLBACK FAIL: restored runtime app missing index.html"; ok=0; }
    [ -f "$LIVE_APP/index.html" ] || { log "ROLLBACK FAIL: restored live app missing index.html"; ok=0; }
  else
    log "ROLLBACK FAIL: snapshot public-app missing"; ok=0
  fi
  (cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
    || { log "ROLLBACK FAIL: composer install"; ok=0; }
  CACHE_CMD="config:cache route:cache"
  [ -d "$DST/resources/views" ] && CACHE_CMD="$CACHE_CMD view:cache"
  (cd "$DST" && "$PHP" artisan $CACHE_CMD) >> "$LOG" 2>&1 || { log "ROLLBACK FAIL: cache rebuild"; ok=0; }
  (cd "$DST" && "$PHP" artisan --version) >> "$LOG" 2>&1 || { log "ROLLBACK FAIL: artisan boot"; ok=0; }
  UP=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 https://jobs.sunrisepaint.in/up)
  [ "$UP" = "200" ] || { log "ROLLBACK FAIL: live /up=$UP"; ok=0; }
  rm -rf "$LIVE_TMP" "$DST/public/app.rbtmp"
  if [ "$ok" = "1" ]; then log "ROLLBACK done $OLD_SHA (live /up=200)"; else log "ROLLBACK FAILED $OLD_SHA"; fi
  [ "$ok" = "1" ]
}
fail(){ log "FAIL: $* — rolling back"; rollback || true; exit 1; }

# ---- stage React assets to temp, verify, then swap both locations ----
rm -rf "$DST/public/app.new" "$LIVE_TMP"
cp -a "$SRC/backend/public/app" "$DST/public/app.new" || fail "stage runtime app"
[ -f "$DST/public/app.new/index.html" ] || fail "staged index.html missing"
cp -a "$DST/public/app.new" "$LIVE_TMP" || fail "stage live app"
[ -f "$LIVE_TMP/index.html" ] || fail "staged live index.html missing"
swap_dir "$DST/public/app" "$DST/public/app.new" || fail "swap runtime app"
swap_dir "$LIVE_APP" "$LIVE_TMP" || fail "swap live app"

# ---- sync code dirs (never bootstrap/cache, never storage) ----
for d in app config database routes tests; do
  rm -rf "$DST/$d"
  cp -a "$SRC/backend/$d" "$DST/$d" || fail "sync $d"
done
# bootstrap: only app.php + providers.php — cache dir preserved
for f in $BOOT_FILES; do
  cp -a "$SRC/backend/bootstrap/$f" "$DST/bootstrap/$f" || fail "sync bootstrap/$f"
done
for f in $TOP_FILES; do
  cp -a "$SRC/backend/$f" "$DST/$f" || fail "sync $f"
done
# public: entry files preserved from runtime if present, app already swapped
[ -f "$DST/public/index.php" ] || cp -a "$SRC/backend/public/index.php" "$DST/public/index.php"
[ -f "$DST/public/.htaccess" ] || cp -a "$SRC/backend/public/.htaccess" "$DST/public/.htaccess"

# ---- writable dirs: ONLY framework cache/session/view + logs — never storage/app ----
mkdir -p "$DST/bootstrap/cache" "$DST/storage/framework/cache" "$DST/storage/framework/sessions" "$DST/storage/framework/views" "$DST/storage/logs" 2>/dev/null
chmod 775 "$DST/storage/framework/cache" "$DST/storage/framework/sessions" "$DST/storage/framework/views" "$DST/storage/logs" 2>/dev/null || true

# ---- composer only when lock changed ----
if ! cmp -s "$SRC/backend/composer.lock" "$SNAPDIR/composer.lock" 2>/dev/null; then
  (cd "$DST" && "$PHP" "$COMPOSER" install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1 \
    || fail "composer install"
fi

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
