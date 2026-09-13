#!/bin/zsh
# Builds the Lemmings 2 solver sources with their tests and runs them.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l2-solver-tests"
cd "$project_dir"
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
solver=(Tools/Lemmings2Solver/*.swift(N))
solver=("${(@)solver:#*/main.swift}")
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  "${solver[@]}" Tests/Lemmings2SolverTests/*.swift -o "$build_dir/SolverTests"
"$build_dir/SolverTests"
