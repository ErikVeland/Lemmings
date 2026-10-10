#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
root="$PWD/.build/release-1.9"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
python3 - "$root" <<'PY'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);audit=json.loads((r/'audit-final/results.json').read_text())
assert (r/'package.log').read_text().count('PASS archive integrity and size:')==2
for variant in ['standard','slim']: assert json.loads((r/(variant+'-notary.json')).read_text())['status']=='Accepted'
assert not audit['sourceDrift']
assert sum(c['status']=='passed' for c in audit['checks'])==48
assert all(c['status'] in ('passed','not-run') for c in audit['checks'])
for scope in ['mac-fidelity','exit-progress','updates','release-ui','music']:
 assert 'PASS release candidate scope: '+scope in (r/(scope+'-runtime.log')).read_text()
print('PASS final audit and all five offscreen release UI scopes')
PY
python3 Tools/ReleaseReadiness/update_notes.py "$root/ReleaseNotes-1.9-build75.md" "$root/updates/UltimateLemmings-1.9-build75.html"
DOWNLOAD_URL_PREFIX=https://github.com/ErikVeland/Lemmings/releases/download/v1.9/ zsh Scripts/generate-appcast.sh "$root/updates"
python3 "$root/preserve-appcast.py"
python3 "$root/verify-publication.py"
zsh Scripts/check-release-inputs.sh
export RELEASE_TAG=v1.9 RELEASE_VERSION=1.9 RELEASE_COMMIT="$revision" RELEASE_NOTES_PATH="$root/ReleaseNotes-1.9-build75.md" DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.9-build75-slim.zip"
zsh Scripts/publish-github-release.sh --check "$root/updates/UltimateLemmings-1.9-build75.zip"
git fetch origin main
git merge-base --is-ancestor origin/main "$revision"
git push origin "${revision}:refs/heads/main"
RELEASE_APPROVED=1 zsh Scripts/publish-github-release.sh "$root/updates/UltimateLemmings-1.9-build75.zip"
python3 "$root/verify-live.py"
