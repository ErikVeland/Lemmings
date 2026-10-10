#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-data-tests"
module_cache="$build_dir/ModuleCache"
mkdir -p "$build_dir/modules" "$module_cache"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -module-cache-path "$module_cache" \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -module-cache-path "$module_cache" \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/SequelDataTests" "$project_dir/Tests/SequelDataTests/main.swift"
"$build_dir/SequelDataTests" "$project_dir/Sources/Ports/Lemm2" "$project_dir/Sources/Ports/LEM3CD"
