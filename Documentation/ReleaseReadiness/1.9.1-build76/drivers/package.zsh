#!/bin/zsh
set -euo pipefail
cd /Users/veland/Lemmings
root="$PWD/.build/release-1.9.1"
app="$root/standard/Ultimate Lemmings.app"
revision="$(cat "$root/source-commit.txt")"
[[ "$(git rev-parse HEAD)" == "$revision" ]]
python3 Tools/TrolleyVerification/catalogue.py check
python3 - "$app" <<'PY'
import pathlib,plistlib,json,subprocess,sys
app=pathlib.Path(sys.argv[1]); r=app/'Contents/Resources'; info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert (info['CFBundleShortVersionString'],info['CFBundleVersion'],info['LSMinimumSystemVersion'])==('1.9.1','76','12.3')
assert info['HostedRankingsURL']=='https://glasscode.academy/lemmings-api/rankings'
for p in ('Contents/MacOS/LemmingsLocal','Contents/Frameworks/libNxlvKit.dylib'):
 assert set(subprocess.check_output(['lipo','-archs',str(app/p)],text=True).split())=={'arm64','x86_64'}
for p in ('Hints/classic.json','Hints/solutions.json','Progression/learning.json','Progression/solutions.json','Trolley/verified-maxima.json','Trolley/engine-fingerprint.txt'):
 assert (pathlib.Path('Resources')/p).read_bytes()==(r/p).read_bytes(),p
assert json.loads((r/'Music/bundle.json').read_text())['scope']=='full'
assert json.loads((r/'GameCenter/leaderboards.json').read_text())['enabled']==False
print('PASS universal macOS 12.3 package, hosted endpoint, current proofs/hints/journey, full music and optional Game Center')
PY
python3 "$root/verify-audio-bundle.py" "$app"
mkdir -p "$root/slim" "$root/updates" "$root/downloads"
cp -c -R "$app" "$root/slim/Ultimate Lemmings.app"
zsh Scripts/strip-recorded-music.sh "$root/slim/Ultimate Lemmings.app/Contents/Resources/Music"
identity="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
[[ -n "$identity" ]]
notarise_variant() {
 local variant="$1"
 local bundle="$root/$variant/Ultimate Lemmings.app"
 bundle="$root/$variant/Ultimate Lemmings.app"
 codesign --force --deep --options runtime --timestamp --sign "$identity" "$bundle"
 codesign --verify --deep --strict --verbose=1 "$bundle"
 ditto -c -k --sequesterRsrc --keepParent "$bundle" "$root/$variant-submission.zip"
 xcrun notarytool submit "$root/$variant-submission.zip" --keychain-profile lemmings-beta --wait --output-format json > "$root/$variant-notary.json"
 python3 - "$root/$variant-notary.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); assert r.get('status')=='Accepted',r
print('PASS Apple notarisation:',r['id'])
PY
}
notarise_variant standard > "$root/standard-sign-notary.log" 2>&1 &
full_pid=$!
notarise_variant slim > "$root/slim-sign-notary.log" 2>&1 &
slim_pid=$!
wait "$full_pid"
wait "$slim_pid"
for variant in standard slim; do
 bundle="$root/$variant/Ultimate Lemmings.app"
 xcrun stapler staple "$bundle"
 xcrun stapler validate "$bundle"
 suffix=""; folder=updates
 if [[ "$variant" == slim ]]; then suffix=-slim; folder=downloads; fi
 archive="$root/$folder/UltimateLemmings-1.9.1-build76$suffix.zip"
 ditto -c -k --sequesterRsrc --keepParent "$bundle" "$archive"
 verify="$root/verify-$variant"
 mkdir -p "$verify"
 ditto -x -k "$archive" "$verify"
 xattr -w com.apple.quarantine '0083;00000000;Safari;' "$verify/Ultimate Lemmings.app"
 codesign --verify --deep --strict --verbose=1 "$verify/Ultimate Lemmings.app"
 xcrun stapler validate "$verify/Ultimate Lemmings.app"
 spctl -a -vv --type execute "$verify/Ultimate Lemmings.app"
 python3 - "$archive" <<'PY'
import pathlib,sys,zipfile
p=pathlib.Path(sys.argv[1]); assert p.stat().st_size<2147483648
with zipfile.ZipFile(p) as z: assert z.testzip() is None
print('PASS archive integrity and size:',p.name,p.stat().st_size)
PY
done
