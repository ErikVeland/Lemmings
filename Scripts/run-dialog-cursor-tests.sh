#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/dialog-cursor-tests"
mkdir -p "$build_dir/ModuleCache"
swiftc -swift-version 6 -warnings-as-errors -framework AppKit \
  -module-cache-path "$build_dir/ModuleCache" \
  -o "$build_dir/tests" \
  "$project_dir/Sources/LemmingsLocal/DialogKeyboardNavigation.swift" \
  "$project_dir/Sources/LemmingsLocal/GameCursor.swift" \
  "$project_dir/Tests/DialogCursorTests/main.swift"
"$build_dir/tests"
