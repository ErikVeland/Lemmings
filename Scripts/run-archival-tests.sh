#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/archival-tests"

mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -parse-as-library \
  -module-cache-path "$build_dir/ModuleCache" \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib -Xlinker -w \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 \
  -module-cache-path "$build_dir/ModuleCache" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" -Xlinker -w \
  -o "$build_dir/ArchivalTests" \
  "$project_dir/Tests/ArchivalTests/main.swift"

"$build_dir/ArchivalTests"
