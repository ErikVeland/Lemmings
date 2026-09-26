#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/failure-mood-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -warnings-as-errors -framework AppKit \
  -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/LemmingsLocal/FailureMood.swift" \
  "$project_dir/Tests/FailureMoodTests/main.swift" \
  -o "$build_dir/tests"
"$build_dir/tests"
