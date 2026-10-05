#!/bin/zsh
set -euo pipefail
project_dir="/Users/veland/.codex/worktrees/release-1-7-9/Lemmings"
cd "$project_dir"
build_dir="$project_dir/.build/arcade"
mkdir -p "$build_dir/modules"
test_optimisation="${ARCADE_TEST_OPTIMISATION:--O}"
sparkle_framework="$(zsh "$project_dir/Scripts/ensure-sparkle.sh")"
sparkle_framework_dir="${sparkle_framework:h}"
library_dir="$project_dir/.build/release-1.8/audit/library"
sources=(Sources/LemmingsLocal/*.swift)
sources=("${(@)sources:#*/main.swift}")
swiftc "$test_optimisation" -swift-version 6 -target "$(uname -m)-apple-macos12.3" \
  -I "$library_dir/modules" -L "$library_dir" -lNxlvKit -Xlinker -rpath -Xlinker "$library_dir" \
  -F "$sparkle_framework_dir" -framework Sparkle -Xlinker -rpath -Xlinker "$sparkle_framework_dir" \
  -framework AppKit -framework AVFoundation -framework Metal -framework QuartzCore \
  -o "$build_dir/arcade-tests" "${sources[@]}" .build/release-1.8/arcade-fixture/main.swift
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/arcade-tests"
