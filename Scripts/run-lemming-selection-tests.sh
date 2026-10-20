#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/lemming-selection-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -target "$(uname -m)-apple-macos12.3" -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" \
  "$project_dir/Sources/LemmingsGameArt/LemmingSelectionRenderer.swift" \
  "$project_dir/Tests/LemmingSelectionTests/main.swift" -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$build_dir/plumbob.png"
