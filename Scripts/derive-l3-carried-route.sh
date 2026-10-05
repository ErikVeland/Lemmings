#!/bin/zsh
# Reuse a verified L3 route at a carried population, then replay the result twice.
# Usage: zsh Scripts/derive-l3-carried-route.sh LEVEL POPULATION SOURCE_FIXTURE OUTPUT_CANDIDATE
set -euo pipefail
if (( $# != 4 )); then
  print -u2 'Usage: derive-l3-carried-route.sh LEVEL POPULATION SOURCE_FIXTURE OUTPUT_CANDIDATE'
  exit 2
fi
project_dir="${0:A:h:h}"
library_dir="${L3_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/l3-carried-derivation"
mkdir -p "$build_dir"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Derive" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/Derive.swift
"$build_dir/Derive" "$@"
