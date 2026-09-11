#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/pointer-capture-tests"
mkdir -p "$build_dir"
swiftc -swift-version 6 -warnings-as-errors -framework AppKit \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/GamePointerCapture.swift" \
  "$project_dir/Tests/PointerCaptureTests/main.swift"
"$build_dir/tests"
