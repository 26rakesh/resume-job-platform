#!/usr/bin/env bash
# rollback.sh <sha> — restore runtime snapshot taken by jobs-sync.sh
# Install: /home/u444986405/bin/jobs-rollback.sh ; usage: jobs-rollback.sh <sha>
set -u
PHP=/opt/alt/php83/usr/bin/php
DST=/home/u444986405/jobs-platform/backend
LIVE_APP=/home/u444986405/domains/jobs.sunrisepaint.in/public_html/app
SNAP=/home/u444986405/jobs-platform/.snapshots
LOG=/home/u444986405/jobs-platform/storage/logs/deploy-sync.log
SHA="${1:?usage: jobs-rollback.sh <deployed-sha>}"
SNAPDIR="$SNAP/$SHA"
[ -d "$SNAPDIR" ] || { echo "no snapshot for $SHA"; ls "$SNAP"; exit 1; }

# restore only synced code dirs — never .env, storage, vendor, private data
for d in app bootstrap config database public routes tests; do
  rm -rf "$DST/$d"; cp -a "$SNAPDIR/$d" "$DST/$d" 2>/dev/null || true
done
for f in artisan composer.json composer.lock phpunit.xml; do
  cp -a "$SNAPDIR/$f" "$DST/$f" 2>/dev/null || true
done
# re-sync React assets to live docroot
rm -rf "$LIVE_APP"; cp -a "$DST/public/app" "$LIVE_APP" 2>/dev/null || true

chmod -R 775 "$DST/storage" "$DST/bootstrap/cache" 2>/dev/null
(cd "$DST" && "$PHP" composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction) >> "$LOG" 2>&1
(cd "$DST" && "$PHP" artisan config:cache route:cache view:cache) >> "$LOG" 2>&1
echo "$(date -u +%FT%TZ) ROLLBACK to $SHA" >> "$LOG"
echo "rolled back to $SHA"
