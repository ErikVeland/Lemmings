#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/explosion-hdr-tests"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -framework AppKit -framework Metal -framework QuartzCore \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/ExplosionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTView.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTShaders.swift" \
  "$project_dir/Tests/ExplosionHDRTests/main.swift"
"$build_dir/tests" "$@"
