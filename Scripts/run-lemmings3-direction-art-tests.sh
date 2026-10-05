#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l3-direction-art"
module_cache="$build_dir/ModuleCache"
sparkle_framework="$(LEMMINGS_BUILD_ROOT="$build_dir/dependencies" \
  zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"
mkdir -p "$build_dir/modules" "$module_cache"
cd "$project_dir"

swiftc -O -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$module_cache" \
  -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift

cat Sources/LemmingsLocal/Lemmings3PlayWindow.swift \
  Tests/Lemmings3DirectionArtTests/main.swift > "$build_dir/main.swift"
app_sources=(Sources/LemmingsLocal/*.swift)
app_sources=("${(@)app_sources:#*/main.swift}")
app_sources=("${(@)app_sources:#*/Lemmings3PlayWindow.swift}")
swiftc -O -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$module_cache" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -F "$sparkle_framework_dir" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$sparkle_framework_dir" \
  -o "$build_dir/DirectionArtTests" "$build_dir/main.swift" "${app_sources[@]}"

python3 Tools/UITestRunner/run.py "$build_dir/DirectionArtTests"
