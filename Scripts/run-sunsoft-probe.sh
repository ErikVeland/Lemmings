#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sunsoft-probe"
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -O -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -O -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -Xlinker -w \
  -o "$build_dir/SunsoftProbe" "$project_dir/Tools/SunsoftProbe/main.swift"
cd "$project_dir"
"$build_dir/SunsoftProbe" "$@"
