#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/explosion-hdr-tests"
module_cache="$build_dir/ModuleCache"
mkdir -p "$module_cache"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$module_cache" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
zsh "$project_dir/Scripts/build-game-art-module.sh" "$build_dir/modules" "$build_dir" \
  "$(uname -m)-apple-macos12.3" -module-cache-path "$module_cache"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$module_cache" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit -lLemmingsAppCore -lLemmingsMobileCore -lLemmingsGameArt \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -framework AppKit -framework Metal -framework QuartzCore \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsGameArt/LemmingSelectionRenderer.swift" \
  "$project_dir/Sources/LemmingsLocal/ExplosionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/LemmingSelectionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTView.swift" \
  "$project_dir/Sources/LemmingsLocal/MacFXPerformance.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTShaders.swift" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Tests/ExplosionHDRTests/main.swift"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$@"
