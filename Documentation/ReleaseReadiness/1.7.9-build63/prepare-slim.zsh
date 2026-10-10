#!/bin/zsh
set -euo pipefail
cd /Users/veland/.codex/worktrees/release-1-7-9/Lemmings
release_root="$PWD/.build/release-1.7.9"
standard="$release_root/standard/Ultimate Lemmings.app"
slim="$release_root/slim/Ultimate Lemmings.app"
[[ "$(git rev-parse HEAD)" == "$(cat "$release_root/source-commit.txt")" ]]
[[ -z "$(git status --porcelain --untracked-files=all)" ]]
mkdir -p "$release_root/slim"
[[ ! -e "$slim" ]]
cp -cR "$standard" "$slim"
python3 Tools/MusicCatalogue/library.py bundle --output "$slim/Contents/Resources/Music" --game all --scope main
python3 - "$standard" "$slim" "$release_root" <<'PY'
from pathlib import Path
import hashlib,json,plistlib,subprocess,sys
standard,slim,root=map(Path,sys.argv[1:])
def files(app):
 return {str(p.relative_to(app)):hashlib.sha256(p.read_bytes()).hexdigest() for p in app.rglob('*') if p.is_file() and not str(p.relative_to(app)).startswith('Contents/Resources/Music/')}
a,b=files(standard),files(slim);assert a==b
info=plistlib.loads((slim/'Contents/Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'])==('1.7.9','63')
for app,scope,count in [(standard,'full',495),(slim,'main',54)]:
 resources=app/'Contents/Resources';bundle=json.loads((resources/'Music/bundle.json').read_text())
 assert (bundle['scope'],bundle['trackCount'])==(scope,count)
 packs=json.loads((resources/'Music/libraries.json').read_text())['packs']
 missing=[p['id'] for p in packs if not all((resources/f['path']).is_file() for f in p['files'] if not f['path'].endswith('.json'))]
 assert len(missing)==(18 if scope=='main' else 0)
 for name in ('Contents/MacOS/LemmingsLocal','Contents/Frameworks/libNxlvKit.dylib'):
  assert set(subprocess.check_output(['lipo','-archs',str(app/name)],text=True).split())=={'arm64','x86_64'}
report={'matchingFilesOutsideMusicBeforeSigning':len(a),'fullMusicVersions':495,'slimMusicVersions':54,'optionalLibraries':18}
(root/'slim-inputs.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
PY
ln -s ../standard/arm64 "$release_root/slim/arm64"
identity="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
[[ -n "$identity" ]]
codesign --force --deep --options runtime --timestamp --sign "$identity" "$slim"
codesign --verify --deep --strict --verbose=1 "$slim"
ditto -c -k --sequesterRsrc --keepParent "$slim" "$release_root/slim-submission.zip"
xcrun notarytool submit "$release_root/slim-submission.zip" --keychain-profile lemmings-beta --output-format json --no-progress > "$release_root/slim-submission.json"
python3 - "$release_root/slim-submission.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]));print('Slim notarisation submitted:',p['id'])
PY
