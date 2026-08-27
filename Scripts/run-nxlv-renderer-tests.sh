#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/.build/nxlv-renderer-tests"
mkdir -p "$build_dir/modules"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -emit-module -emit-library \
  -module-name NxlvKit \
  -emit-module-path "$build_dir/modules/NxlvKit.swiftmodule" \
  -Xlinker -install_name -Xlinker @rpath/libNxlvKit.dylib \
  -o "$build_dir/libNxlvKit.dylib" \
  "$project_dir/Sources/NxlvKit/NxlvDocument.swift" \
  "$project_dir/Sources/NxlvKit/NxlvTypes.swift" \
  "$project_dir/Sources/NxlvKit/NxlvLevel.swift" \
  "$project_dir/Sources/NxlvKit/NxlvStyleResolver.swift" \
  "$project_dir/Sources/NxlvKit/NxlvRenderer.swift"

swiftc -swift-version 6 -warnings-as-errors -parse-as-library \
  -I "$build_dir/modules" -L "$build_dir" -lNxlvKit \
  -Xlinker -rpath -Xlinker "$build_dir" \
  -o "$build_dir/NxlvRendererTests" \
  "$project_dir/Tests/NxlvRendererTests/main.swift"

"$build_dir/NxlvRendererTests"
