#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
module_dir="$1"
library_dir="$2"
target="$3"
shift 3
compatibility=()
[[ "$target" == x86_64-* ]] && compatibility=(-runtime-compatibility-version none)
swiftc -swift-version 6 "${compatibility[@]}" "$@" -target "$target" -parse-as-library \
  -emit-module -emit-library -module-name LemmingsGameArt \
  -I "$module_dir" -L "$library_dir" -lNxlvKit \
  -emit-module-path "$module_dir/LemmingsGameArt.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libLemmingsGameArt.dylib \
  -o "$library_dir/libLemmingsGameArt.dylib" "$project_dir"/Sources/LemmingsGameArt/*.swift
