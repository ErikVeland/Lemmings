#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-dos-rewind-tests"
classic_data_dir="${1:-$project_dir/Content/lemming1.pc}"
if [[ "$classic_data_dir" != --synthetic && ! -d "$classic_data_dir" ]]; then
  print -u2 "Classic data directory does not exist: $classic_data_dir"
  exit 2
fi
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/ClassicDOSRewindTests" \
  "$project_dir/Tests/ClassicDOSRewindTests/main.swift"
"$build_dir/ClassicDOSRewindTests" "$classic_data_dir"
