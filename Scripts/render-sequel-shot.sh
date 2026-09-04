#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/sequel-shot"
if (( $# < 2 || $# > 5 )); then
  echo "Usage: zsh Scripts/render-sequel-shot.sh DATA_ROOT OUTPUT.png [--sprites|--level=N] [--object=ID] [--frame=N] (L2: 0..119, 904/906/908/910; L3: 1..999, object options)" >&2
  exit 2
fi
mkdir -p "$build_dir/modules"
swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/SequelBinary.swift" \
  "$project_dir"/Sources/NxlvKit/Lemmings2*.swift \
  "$project_dir"/Sources/NxlvKit/Lemmings3*.swift
swiftc -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/SequelProbe" "$project_dir/Tools/SequelProbe/main.swift"
"$build_dir/SequelProbe" "$@"
