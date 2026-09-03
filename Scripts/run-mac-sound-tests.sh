#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/mac-sound-tests"
image="${1:-$project_dir/Sources/Ports/lemmings_1_5_2/Lemmings_1_5_2.dsk}"
if [[ ! -f "$image" ]]; then
  print "No Mac disk image at $image"
  exit 0
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
  -o "$build_dir/MacSoundTests" "$project_dir/Tests/ClassicMacSoundTests/main.swift"
"$build_dir/MacSoundTests" "$image"
