#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/community-preview-tests"
candidate="${ULTIMATE_LEMMIX_PERSONAL_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-personal-preview}/Ultimate Lemmix.app"
base="$project_dir/.build/ultimate-lemmix-app-store-universal"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
architecture="$(uname -m)"
test_app="$build_dir/CommunityPreviewTests.app"
mkdir -p "$test_app/Contents/MacOS" "$build_dir/ModuleCache"
python3 - "$test_app/Contents/Info.plist" <<'PLIST'
import plistlib,sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({'CFBundleIdentifier':'academy.glasscode.lemmix.integration-tests.community',
 'CFBundleExecutable':'CommunityPreviewTests','CFBundleName':'Community Preview Tests',
 'CFBundlePackageType':'APPL','UltimateLemmixPersonalPreview':True}))
PLIST
ln -sfn "$candidate/Contents/Resources" "$test_app/Contents/Resources"
"$compiler" -O -swift-version 6 -parse-as-library -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$base/$architecture/modules" \
  -L "$base/Ultimate Lemmix.app/Contents/Frameworks" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$base/Ultimate Lemmix.app/Contents/Frameworks" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Tests/CommunityPreviewTests/main.swift" -o "$test_app/Contents/MacOS/CommunityPreviewTests"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMIX_CORPUS_REPORT="$build_dir/results.json"
python3 "$project_dir/Tools/UITestRunner/run.py" "$test_app/Contents/MacOS/CommunityPreviewTests"
