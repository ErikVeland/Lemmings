#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/original-font-tests"
candidate="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-universal}"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
compiler="$developer_dir/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
sdk="$developer_dir/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
architecture="$(uname -m)"
module_dir="${ULTIMATE_LEMMIX_CORE_MODULE_DIR:-$candidate/$architecture/modules}"
library_dir="${ULTIMATE_LEMMIX_CORE_LIBRARY_DIR:-$candidate/Ultimate Lemmix.app/Contents/Frameworks}"
mkdir -p "$build_dir/ModuleCache"
zsh "$project_dir/Scripts/prepare-original-font.sh" --self-test
zsh "$project_dir/Scripts/prepare-original-font.sh" --verify
for mode in personal clean; do
  app="$build_dir/Font-$mode.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  ln -sfn "$project_dir/.build/personal-preview-assets/Fonts" "$app/Contents/Resources/Fonts"
  python3 - "$app/Contents/Info.plist" "$mode" <<'PLIST'
import plistlib,sys
from pathlib import Path
Path(sys.argv[1]).write_bytes(plistlib.dumps({'CFBundleIdentifier':'academy.glasscode.lemmix.font-test.'+sys.argv[2],
 'CFBundleExecutable':'FontTests','CFBundleName':'Original Font Tests','CFBundlePackageType':'APPL',
 'UltimateLemmixStore':True,'UltimateLemmixPersonalPreview':sys.argv[2]=='personal'}))
PLIST
done
"$compiler" -swift-version 6 -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" \
  -I "$module_dir" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -framework AppKit \
  "$project_dir/Sources/LemmingsLocal/GameMenuArtwork.swift" \
  "$project_dir/Sources/LemmingsLocal/MacInterfaceRenderer.swift" \
  "$project_dir/Tests/OriginalFontTests/main.swift" -o "$build_dir/Font-personal.app/Contents/MacOS/FontTests"
cp "$build_dir/Font-personal.app/Contents/MacOS/FontTests" "$build_dir/Font-clean.app/Contents/MacOS/FontTests"
export LEMMINGS_TEST_AUDIO=muted
export LEMMINGS_TEST_WINDOWS=offscreen
export LEMMIX_FONT_PROOF="$build_dir/original-font-menu.png"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/Font-personal.app/Contents/MacOS/FontTests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/Font-clean.app/Contents/MacOS/FontTests" --expect-disabled
