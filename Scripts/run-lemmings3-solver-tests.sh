#!/bin/zsh
# Builds the Lemmings 3 solver sources with their focused tests.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l3-solver-tests"
cd "$project_dir"
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Solver/Search.swift \
  Tests/Lemmings3SolverTests/main.swift -o "$build_dir/SolverTests"
"$build_dir/SolverTests"
