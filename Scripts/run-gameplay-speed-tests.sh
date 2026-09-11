#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/gameplay-speed-tests"
mkdir -p "$build_dir"
swiftc -swift-version 6 -o "$build_dir/SpeedTests" \
  "$project_dir/Sources/NxlvKit/GameplaySpeed.swift" "$project_dir/Tests/GameplaySpeedTests/main.swift"
"$build_dir/SpeedTests"
