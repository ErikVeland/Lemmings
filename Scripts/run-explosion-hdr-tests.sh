#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/explosion-hdr-tests"
module_cache="$build_dir/ModuleCache"
mkdir -p "$module_cache"
swiftc -swift-version 6 -warnings-as-errors -target "$(uname -m)-apple-macos12.3" \
  -module-cache-path "$module_cache" \
  -framework AppKit -framework Metal -framework QuartzCore \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/ExplosionHDR.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTView.swift" \
  "$project_dir/Sources/LemmingsLocal/CRTShaders.swift" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Tests/ExplosionHDRTests/main.swift"
"$build_dir/tests" "$@"
