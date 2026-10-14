#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/mac-performance-tests"
mkdir -p "$build_dir/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache"
cd "$project_dir"
swift build --build-system native --product LemmingsLocal --disable-sandbox --disable-automatic-resolution
products="$(swift build --build-system native --show-bin-path --disable-sandbox --disable-automatic-resolution)"
sources=("$project_dir"/Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
swiftc -swift-version 6 -D PERFORMANCE_TESTS -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -I "$products/Modules" \
  -F "$products" -framework Sparkle -Xlinker -rpath -Xlinker "$products" \
  -o "$build_dir/tests" "${sources[@]}" \
  "$project_dir"/Tests/MacPerformanceTests/*.swift \
  "$products"/{NxlvKit,LemmingsAppCore,LemmingsAudio,LemmingsGameArt,LemmingsMobileCore,LemmingsTVCore}.build/*.swift.o
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$project_dir"
