#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/adf-tests"
mkdir -p "$build_dir/modules"

image="${1:-}"
if [[ -z "$image" ]]; then
  for candidate in "$project_dir"/Sources/Ports/holiday_adf/*.adf(N); do
    image="$candidate"
    break
  done
fi
if [[ -z "$image" || ! -f "$image" ]]; then
  print "No .adf image found. Pass one explicitly."
  exit 0
fi

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" "$project_dir"/Sources/NxlvKit/*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/ADFTests" "$project_dir/Tests/ClassicADFTests/main.swift"
"$build_dir/ADFTests" "$image"
