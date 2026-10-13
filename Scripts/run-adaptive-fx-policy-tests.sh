#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/adaptive-fx-policy-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/LemmingsGameArt/AdaptiveFXQuality.swift" \
  "$project_dir/Sources/LemmingsGameArt/AdaptiveFXPerformance.swift" \
  "$project_dir/Tests/AdaptiveFXPolicyTests/main.swift" -o "$build_dir/tests"
"$build_dir/tests"
