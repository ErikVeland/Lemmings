#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/mobile-energy-tests"
mkdir -p "$build_dir/modules" "$build_dir/ModuleCache"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
# Join extensions to the audio sources to inspect actual engine state without test APIs.
cat "$project_dir"/Sources/LemmingsAudio/*.swift \
  "$project_dir/Tests/MobileEnergyTests/main.swift" > "$build_dir/main.swift"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$build_dir/ModuleCache" -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AVFoundation -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/checks" "$build_dir/main.swift"
LEMMINGS_TEST_AUDIO=muted python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/checks"
