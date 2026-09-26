#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
build_dir="$project_dir/.build/trolley"
mkdir -p "$build_dir/modules"
sparkle_framework="$(SPARKLE_FRAMEWORK_PATH="${SPARKLE_FRAMEWORK_PATH:-}" \
  LEMMINGS_BUILD_ROOT="$build_dir/dependencies" zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
sources=(Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$build_dir" \
  -F "$sparkle_framework_dir" -framework Sparkle -Xlinker -rpath -Xlinker "$sparkle_framework_dir" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -o "$build_dir/trolley-tests" "${sources[@]}" Tests/TrolleyTests/main.swift
"$build_dir/trolley-tests"
