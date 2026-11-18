#!/bin/zsh
# Exercise resource generation changes without opening or altering the review app.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/resource-artwork-tests"
base="${ULTIMATE_LEMMIX_CORE_BUILD_DIR:-$project_dir/.build/ultimate-lemmix-app-store-build3-universal}"
framework_dir="$base/Ultimate Lemmix.app/Contents/Frameworks"
compiler=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX27.2.sdk
mkdir -p "$build_dir/ModuleCache"
"$compiler" -swift-version 6 -warnings-as-errors -DULTIMATE_LEMMIX_STORE -sdk "$sdk" \
  -module-cache-path "$build_dir/ModuleCache" -I "$base/$(uname -m)/modules" \
  -L "$framework_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$framework_dir" -framework AppKit \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/GameResources.swift" \
  "$project_dir/Sources/LemmingsLocal/GameMenuArtwork.swift" \
  "$project_dir/Sources/LemmingsLocal/LixInterfaceRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/MacInterfaceRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Tests/ResourceArtworkTests/main.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests"
