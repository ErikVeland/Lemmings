#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/difficulty-diagnostics"
mkdir -p "$build_dir/modules" "$build_dir/source"
# Compile a coherent copy when another local task is editing engine sources.
cp "$project_dir"/Sources/NxlvKit/*.swift "$build_dir/source/"
shasum -a 256 "$build_dir"/source/*.swift > "$build_dir/source-manifest.sha256"
export DIFFICULTY_SIMULATION_REVISION="$(shasum -a 256 "$build_dir/source-manifest.sha256" | cut -d ' ' -f 1)"
swiftc -O -swift-version 6 -parse-as-library -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$build_dir"/source/*.swift
swiftc -O -swift-version 6 -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/DifficultyDiagnostics" \
  "$project_dir/Tools/DifficultyDiagnostics/main.swift"
"$build_dir/DifficultyDiagnostics" "$@"
if (( $# >= 7 )); then
  swiftc -O -swift-version 6 -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
    -Xlinker -rpath -Xlinker "$build_dir" -o "$build_dir/OfficialDifficultyDiagnostics" \
    "$project_dir/Tools/DifficultyDiagnostics/Official.swift"
  "$build_dir/OfficialDifficultyDiagnostics" "$6" "$7" "$4/profiles.json" "$4/combined"
fi
