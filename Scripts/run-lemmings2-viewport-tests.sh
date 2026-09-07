#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
mkdir -p "$project_dir/.build/l2-viewport-tests"
swiftc -swift-version 6 -warnings-as-errors \
  "$project_dir/Sources/NxlvKit/Lemmings2Viewport.swift" \
  "$project_dir/Tests/Lemmings2ViewportTests/main.swift" \
  -o "$project_dir/.build/l2-viewport-tests/ViewportTests"
"$project_dir/.build/l2-viewport-tests/ViewportTests"
