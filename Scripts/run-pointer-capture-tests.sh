#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/pointer-capture-tests"
module_cache="$build_dir/ModuleCache"
mkdir -p "$module_cache"
swiftc -swift-version 6 -warnings-as-errors -framework AppKit \
  -module-cache-path "$module_cache" \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/GamePointerCapture.swift" \
  "$project_dir/Tests/PointerCaptureTests/main.swift"
"$build_dir/tests"
