#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/failure-mood-render-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -parse-as-library -module-cache-path "$build_dir/ModuleCache" \
    "$project_dir/Sources/LemmingsGameArt/FailureMoodArt.swift" \
    "$project_dir/Sources/LemmingsGameArt/CRTShaders.swift" \
    "$project_dir/Sources/LemmingsGameArt/CRTSettings.swift" \
    "$project_dir/Tests/MobileFailureMoodTests/main.swift" -o "$build_dir/tests"
python3 "$project_dir/Tools/UITestRunner/run.py" "$build_dir/tests" "$project_dir"
