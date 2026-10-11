#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
root="$PWD/.build/release-1.9.2"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
[[ -z "$(git status --porcelain --untracked-files=all)" ]]
python3 - <<'PY'
from pathlib import Path
import json
r=Path('.build/release-1.9.2'); a=json.loads((r/'audit/results.json').read_text())
assert not a['sourceDrift']
assert sum(c['status']=='passed' for c in a['checks'])==48
assert 'PASS all 48 minor-release audit checks' in (r/'finalise.log').read_text()
assert (r/'package.log').read_text().count('PASS archive integrity and size:')==2
assert 'Celebration music, golden glow, Records, notices and release UI integration tests passed.' in (r/'native-runtime.log').read_text()
for v in ['standard','slim']:assert json.loads((r/(v+'-notary.json')).read_text())['status']=='Accepted'
print('PASS frozen source, release audit, native UI and both notarised downloads',flush=True)
PY
git fetch origin main
git diff --quiet HEAD origin/main -- appcast.xml
cp appcast.xml "$root/previous-appcast.xml"
python3 - <<'VERIFY_BASE'
from pathlib import Path
import plistlib,subprocess,xml.etree.ElementTree as E
n='{http://www.andymatuschak.org/xml-namespaces/sparkle}'
i=next(x for x in E.parse('appcast.xml').findall('./channel/item') if x.findtext(n+'version')=='76')
p=plistlib.loads(Path('Resources/Info.plist').read_bytes())
subprocess.run(['.build/release-1.9.2/verify-signature','.build/release-1.9.1/updates/UltimateLemmings-1.9.1-build76.zip',p['SUPublicEDKey'],i.find('enclosure').get(n+'edSignature')],check=True)
print('PASS previous published full archive signature')
VERIFY_BASE
python3 Tools/ReleaseReadiness/update_notes.py "$root/ReleaseNotes-1.9.2-build77.md" "$root/updates/UltimateLemmings-1.9.2-build77.html"
DOWNLOAD_URL_PREFIX=https://github.com/ErikVeland/Lemmings/releases/download/v1.9.2/ PREVIOUS_UPDATE_ZIP="$PWD/.build/release-1.9.1/updates/UltimateLemmings-1.9.1-build76.zip" zsh Scripts/generate-appcast.sh "$root/updates"
python3 "$root/verify-publication.py"
mkdir -p "$root/delta-patched"
.build/dependencies/Sparkle-2.7.3/bin/BinaryDelta apply "$PWD/.build/release-1.9.1/standard/Ultimate Lemmings.app" "$root/delta-patched/Ultimate Lemmings.app" "$root/updates/UltimateLemmings-build77-from76.delta" > "$root/delta-apply.log" 2>&1
python3 "$root/verify-delta.py" > "$root/delta-verification.log"
codesign --verify --deep --strict "$root/delta-patched/Ultimate Lemmings.app"
xattr -w com.apple.quarantine '0083;00000000;Safari;' "$root/delta-patched/Ultimate Lemmings.app"
spctl -a -vv --type execute "$root/delta-patched/Ultimate Lemmings.app" >> "$root/delta-verification.log" 2>&1
zsh Scripts/check-release-inputs.sh
RELEASE_TAG=v1.9.2 RELEASE_VERSION=1.9.2 RELEASE_COMMIT="$revision" RELEASE_NOTES_PATH="$root/ReleaseNotes-1.9.2-build77.md" DOWNLOAD_ZIP="$root/downloads/UltimateLemmings-1.9.2-build77-slim.zip" zsh Scripts/publish-github-release.sh --check "$root/updates/UltimateLemmings-1.9.2-build77.zip"
print "PASS signed update feed, exact delta payload and publication inputs"
