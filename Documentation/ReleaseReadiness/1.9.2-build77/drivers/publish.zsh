#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
root="$PWD/.build/release-1.9.2"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
[[ -f "$root/publication.json" && -f "$root/delta-verification.json" ]]
python3 - "$revision" <<'PY'
import json,subprocess,sys
p=subprocess.run(['gh','api','repos/ErikVeland/Lemmings/git/ref/tags/v1.9.2'],capture_output=True,text=True)
if p.returncode==0:assert json.loads(p.stdout)['object']['sha']==sys.argv[1],'Existing tag belongs to another source commit'
else:assert '404' in p.stderr,p.stderr
r=json.load(open('.build/release-1.9.2/delta-verification.json'))
assert r['signatureVerified'] and r['patchedPayloadMatchesShippingApp']
print('PASS release identity and verified delta payload',flush=True)
PY
git fetch origin main
git merge-base --is-ancestor origin/main "$revision"
git push origin "${revision}:refs/heads/main"
export RELEASE_TAG=v1.9.2 RELEASE_VERSION=1.9.2 RELEASE_COMMIT="$revision" RELEASE_NOTES_PATH="$root/ReleaseNotes-1.9.2-build77.md" DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.9.2-build77-slim.zip"
RELEASE_APPROVED=1 zsh Scripts/publish-github-release.sh "$root/updates/UltimateLemmings-1.9.2-build77.zip"
python3 "$root/verify-live.py"
python3 - <<'PY'
from pathlib import Path
import json,subprocess,hashlib
r=Path('.build/release-1.9.2');receipt=json.loads((r/'delta-verification.json').read_text());p=r/'updates'/receipt['delta']['name']
release=json.loads(subprocess.check_output(['gh','api','repos/ErikVeland/Lemmings/releases/tags/v1.9.2'],text=True))
a=next(x for x in release['assets'] if x['name']==p.name)
assert a['size']==p.stat().st_size and a['digest']=='sha256:'+hashlib.sha256(p.read_bytes()).hexdigest()
receipt['remoteAssetVerified']=True;receipt['delta']['url']=a['browser_download_url']
(r/'delta-verification.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('PASS published signed delta size and SHA256 digest',flush=True)
PY
