#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-7/Lemmings
release_root="$PWD/.build/release-1.7.8"
[[ "$(git rev-parse HEAD)" == "$(cat "$release_root/source-commit.txt")" ]]
mkdir -p "$release_root/downloads" "$release_root/updates"
for scope in slim standard; do
  if [[ "$scope" == slim ]]; then
    prefix=slim
    archive="$release_root/downloads/UltimateLemmings-1.7.8-build62-slim.zip"
    submission="$release_root/slim-submission.zip"
    response="$release_root/slim-submission.json"
  else
    prefix=standard
    archive="$release_root/updates/UltimateLemmings-1.7.8-build62.zip"
    submission="$release_root/notary-submission.zip"
    response="$release_root/notary-submission.json"
  fi
  app="$release_root/$scope/Ultimate Lemmings.app"
  submission_id="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["id"])' "$response")"
  xcrun notarytool info "$submission_id" --keychain-profile lemmings-beta --output-format json > "$release_root/$prefix-notary-status.json"
  python3 - "$release_root/$prefix-notary-status.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]));assert p['status']=='Accepted',p
print('PASS Apple accepted',p['id'])
PY
  xcrun notarytool log "$submission_id" --keychain-profile lemmings-beta "$release_root/$prefix-notary-log.json"
  python3 - "$release_root/$prefix-notary-log.json" "$submission" <<'PY'
import hashlib,json,sys
from pathlib import Path
p=json.load(open(sys.argv[1]));assert p['status']=='Accepted' and not p.get('issues')
assert p['sha256']==hashlib.file_digest(Path(sys.argv[2]).open('rb'),'sha256').hexdigest()
print('PASS Apple log matches exact submitted archive')
PY
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  codesign --verify --deep --strict --verbose=1 "$app"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
  python3 - "$archive" "$scope" <<'PY'
from pathlib import Path
import sys,zipfile
p=Path(sys.argv[1]);limit=250_000_000 if sys.argv[2]=='slim' else 2147483648
assert 0<p.stat().st_size<limit
with zipfile.ZipFile(p) as z:
 assert z.testzip() is None
 assert len(z.namelist())==len(set(z.namelist()))
 assert {n.split('/')[0] for n in z.namelist()}<={'Ultimate Lemmings.app','__MACOSX'}
print('PASS ZIP integrity, app-only contents and size',p.stat().st_size)
PY
  verification="$release_root/$scope-gatekeeper"
  mkdir -p "$verification"
  ditto -x -k "$archive" "$verification"
  checked="$verification/Ultimate Lemmings.app"
  xattr -w com.apple.quarantine '0083;00000000;Safari;' "$checked"
  spctl -a -vv --type execute "$checked"
  xcrun stapler validate "$checked"
  codesign --verify --deep --strict --verbose=1 "$checked"
  python3 - "$archive" "$release_root" "$prefix" "$submission_id" <<'PY'
from pathlib import Path
import hashlib,json,sys
archive,root=map(Path,sys.argv[1:3]);prefix,submission=sys.argv[3:]
p={'sourceCommit':(root/'source-commit.txt').read_text().strip(),'archive':archive.name,'size':archive.stat().st_size,'sha256':hashlib.file_digest(archive.open('rb'),'sha256').hexdigest(),'notarySubmission':submission}
(root/(prefix+'-final-archive.json')).write_text(json.dumps(p,indent=2)+'\n');print(json.dumps(p,indent=2))
PY
done
