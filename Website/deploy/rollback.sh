#!/bin/bash
# Restore one retained website release and its reviewed Nginx configuration.
set -euo pipefail
[ "$#" -eq 1 ] && [[ "$1" =~ ^[0-9a-f]{40,64}$ ]] || {
  echo 'Usage: bash Website/deploy/rollback.sh COMMIT' >&2; exit 1;
}
ssh -o BatchMode=yes "${APP_HOST:-glasscode}" sudo -n bash -s -- "$1" <<'REMOTE'
set -euo pipefail
revision="$1"
exec 9>/var/lock/ultimate-lemmix-website.lock
flock -n 9
base=/var/www/lemmings
release="$base/releases/$revision"
receipt="$base/deployments/$revision"
config=/etc/nginx/sites-available/lemmings.conf
[ -f "$release/deployment.json" ] && [ -f "$receipt/active-nginx.conf" ]
previous="$(readlink "$base/current")"
backup="$(mktemp "$base/deployments/rollback-nginx.XXXXXXXX")"
cp -a "$config" "$backup"
restore() {
  cp -a "$backup" "$config"
  ln -s "$previous" "$base/rollback-restore-$revision"
  mv -Tf "$base/rollback-restore-$revision" "$base/current"
  nginx -t && systemctl reload nginx
}
trap restore ERR
cp -a "$receipt/active-nginx.conf" "$config"
nginx -t
ln -s "$release" "$base/rollback-$revision"
mv -Tf "$base/rollback-$revision" "$base/current"
systemctl reload nginx
curl --noproxy "*" --fail --silent --show-error --retry 5 --retry-all-errors --retry-delay 1 \
  --resolve lemmings.glasscode.academy:443:127.0.0.1 \
  https://lemmings.glasscode.academy/build.json | python3 -c \
  'import json,sys; assert json.load(sys.stdin)["source_revision"] == sys.argv[1]' "$revision"
trap - ERR
printf 'Restored %s\n' "$release"
REMOTE
