#!/bin/zsh
# Builds the Lemmings 3 route solver and searches the named levels.
# Usage: zsh Scripts/solve-lemmings3-levels.sh <level number>... | missing [--budget SECONDS] [--beam N]
#        [--fewer-inputs-first] [--promote] [--out DIR]
# A route counts only after two replays agree. --promote writes it into
# Tests/Lemmings3CompletionTests/Fixtures when it keeps more lemmings than the existing route.
# Then run python3 Tools/CampaignCompletion/report.py and Scripts/verify-l3-completion.sh.
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/l3-solver"
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
  Tools/Lemmings3Completion/Replay.swift Tools/Lemmings3Solver/*.swift -o "$build_dir/solver"
exec "$build_dir/solver" "$@"
