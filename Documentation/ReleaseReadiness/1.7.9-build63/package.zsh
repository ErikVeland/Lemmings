#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
root="$PWD/.build/release-1.7.9"
app="$root/standard/Ultimate Lemmings.app"
source_revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$source_revision" ]]
[[ -z "$(git status --porcelain --untracked-files=all)" ]]
python3 - "$root" "$app" <<'PY'
import hashlib,json,pathlib,plistlib,sys
root,app=map(pathlib.Path,sys.argv[1:]);resources=app/'Contents/Resources'
source=json.loads((root/'build-inputs.json').read_text())
assert all(hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()==h for p,h in source.items())
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'],info['LSMinimumSystemVersion'])==('1.7.9','63','12.3')
for name in ('Hints/classic.json','Hints/solutions.json','Progression/learning.json','Progression/solutions.json','Trolley/verified-maxima.json','Trolley/engine-fingerprint.txt'):
 assert (pathlib.Path('Resources')/name).read_bytes()==(resources/name).read_bytes(),name
music=json.loads((resources/'Music/bundle.json').read_text());assert music['scope']=='full'
packs=json.loads((resources/'Music/libraries.json').read_text())['packs']
assert all((resources/f['path']).is_file() for p in packs for f in p['files'] if not f['path'].endswith('.json'))
print('PASS frozen source, packaged version, hints, rescue proofs, learning resources and full soundtrack:',music['trackCount'],'versions')
PY
python3 - "$app" <<'ARCH'
import pathlib,subprocess,sys
app=pathlib.Path(sys.argv[1])
for name in ('Contents/MacOS/LemmingsLocal','Contents/Frameworks/libNxlvKit.dylib'):
 arches=subprocess.check_output(['lipo','-archs',str(app/name)],text=True).split()
 assert set(arches)=={'arm64','x86_64'},arches
print('PASS universal app and core library')
ARCH
identity="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
[[ -n "$identity" ]]
codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=1 "$app"
python3 - "$app" <<'PY'
from pathlib import Path
import subprocess,sys
app=Path(sys.argv[1])
def team(p):
 text=subprocess.run(['codesign','-dv',str(p)],capture_output=True,text=True,check=True).stderr
 return next(x.split('=',1)[1] for x in text.splitlines() if x.startswith('TeamIdentifier='))
expected=team(app)
items=list((app/'Contents/Frameworks').glob('*'))
items.extend((app/'Contents/Frameworks').glob('*.framework/Versions/Current/XPCServices/*.xpc'))
items.extend((app/'Contents/Frameworks').glob('*.framework/Versions/Current/Autoupdate'))
items.extend((app/'Contents/Frameworks').glob('*.framework/Versions/Current/Updater.app'))
assert expected and expected!='not set'
assert all(team(p)==expected for p in items)
print('PASS shipping app and nested code share one signing team')
PY
ditto -c -k --sequesterRsrc --keepParent "$app" "$root/notary-submission.zip"
shasum -a 256 "$root/notary-submission.zip" > "$root/submission-sha256.txt"
xcrun notarytool submit "$root/notary-submission.zip" --keychain-profile lemmings-beta --output-format json --no-progress > "$root/notary-submission.json"
python3 - "$root/notary-submission.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]));print('Notarisation submitted:',result['id'],result.get('message',''))
PY
