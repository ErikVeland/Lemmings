#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/nxlv-corpus-diagnostics"

if (( $# != 2 )); then
  print -u2 "Usage: $0 <levels-directory> <styles-directory>"
  exit 2
fi

mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir"/Sources/NxlvKit/*.swift

swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/NxlvCorpusDiagnostics" \
  "$project_dir/Tests/NxlvCorpusDiagnostics/main.swift"

"$build_dir/NxlvCorpusDiagnostics" "$1" "$2"
