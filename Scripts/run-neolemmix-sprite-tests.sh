#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/neolemmix-sprite-tests"
mkdir -p "$build_dir/modules"
cd "$project_dir"
swiftc -O -swift-version 6 -warnings-as-errors -parse-as-library -emit-module -emit-library \
  -module-name NxlvKit -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" Sources/NxlvKit/*.swift
swiftc -O -swift-version 6 -warnings-as-errors \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -framework AppKit -framework ImageIO \
  -Xlinker -rpath -Xlinker "$build_dir" \
  Sources/LemmingsLocal/NeoLemmixSpriteSet.swift Tests/NeoLemmixSpriteTests/main.swift \
  -o "$build_dir/tests"
"$build_dir/tests" "$@"
