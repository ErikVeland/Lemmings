#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
root="$PWD/.build/release-1.9.1"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
python3 - "$root" <<'CHECK'
import json,pathlib,sys
r=pathlib.Path(sys.argv[1]);audit=json.loads((r/'audit/results.json').read_text())
assert not audit['sourceDrift']
assert sum(c['status']=='passed' for c in audit['checks'])==48
assert all(c['status'] in ('passed','not-run') for c in audit['checks'])
assert (r/'package.log').read_text().count('PASS archive integrity and size:')==2
for variant in ['standard','slim']:
 assert json.loads((r/(variant+'-notary.json')).read_text())['status']=='Accepted'
assert 'PASS release notes stay clipped and scrollable' in (r/'release-notes-runtime.log').read_text()
print('PASS final audit, focused UI checks and both notarised packages')
CHECK
python3 Tools/ReleaseReadiness/update_notes.py "$root/ReleaseNotes-1.9.1-build76.md" "$root/updates/UltimateLemmings-1.9.1-build76.html"
DOWNLOAD_URL_PREFIX=https://github.com/ErikVeland/Lemmings/releases/download/v1.9.1/ zsh Scripts/generate-appcast.sh "$root/updates"
python3 "$root/preserve-appcast.py"
python3 "$root/verify-publication.py"
zsh Scripts/check-release-inputs.sh
export RELEASE_TAG=v1.9.1 RELEASE_VERSION=1.9.1 RELEASE_COMMIT="$revision" RELEASE_NOTES_PATH="$root/ReleaseNotes-1.9.1-build76.md" DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.9.1-build76-slim.zip"
zsh Scripts/publish-github-release.sh --check "$root/updates/UltimateLemmings-1.9.1-build76.zip"
# A release must not reuse a tag from another source commit.
python3 - "$revision" <<'TAG'
import json,subprocess,sys
p=subprocess.run(['gh','api','repos/ErikVeland/Lemmings/git/ref/tags/v1.9.1'],capture_output=True,text=True)
if p.returncode==0:
 assert json.loads(p.stdout)['object']['sha']==sys.argv[1], 'Existing tag belongs to another commit'
else:
 assert '404' in p.stderr, p.stderr
TAG
git fetch origin main
git merge-base --is-ancestor origin/main "$revision"
git push origin "${revision}:refs/heads/main"
RELEASE_APPROVED=1 zsh Scripts/publish-github-release.sh "$root/updates/UltimateLemmings-1.9.1-build76.zip"
python3 "$root/verify-live.py"
