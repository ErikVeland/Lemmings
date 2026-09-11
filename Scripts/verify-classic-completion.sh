#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/classic-completion/check"
mode="${1:-verify}"
data_dir="${2:-$project_dir/.build/local/Ultimate Lemmings.app/Contents/Resources/Ports/lemmings_dos_1991-07-30}"
mkdir -p "$build_dir/modules"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Tools/ClassicCompletion/main.swift -o "$build_dir/verify"
"$build_dir/verify" "$mode" "$data_dir" "${@:3}"
