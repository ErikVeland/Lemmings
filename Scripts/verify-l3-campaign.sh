#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
library_dir="${L3_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/l3-campaign"
mkdir -p "$build_dir"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Verify" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/Campaign.swift
"$build_dir/Verify" "$@"
