#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/hint-export"
data_dir="${1:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/lemmings_dos_1991-07-30}"
mkdir -p "$build_dir/modules"
cd "$project_dir"
python3 Tools/SolutionReplays/generate.py --check
engine_fingerprint="$(python3 Tools/TrolleyVerification/catalogue.py fingerprint)"
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" Tools/LevelHints/main.swift -o "$build_dir/export"
"$build_dir/export" "$data_dir" Resources/Trolley Resources/Hints/classic.json "$engine_fingerprint"
