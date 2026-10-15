#!/bin/zsh
# Replay every retained standalone and carried L3 fixture, including after failures.
set -euo pipefail
project_dir="${0:A:h:h}"
library_dir="${L3_TEST_LIBRARY_DIR:-$project_dir/.build/local/$(uname -m)}"
build_dir="$project_dir/.build/l3-fixture-audit"
mkdir -p "$build_dir"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -I "$library_dir/modules" -L "$library_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$library_dir" -o "$build_dir/Audit" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Completion/Audit.swift
"$build_dir/Audit" "${1:-$build_dir/report.json}"
