#!/bin/bash
# Publish the committed Lemmix website through the existing Glasscode server.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"
APP_HOST="${APP_HOST:-glasscode}"
DOMAIN=lemmings.glasscode.academy
DIST="$REPO_ROOT/Website/dist"
[ "$#" -eq 0 ] || { echo 'Usage: bash Website/deploy/publish.sh' >&2; exit 1; }
python3 Tools/Publication/publication.py guard ultimate-lemmix
[ -z "$(git status --porcelain --untracked-files=all -- Website)" ] || {
  echo 'Commit the website source before publication.' >&2; exit 1;
}
git ls-files --error-unmatch Website/build.py Website/check_site.py Website/deploy/nginx.conf >/dev/null
python3 - <<'PYSOURCE'
from pathlib import Path
import subprocess
tracked = set(subprocess.check_output(['git', 'ls-files', '-z', '--', 'Website']).decode().split('\0'))
for path in Path('Website').rglob('*'):
    relative = path.relative_to('Website')
    if relative.parts[0] in ('dist', 'verification') or '__pycache__' in relative.parts or path.name == '.DS_Store':
        continue
    if path.is_symlink():
        raise SystemExit('Website source must not contain symbolic links.')
    if path.is_file() and path.as_posix() not in tracked:
        raise SystemExit('Commit the website build input before publication: ' + path.as_posix())
PYSOURCE
REVISION="$(git rev-parse HEAD)"
python3 Website/build.py
python3 Website/check_site.py
[ "$(git rev-parse HEAD)" = "$REVISION" ] || {
  echo 'The source revision changed during the website build. Run publication again.' >&2; exit 1;
}
[ -z "$(git status --porcelain --untracked-files=all -- Website)" ] || {
  echo 'The website build changed its source. Review and commit those changes.' >&2; exit 1;
}
python3 - "$DIST" "$REVISION" <<'PY'
from pathlib import Path
import hashlib, json, sys
root, revision = Path(sys.argv[1]).resolve(), sys.argv[2]
if not (root / 'index.html').is_file():
    raise SystemExit('The built website has no home page.')
for path in root.rglob('*'):
    if path.is_symlink():
        raise SystemExit('The website output must not contain symbolic links.')
metadata_path = root / 'build.json'
metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
metadata.update(source_revision=revision, canonical_origin='https://lemmings.glasscode.academy')
metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n')
files = {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(root.rglob('*')) if path.is_file() and path.name != 'deployment.json'}
(root / 'deployment.json').write_text(json.dumps({'source_revision': revision, 'files': files},
                                                indent=2, sort_keys=True) + '\n')
PY
ssh -o BatchMode=yes "$APP_HOST" "test ! -e /var/www/lemmings/releases/$REVISION && sudo -n test -r /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
STAGING="$(ssh -o BatchMode=yes "$APP_HOST" 'mktemp -d /tmp/ultimate-lemmix-site.XXXXXXXX')"
[[ "$STAGING" =~ ^/tmp/ultimate-lemmix-site\.[A-Za-z0-9]+$ ]] || {
  echo 'The remote staging path is invalid.' >&2; exit 1;
}
rsync -az "$DIST/" "$APP_HOST:$STAGING/site/"
scp -q Website/deploy/nginx.conf "$APP_HOST:$STAGING/nginx.conf"
ssh -o BatchMode=yes "$APP_HOST" sudo -n bash -s -- "$REVISION" "$STAGING" <<'REMOTE'
set -euo pipefail
revision="$1"
staging="$2"
[[ "$revision" =~ ^[0-9a-f]{40,64}$ ]] || exit 1
[[ "$staging" =~ ^/tmp/ultimate-lemmix-site\.[A-Za-z0-9]+$ ]] || exit 1
exec 9>/var/lock/ultimate-lemmix-website.lock
flock -n 9
base=/var/www/lemmings
release="$base/releases/$revision"
receipt="$base/deployments/$revision"
config=/etc/nginx/sites-available/lemmings.conf
enabled=/etc/nginx/sites-enabled/lemmings.conf
[ ! -e "$release" ] && [ ! -e "$receipt" ]
[ ! -e "$base/current" ] || [ -L "$base/current" ]
[ ! -e "$enabled" ] || [ -L "$enabled" ]
[ ! -L "$enabled" ] || [ "$(readlink "$enabled")" = "$config" ]
python3 - "$staging/site" "$revision" <<'PY'
from pathlib import Path
import hashlib, json, sys
root, revision = Path(sys.argv[1]), sys.argv[2]
manifest = json.loads((root / 'deployment.json').read_text())
actual = {}
for path in root.rglob('*'):
    if path.is_symlink():
        raise SystemExit('The uploaded website contains a symbolic link.')
    if path.is_file() and path.name != 'deployment.json':
        actual[path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
if manifest['source_revision'] != revision or actual != manifest['files']:
    raise SystemExit('The uploaded website differs from its deployment inventory.')
PY
install -d "$base/releases" "$base/deployments" "$receipt"
previous="$(readlink "$base/current" || true)"
printf '%s\n' "$previous" > "$receipt/previous-release.txt"
config_existed=0
enabled_existed=0
if [ -e "$config" ]; then
  cp -a "$config" "$receipt/previous-nginx.conf"
  config_existed=1
fi
[ ! -L "$enabled" ] || enabled_existed=1
rollback() {
  if [ "$config_existed" -eq 1 ]; then
    cp -a "$receipt/previous-nginx.conf" "$config"
  else
    rm -f "$config"
  fi
  if [ -n "$previous" ]; then
    ln -s "$previous" "$base/restore-$revision"
    mv -Tf "$base/restore-$revision" "$base/current"
  elif [ -L "$base/current" ]; then
    rm "$base/current"
  fi
  [ "$enabled_existed" -eq 1 ] || rm -f "$enabled"
  nginx -t && systemctl reload nginx
}
trap rollback ERR
cp -a "$staging/site" "$release"
chown -R root:root "$release"
find "$release" -type d -exec chmod 755 '{}' +
find "$release" -type f -exec chmod 644 '{}' +
install -m 644 "$staging/nginx.conf" "$config"
cp -a "$config" "$receipt/active-nginx.conf"
[ -L "$enabled" ] || ln -s "$config" "$enabled"
nginx -t
ln -s "$release" "$base/current-$revision"
mv -Tf "$base/current-$revision" "$base/current"
systemctl reload nginx
curl --noproxy "*" --fail --silent --show-error --retry 5 --retry-all-errors --retry-delay 1 \
  --resolve lemmings.glasscode.academy:443:127.0.0.1 \
  https://lemmings.glasscode.academy/build.json | python3 -c \
  'import json,sys; assert json.load(sys.stdin)["source_revision"] == sys.argv[1]' "$revision"
trap - ERR
printf 'Published %s\n' "$release"
REMOTE
curl --fail --silent --show-error "https://$DOMAIN/build.json" | python3 -c \
  'import json,sys; value=json.load(sys.stdin); assert value["source_revision"] == sys.argv[1]; print(json.dumps(value,indent=2))' "$REVISION"
