#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-dos-solvability-probe"
classic_data_dir="${1:-$project_dir/Content/lemming1.pc}"

if [[ ! -d "$classic_data_dir" ]]; then
  print -u2 "Classic data directory does not exist: $classic_data_dir"
  exit 2
fi

mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library -O \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 -warnings-as-errors -O \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/ClassicDOSSolvabilityProbe" \
  "$project_dir/Tests/ClassicDOSSolvabilityProbe/main.swift"

"$build_dir/ClassicDOSSolvabilityProbe" "$classic_data_dir"
