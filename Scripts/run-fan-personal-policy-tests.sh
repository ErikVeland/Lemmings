#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/fan-personal-policy-tests"
library_dir="${FAN_TEST_LIBRARY_DIR:-$build_dir}"
swift_compiler="${LEMMINGS_SWIFTC:-/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc}"
sdk_dir="${LEMMINGS_MACOS_SDK:-/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk}"
if [[ ! -x "$swift_compiler" ]]; then swift_compiler="$(xcrun --find swiftc)"; fi
if [[ ! -d "$sdk_dir" ]]; then sdk_dir="$(xcrun --sdk macosx --show-sdk-path)"; fi
app_dir="$build_dir/Policy Tests.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/LevelPacks" "$build_dir/external"
if [[ -z "${FAN_TEST_LIBRARY_DIR:-}" ]]; then
  mkdir -p "$library_dir/modules"
  "$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
    -module-cache-path "$build_dir/ModuleCache" -swift-version 6 -warnings-as-errors \
    -parse-as-library -emit-module -emit-library -module-name NxlvKit \
    -emit-module-path "$library_dir/modules/NxlvKit.swiftmodule" \
    -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
    -framework CoreGraphics -framework ImageIO \
    -o "$library_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
fi
python3 - "$project_dir" "$build_dir" <<'PY'
import hashlib, json, pathlib, plistlib, sys
root, build = map(pathlib.Path, sys.argv[1:])
app = build / 'Policy Tests.app' / 'Contents'
payload = (root / 'Tests/FanLevelLibraryTests/Fixtures/literal-members.zip').read_bytes()
packs = app / 'Resources/LevelPacks'
for name in ('0001-pinned.zip', '0002-changed.zip', '9002-unlisted.zip'):
    (packs / name).write_bytes(payload)
for name in ('9001-selected.zip', '0001-pinned.zip'):
    (build / 'external' / name).write_bytes(payload)
linked = packs / 'linked-bundle.zip'
linked.unlink(missing_ok=True)
linked.symlink_to(build / 'external' / '9001-selected.zip')
digest = hashlib.sha256(payload).hexdigest()
(packs / 'community-manifest.json').write_text(json.dumps({
    'schemaVersion': 1,
    'packs': [dict(archive='0001-pinned.zip', archiveSHA256=digest, included=True),
              dict(archive='0002-changed.zip', archiveSHA256='0' * 64, included=True)],
    'entryExclusions': [dict(archive='0001-pinned.zip', archiveSHA256=digest,
                             file='level[1].ini', section=None)]
}))
(app / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'academy.glasscode.lemmix.fan-personal-policy-tests',
    'CFBundleExecutable': 'Tests', 'CFBundlePackageType': 'APPL',
    'UltimateLemmixPersonalPreview': True
}))
PY
"$swift_compiler" -sdk "$sdk_dir" -target "$(uname -m)-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" \
  -O -swift-version 6 -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$app_dir/Contents/MacOS/Tests" \
  "$project_dir/Tests/FanPersonalPolicyTests/main.swift" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$app_dir/Contents/MacOS/Tests" "$build_dir/external"
