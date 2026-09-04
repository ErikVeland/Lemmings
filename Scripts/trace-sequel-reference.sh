#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-shot"
if (( $# != 3 )); then
  echo "Usage: zsh Scripts/trace-sequel-reference.sh L2_ROOT STYLE RAW_RGB24" >&2
  exit 2
fi
mkdir -p "$build_dir/modules"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/SequelBinary.swift" \
  "$project_dir"/Sources/NxlvKit/Lemmings2*.swift \
  "$project_dir"/Sources/NxlvKit/Lemmings3*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/SequelTrace" "$project_dir/Tools/SequelTrace/main.swift"
"$build_dir/SequelTrace" "$@"
