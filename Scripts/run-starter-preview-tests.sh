#!/bin/zsh
# Validate generated starter thumbnails without game data or visible windows.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/starter-preview-tests"
base="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-build3-universal}"
architecture="$(uname -m)"
framework_dir="$base/Ultimate Lemmix.app/Contents/Frameworks"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
artwork="${LEMMIX_PREVIEW_TEST_LIX_DIRECTORY:-$base/Ultimate Lemmix.app/Contents/Resources/AlternativeAssets/Lix}"
mkdir -p "$build_dir/ModuleCache" "$build_dir/captures"
"$compiler" -swift-version 6 -warnings-as-errors -sdk "$sdk" -target "$architecture-apple-macosx12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$base/$architecture/modules" \
  -L "$framework_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$framework_dir" \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/GameAssetCache.swift" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/FanLevelLibrary.swift" \
  "$project_dir/Sources/LemmingsLocal/LevelPreviewStore.swift" \
  "$project_dir/Tests/LevelPreviewStarterTests/main.swift"
LEMMIX_PREVIEW_TEST_LIX_DIRECTORY="$artwork" LEMMIX_PREVIEW_TEST_CAPTURES="$build_dir/captures" \
  python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
