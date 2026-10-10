#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/precision-zoom-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -warnings-as-errors -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/NxlvKit/PrecisionZoomLedger.swift" \
  "$project_dir/Sources/NxlvKit/PrecisionZoomLens.swift" \
  "$project_dir/Sources/NxlvKit/PrecisionZoomScrollGesture.swift" \
  "$project_dir/Tests/PrecisionZoomTests/main.swift" \
  -o "$build_dir/tests"
"$build_dir/tests"
