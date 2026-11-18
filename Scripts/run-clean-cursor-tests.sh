#!/bin/zsh
# Check licensed cursor modes without activating a window or moving the cursor.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/clean-cursor-tests"
base="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-build3-universal}"
app="$build_dir/CleanCursorTests.app"
mkdir -p "$app/Contents/MacOS" "$build_dir/ModuleCache" "$build_dir/captures"
ln -sfn "$base/Ultimate Lemmix.app/Contents/Resources" "$app/Contents/Resources"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
"$compiler" -swift-version 6 -warnings-as-errors -DULTIMATE_LEMMIX_STORE -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -framework AppKit \
  -o "$app/Contents/MacOS/CleanCursorTests" "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Tests/CleanCursorTests/main.swift"
LEMMIX_CURSOR_CAPTURES="$build_dir/captures" python3 "$project_dir/Tools/UITestRunner/run.py" \
  "$app/Contents/MacOS/CleanCursorTests"
