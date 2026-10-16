#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-solver-decision-tests"
mkdir -p "$build_dir"

swiftc -swift-version 6 -warnings-as-errors \
  "$project_dir/Tools/ClassicSolver/DecisionOffers.swift" \
  "$project_dir/Tests/ClassicSolverTests/main.swift" \
  -o "$build_dir/DecisionOffers"

"$build_dir/DecisionOffers"
